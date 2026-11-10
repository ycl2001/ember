import Foundation
import SwiftData

@Model
final class LearningGoal {
    var id: UUID
    var topic: String
    /// Optional organisational category. Nil keeps existing and "Other" goals uncategorised.
    var category: String? = nil
    var createdAt: Date

    init(id: UUID = UUID(), topic: String, category: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.topic = topic
        self.category = category
        self.createdAt = createdAt
    }
}
