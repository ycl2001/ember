import Foundation
import SwiftData

@Model
final class LearningTask {
    var id: UUID
    /// References LearningGoal.id. Simple IDs avoid cross-feature relationship conflicts this week.
    var goalID: UUID
    var title: String
    /// Optional learner notes (pages, links, reminders). The default keeps existing saved tasks valid.
    var notes: String = ""
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    /// True only for checklist items the learner explicitly accepted from an on-device AI suggestion.
    var isAIGenerated: Bool = false

    init(id: UUID = UUID(), goalID: UUID, title: String, notes: String = "",
         isCompleted: Bool = false, createdAt: Date = .now, completedAt: Date? = nil,
         isAIGenerated: Bool = false) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isAIGenerated = isAIGenerated
    }
}
