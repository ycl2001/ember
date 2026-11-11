///DailyAnalysis

import Foundation

// MARK: - Config

enum DailyAnalysisConfig {
    /// Set to true to always show the built-in sample day, even when you have real data.
    static let alwaysUseSampleData = false

    /// Scale of `EnergyRecord.energySpent`: 0 = no energy spent, this value = fully drained.
    /// Used to turn "energy spent" into an "energy %" (lower spent = higher energy).
    static let energyScaleMax = 10.0
}

// MARK: - Model adapter  ← MAP THESE TO YOUR REAL PROPERTIES
//
// I only know that LearningTask.isCompleted, EnergyRecord.createdAt and
// EnergyRecord.energySpent exist. Replace the `nil` bodies below with your real
// property names (the comment on each line shows the likely one). Until then the
// daily view is built from reflections only, and falls back to sample data.

enum DailyModelAdapter {
    static func completionDate(_ task: LearningTask) -> Date? { nil }   // e.g. task.completedAt
    static func title(_ task: LearningTask) -> String? { nil }          // e.g. task.title
    static func endDate(_ session: FocusSession) -> Date? { nil }       // e.g. session.endedAt
    static func minutes(_ session: FocusSession) -> Int? { nil }        // e.g. Int(session.duration / 60)
}

// MARK: - Model

struct DailyAnalysis {
    struct Hero {
        var headline: String
        var scoreText: String?
        var body: String          // supports **bold**
        var curve: [Double]       // 0...1, left to right through the day
        var peakIndex: Int
    }

    struct Chip: Identifiable {
        var icon: String
        var text: String
        var id: String { text }
    }

    struct Note {
        var icon: String
        var lead: String
        var highlight: String
    }

    struct Window: Identifiable {
        enum Kind: String { case morning, afternoon, evening }
        enum Tone { case peak, steady, recovery, neutral }

        var kind: Kind
        var title: String
        var badge: String
        var tone: Tone
        var summary: String       // supports **bold**
        var chips: [Chip] = []
        var note: Note? = nil
        var footer: String? = nil
        var id: String { kind.rawValue }
    }

    struct Friction {
        var headline: String
        var status: String
        var isProtected: Bool
        var body: String
        var reserve: Double       // 0...1
    }

    var isSample: Bool
    var hero: Hero
    var windows: [Window]
    var friction: Friction?
}

// MARK: - Sample data (matches the design mockup)

extension DailyAnalysis {
    static var sample: DailyAnalysis {
        DailyAnalysis(
            isSample: true,
            hero: Hero(
                headline: "Optimal Flow Achieved",
                scoreText: "92%",
                body: "Peak focus captured between **8:30 AM – 11:00 AM**. Bio-rhythm alignment stayed above target threshold all day.",
                curve: [0.35, 0.42, 0.55, 0.68, 0.78, 0.80, 0.70, 0.58, 0.50, 0.46, 0.42, 0.38, 0.34, 0.30, 0.28],
                peakIndex: 5
            ),
            windows: [
                Window(
                    kind: .morning,
                    title: "Morning (8:00 – 11:00 AM)",
                    badge: "85% Peak Energy",
                    tone: .peak,
                    summary: "Completed **3/3 Deep Learning** blocks: Neural Network Architecture & Backpropagation formal proof.",
                    chips: [
                        Chip(icon: "checkmark.circle.fill", text: "0 context-switches"),
                        Chip(icon: "stopwatch.fill", text: "18 min sprint duration")
                    ]
                ),
                Window(
                    kind: .afternoon,
                    title: "Afternoon (2:00 – 4:00 PM)",
                    badge: "60% Steady",
                    tone: .steady,
                    summary: "Completed **2/2 Active recall** micro-quizzes & semantic flashcard decks.",
                    note: Note(
                        icon: "cup.and.saucer.fill",
                        lead: "1 restorative tea pause at 3:15 PM resulted in a ",
                        highlight: "+12% stamina rebound"
                    )
                ),
                Window(
                    kind: .evening,
                    title: "Evening (7:00 – 8:00 PM)",
                    badge: "40% Recovery",
                    tone: .recovery,
                    summary: "Completed **1 Restorative** literature review & tomorrow’s syllabus preparation.",
                    footer: "Wind-down ritual completed on schedule"
                )
            ],
            friction: Friction(
                headline: "Low Depletion Detected",
                status: "Protected",
                isProtected: true,
                body: "Dense reading was proactively capped at 12 minutes, preventing the typical 4:00 PM cognitive cliff. Bio-metabolic recovery remained undisturbed.",
                reserve: 0.78
            )
        )
    }
}

