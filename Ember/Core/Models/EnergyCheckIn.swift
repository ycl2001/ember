import Foundation
import SwiftData

@Model
final class EnergyCheckIn {
    var id: UUID
    var createdAt: Date
    /// User-reported energy level from 1 (low) to 5 (high).
    var level: Int

    init(id: UUID = UUID(), createdAt: Date = .now, level: Int) {
        self.id = id
        self.createdAt = createdAt
        self.level = min(5, max(1, level))
    }
}
