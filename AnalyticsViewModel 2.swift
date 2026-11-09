import Foundation
import Observation

/// Member 5: transform persisted sessions/tasks into chart-ready summary values.
@MainActor
@Observable
final class AnalyticsViewModel {
    // MARK: - Task Metrics
    func completedTaskCount(in tasks: [LearningTask]) -> Int {
        tasks.filter(\.isCompleted).count
    }

    // MARK: - Energy Metrics (EnergyRecord)
    /// Sum of energySpent across all reflections. Positive means energy decreased overall.
    func netReportedEnergyChange(in reflections: [EnergyRecord]) -> Int {
        reflections.reduce(0) { $0 + $1.energySpent }
    }

    /// Average start energy across reflections (optional helper for future charts).
    func averageStartEnergy(in reflections: [EnergyRecord]) -> Double? {
        guard !reflections.isEmpty else { return nil }
        let sum = reflections.reduce(0) { $0 + $1.energyBefore }
        return Double(sum) / Double(reflections.count)
        }

    /// Average end energy across reflections (optional helper for future charts).
    func averageEndEnergy(in reflections: [EnergyRecord]) -> Double? {
        guard !reflections.isEmpty else { return nil }
        let sum = reflections.reduce(0) { $0 + $1.energyAfter }
        return Double(sum) / Double(reflections.count)
    }

    // MARK: - Simple daily grouping for future charts
    struct DailyEnergyAggregate: Identifiable {
        let id = UUID()
        let day: Date
        let avgSpent: Double
        let count: Int
    }

    func dailyEnergyAggregates(from reflections: [EnergyRecord]) -> [DailyEnergyAggregate] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: reflections) { rec in
            calendar.startOfDay(for: rec.createdAt)
        }
        return grouped.keys.sorted().compactMap { day in
            guard let items = grouped[day], !items.isEmpty else { return nil }
            let avgSpent = items.map { Double($0.energySpent) }.reduce(0, +) / Double(items.count)
            return DailyEnergyAggregate(day: day, avgSpent: avgSpent, count: items.count)
        }
    }
    
    // MARK: - EnergyRecord-based chart helpers
    struct DailyEnergyPoint: Identifiable {
        let id = UUID()
        let day: Date
        let avgDelta: Double
        let count: Int
    }

    /// Groups EnergyRecord by day and computes the average (before - after) per day.
    func dailyEnergySeries(from records: [EnergyRecord]) -> [DailyEnergyPoint] {
        guard !records.isEmpty else { return [] }
        let cal = Calendar.current
        let grouped = Dictionary(grouping: records) { rec in
            cal.startOfDay(for: rec.createdAt)
        }
        let days = grouped.keys.sorted()
        return days.compactMap { day in
            guard let items = grouped[day], !items.isEmpty else { return nil }
            let avg = items.map { Double($0.energySpent) }.reduce(0, +) / Double(items.count)
            return DailyEnergyPoint(day: day, avgDelta: avg, count: items.count)
        }
    }
}
