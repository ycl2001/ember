import Foundation
import Observation

/// Member 3: task input validation and checklist progress calculations.
@MainActor
@Observable
final class TaskPlannerViewModel {
    var draftTaskTitle = ""

    var canCreateTask: Bool {
        !draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func completedCount(in tasks: [LearningTask]) -> Int {
        tasks.filter(\.isCompleted).count
    }
}
