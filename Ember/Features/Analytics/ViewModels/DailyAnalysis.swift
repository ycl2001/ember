import Foundation

enum DailyModelAdapter {
    static func completionDate(_ task: LearningTask) -> Date? { task.completedAt }
    static func title(_ task: LearningTask) -> String { task.title }
    static func endDate(_ session: FocusSession) -> Date? { session.endedAt }
    static func minutes(_ session: FocusSession) -> Int { session.durationSeconds / 60 }
}
struct DailyAnalysis {
    struct Hero {
        var headline: String
        var scoreText: String?
        var body: String
        var curve: [Double]
        var peakIndex: Int
    }

    struct Chip: Identifiable {
        var icon: String
        var text: String
        var id: String { "\(icon)-\(text)" }
    }

    struct Window: Identifiable {
        enum Kind: String { case morning, afternoon, evening }
        enum Tone { case peak, steady, recovery, neutral }

        var kind: Kind
        var title: String
        var badge: String
        var tone: Tone
        var summary: String
        var chips: [Chip] = []
        var id: String { kind.rawValue }
    }

    struct Friction {
        var headline: String
        var status: String
        var isProtected: Bool
        var body: String
        var reserve: Double
    }

    var state: AnalyticsDataState
    var hero: Hero
    var windows: [Window]
    var friction: Friction?

    static let insufficient = DailyAnalysis(
        state: .insufficient,
        hero: .init(headline: "No observations yet", scoreText: nil, body: "", curve: [], peakIndex: 0),
        windows: [],
        friction: nil
    )
}

