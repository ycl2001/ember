///WeeklyAnalysis

import Foundation

// MARK: - Config
enum WeeklyAnalysisConfig {
    /// Set to true to always show the built-in sample week, even when you have real data.
    static let alwaysUseSampleData = false
}

// MARK: - Model
struct WeeklyAnalysis {
    struct Day: Identifiable {
        var date: Date
        var label: String   // e.g., "Mon", "Tue"
        var tasks: Int
        var energy: Double  // average self-reported energy spent (0 = none)
        var isPeak: Bool
        var id: Date { date }
    }

    var isSample: Bool
    var headline: String
    var summary: String
    var days: [Day]
}

// MARK: - Sample data
extension WeeklyAnalysis {
    static var sample: WeeklyAnalysis {
        let calendar = Calendar.current
        
        // Get the Monday of the current week
        guard let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            fatalError("Could not compute Monday of the current week")
        }
        
        let tasksArr = [2, 3, 4, 3, 2, 0, 0]
        let energyArr = [3.2, 4.1, 4.4, 3.6, 3.1, 0, 0]
        
        // Get short weekday symbols starting from Monday
        var weekdaySymbols = DateFormatter().shortWeekdaySymbols // Sun ... Sat
        // Rotate array so it starts on Monday
        let sunday = weekdaySymbols.removeFirst()
        weekdaySymbols.append(sunday)
        
        // Build days array
        var days = [Day]()
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: monday) else {
                continue
            }
            let label = weekdaySymbols[i]
            let tasks = tasksArr[i]
            let energy = energyArr[i]
            days.append(Day(date: date, label: label, tasks: tasks, energy: energy, isPeak: false))
        }
        
        // Identify the two peak days (highest tasks, break ties by earlier day)
        let sortedByTasks = days.enumerated().sorted { (lhs, rhs) in
            if lhs.element.tasks == rhs.element.tasks {
                return lhs.offset < rhs.offset
            }
            return lhs.element.tasks > rhs.element.tasks
        }
        let peakIndices = sortedByTasks.prefix(2).map { $0.offset }
        
        for index in peakIndices {
            days[index].isPeak = true
        }
        
        return WeeklyAnalysis(
            isSample: true,
            headline: "Mindful Cadence Peak",
            summary: "This week highlights your peak productivity and energy patterns.",
            days: days
        )
    }
}
