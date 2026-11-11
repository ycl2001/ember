import Foundation

struct MonthlyAnalysis {
    enum BadgeTone { case mint, peach, grey }

    struct StatCard {
        var value: String
        var unit: String?
        var caption: String
        var badge: String
        var badgeIcon: String
        var badgeTone: BadgeTone
        var footnote: String
    }

    struct Cell: Identifiable {
        var id: Int
        var day: Int
        var level: Int?
    }

    struct Week: Identifiable {
        var label: String
        var cells: [Cell]
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
        var body: String
        var id: String { title }
    }

    var state: AnalyticsDataState
    var streak: StatCard
    var energy: StatCard
    var cadenceEyebrow: String
    var cadenceTitle: String
    var matrixDescription: String
    var weeks: [Week]
    var insights: [Insight]

    var legend: [LegendItem] {
        let allLevels = weeks.flatMap(\.cells).compactMap(\.level)
        let names = [(5, "High"), (4, "Good"), (3, "Steady"), (2, "Low"), (1, "Very low")]
        return names.map { level, name in
            LegendItem(level: level, name: name, days: allLevels.count { $0 == level })
        }
    }

    static let observedMatrixDescription = "Average after-session energy for each day with a saved reflection."

    static let insufficient = MonthlyAnalysis(
        state: .insufficient,
        streak: .init(
            value: "–",
            unit: nil,
            caption: "Active days",
            badge: "No data",
            badgeIcon: "calendar",
            badgeTone: .grey,
            footnote: "Complete a task, finish a session, or save a reflection."
        ),
        energy: .init(
            value: "–",
            unit: "/ 5",
            caption: "After-session energy",
            badge: "No reflections",
            badgeIcon: "bolt",
            badgeTone: .grey,
            footnote: "Saved reflections will appear here."
        ),
        cadenceEyebrow: "Observed cadence",
        cadenceTitle: "Not enough data",
        matrixDescription: "No saved observations fall within this month.",
        weeks: [],
        insights: []
    )
}

extension AnalyticsViewModel {
    static func monthlyEnergyObservations(
        sessions: [FocusSession],
        reflections: [SessionReflection]
    ) -> [MonthlyEnergyObservation] {
        let sessionsByID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return monthlyEnergyObservations(sessionsByID: sessionsByID, reflections: reflections)
    }

    private static func monthlyEnergyObservations(
        sessionsByID: [UUID: FocusSession],
        reflections: [SessionReflection]
    ) -> [MonthlyEnergyObservation] {
        reflections.map { reflection in
            MonthlyEnergyObservation(
                date: sessionsByID[reflection.sessionID]?.endedAt ?? reflection.createdAt,
                level: reflection.energyAfter
            )
        }.sorted(by: MonthlyEnergyObservation.chronological)
    }

