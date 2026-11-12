import Foundation

struct EnergySummary: Equatable, Hashable {
    enum Trend: String, Equatable, Hashable {
        case rising
        case falling
        case steady
        case unclear
    }

    struct Bucket: Identifiable, Equatable, Hashable {
        let name: String
        let count: Int
        let averageLevel: Double

        var id: String { name }
    }

    let periodDays: Int
    let checkInCount: Int
    let activeDays: Int
    let averageLevel: Double
    let gentleCount: Int
    let steadyCount: Int
    let highFocusCount: Int
    let buckets: [Bucket]
    let bestBucket: Bucket?
    let trend: Trend

    var hasEnoughData: Bool {
        checkInCount >= 5 && activeDays >= 3
    }

    static func make(
        from checkIns: [EnergyCheckIn],
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> EnergySummary {
        let end = now
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        let recent = checkIns
            .filter { $0.createdAt >= start && $0.createdAt <= end }
            .sorted { $0.createdAt < $1.createdAt }
        let count = recent.count
        let average = count == 0 ? 0 : Double(recent.map(\.level).reduce(0, +)) / Double(count)

        var gentle = 0
        var steady = 0
        var highFocus = 0
        for checkIn in recent {
            switch checkIn.level {
            case ...2: gentle += 1
            case 3: steady += 1
            default: highFocus += 1
            }
        }

        let grouped = Dictionary(grouping: recent) { bucketName(for: $0.createdAt, calendar: calendar) }
        let bucketOrder = ["Morning", "Afternoon", "Evening", "Night"]
        let buckets = bucketOrder.compactMap { name -> Bucket? in
            guard let values = grouped[name], !values.isEmpty else { return nil }
            let bucketAverage = Double(values.map(\.level).reduce(0, +)) / Double(values.count)
            return Bucket(name: name, count: values.count, averageLevel: bucketAverage)
        }
        let bestBucket = buckets
            .filter { $0.count >= 2 }
            .max { ($0.averageLevel, $0.count) < ($1.averageLevel, $1.count) }

        return EnergySummary(
            periodDays: days,
            checkInCount: count,
            activeDays: Set(recent.map { calendar.startOfDay(for: $0.createdAt) }).count,
            averageLevel: average,
            gentleCount: gentle,
            steadyCount: steady,
            highFocusCount: highFocus,
            buckets: buckets,
            bestBucket: bestBucket,
            trend: trend(for: recent)
        )
    }

    var promptText: String {
        var lines = [
            "Period: last \(periodDays) days",
            "Check-ins: \(checkInCount) on \(activeDays) different days",
            "Feeling mix: Gentle \(gentleCount), Steady \(steadyCount), High Focus \(highFocusCount)",
            "Average energy (1-5): \(averageLevel.formatted(.number.precision(.fractionLength(1))))"
        ]
        if let bestBucket {
            lines.append(
                "Strongest time of day: \(bestBucket.name) (average \(bestBucket.averageLevel.formatted(.number.precision(.fractionLength(1)))), \(bestBucket.count) check-ins)"
            )
        }
        lines.append("Trend across the period: \(trend.rawValue)")
        return lines.joined(separator: "\n")
    }

    var fallbackText: String {
        guard hasEnoughData else {
            return "Keep checking in. After a few more days Ember can show your weekly energy pattern."
        }
        if let bestBucket {
            return "Your energy tended to be highest in the \(bestBucket.name.lowercased()) this week."
        }
        switch trend {
        case .rising:
            return "Your recorded energy rose across the week. Keep checking in to see whether that pattern continues."
        case .falling:
            return "Your recorded energy eased across the week. Consider planning a gentler first step next week."
        case .steady:
            return "Your recorded energy stayed fairly steady this week."
        case .unclear:
            return "You logged \(checkInCount) check-ins this week. Keep checking in to reveal a clearer pattern."
        }
    }

    private static func bucketName(for date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<22: "Evening"
        default: "Night"
        }
    }

    private static func trend(for sortedCheckIns: [EnergyCheckIn]) -> Trend {
        guard sortedCheckIns.count >= 4 else { return .unclear }
        let midpoint = sortedCheckIns.count / 2
        let first = sortedCheckIns[..<midpoint].map(\.level)
        let second = sortedCheckIns[midpoint...].map(\.level)
        let firstAverage = Double(first.reduce(0, +)) / Double(first.count)
        let secondAverage = Double(second.reduce(0, +)) / Double(second.count)
        let difference = secondAverage - firstAverage
        if difference >= 0.5 { return .rising }
        if difference <= -0.5 { return .falling }
        return .steady
    }
}
