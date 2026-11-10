import Foundation
import Observation

enum AnalyticsDataState: Equatable {
    case sample
    case insufficient
    case observed
}

@MainActor
@Observable
final class AnalyticsViewModel {
    enum Period: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var id: String { rawValue }
    }

    struct ChartPoint: Identifiable, Equatable {
        let date: Date
        let energy: Double?
        let tasksCompleted: Int

        var id: Date { date }
    }

    struct ObservedPattern: Equatable {
        let title: String
        let message: String
        let hasEnoughData: Bool
    }

    var period: Period
    var selectedRange: DateInterval

    let calendar: Calendar
    let referenceDate: Date

    init(
        period: Period = .weekly,
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        self.period = period
        self.calendar = calendar
        referenceDate = now
        selectedRange = Self.defaultRange(for: period, calendar: calendar, now: now)
    }

    static func defaultRange(
        for period: Period,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> DateInterval {
        switch period {
        case .daily:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .weekly:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        }
    }

    func updatePeriod(_ newPeriod: Period) {
        period = newPeriod
        selectedRange = Self.defaultRange(for: newPeriod, calendar: calendar, now: referenceDate)
    }

    func contains(_ date: Date, in range: DateInterval) -> Bool {
        date >= range.start && date < range.end
    }

    func completedTaskCount(in tasks: [LearningTask], during range: DateInterval) -> Int {
        tasks.count { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return contains(completedAt, in: range)
        }
    }

    func sessionsCount(in sessions: [FocusSession], during range: DateInterval) -> Int {
        sessions.count { session in
            guard let endedAt = session.endedAt else { return false }
            return contains(endedAt, in: range)
        }
    }

    func focusMinutes(in sessions: [FocusSession], during range: DateInterval) -> Int {
        sessions.reduce(into: 0) { total, session in
            guard let endedAt = session.endedAt, contains(endedAt, in: range) else { return }
            total += session.durationSeconds / 60
        }
    }

    func reflectionsInRange(
        _ reflections: [SessionReflection],
        sessions: [FocusSession] = [],
        during range: DateInterval
    ) -> [SessionReflection] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        return reflections.filter { reflection in
            contains(observationDate(for: reflection, sessionsByID: sessionsByID), in: range)
        }
    }

    /// Positive values mean participants reported more energy after sessions.
    func netReportedEnergyChange(in reflections: [SessionReflection]) -> Int {
        reflections.reduce(0) { total, reflection in
            total + reflection.energyAfter - reflection.energyBefore
        }
    }

    func averageAfterSessionEnergy(in reflections: [SessionReflection]) -> Double? {
        guard !reflections.isEmpty else { return nil }
        let total = reflections.reduce(0) { $0 + $1.energyAfter }
        return Double(total) / Double(reflections.count)
    }

    func chartPoints(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [SessionReflection],
        during range: DateInterval
    ) -> [ChartPoint] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        let inRangeReflections = reflections.filter {
            contains(observationDate(for: $0, sessionsByID: sessionsByID), in: range)
        }
        let reflectionsByDay = Dictionary(grouping: inRangeReflections) {
            calendar.startOfDay(for: observationDate(for: $0, sessionsByID: sessionsByID))
        }
        let energyByDay = reflectionsByDay.mapValues { observations in
            Double(observations.reduce(0) { $0 + $1.energyAfter }) / Double(observations.count)
        }

        let completedTasks = tasks.compactMap { task -> (Date, LearningTask)? in
            guard task.isCompleted,
                  let completedAt = task.completedAt,
                  contains(completedAt, in: range)
            else { return nil }
            return (calendar.startOfDay(for: completedAt), task)
        }
        let tasksByDay = Dictionary(grouping: completedTasks, by: \.0)

        var points: [ChartPoint] = []
        var day = calendar.startOfDay(for: range.start)
        while day < range.end {
            points.append(
                ChartPoint(
                    date: day,
                    energy: energyByDay[day],
                    tasksCompleted: tasksByDay[day]?.count ?? 0
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return points
    }

    func rangeTitle(_ range: DateInterval) -> String {
        switch period {
        case .daily:
            return range.start.formatted(.dateTime.month(.abbreviated).day())
        case .weekly:
            let finalDay = calendar.date(byAdding: .day, value: -1, to: range.end) ?? range.end
            return "\(range.start.formatted(.dateTime.month(.abbreviated).day())) – \(finalDay.formatted(.dateTime.month(.abbreviated).day()))"
        case .monthly:
            return range.start.formatted(.dateTime.month(.wide).year())
        }
    }

    func observedPattern(
        sessions: [FocusSession],
        reflections: [SessionReflection],
        lookbackDays: Int
    ) -> ObservedPattern {
        guard let start = calendar.date(byAdding: .day, value: -lookbackDays, to: calendar.startOfDay(for: referenceDate)) else {
            return .init(title: "Pattern unavailable", message: "The requested date range could not be created.", hasEnoughData: false)
        }
        let range = DateInterval(start: start, end: referenceDate.addingTimeInterval(0.001))
        let observations = reflectionsInRange(reflections, sessions: sessions, during: range)
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: observations) {
            calendar.component(.weekday, from: observationDate(for: $0, sessionsByID: sessionsByID))
        }
        guard observations.count >= 4, grouped.count >= 2 else {
            return .init(
                title: "More observations needed",
                message: "Log at least four reflections across two different weekdays to compare a recurring pattern. No tasks or schedules were changed.",
                hasEnoughData: false
            )
        }

        var ranked: [(weekday: Int, average: Double, count: Int)] = grouped.map { entry in
            let average = averageAfterSessionEnergy(in: entry.value) ?? 0
            return (weekday: entry.key, average: average, count: entry.value.count)
        }
        ranked.sort { lhs, rhs in
            lhs.average == rhs.average ? lhs.count > rhs.count : lhs.average > rhs.average
        }
        guard let strongest = ranked.first, strongest.count >= 2 else {
            return .init(
                title: "More observations needed",
                message: "The current observations are spread too thinly to identify a repeated weekday pattern. No tasks or schedules were changed.",
                hasEnoughData: false
            )
        }

        let weekday = calendar.weekdaySymbols[strongest.weekday - 1]
        let energy = strongest.average.formatted(.number.precision(.fractionLength(1)))
        return .init(
            title: "Observed weekday pattern",
            message: "Across \(strongest.count) saved reflections, \(weekday) had the highest average after-session energy at \(energy) out of 5. Treat this as a pattern to keep observing, not a prediction. No tasks or schedules were changed.",
            hasEnoughData: true
        )
    }

    func observationDate(
        for reflection: SessionReflection,
        sessionsByID: [UUID: FocusSession]
    ) -> Date {
        sessionsByID[reflection.sessionID]?.endedAt ?? reflection.createdAt
    }
}
