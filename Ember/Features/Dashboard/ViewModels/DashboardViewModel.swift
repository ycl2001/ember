import Foundation
import Observation

/// Presentation logic for DashboardView. SwiftData fetching remains in the View via @Query.
@MainActor
@Observable
final class DashboardViewModel {
    func completedCount(in tasks: [LearningTask]) -> Int {
        tasks.filter(\.isCompleted).count
    }
}