    func monthlyAnalysis(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [SessionReflection]
    ) -> MonthlyAnalysis {
        let month = selectedRange
        let sessionsByID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let finalIncludedDay = calendar.date(byAdding: .day, value: -1, to: month.end) ?? month.end
        let effectiveEnd = min(referenceDate, finalIncludedDay)
        let grid = MonthlyEnergyGrid(
            observations: Self.monthlyEnergyObservations(sessionsByID: sessionsByID, reflections: reflections),
            asOf: effectiveEnd,
            calendar: calendar
        )
        let weeks = grid.weeks.enumerated().map { weekIndex, days in
            MonthlyAnalysis.Week(label: "W\(weekIndex + 1)", cells: days.enumerated().map { dayIndex, day in
                MonthlyAnalysis.Cell(
                    id: weekIndex * 7 + dayIndex,
                    day: calendar.component(.day, from: day.date),
                    level: day.level
                )
            })
        }

        func activityDays(in range: DateInterval) -> Set<Date> {
            var days = Set<Date>()
            for task in tasks where task.isCompleted {
                guard let date = task.completedAt, contains(date, in: range) else { continue }
                days.insert(calendar.startOfDay(for: date))
            }
            for session in sessions {
                guard let date = session.endedAt, contains(date, in: range) else { continue }
                days.insert(calendar.startOfDay(for: date))
            }
            for reflection in reflections {
                let date = observationDate(for: reflection, sessionsByID: sessionsByID)
                guard contains(date, in: range) else { continue }
                days.insert(calendar.startOfDay(for: date))
            }
            return days
        }

        let activeDays = activityDays(in: month).sorted()
        let monthReflections = reflections.filter {
            contains(observationDate(for: $0, sessionsByID: sessionsByID), in: month)
        }
        guard !activeDays.isEmpty else {
            // The visible four-week window can contain observations before the current month.
            guard weeks.contains(where: { $0.cells.contains { $0.level != nil } }) else { return .insufficient }
            var result = MonthlyAnalysis.insufficient
            result.matrixDescription = MonthlyAnalysis.observedMatrixDescription
            result.weeks = weeks
            return result
        }

        let elapsedDays = max(
            1,
            (calendar.dateComponents([.day], from: month.start, to: effectiveEnd).day ?? 0) + 1
        )
        let consistency = min(100, Int((Double(activeDays.count) / Double(elapsedDays) * 100).rounded()))

        var longestStreak = 0
        var currentStreak = 0
        var previous: Date?
        for day in activeDays {
            if let previous,
               calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            longestStreak = max(longestStreak, currentStreak)
            previous = day
        }

        let streak = MonthlyAnalysis.StatCard(
            value: "\(activeDays.count)",
            unit: nil,
            caption: "Active days this month",
            badge: "\(consistency)% of elapsed days",
            badgeIcon: "calendar",
            badgeTone: .mint,
            footnote: "Longest observed streak: \(longestStreak) day\(longestStreak == 1 ? "" : "s")."
        )

        let energy: MonthlyAnalysis.StatCard
        if let average = averageAfterSessionEnergy(in: monthReflections) {
            let net = netReportedEnergyChange(in: monthReflections)
            let direction = net > 0 ? "+\(net)" : "\(net)"
            energy = .init(
                value: average.formatted(.number.precision(.fractionLength(1))),
                unit: "/ 5",
                caption: "After-session energy",
                badge: "\(monthReflections.count) reflection\(monthReflections.count == 1 ? "" : "s")",
                badgeIcon: "bolt",
                badgeTone: average >= 3 ? .peach : .grey,
                footnote: "Net before-to-after change: \(direction) points."
            )
        } else {
            energy = .init(
                value: "–",
                unit: "/ 5",
                caption: "After-session energy",
                badge: "No reflections",
                badgeIcon: "bolt",
                badgeTone: .grey,
                footnote: "Activity exists, but no energy reflections were saved."
            )
        }

        var insights: [MonthlyAnalysis.Insight] = []
        let byWeekday = Dictionary(grouping: monthReflections) {
            calendar.component(.weekday, from: observationDate(for: $0, sessionsByID: sessionsByID))
        }
        var rankedWeekdays: [(weekday: Int, average: Double, count: Int)] = byWeekday.map { entry in
            let average = averageAfterSessionEnergy(in: entry.value) ?? 0
            return (weekday: entry.key, average: average, count: entry.value.count)
        }
        rankedWeekdays.sort { lhs, rhs in
            lhs.average == rhs.average ? lhs.count > rhs.count : lhs.average > rhs.average
        }
        if let strongest = rankedWeekdays.first, strongest.count >= 2 {
            let weekday = calendar.weekdaySymbols[strongest.weekday - 1]
            insights.append(
                .init(
                    icon: "chart.line.uptrend.xyaxis",
                    tone: .mint,
                    title: "Highest Observed Weekday Energy",
                    body: "**\(weekday)** averaged **\(strongest.average.formatted(.number.precision(.fractionLength(1)))) out of 5** after sessions across \(strongest.count) reflections. This is an observation, not a prediction."
                )
            )
        }

        if !monthReflections.isEmpty {
            let averageChange = Double(netReportedEnergyChange(in: monthReflections)) / Double(monthReflections.count)
            let direction = averageChange > 0 ? "increased" : averageChange < 0 ? "decreased" : "was unchanged"
            insights.append(
                .init(
                    icon: "arrow.left.arrow.right",
                    tone: .peach,
                    title: "Before and After Sessions",
                    body: "Reported energy **\(direction)** by **\(abs(averageChange).formatted(.number.precision(.fractionLength(1)))) points on average** across \(monthReflections.count) reflections."
                )
            )
        }

        let bucketed = Dictionary(grouping: monthReflections) { reflection -> String in
            let date = observationDate(for: reflection, sessionsByID: sessionsByID)
            switch calendar.component(.hour, from: date) {
            case ..<12: return "Morning"
            case 12..<17: return "Afternoon"
            default: return "Evening"
            }
        }
        let mostFrequentBucket = bucketed.max { lhs, rhs in lhs.value.count < rhs.value.count }
        let cadenceTitle = mostFrequentBucket.map {
            "Most reflections recorded in the \($0.key.lowercased()) (\($0.value.count))"
        } ?? "No reflection timing yet"

        return MonthlyAnalysis(
            state: .observed,
            streak: streak,
            energy: energy,
            cadenceEyebrow: "Observed cadence",
            cadenceTitle: cadenceTitle,
            matrixDescription: MonthlyAnalysis.observedMatrixDescription,
            weeks: weeks,
            insights: insights
        )
    }
}
