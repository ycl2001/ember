
import Foundation
import Observation

@MainActor
@Observable
final class AnalyticsViewModel {
    // MARK: - Period Filtering
    enum Period: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }

    var period: Period = .weekly
    var selectedRange: DateInterval = AnalyticsViewModel.defaultRange(for: .weekly)

    static func defaultRange(for period: Period) -> DateInterval {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .daily:
            let start = cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .weekly:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let weekStart = cal.date(from: comps) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 7, to: weekStart) ?? now
            return DateInterval(start: weekStart, end: end)
        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: now)
            let monthStart = cal.date(from: comps) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .month, value: 1, to: monthStart) ?? now
            return DateInterval(start: monthStart, end: end)
        }
    }

    func updatePeriod(_ new: Period) {
        period = new
        selectedRange = Self.defaultRange(for: new)
    }

    // MARK: - Metrics
    func completedTaskCount(in tasks: [LearningTask], during range: DateInterval) -> Int {
        tasks.filter { task in
            guard task.isCompleted else { return false }
            if let finished = (task as AnyObject).value(forKey: "completedAt") as? Date {
                return range.contains(finished)
            }
            // If you don’t track completedAt, fallback to included for now:
            return true
        }.count
    }

    func sessionsCount(in sessions: [FocusSession], during range: DateInterval) -> Int {
        sessions.filter { s in
            if let end = (s as AnyObject).value(forKey: "endedAt") as? Date {
                return range.contains(end)
            }
            return false
        }.count
    }

    func reflectionsInRange(_ reflections: [EnergyRecord], during range: DateInterval) -> [EnergyRecord] {
        reflections.filter { range.contains($0.createdAt) }
    }

    func netReportedEnergyChange(in reflections: [EnergyRecord]) -> Int {
        reflections.reduce(0) { $0 + $1.energySpent }
    }

    func averageEnergySpentPerWeek(in reflections: [EnergyRecord]) -> Double? {
        guard !reflections.isEmpty else { return nil }
        let net = Double(netReportedEnergyChange(in: reflections))
        // For weekly, just return net/1; for daily/monthly, adjust as needed
        return net
    }

    // MARK: - Chart Series
    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let energy: Double
        let tasksCompleted: Int
    }

    // Build smoothed day-level points over the selected range
    func chartPoints(tasks: [LearningTask], reflections: [EnergyRecord], during range: DateInterval) -> [ChartPoint] {
        let cal = Calendar.current
        // Group reflections per day avg energy delta
        let reflectionsByDay = Dictionary(grouping: reflectionsInRange(reflections, during: range)) {
            cal.startOfDay(for: $0.createdAt)
        }
        let energyByDay: [Date: Double] = reflectionsByDay.mapValues { items in
            let avg = items.map { Double($0.energySpent) }.reduce(0, +) / Double(items.count)
            return avg
        }

        // Group tasks completed per day
        let completedTasks = tasks.filter { $0.isCompleted }
        let tasksByDay = Dictionary(grouping: completedTasks) { task -> Date in
            if let finished = (task as AnyObject).value(forKey: "completedAt") as? Date {
                return cal.startOfDay(for: finished)
            }
            return Date.distantPast
        }

        // Iterate days in range
        var points: [ChartPoint] = []
        var day = cal.startOfDay(for: range.start)
        let endDay = cal.startOfDay(for: range.end)
        while day < endDay {
            let energy = energyByDay[day] ?? 0
            let taskCount = tasksByDay[day]?.count ?? 0
            points.append(ChartPoint(date: day, energy: energy, tasksCompleted: taskCount))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? endDay
        }
        return points
    }

    // MARK: - Formatting Helpers
    func rangeTitle(_ range: DateInterval) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return "\(df.string(from: range.start)) – \(df.string(from: range.end.addingTimeInterval(-1)))"
    }

    func calibrationBadgeText() -> String { "Calibrated" }
    func termText() -> String { "Fall Sem Wk 6" } // replace with your term logic
}

