import Foundation
import SwiftData

@Model
final class LearningTask {
    var id: UUID
    /// References LearningGoal.id. Simple IDs avoid cross-feature relationship conflicts this week.
    var goalID: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(), goalID: UUID, title: String, isCompleted: Bool = false,
         createdAt: Date = .now, completedAt: Date? = nil) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
