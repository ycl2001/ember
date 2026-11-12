import Foundation
import Testing
@testable import Ember

@MainActor
struct MonthlyEnergyWidgetTests {
    @Test
    func matrixUsesDailyAverageAcrossMonthsAndKeepsLevelOne() throws {
        let calendar = makeCalendar(timeZone: .gmt)
        let october = try date(2026, 10, 29, in: calendar)
        let november = try date(2026, 11, 2, in: calendar)
        let future = try date(2026, 11, 3, in: calendar)
        let grid = MonthlyEnergyGrid(observations: [
            .init(date: october, level: 1),
            .init(date: november, level: 2),
            .init(date: november, level: 5),
            .init(date: november, level: 0),
            .init(date: future, level: 5)
        ], asOf: november, calendar: calendar)

        #expect(grid.weeks.map(\.count) == [7, 7, 7, 7])
        let recordedDays = grid.weeks.flatMap { $0 }.filter { $0.level != nil }
        #expect(recordedDays == [
            .init(date: calendar.startOfDay(for: october), level: 1),
            .init(date: calendar.startOfDay(for: november), level: 4)
        ])
    }

    @Test
    func emptyMatrixStaysMondayAlignedAcrossDaylightSavingChange() throws {
        let calendar = makeCalendar(timeZone: try #require(TimeZone(identifier: "Australia/Sydney")))
        let october = try date(2026, 10, 5, in: calendar)
        let grid = MonthlyEnergyGrid(observations: [], asOf: october, calendar: calendar)

        #expect(grid.weeks.map(\.count) == [7, 7, 7, 7])
        #expect(grid.weeks.compactMap(\.first).map { calendar.component(.weekday, from: $0.date) } == [2, 2, 2, 2])
        let days = grid.weeks.flatMap { $0 }
        #expect(Set(days.map(\.date)).count == 28)
        #expect(days.allSatisfy { $0.level == nil && calendar.component(.hour, from: $0.date) == 0 })
        #expect(grid.weeks.last?.first?.date == calendar.startOfDay(for: october))
    }

    @Test
    func monthlyReportAndWidgetUseTheSessionDateEvenWhenSavedLater() throws {
        let calendar = makeCalendar(timeZone: .gmt)
        let sessionDay = try date(2026, 10, 29, in: calendar)
        let savedDay = try date(2026, 11, 2, in: calendar)
        let taskID = UUID()
        let session = FocusSession(taskID: taskID, endedAt: sessionDay, durationSeconds: 60)
        let reflection = SessionReflection(
            taskID: taskID, sessionID: session.id, energyBefore: 3, energyAfter: 1, createdAt: savedDay
        )
        let observations = AnalyticsViewModel.monthlyEnergyObservations(sessions: [session], reflections: [reflection])
        #expect(observations == [.init(date: sessionDay, level: 1)])

        let grid = MonthlyEnergyGrid(observations: observations, asOf: savedDay, calendar: calendar)
        let monthly = AnalyticsViewModel(period: .monthly, calendar: calendar, now: savedDay)
            .monthlyAnalysis(tasks: [], sessions: [session], reflections: [reflection])
        #expect(monthly.state == .insufficient)
        #expect(monthly.weeks.flatMap(\.cells).map(\.level) == grid.weeks.flatMap { $0 }.map(\.level))
        #expect(monthly.legend.first { $0.level == 1 }?.days == 1)
    }

    private func makeCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }
}
