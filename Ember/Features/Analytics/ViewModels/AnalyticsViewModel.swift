import Foundation
import Observation

/// Member 5: transform persisted sessions/tasks into chart-ready summary values.
@MainActor
@Observable
final class AnalyticsViewModel {
    func completedTaskCount(in tasks: [LearningTask]) -> Int {
        tasks.filter(\.isCompleted).count
    }

    func netReportedEnergyChange(in reflections: [SessionReflection]) -> Int {
        reflections.reduce(0) { $0 + $1.energySpent }
    }
}
