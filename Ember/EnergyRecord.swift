import Foundation
import SwiftData

@Model
final class EnergyRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var energyBefore: Int
    var energyAfter: Int
    var notes: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        energyBefore: Int,
        energyAfter: Int,
        notes: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.energyBefore = energyBefore
        self.energyAfter = energyAfter
        self.notes = notes
    }

    // Positive = energy decreased (before > after). Negative = energy increased.
    var energySpent: Int { energyBefore - energyAfter }
}