// MARK: - Builder: real data for the selected day, sample if there's nothing to show

extension AnalyticsViewModel {

    func dailyAnalysis(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [EnergyRecord]
    ) -> DailyAnalysis {
        if DailyAnalysisConfig.alwaysUseSampleData { return .sample }

        let cal = Calendar.current
        let range = selectedRange
        let scale = DailyAnalysisConfig.energyScaleMax

        // 1. Collect today's events
        struct Event {
            enum Kind { case task, session, reflection }
            let kind: Kind
            let date: Date
            var title: String? = nil
            var minutes: Int? = nil
            var energySpent: Int? = nil
        }

        var events: [Event] = []

        for task in tasks where task.isCompleted {
            if let d = DailyModelAdapter.completionDate(task), range.contains(d) {
                events.append(Event(kind: .task, date: d, title: DailyModelAdapter.title(task)))
            }
        }
        for session in sessions {
            if let d = DailyModelAdapter.endDate(session), range.contains(d) {
                events.append(Event(kind: .session, date: d, minutes: DailyModelAdapter.minutes(session)))
            }
        }
        for r in reflectionsInRange(reflections, during: range) {
            events.append(Event(kind: .reflection, date: r.createdAt, energySpent: r.energySpent))
        }

        guard !events.isEmpty else { return .sample }

        // 2. Helpers
        func hour(_ e: Event) -> Int { cal.component(.hour, from: e.date) }

        func hourText(_ h: Int) -> String {
            let d = cal.date(bySettingHour: h % 24, minute: 0, second: 0, of: range.start) ?? range.start
            return d.formatted(date: .omitted, time: .shortened)
        }

        func plural(_ n: Int, _ noun: String) -> String {
            "\(n) \(noun)\(n == 1 ? "" : "s")"
        }

        func toneAndLabel(_ pct: Int) -> (DailyAnalysis.Window.Tone, String) {
            if pct >= 75 { return (.peak, "Peak Energy") }
            if pct >= 50 { return (.steady, "Steady") }
            return (.recovery, "Recovery")
        }

        func energyPercent(_ values: [Int]) -> Int? {
            guard !values.isEmpty else { return nil }
            let avg = Double(values.reduce(0, +)) / Double(values.count)
            let pct = Int(((1 - avg / scale) * 100).rounded())
            return min(max(pct, 0), 100)
        }

        // 3. Morning / afternoon / evening windows
        let buckets: [(DailyAnalysis.Window.Kind, String, Range<Int>)] = [
            (.morning, "Morning", 5..<12),
            (.afternoon, "Afternoon", 12..<17),
            (.evening, "Evening", 17..<24)
        ]

        var windows: [DailyAnalysis.Window] = []
        var scores: [Int] = []
        var busiest: (count: Int, range: String)? = nil

        for (kind, name, hours) in buckets {
            let evs = events.filter { hours.contains(hour($0)) }
            guard !evs.isEmpty else { continue }

            let hourValues = evs.map(hour)
            guard let firstHour = hourValues.min(), let lastHour = hourValues.max() else { continue }
            let rangeText = "\(hourText(firstHour)) – \(hourText(lastHour + 1))"

            let taskEvents = evs.filter { $0.kind == .task }
            let sessionEvents = evs.filter { $0.kind == .session }
            let reflectionEvents = evs.filter { $0.kind == .reflection }

            // Badge + tone
            var tone: DailyAnalysis.Window.Tone = .neutral
            var badge = "\(plural(evs.count, "item")) logged"
            if let pct = energyPercent(reflectionEvents.compactMap(\.energySpent)) {
                let t = toneAndLabel(pct)
                tone = t.0
                badge = "\(pct)% \(t.1)"
                scores.append(pct)
            }

            // Summary
            let titles = taskEvents.compactMap(\.title)
            var summary: String
            if !taskEvents.isEmpty {
                summary = "Completed **\(plural(taskEvents.count, "task"))**"
                summary += titles.isEmpty ? "." : (": " + titles.prefix(3).joined(separator: ", ") + ".")
            } else if !sessionEvents.isEmpty {
                summary = "Logged **\(plural(sessionEvents.count, "focus session"))**."
            } else {
                summary = "Logged **\(plural(reflectionEvents.count, "reflection"))** in this window."
            }

            // Chips
            var chips: [DailyAnalysis.Chip] = []
            if !sessionEvents.isEmpty {
                chips.append(.init(icon: "timer", text: plural(sessionEvents.count, "focus session")))
            }
            let mins = sessionEvents.compactMap(\.minutes)
            if !mins.isEmpty {
                chips.append(.init(icon: "stopwatch.fill", text: "\(mins.reduce(0, +) / mins.count) min avg sprint"))
            }
            if !reflectionEvents.isEmpty {
                chips.append(.init(icon: "square.and.pencil", text: plural(reflectionEvents.count, "reflection")))
            }

            windows.append(
                DailyAnalysis.Window(
                    kind: kind,
                    title: "\(name) (\(rangeText))",
                    badge: badge,
                    tone: tone,
                    summary: summary,
                    chips: chips
                )
            )

            if busiest == nil || evs.count > busiest!.count {
                busiest = (evs.count, rangeText)
            }
        }

        // 4. Hero card: hourly activity curve 6 AM – 9 PM
        let hoursShown = Array(6...21)
        let counts = hoursShown.map { h in Double(events.filter { hour($0) == h }.count) }
        let smoothed = counts.indices.map { i -> Double in
            let lo = max(0, i - 1), hi = min(counts.count - 1, i + 1)
            return counts[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
        let maxValue = smoothed.max() ?? 0
        let curve = maxValue > 0 ? smoothed.map { 0.1 + 0.9 * $0 / maxValue } : [0.3, 0.3]
        let peakIndex = maxValue > 0 ? (smoothed.firstIndex(of: maxValue) ?? 0) : 0

        let flowScore: Int? = scores.isEmpty ? nil : scores.reduce(0, +) / scores.count
        let headline: String
        switch flowScore {
        case .some(let s) where s >= 75: headline = "Optimal Flow Achieved"
        case .some(let s) where s >= 50: headline = "Steady Flow"
        case .some: headline = "Recovery Day"
        case .none: headline = "Activity Logged"
        }

        let totalTasks = events.filter { $0.kind == .task }.count
        let totalSessions = events.filter { $0.kind == .session }.count
        let totalReflections = events.filter { $0.kind == .reflection }.count
        var heroBody = ""
        if let busiest { heroBody += "Most activity came between **\(busiest.range)**. " }
        heroBody += "Logged \(plural(totalTasks, "task")), \(plural(totalSessions, "session")) and \(plural(totalReflections, "reflection")) today."

        // 5. Friction factor (needs reflections)
        var friction: DailyAnalysis.Friction? = nil
        let allEnergies = events.compactMap(\.energySpent)
        if !allEnergies.isEmpty {
            let avg = Double(allEnergies.reduce(0, +)) / Double(allEnergies.count)
            let reserve = min(max(1 - avg / scale, 0), 1)
            let pct = Int((reserve * 100).rounded())
            let isProtected = reserve >= 0.6
            friction = DailyAnalysis.Friction(
                headline: isProtected ? "Low Depletion Detected" : "High Depletion Detected",
                status: isProtected ? "Protected" : "Needs recovery",
                isProtected: isProtected,
                body: "Average self-reported energy across \(plural(allEnergies.count, "reflection")) today was \(pct)%."
                    + (isProtected ? " Your reserves held up well." : " Consider shorter sprints and more recovery pauses."),
                reserve: reserve
            )
        }

        return DailyAnalysis(
            isSample: false,
            hero: .init(
                headline: headline,
                scoreText: flowScore.map { "\($0)%" },
                body: heroBody,
                curve: curve,
                peakIndex: peakIndex
            ),
            windows: windows,
            friction: friction
        )
    }
}
