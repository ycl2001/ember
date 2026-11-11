import Testing
import Foundation
import SwiftData
@testable import Ember

/// Regression tests for Member 4's Focus recovery and the Planner changes in PR #16.
/// Serialized because the unfinished-session store uses shared UserDefaults.
@MainActor
@Suite(.serialized)
struct FocusAndPlannerTests {

    // MARK: - Unfinished session recovery

    @Test
    func resumingUsesOnlyFocusedTimeFromTheDraft() throws {
        FocusDraftStore.clear()
        defer { FocusDraftStore.clear() }
        let task = LearningTask(goalID: UUID(), title: "Practice SQL joins")
        // 6 focused seconds, saved a while ago: the time the app was closed must not count.
        FocusDraftStore.save(draft(for: task, focusedSeconds: 6, savedAt: .now.addingTimeInterval(-600)))

        let viewModel = FocusSessionViewModel()
        viewModel.checkForUnfinishedSession(tasks: [task])
        #expect(viewModel.unfinishedDraft?.taskID == task.id)

        viewModel.resumeUnfinished()
        #expect(viewModel.phase == .running)
        #expect(viewModel.elapsedSeconds == 6)
        #expect(viewModel.activeTaskTitle == "Practice SQL joins")
        #expect(viewModel.unfinishedDraft == nil)
        viewModel.discard()
    }

