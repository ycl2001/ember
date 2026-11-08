import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TaskPlannerViewModel {
    var draftTaskTitle = ""
    var draftGoalID: UUID?

    var canSaveTask: Bool {
        !trimmedTitle.isEmpty && draftGoalID != nil
    }

    private var trimmedTitle: String {
        draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func prepareEditor(for task: LearningTask?, goals: [LearningGoal]) {
        draftTaskTitle = task?.title ?? ""
        draftGoalID = task?.goalID ?? goals.first?.id
    }

    func saveTask(_ task: LearningTask?, goals: [LearningGoal], in context: ModelContext) throws {
        let title = trimmedTitle
        guard !title.isEmpty else { throw SaveError.emptyTitle }
        guard let goalID = draftGoalID,
              goalID == task?.goalID || goals.contains(where: { $0.id == goalID }) else {
            throw SaveError.unavailableGoal
        }

        if let task {
            task.title = title
            task.goalID = goalID
        } else {
            context.insert(LearningTask(goalID: goalID, title: title))
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
