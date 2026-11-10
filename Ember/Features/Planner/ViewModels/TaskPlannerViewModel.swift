import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TaskPlannerViewModel {
    var draftTaskTitle = ""
    var draftGoalID: UUID?
    var draftNotes = ""

    var canSaveTask: Bool {
        !trimmedTitle.isEmpty && draftGoalID != nil
    }

    private var trimmedTitle: String {
        draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func prepareEditor(for task: LearningTask?, goals: [LearningGoal]) {
        draftTaskTitle = task?.title ?? ""
        draftNotes = task?.notes ?? ""
        draftGoalID = task?.goalID ?? goals.first?.id
    }

    func saveTask(_ task: LearningTask?, goals: [LearningGoal], in context: ModelContext) throws {
        let title = trimmedTitle
        guard !title.isEmpty else { throw SaveError.emptyTitle }
        guard let goalID = draftGoalID,
              goalID == task?.goalID || goals.contains(where: { $0.id == goalID }) else {
            throw SaveError.unavailableGoal
        }

        let notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let task {
            task.title = title
            task.goalID = goalID
            task.notes = notes
        } else {
            context.insert(LearningTask(goalID: goalID, title: title, notes: notes))
        }
        try persist(in: context)
    }

    func toggleCompletion(of task: LearningTask, in context: ModelContext) throws {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        try persist(in: context)
    }

    func deleteTask(_ task: LearningTask, in context: ModelContext) throws {
        context.delete(task)
        try persist(in: context)
    }

    func completedCount(in tasks: [LearningTask]) -> Int {
        tasks.filter(\.isCompleted).count
    }

    // MARK: - Goal grouping

    /// Tasks that belong to one goal, oldest first so the checklist reads in the order it was planned.
    func tasks(for goalID: UUID, in tasks: [LearningTask]) -> [LearningTask] {
        tasks
            .filter { $0.goalID == goalID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The next unfinished task within one goal.
    func nextTask(for goalID: UUID, in tasks: [LearningTask]) -> LearningTask? {
        self.tasks(for: goalID, in: tasks).first { !$0.isCompleted }
    }

    /// The first unfinished task, walking goals in order. Used by the "Up next" card.
    func nextTask(across goals: [LearningGoal], in tasks: [LearningTask]) -> (goal: LearningGoal, task: LearningTask)? {
        for goal in goals {
            if let task = nextTask(for: goal.id, in: tasks) {
                return (goal, task)
            }
        }
        return nil
    }

    private func persist(in context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw SaveError.persistenceFailed
        }
    }

    private enum SaveError: LocalizedError {
        case emptyTitle
        case unavailableGoal
        case persistenceFailed

        var errorDescription: String? {
            switch self {
            case .emptyTitle: "Enter a task title."
            case .unavailableGoal: "Choose an available learning goal."
            case .persistenceFailed: "Your changes couldn’t be saved. Please try again."
            }
        }
    }
}
