import Foundation

struct MonthlyEnergyObservation: Codable, Equatable, Sendable {
    let date: Date
    let level: Int

    static func chronological(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.date == rhs.date { return lhs.level < rhs.level }
        return lhs.date < rhs.date
    }
}

struct MonthlyEnergyGrid: Sendable {
    struct Day: Identifiable, Equatable, Sendable {
        let date: Date
        let level: Int?

        var id: Date { date }
    }

    let weeks: [[Day]]

    init(observations: [MonthlyEnergyObservation], asOf: Date, calendar: Calendar = .current) {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let today = calendar.startOfDay(for: asOf)
        guard let currentWeek = mondayCalendar.dateInterval(of: .weekOfYear, for: asOf),
              let firstDay = calendar.date(byAdding: .day, value: -21, to: currentWeek.start)
        else {
            weeks = []
            return
        }

        var totals: [Date: (sum: Int, count: Int)] = [:]
        for observation in observations where (1...5).contains(observation.level) {
            let day = calendar.startOfDay(for: observation.date)
            guard day >= firstDay, day <= today else { continue }
            totals[day, default: (0, 0)].sum += observation.level
            totals[day, default: (0, 0)].count += 1
        }

        weeks = (0..<4).map { week in
            (0..<7).compactMap { weekday in
                let offset = week * 7 + weekday
                guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
                let date = calendar.startOfDay(for: day)
                let level = totals[date].map { Int((Double($0.sum) / Double($0.count)).rounded()) }
                return Day(date: date, level: level)
            }
        }
    }
}

enum MonthlyEnergyWidgetData {
    static let kind = "EmberMonthlyEnergy"
    static let reportURL = URL(string: "ember://analytics/monthly")!

    private static let appGroupID = "group.au.edu.uts.ember"

    private static var snapshotURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("monthly-energy.json")
    }

    static func load() -> [MonthlyEnergyObservation] {
        guard let snapshotURL else { return [] }
        return readSnapshot(at: snapshotURL) ?? []
    }

    @discardableResult
    static func save(
        _ observations: [MonthlyEnergyObservation],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) throws -> Bool {
        guard let snapshotURL else { throw CocoaError(.fileNoSuchFile) }

        // Keep enough dates for the grid across time-zone changes, without sharing the full history.
        let today = calendar.startOfDay(for: asOf)
        let firstDay = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let end = calendar.dateInterval(of: .day, for: asOf)?.end ?? asOf
        let recentObservations = observations.filter {
            $0.date >= firstDay && $0.date < end && (1...5).contains($0.level)
        }.sorted(by: MonthlyEnergyObservation.chronological)

        guard recentObservations != readSnapshot(at: snapshotURL) else { return false }
        let data = try JSONEncoder().encode(recentObservations)
        try data.write(to: snapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return true
    }

    private static func readSnapshot(at url: URL) -> [MonthlyEnergyObservation]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([MonthlyEnergyObservation].self, from: data)
    }
}