extension AnalyticsViewModel {
    func dailyAnalysis(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [SessionReflection]
    ) -> DailyAnalysis {
        struct Event {
            enum Kind { case task, session, reflection }
            let kind: Kind
            let date: Date
            let title: String?
            let minutes: Int?
            let energyAfter: Int?
            let energyChange: Int?
        }

        let range = selectedRange
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var events: [Event] = []

        for task in tasks where task.isCompleted {
            guard let date = DailyModelAdapter.completionDate(task), contains(date, in: range) else { continue }
            events.append(.init(kind: .task, date: date, title: DailyModelAdapter.title(task), minutes: nil, energyAfter: nil, energyChange: nil))
        }
        for session in sessions {
            guard let date = DailyModelAdapter.endDate(session), contains(date, in: range) else { continue }
            events.append(.init(kind: .session, date: date, title: nil, minutes: DailyModelAdapter.minutes(session), energyAfter: nil, energyChange: nil))
        }
        for reflection in reflections {
            let date = observationDate(for: reflection, sessionsByID: sessionsByID)
            guard contains(date, in: range) else { continue }
            events.append(
                .init(
                    kind: .reflection,
                    date: date,
                    title: nil,
                    minutes: nil,
                    energyAfter: reflection.energyAfter,
                    energyChange: reflection.energyAfter - reflection.energyBefore
                )
            )
        }

        guard !events.isEmpty else { return .insufficient }

        func hour(_ event: Event) -> Int { calendar.component(.hour, from: event.date) }
        func time(_ hour: Int) -> String {
            let date = calendar.date(bySettingHour: hour % 24, minute: 0, second: 0, of: range.start) ?? range.start
            return date.formatted(date: .omitted, time: .shortened)
        }
        func countText(_ count: Int, singular: String) -> String {
            "\(count) \(singular)\(count == 1 ? "" : "s")"
        }

        let buckets: [(DailyAnalysis.Window.Kind, String, Range<Int>)] = [
            (.morning, "Morning", 5..<12),
            (.afternoon, "Afternoon", 12..<17),
            (.evening, "Evening", 17..<24)
        ]
        var windows: [DailyAnalysis.Window] = []
        var busiest: (count: Int, range: String)?

        for (kind, name, hours) in buckets {
            let bucketEvents = events.filter { hours.contains(hour($0)) }
            guard let firstHour = bucketEvents.map(hour).min(),
                  let lastHour = bucketEvents.map(hour).max()
            else { continue }
            let rangeText = "\(time(firstHour)) – \(time(lastHour + 1))"
            let taskEvents = bucketEvents.filter { $0.kind == .task }
            let sessionEvents = bucketEvents.filter { $0.kind == .session }
            let reflectionEvents = bucketEvents.filter { $0.kind == .reflection }
            let energies = reflectionEvents.compactMap(\.energyAfter)
            let averageEnergy = energies.isEmpty ? nil : Double(energies.reduce(0, +)) / Double(energies.count)

            let tone: DailyAnalysis.Window.Tone
            switch averageEnergy {
            case .some(let value) where value >= 4: tone = .peak
            case .some(let value) where value >= 3: tone = .steady
            case .some: tone = .recovery
            case .none: tone = .neutral
            }
            let badge = averageEnergy.map {
                "\($0.formatted(.number.precision(.fractionLength(1)))) / 5 after"
            } ?? "\(countText(bucketEvents.count, singular: "record"))"

            let summary: String
            if !taskEvents.isEmpty {
                let titles = taskEvents.compactMap(\.title).prefix(3).joined(separator: ", ")
                summary = "Completed **\(countText(taskEvents.count, singular: "task"))**\(titles.isEmpty ? "." : ": \(titles).")"
            } else if !sessionEvents.isEmpty {
                summary = "Logged **\(countText(sessionEvents.count, singular: "focus session"))**."
            } else {
                summary = "Logged **\(countText(reflectionEvents.count, singular: "reflection"))**."
            }

            var chips: [DailyAnalysis.Chip] = []
            if !sessionEvents.isEmpty {
                chips.append(.init(icon: "timer", text: countText(sessionEvents.count, singular: "focus session")))
                let minutes = sessionEvents.compactMap(\.minutes)
                if !minutes.isEmpty {
                    chips.append(.init(icon: "stopwatch.fill", text: "\(minutes.reduce(0, +) / minutes.count) min average"))
                }
            }
            if !reflectionEvents.isEmpty {
                chips.append(.init(icon: "square.and.pencil", text: countText(reflectionEvents.count, singular: "reflection")))
            }

            windows.append(.init(kind: kind, title: "\(name) (\(rangeText))", badge: badge, tone: tone, summary: summary, chips: chips))
            if busiest == nil || bucketEvents.count > busiest?.count ?? 0 {
                busiest = (bucketEvents.count, rangeText)
            }
        }

        let hourlyEnergies = (6...21).map { targetHour -> Double? in
            let values = events.filter { hour($0) == targetHour }.compactMap(\.energyAfter)
            guard !values.isEmpty else { return nil }
            return Double(values.reduce(0, +)) / Double(values.count) / 5
        }
        let activity = (6...21).map { targetHour in Double(events.count { hour($0) == targetHour }) }
        let maxActivity = activity.max() ?? 0
        let curve = hourlyEnergies.enumerated().map { index, energy in
            energy ?? (maxActivity > 0 ? activity[index] / maxActivity : 0)
        }
        let peakIndex = curve.enumerated().max { $0.element < $1.element }?.offset ?? 0
        let observedReflections = events.filter { $0.kind == .reflection }
        let energies = observedReflections.compactMap(\.energyAfter)
        let averageEnergy = energies.isEmpty ? nil : Double(energies.reduce(0, +)) / Double(energies.count)

        let headline = averageEnergy == nil ? "Activity Recorded" : "After-Session Energy"
        var body = busiest.map { "Most saved activity occurred between **\($0.range)**. " } ?? ""
        body += "Recorded \(countText(events.count { $0.kind == .task }, singular: "task")), \(countText(events.count { $0.kind == .session }, singular: "session")), and \(countText(observedReflections.count, singular: "reflection")) today."

        let friction: DailyAnalysis.Friction? = averageEnergy.map { average in
            let changes = observedReflections.compactMap(\.energyChange)
            let averageChange = Double(changes.reduce(0, +)) / Double(changes.count)
            let direction = averageChange > 0 ? "higher" : averageChange < 0 ? "lower" : "unchanged"
            return .init(
                headline: "Observed Energy Change",
                status: "\(average.formatted(.number.precision(.fractionLength(1)))) / 5",
                isProtected: averageChange >= 0,
                body: "Across \(countText(changes.count, singular: "reflection")), after-session energy was \(direction) by \(abs(averageChange).formatted(.number.precision(.fractionLength(1)))) points on average.",
                reserve: average / 5
            )
        }

        return DailyAnalysis(
            state: .observed,
            hero: .init(
                headline: headline,
                scoreText: averageEnergy.map { "\($0.formatted(.number.precision(.fractionLength(1)))) / 5" },
                body: body,
                curve: curve,
                peakIndex: peakIndex
            ),
            windows: windows,
            friction: friction
        )
    }
}
