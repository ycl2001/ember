import Foundation
import Observation

/// Reflection form state for a single entry.
/// Energy scale is 1...5. Positive `energySpent` means energy decreased (before > after).
@MainActor
@Observable
final class ReflectionViewModel {
    // MARK: - Form State
    var energyBefore: Int = 3
    var energyAfter: Int = 3
    var notes: String = ""

    // MARK: - Derived
    /// Positive = self-reported energy decrease. Negative = increase.
    var energySpent: Int { energyBefore - energyAfter }

    /// Valid when both energies are within 1...5 inclusive.
    var canSave: Bool {
        (1...5).contains(energyBefore) && (1...5).contains(energyAfter)
    }

    // MARK: - Dependency (Pluggable Persistence)
    /// Provide a save action from the outside (e.g., SwiftData/Core Data / any persistence).
    /// This closure receives sanitized values and can throw on failure.
    private let saveAction: (_ energyBefore: Int, _ energyAfter: Int, _ notes: String, _ createdAt: Date) throws -> Void

    init(
        energyBefore: Int = 3,
        energyAfter: Int = 3,
        notes: String = "",
        saveAction: @escaping (_ energyBefore: Int, _ energyAfter: Int, _ notes: String, _ createdAt: Date) throws -> Void
    ) {
        self.energyBefore = energyBefore
        self.energyAfter = energyAfter
        self.notes = notes
        self.saveAction = saveAction
    }

    // MARK: - Intent
    func reset() {
        energyBefore = 3
        energyAfter = 3
        notes = ""
    }

    /// Validates and persists the reflection via `saveAction`.
    func save() throws {
        guard canSave else { return }
        // Clamp defensively in case external callers bypass UI controls.
        let clampedBefore = min(5, max(1, energyBefore))
        let clampedAfter = min(5, max(1, energyAfter))
        try saveAction(clampedBefore, clampedAfter, notes, Date())
        reset()
    }

    // MARK: - Helper
    /// A short, context-aware prompt to encourage reflection in the UI.
    var reflectionPrompt: String {
        switch energySpent {
        case let x where x >= 2:
            return "Energy decreased notably. What made this task draining?"
        case 1:
            return "Slight energy decrease. Any small friction you noticed?"
        case 0:
            return "No net change. What kept things balanced?"
        case -1:
            return "Slight energy increase. What helped a little?"
        default:
            return "Energy increased. What made this task energizing?"
        }
    }
}
