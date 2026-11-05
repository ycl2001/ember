import Foundation
import Observation

/// Member 2: presentation state and validation for learning goal onboarding.
@MainActor
@Observable
final class OnboardingViewModel {
    var topic = ""

    var canCreateGoal: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
