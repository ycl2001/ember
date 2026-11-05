import Foundation
import SwiftData

@Model
final class LearningGoal {
    var id: UUID
    var topic: String
    var createdAt: Date

    init(id: UUID = UUID(), topic: String, createdAt: Date = .now) {
        self.id = id
        self.topic = topic
        self.createdAt = createdAt
    }
}
