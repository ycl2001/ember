import Foundation
import Observation

/// Member 2: presentation state for the daily 1–5 check-in.
@MainActor
@Observable
final class EnergyCheckInViewModel {
    var selectedLevel = 3

    var isValidLevel: Bool { (1...5).contains(selectedLevel) }
}
