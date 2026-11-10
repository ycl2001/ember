///MonthlyAnalytsis

import Foundation

// MARK: - Config

enum MonthlyAnalysisConfig {
    /// Set to true to always show the built-in sample month, even when you have real data.
    /// (Energy scale is shared with the daily view: see DailyAnalysisConfig.energyScaleMax.)
    static let alwaysUseSampleData = false
}

// MARK: - Model

struct MonthlyAnalysis {
    enum BadgeTone { case mint, peach, grey }

    struct StatCard {
        var value: String
        var unit: String? = nil          // e.g. "/ 5 Scale"
        var caption: String
        var badge: String
        var badgeIcon: String
        var badgeTone: BadgeTone
        var footnote: String
    }

    struct Cell: Identifiable {
        var id: Int
        var day: Int                      // day of month shown under the dot
        var level: Int?                   // 2...5, nil = nothing logged
    }

    struct Week: Identifiable {
        var label: String                 // "W1"
        var cells: [Cell]                 // 7 cells, Monday first
        var id: String { label }
    }

    struct LegendItem: Identifiable {
        var level: Int
        var name: String
        var days: Int
        var id: Int { level }
    }

    struct Insight: Identifiable {
        enum Tone { case mint, peach }
        var icon: String
        var tone: Tone
        var title: String
        var body: String                  // supports **bold**
        var id: String { title }
    }

    var isSample: Bool
    var streak: StatCard
    var energy: StatCard
    var cadenceEyebrow: String
    var cadenceTitle: String
    var matrixDescription: String
    var weeks: [Week]
    var insights: [Insight]

    /// Counted from the matrix so the legend always agrees with the dots.
    var legend: [LegendItem] {
        let all = weeks.flatMap(\.cells).compactMap(\.level)
        let names: [(Int, String)] = [(5, "Focus"), (4, "Alert"), (3, "Steady"), (2, "Recovery")]
        return names.map { level, name in
            LegendItem(level: level, name: name, days: all.filter { $0 == level }.count)
        }
    }
}

// MARK: - Sample data (matches the design mockup)

extension MonthlyAnalysis {
    static var sample: MonthlyAnalysis {
        // 4 weeks, Monday first. nil = nothing logged.
        let levels: [[Int?]] = [
            [2, 5, 4, 5, 3, 2, nil],
            [4, 5, 4, 5, 4, 2, 3],
            [5, 5, 4, 5, 4, 4, nil],
            [4, 5, 5, 4, 3, 2, 5]
        ]

        var weeks: [Week] = []
        var index = 0
        for (w, row) in levels.enumerated() {
            var cells: [Cell] = []
            for level in row {
                cells.append(Cell(id: index, day: index + 1, level: level))
                index += 1
            }
            weeks.append(Week(label: "W\(w + 1)", cells: cells))
        }

        return MonthlyAnalysis(
            isSample: true,
            streak: StatCard(
                value: "18.4",
                caption: "Days Active / Mo",
                badge: "84% Consistency",
                badgeIcon: "sparkle",
                badgeTone: .mint,
                footnote: "Longest cadence: 22 days."
            ),
            energy: StatCard(
                value: "4.1",
                unit: "/ 5 Scale",
                caption: "Sustained Stamina",
                badge: "High Resilience",
                badgeIcon: "bolt.fill",
                badgeTone: .peach,
                footnote: "+0.3 vs last month baseline."
            ),
            cadenceEyebrow: "Reflective Cadence",
            cadenceTitle: "Deliberate Morning Depth",
            matrixDescription: "Energy intensity recorded for every logged day across the month.",
            weeks: weeks,
            insights: [
                Insight(
                    icon: "chart.line.uptrend.xyaxis",
                    tone: .mint,
                    title: "Peak Bio-Window Correlation",
                    body: "Mid-week mornings (**Tue & Thu 9–11 AM**) demonstrated **94% task retention** and lowest perceived cognitive strain."
                ),
                Insight(
                    icon: "leaf.fill",
                    tone: .peach,
                    title: "Cognitive Burnout Prevention",
                    body: "**Zero cognitive crash days** observed across October, credited directly to adherence to scheduled 5–10 min somatic pauses."
                )
            ]
        )
    }
}

// MARK: - Builder: real data for the selected month, sample if there's nothing to show

extension AnalyticsViewModel {

