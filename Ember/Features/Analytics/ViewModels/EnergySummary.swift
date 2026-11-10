import Foundation

/// Plain-Swift weekly summary of EnergyCheckIn records.
/// All the maths happens here; the AI model only turns the result into friendly wording.
/// Suggested location: Features/Analytics/ViewModels/EnergySummary.swift
struct EnergySummary {

    enum Trend: String {
        case rising, falling, steady, unclear
    }

    struct Bucket: Identifiable {
        let name: String          // "Morning", "Afternoon", ...
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

    /// The AI only runs when there is enough to say something real.
    var hasEnoughData: Bool { checkInCount >= 5 && activeDays >= 3 }

    // MARK: Build from SwiftData records

    static func make(
        from checkIns: [EnergyCheckIn],
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> EnergySummary {
        let start = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        let recent = checkIns
            .filter { $0.createdAt >= start && $0.createdAt <= now }
            .sorted { $0.createdAt < $1.createdAt }

        let count = recent.count
        let average = count == 0 ? 0 : Double(recent.map(\.level).reduce(0, +)) / Double(count)
        let activeDays = Set(recent.map { calendar.startOfDay(for: $0.createdAt) }).count

        // Feeling mix, using the same mapping as the Today picker.
        var gentle = 0, steady = 0, high = 0
        for item in recent {
            switch item.level {
            case ...2: gentle += 1
            case 3: steady += 1
            default: high += 1
            }
        }

        // Time-of-day buckets.
        let grouped = Dictionary(grouping: recent) { bucketName(for: $0.createdAt, calendar: calendar) }
        let order = ["Morning", "Afternoon", "Evening", "Night"]
        let buckets: [Bucket] = order.compactMap { name in
            guard let items = grouped[name], !items.isEmpty else { return nil }
            let avg = Double(items.map(\.level).reduce(0, +)) / Double(items.count)
            return Bucket(name: name, count: items.count, averageLevel: avg)
        }

        // Only call a window "best" if it has at least 2 check-ins behind it.
        let best = buckets
            .filter { $0.count >= 2 }
            .max { ($0.averageLevel, Double($0.count)) < ($1.averageLevel, Double($1.count)) }

        return EnergySummary(
            periodDays: days,
            checkInCount: count,
            activeDays: activeDays,
            averageLevel: average,
            gentleCount: gentle,
            steadyCount: steady,
            highFocusCount: high,
            buckets: buckets,
            bestBucket: best,
            trend: trend(for: recent)
        )
    }

    // MARK: Helpers

    private static func bucketName(for date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Night"
        }
    }

    /// Compares the average of the first half of the week with the second half.
    private static func trend(for sorted: [EnergyCheckIn]) -> Trend {
        guard sorted.count >= 4 else { return .unclear }
        let mid = sorted.count / 2
        let first = sorted[..<mid].map(\.level)
        let second = sorted[mid...].map(\.level)
        let firstAvg = Double(first.reduce(0, +)) / Double(first.count)
        let secondAvg = Double(second.reduce(0, +)) / Double(second.count)
        let diff = secondAvg - firstAvg
        if diff >= 0.5 { return .rising }
        if diff <= -0.5 { return .falling }
        return .steady
    }

    // MARK: Text for the model and for the non-AI fallback

    /// Compact text that goes into the prompt.
    var promptText: String {
        var lines = [
            "Period: last \(periodDays) days",
            "Check-ins: \(checkInCount) on \(activeDays) different days",
            "Feeling mix: Gentle \(gentleCount), Steady \(steadyCount), High Focus \(highFocusCount)",
            "Average energy (1-5): \(String(format: "%.1f", averageLevel))"
        ]
        if let best = bestBucket {
            lines.append("Strongest time of day: \(best.name) (average \(String(format: "%.1f", best.averageLevel)), \(best.count) check-ins)")
        }
        if !buckets.isEmpty {
            let list = buckets
                .map { "\($0.name) \(String(format: "%.1f", $0.averageLevel)) (\($0.count))" }
                .joined(separator: ", ")
            lines.append("Energy by time of day: \(list)")
        }
        lines.append("Trend across the period: \(trend.rawValue)")
        return lines.joined(separator: "\n")
    }

    /// Rule-based sentence shown when AI is unavailable or there is too little data.
    var fallbackText: String {
        guard hasEnoughData else {
            return "Keep checking in. After a few more days Ember can show your energy pattern."
        }
        if let best = bestBucket {
            return "Your energy tends to be highest in the \(best.name.lowercased())."
        }
        return "You've logged \(checkInCount) check-ins this week. Keep going to reveal your pattern."
    }
}
