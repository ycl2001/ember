import Foundation
import Observation

/// Member 5: reflection form state, input validation and energy-change logic.
@MainActor
@Observable
final class ReflectionViewModel {
    var energyBefore = 3
    var energyAfter = 3
    var notes = ""

    /// Positive = self-reported energy decrease. Negative = increase.
    var energySpent: Int { energyBefore - energyAfter }

    var canSave: Bool {
        (1...5).contains(energyBefore) && (1...5).contains(energyAfter)
    }
}