    @Test
    func savingAnUnfinishedSessionPersistsItsFocusedTime() throws {
        FocusDraftStore.clear()
        defer { FocusDraftStore.clear() }
        let container = try makeContainer()
        let task = LearningTask(goalID: UUID(), title: "Deep research")
        container.mainContext.insert(task)
        let savedAt = Date(timeIntervalSince1970: 2_000)
        FocusDraftStore.save(draft(for: task, focusedSeconds: 31, savedAt: savedAt))

        let viewModel = FocusSessionViewModel()
        viewModel.checkForUnfinishedSession(tasks: [task])
        viewModel.finishUnfinished(in: container.mainContext)

        let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.taskID == task.id)
        #expect(sessions.first?.taskTitle == "Deep research")
        #expect(sessions.first?.durationSeconds == 31)
        #expect(sessions.first?.endedAt == savedAt)
        #expect(viewModel.phase == .finished)
        #expect(viewModel.savedSession?.id == sessions.first?.id)
        #expect(FocusDraftStore.load() == nil)
    }

    @Test
    func discardingAnUnfinishedSessionSavesNothing() throws {
        FocusDraftStore.clear()
        defer { FocusDraftStore.clear() }
        let container = try makeContainer()
        let task = LearningTask(goalID: UUID(), title: "Read one chapter")
        container.mainContext.insert(task)
        FocusDraftStore.save(draft(for: task, focusedSeconds: 15, savedAt: .now))

        let viewModel = FocusSessionViewModel()
        viewModel.checkForUnfinishedSession(tasks: [task])
        viewModel.discardUnfinished()

        #expect(viewModel.unfinishedDraft == nil)
        #expect(FocusDraftStore.load() == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<FocusSession>()).isEmpty)
    }

    @Test
    func unfinishedSessionForADeletedTaskIsDropped() {
        FocusDraftStore.clear()
        defer { FocusDraftStore.clear() }
        let deletedTask = LearningTask(goalID: UUID(), title: "Gone")
        FocusDraftStore.save(draft(for: deletedTask, focusedSeconds: 40, savedAt: .now))

        let viewModel = FocusSessionViewModel()
        viewModel.checkForUnfinishedSession(tasks: [])

        #expect(viewModel.unfinishedDraft == nil)
        #expect(FocusDraftStore.load() == nil)
    }

    @Test
    func pausingStopsTheClockAndKeepsADraft() async throws {
        FocusDraftStore.clear()
        defer { FocusDraftStore.clear() }
        let task = LearningTask(goalID: UUID(), title: "Timer check")
        let viewModel = FocusSessionViewModel()
        viewModel.start(task: task)
        try await Task.sleep(for: .milliseconds(1_100))
        viewModel.pause()
        let pausedAt = viewModel.elapsedSeconds

        try await Task.sleep(for: .milliseconds(1_200))
        viewModel.refresh()

        #expect(pausedAt >= 1)
        #expect(viewModel.elapsedSeconds == pausedAt)
        #expect(FocusDraftStore.load()?.taskID == task.id)
        viewModel.discard()
        #expect(FocusDraftStore.load() == nil)
    }

    @Test
    func widgetTracksStartPauseResumeDiscardAndRecovery() {
        FocusDraftStore.clear()
        defer { FocusDraftStore.clear() }
        let task = LearningTask(goalID: UUID(), title: "Widget state")
        let viewModel = FocusSessionViewModel()

        viewModel.start(task: task)
        #expect(FocusWidgetStore.load().status == .running)
        #expect(FocusWidgetStore.load().taskTitle == task.title)

        viewModel.pause()
        #expect(FocusWidgetStore.load().status == .paused)

        viewModel.resume()
        #expect(FocusWidgetStore.load().status == .running)

        viewModel.discard()
        #expect(FocusWidgetStore.load() == .idle)

        FocusDraftStore.save(draft(for: task, focusedSeconds: 42, savedAt: .now))
        viewModel.checkForUnfinishedSession(tasks: [task])
        #expect(FocusWidgetStore.load().status == .paused)
        #expect(FocusWidgetStore.load().pausedSeconds == 42)
    }

    // MARK: - Goals and task notes

    @Test
    func deletingAGoalRemovesOnlyItsTasksAndKeepsPastSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let academic = LearningGoal(topic: "Academic")
        let leisure = LearningGoal(topic: "Leisure")
        let mathematics = LearningTask(goalID: academic.id, title: "Mathematics")
        let programming = LearningTask(goalID: academic.id, title: "Programming")
        let cooking = LearningTask(goalID: leisure.id, title: "Cooking")
        let pastSession = FocusSession(taskID: mathematics.id, endedAt: .now, durationSeconds: 300)
        [academic, leisure].forEach(context.insert)
        [mathematics, programming, cooking].forEach(context.insert)
        context.insert(pastSession)
        try context.save()

        let allTasks = try context.fetch(FetchDescriptor<LearningTask>())
        try TaskPlannerViewModel().deleteGoal(academic, tasks: allTasks, in: context)

        let goals = try context.fetch(FetchDescriptor<LearningGoal>())
        let tasks = try context.fetch(FetchDescriptor<LearningTask>())
        #expect(goals.map(\.topic) == ["Leisure"])
        #expect(tasks.map(\.title) == ["Cooking"])
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.taskTitle == "Mathematics")
    }

    @Test
    func taskNotesSurviveReopeningTheStore() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ember-notes-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let goalID = UUID()

        do {
            let container = try makeContainer(url: url)
            let viewModel = TaskPlannerViewModel()
            let goal = LearningGoal(id: goalID, topic: "Professional")
            container.mainContext.insert(goal)
            viewModel.draftTaskTitle = "Practice SQL joins"
            viewModel.draftNotes = "  Pages 40-58, skip 3.4  "
            viewModel.draftGoalID = goalID
            try viewModel.saveTask(nil, goals: [goal], in: container.mainContext)
            container.mainContext.insert(LearningTask(goalID: goalID, title: "No notes"))
            try container.mainContext.save()
        }

        let reopened = try makeContainer(url: url)
        let tasks = try reopened.mainContext.fetch(
            FetchDescriptor<LearningTask>(sortBy: [SortDescriptor(\.title)])
        )
        #expect(tasks.map(\.title) == ["No notes", "Practice SQL joins"])
        #expect(tasks.first?.notes == "")
        #expect(tasks.last?.notes == "Pages 40-58, skip 3.4")
    }

    // MARK: - Helpers

    private func draft(for task: LearningTask, focusedSeconds: TimeInterval, savedAt: Date) -> FocusSessionDraft {
        FocusSessionDraft(
            taskID: task.id,
            taskTitle: task.title,
            startedAt: savedAt.addingTimeInterval(-focusedSeconds),
            focusedSeconds: focusedSeconds,
            hasReachedMilestone: false,
            milestoneReminderEnabled: true,
            savedAt: savedAt
        )
    }

    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let configuration = url.map { ModelConfiguration(url: $0) }
            ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LearningGoal.self, LearningTask.self, EnergyCheckIn.self,
                FocusSession.self, SessionReflection.self,
            configurations: configuration
        )
    }
}
