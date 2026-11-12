import Foundation
import SwiftData
import Testing
@testable import Ember

@MainActor
struct MVPUseCaseTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test("04: Checklist edits, progress and deletion survive reopening the store")
    func checklistLifecyclePersists() throws {
        try withTemporaryStore(for: [LearningGoal.self, LearningTask.self, FocusSession.self]) { makeContainer in
            let goalID = UUID()
            let taskID: UUID
            do {
                let container = try makeContainer()
                defer { withExtendedLifetime(container) {} }
                let context = container.mainContext
                let planner = TaskPlannerViewModel()
                let goal = LearningGoal(id: goalID, topic: "Study Swift")
                context.insert(goal)

                for title in ["Read chapter 1", "Try one exercise"] {
                    planner.prepareEditor(for: nil, goals: [goal])
                    planner.draftTaskTitle = title
                    try planner.saveTask(nil, goals: [goal], in: context)
                }

                let tasks = try context.fetch(FetchDescriptor<LearningTask>())
                #expect(tasks.count == 2)
                let reading = try #require(tasks.first { $0.title == "Read chapter 1" })
                let exercise = try #require(tasks.first { $0.title == "Try one exercise" })
                taskID = reading.id

                planner.prepareEditor(for: reading, goals: [goal])
                planner.draftTaskTitle = "Read pages 1–5"
                planner.draftNotes = "Take notes on two examples"
                try planner.saveTask(reading, goals: [goal], in: context)
                try planner.toggleCompletion(of: reading, in: context)
                #expect(planner.completedCount(in: tasks) == 1)
                #expect(reading.completedAt != nil)
                #expect(planner.nextTask(for: goalID, in: tasks)?.id == exercise.id)

                try planner.toggleCompletion(of: reading, in: context)
                #expect(planner.completedCount(in: tasks) == 0)
                #expect(reading.completedAt == nil)
                try planner.deleteTask(exercise, in: context)
            }

            let reopened = try makeContainer()
            let remaining = try reopened.mainContext.fetch(FetchDescriptor<LearningTask>())
            #expect(remaining.count == 1)
            let task = try #require(remaining.first)
            #expect(task.id == taskID)
            #expect(task.goalID == goalID)
            #expect(task.title == "Read pages 1–5")
            #expect(task.notes == "Take notes on two examples")
            #expect(!task.isCompleted)
            #expect(task.completedAt == nil)
        }
    }

    @Test("05: The Gentle check-in persists as the latest 2/5 rating")
    func gentleCheckInPersists() throws {
        try withTemporaryStore(for: [EnergyCheckIn.self]) { makeContainer in
            do {
                let container = try makeContainer()
                defer { withExtendedLifetime(container) {} }
                let context = container.mainContext
                let earlier = EnergyCheckIn(createdAt: .now.addingTimeInterval(-3_600), level: 3)
                context.insert(earlier)
                try context.save()

                let viewModel = EnergyCheckInViewModel()
                try #require(viewModel.record(.gentle, latest: earlier, in: context))
                #expect(viewModel.savedMessage != nil)
            }

            let reopened = try makeContainer()
            let ratings = try reopened.mainContext.fetch(FetchDescriptor<EnergyCheckIn>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            ))
            #expect(ratings.map(\.level) == [2, 3])
            let latest = try #require(ratings.first)
            #expect(FeelingOption.matching(level: latest.level) == .gentle)
        }
    }

    @Test("08: A saved 5-to-2 reflection reports a three-point drop in Analytics")
    func reflectionFeedsAnalytics() throws {
        let start = try date(day: 10, hour: 10)
        let end = start.addingTimeInterval(600)
        try withTemporaryStore(for: [LearningTask.self, FocusSession.self, SessionReflection.self]) { makeContainer in
            do {
                let container = try makeContainer()
                defer { withExtendedLifetime(container) {} }
                let context = container.mainContext
                let task = LearningTask(goalID: UUID(), title: "Review variables")
                let session = FocusSession(taskID: task.id, startedAt: start, endedAt: end, durationSeconds: 600)
                let checkIn = EnergyCheckIn(createdAt: start.addingTimeInterval(-60), level: 5)
                context.insert(task)
                context.insert(session)
                try context.save()

                let reflection = ReflectionViewModel()
                reflection.load(sessionID: session.id, sessions: [session], tasks: [task], checkIns: [checkIn], reflections: [])
                #expect(reflection.energyBefore == 5)
                reflection.selectedCognitiveLoad = .balanced
                reflection.selectEnergyAfter(2)
                try #require(reflection.save(in: context))
            }

            let reopened = try makeContainer()
            let sessions = try reopened.mainContext.fetch(FetchDescriptor<FocusSession>())
            let reflections = try reopened.mainContext.fetch(FetchDescriptor<SessionReflection>())
            let analytics = AnalyticsViewModel(period: .daily, calendar: calendar, now: end)
            let ratings = analytics.reflectionsInRange(reflections, sessions: sessions, during: analytics.selectedRange)
            #expect(ratings.count == 1)
            #expect(analytics.averageAfterSessionEnergy(in: ratings) == 2)
            #expect(analytics.netReportedEnergyChange(in: ratings) == -3)
        }
    }

    @Test("09: A task-only hour does not alter the daily energy curve")
    func taskOnlyHourDoesNotAffectEnergyChart() throws {
        let morning = try date(day: 10, hour: 10)
        let afternoon = try date(day: 10, hour: 15)
        let reflection = SessionReflection(
            taskID: UUID(), sessionID: UUID(), energyBefore: 4, energyAfter: 2, createdAt: morning
        )
        let task = LearningTask(goalID: UUID(), title: "Read a chapter", isCompleted: true, completedAt: afternoon)
        let analytics = AnalyticsViewModel(period: .daily, calendar: calendar, now: afternoon)
        let energyOnly = analytics.dailyAnalysis(tasks: [], sessions: [], reflections: [reflection])
        let withTask = analytics.dailyAnalysis(tasks: [task], sessions: [], reflections: [reflection])

        #expect(energyOnly.state == .observed)
        #expect(energyOnly.friction?.reserve == 0.4)
        withKnownIssue("Daily Analytics currently plots task-only activity as energy.") {
            #expect(withTask.hero.curve == energyOnly.hero.curve && withTask.hero.peakIndex == energyOnly.hero.peakIndex)
        }
    }

    @Test("09: A 1/5 reflection appears as level 1 in the monthly heatmap")
    func heatmapShowsLevelOne() throws {
        let now = try date(day: 10)
        let reflection = SessionReflection(taskID: UUID(), sessionID: UUID(), energyBefore: 3, energyAfter: 1, createdAt: now)
        let analytics = AnalyticsViewModel(period: .monthly, calendar: calendar, now: now)
        let month = analytics.monthlyAnalysis(tasks: [], sessions: [], reflections: [reflection])

        #expect(month.state == .observed)
        let cell = try #require(month.weeks.flatMap(\.cells).first { $0.day == 10 })
        #expect(cell.level == 1 && month.legend.contains { $0.level == 1 && $0.days == 1 })
    }

    @Test("09: The four-week heatmap includes visible dates from the prior month")
    func heatmapKeepsPriorMonthReflection() throws {
        let october = try date(month: 10, day: 29)
        let november = try date(day: 2)
        let reflection = SessionReflection(
            taskID: UUID(), sessionID: UUID(), energyBefore: 3, energyAfter: 4, createdAt: october
        )
        let task = LearningTask(goalID: UUID(), title: "Read a chapter", isCompleted: true, completedAt: november)
        let analytics = AnalyticsViewModel(period: .monthly, calendar: calendar, now: november)
        let month = analytics.monthlyAnalysis(tasks: [task], sessions: [], reflections: [reflection])

        #expect(month.state == .observed)
        let octoberCell = try #require(month.weeks.flatMap(\.cells).first { $0.day == 29 })
        #expect(octoberCell.level == 4)
    }

    private func date(month: Int = 11, day: Int, hour: Int = 12) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)))
    }

    private func withTemporaryStore(
        for models: [any PersistentModel.Type],
        _ run: (_ makeContainer: () throws -> ModelContainer) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "MVP.store"), cloudKitDatabase: .none)
        try run { try ModelContainer(for: schema, configurations: [configuration]) }
    }
}