    func monthlyAnalysis(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [EnergyRecord]
    ) -> MonthlyAnalysis {
        if MonthlyAnalysisConfig.alwaysUseSampleData { return .sample }

        let cal = Calendar.current
        let scale = DailyAnalysisConfig.energyScaleMax
        let month = selectedRange
        let now = Date()

        // MARK: helpers

        func monthInterval(offset k: Int) -> DateInterval? {
            guard
                let start = cal.date(byAdding: .month, value: -k, to: month.start),
                let end = cal.date(byAdding: .month, value: 1, to: start)
            else { return nil }
            return DateInterval(start: start, end: end)
        }

        /// Average energy (0...1, higher = more energy) for each day that has reflections.
        func energyFractions(in interval: DateInterval) -> [Date: Double] {
            let inRange = reflections.filter { interval.contains($0.createdAt) }
            let grouped = Dictionary(grouping: inRange) { cal.startOfDay(for: $0.createdAt) }
            return grouped.mapValues { items in
                let avg = Double(items.map(\.energySpent).reduce(0, +)) / Double(items.count)
                return min(max(1 - avg / scale, 0), 1)
            }
        }

        /// Days with any logged activity (reflection, completed task, finished session).
        func activeDays(in interval: DateInterval) -> Set<Date> {
            var days = Set<Date>()
            for r in reflections where interval.contains(r.createdAt) {
                days.insert(cal.startOfDay(for: r.createdAt))
            }
            for t in tasks where t.isCompleted {
                if let d = DailyModelAdapter.completionDate(t), interval.contains(d) {
                    days.insert(cal.startOfDay(for: d))
                }
            }
            for s in sessions {
                if let d = DailyModelAdapter.endDate(s), interval.contains(d) {
                    days.insert(cal.startOfDay(for: d))
                }
            }
            return days
        }

        func mean(_ values: [Date: Double]) -> Double? {
            values.isEmpty ? nil : values.values.reduce(0, +) / Double(values.count)
        }

        func level(_ fraction: Double) -> Int {
            max(2, min(5, Int((fraction * 5).rounded(.up))))
        }

        // MARK: nothing in the last 3 months? show the sample

        let recentMonths = (0..<3).compactMap { monthInterval(offset: $0) }
        let monthlyCounts = recentMonths.map { activeDays(in: $0).count }
        guard monthlyCounts.contains(where: { $0 > 0 }) else { return .sample }

        // MARK: streak card

        let activeThisMonth = activeDays(in: month).sorted()
        let nonZero = monthlyCounts.filter { $0 > 0 }
        let avgActive = Double(nonZero.reduce(0, +)) / Double(max(nonZero.count, 1))

        let upTo = min(now, month.end)
        let elapsed = max(
            1,
            (cal.dateComponents([.day], from: cal.startOfDay(for: month.start), to: cal.startOfDay(for: upTo)).day ?? 0) + 1
        )
        let consistency = min(100, Int((Double(activeThisMonth.count) / Double(elapsed) * 100).rounded()))

        var longest = 0
        var run = 0
        var previous: Date? = nil
        for d in activeThisMonth {
            if let p = previous, cal.dateComponents([.day], from: p, to: d).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = d
        }

        let streak = MonthlyAnalysis.StatCard(
            value: String(format: "%.1f", avgActive),
            caption: "Days Active / Mo",
            badge: "\(consistency)% Consistency",
            badgeIcon: "sparkle",
            badgeTone: .mint,
            footnote: longest == 0
                ? "No active days yet this month."
                : "Longest cadence: \(longest) day\(longest == 1 ? "" : "s")."
        )

        // MARK: energy card

        let currentFractions = energyFractions(in: month)
        let previousFractions = monthInterval(offset: 1).map { energyFractions(in: $0) } ?? [:]

        let energy: MonthlyAnalysis.StatCard
        if let current = mean(currentFractions) {
            let avg5 = current * 5
            let tier: (String, MonthlyAnalysis.BadgeTone) =
                avg5 >= 4 ? ("High Resilience", .peach)
                : avg5 >= 3 ? ("Steady Stamina", .mint)
                : ("Needs Recovery", .grey)

            var footnote = "No prior month to compare."
            if let prev = mean(previousFractions) {
                footnote = String(format: "%+.1f vs last month baseline.", (current - prev) * 5)
            }

            energy = MonthlyAnalysis.StatCard(
                value: String(format: "%.1f", avg5),
                unit: "/ 5 Scale",
                caption: "Sustained Stamina",
                badge: tier.0,
                badgeIcon: "bolt.fill",
                badgeTone: tier.1,
                footnote: footnote
            )
        } else {
            energy = MonthlyAnalysis.StatCard(
                value: "–",
                unit: "/ 5 Scale",
                caption: "Sustained Stamina",
                badge: "No data",
                badgeIcon: "bolt.fill",
                badgeTone: .grey,
                footnote: "Log reflections to track energy."
            )
        }

        // MARK: 4-week spot matrix (last four Monday-first weeks up to today / month end)

        var isoCal = Calendar(identifier: .gregorian)
        isoCal.firstWeekday = 2
        let anchor = min(now, month.end.addingTimeInterval(-1))
        let weekStart = isoCal.dateInterval(of: .weekOfYear, for: anchor)?.start ?? cal.startOfDay(for: anchor)

        guard
            let matrixStart = cal.date(byAdding: .day, value: -21, to: weekStart),
            let matrixEnd = cal.date(byAdding: .day, value: 28, to: matrixStart)
        else { return .sample }

        let matrixFractions = energyFractions(in: DateInterval(start: matrixStart, end: matrixEnd))

        var weeks: [MonthlyAnalysis.Week] = []
        for w in 0..<4 {
            var cells: [MonthlyAnalysis.Cell] = []
            for d in 0..<7 {
                let index = w * 7 + d
                guard let date = cal.date(byAdding: .day, value: index, to: matrixStart) else { continue }
                let fraction = matrixFractions[cal.startOfDay(for: date)]
                cells.append(
                    MonthlyAnalysis.Cell(
                        id: index,
                        day: cal.component(.day, from: date),
                        level: fraction.map(level)
                    )
                )
            }
            weeks.append(MonthlyAnalysis.Week(label: "W\(w + 1)", cells: cells))
        }

        // MARK: synthesis insights (only statements the data supports)

        var insights: [MonthlyAnalysis.Insight] = []

        // 1. Strongest weekdays this month
        let daysByWeekday = Dictionary(grouping: currentFractions.keys) { cal.component(.weekday, from: $0) }
        let weekdayAverages = daysByWeekday.mapValues { days in
            days.compactMap { currentFractions[$0] }.reduce(0, +) / Double(days.count)
        }
        let topWeekdays = weekdayAverages
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(2)

        if !topWeekdays.isEmpty {
            let names = topWeekdays.map { cal.shortWeekdaySymbols[$0.key - 1] }.joined(separator: " & ")
            let average = topWeekdays.map { $0.value }.reduce(0, +) / Double(topWeekdays.count)
            let pct = Int((average * 100).rounded())
            insights.append(
                MonthlyAnalysis.Insight(
                    icon: "chart.line.uptrend.xyaxis",
                    tone: .mint,
                    title: "Peak Bio-Window Correlation",
                    body: "Your strongest \(topWeekdays.count == 1 ? "weekday was" : "weekdays were") **\(names)**, averaging **\(pct)% energy** with the lowest perceived cognitive strain."
                )
            )
        }

        // 2. Crash days this month (average energy under 30%)
        if !currentFractions.isEmpty {
            let crashDays = currentFractions.values.filter { $0 < 0.3 }.count
            let monthName = month.start.formatted(.dateTime.month(.wide))
            let body = crashDays == 0
                ? "**Zero cognitive crash days** observed across \(monthName). Keep protecting your 5–10 min recovery pauses."
                : "**\(crashDays) cognitive crash day\(crashDays == 1 ? "" : "s")** observed across \(monthName). Short 5–10 min pauses after deep sessions may help."
            insights.append(
                MonthlyAnalysis.Insight(
                    icon: "leaf.fill",
                    tone: .peach,
                    title: "Cognitive Burnout Prevention",
                    body: body
                )
            )
        }

        // MARK: reflective cadence card (time of day with the highest energy)

        func bucketName(_ hour: Int) -> String {
            hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")
        }
        let monthReflections = reflections.filter { month.contains($0.createdAt) }
        let byBucket = Dictionary(grouping: monthReflections) { bucketName(cal.component(.hour, from: $0.createdAt)) }
        let bestBucket = byBucket
            .mapValues { items in
                items.map { 1 - Double($0.energySpent) / scale }.reduce(0, +) / Double(items.count)
            }
            .max { $0.value < $1.value }?
            .key

        let cadenceTitle: String
        switch bestBucket ?? "" {
        case "morning": cadenceTitle = "Deliberate Morning Depth"
        case "afternoon": cadenceTitle = "Steady Afternoon Rhythm"
        case "evening": cadenceTitle = "Calm Evening Focus"
        default: cadenceTitle = "Building Your Cadence"
        }

        return MonthlyAnalysis(
            isSample: false,
            streak: streak,
            energy: energy,
            cadenceEyebrow: "Reflective Cadence",
            cadenceTitle: cadenceTitle,
            matrixDescription: "Energy intensity recorded for every logged day across the last four weeks.",
            weeks: weeks,
            insights: insights
        )
    }
}
