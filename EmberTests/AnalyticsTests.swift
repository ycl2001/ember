import Foundation
import SwiftData
import Testing
@testable import Ember

@MainActor
struct AnalyticsIntegrationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    @Test
    func adaptersUseIntegratedModelProperties() {
        let completedAt = Date(timeIntervalSince1970: 1_500)
        let task = LearningTask(
            goalID: UUID(),
            title: "Read chapter",
            isCompleted: true,
            completedAt: completedAt
        )
        let endedAt = Date(timeIntervalSince1970: 1_800)
        let session = FocusSession(
            taskID: task.id,
            endedAt: endedAt,
            durationSeconds: 750
        )

        #expect(DailyModelAdapter.completionDate(task) == completedAt)
        #expect(DailyModelAdapter.title(task) == "Read chapter")
        #expect(DailyModelAdapter.endDate(session) == endedAt)
        #expect(DailyModelAdapter.minutes(session) == 12)
    }

    @Test
    func dateFilteringUsesHalfOpenRanges() {
        let range = DateInterval(
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let includedTask = LearningTask(
            goalID: UUID(),
            title: "Included",
            isCompleted: true,
            completedAt: Date(timeIntervalSince1970: 1_999)
        )
        let boundaryTask = LearningTask(
            goalID: UUID(),
            title: "Boundary",
            isCompleted: true,
            completedAt: range.end
        )
        let missingDateTask = LearningTask(
            goalID: UUID(),
            title: "No completion date",
            isCompleted: true
        )
        let includedSession = FocusSession(
            taskID: includedTask.id,
            endedAt: Date(timeIntervalSince1970: 1_500),
            durationSeconds: 600
        )
        let boundarySession = FocusSession(
            taskID: boundaryTask.id,
            endedAt: range.end,
            durationSeconds: 600
        )
        let analytics = AnalyticsViewModel(calendar: calendar, now: range.start)

        #expect(analytics.completedTaskCount(
            in: [includedTask, boundaryTask, missingDateTask],
            during: range
        ) == 1)
        #expect(analytics.sessionsCount(
            in: [includedSession, boundarySession],
            during: range
        ) == 1)
        #expect(analytics.focusMinutes(
            in: [includedSession, boundarySession],
            during: range
        ) == 10)
    }

    @Test
    func energyCalculationsUseBeforeAndAfterRatings() {
        let reflections = [
            SessionReflection(
                taskID: UUID(),
                sessionID: UUID(),
                energyBefore: 2,
                energyAfter: 4
            ),
            SessionReflection(
                taskID: UUID(),
                sessionID: UUID(),
                energyBefore: 5,
                energyAfter: 3
            )
        ]
        let analytics = AnalyticsViewModel(calendar: calendar)

        #expect(analytics.netReportedEnergyChange(in: reflections) == 0)
        #expect(analytics.averageAfterSessionEnergy(in: reflections) == 3.5)
    }

    @Test
    func chartGroupsReflectionByLinkedSessionEndDate() {
        let dayOne = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let rangeEnd = calendar.date(byAdding: .day, value: 2, to: dayOne)!
        let task = LearningTask(
            goalID: UUID(),
            title: "Observed task",
            isCompleted: true,
            completedAt: dayOne.addingTimeInterval(3_600)
        )
        let session = FocusSession(
            taskID: task.id,
            startedAt: dayOne.addingTimeInterval(1_800),
            endedAt: dayOne.addingTimeInterval(3_600),
            durationSeconds: 1_800
        )
        let reflection = SessionReflection(
            taskID: task.id,
            sessionID: session.id,
            energyBefore: 2,
            energyAfter: 4,
            createdAt: dayTwo.addingTimeInterval(3_600)
        )
        let analytics = AnalyticsViewModel(calendar: calendar, now: dayOne)
        let points = analytics.chartPoints(
            tasks: [task],
            sessions: [session],
            reflections: [reflection],
            during: DateInterval(start: dayOne, end: rangeEnd)
        )

        #expect(points.count == 2)
        #expect(points[0].tasksCompleted == 1)
        #expect(points[0].energy == 4)
        #expect(points[1].energy == nil)
    }

    @Test
    func emptyPeriodsRemainInsufficientInsteadOfUsingSampleData() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        let analytics = AnalyticsViewModel(period: .daily, calendar: calendar, now: now)

        #expect(analytics.dailyAnalysis(tasks: [], sessions: [], reflections: []).state == .insufficient)

        analytics.updatePeriod(.monthly)
        #expect(analytics.monthlyAnalysis(tasks: [], sessions: [], reflections: []).state == .insufficient)
    }

    @Test
    func analyticsReadsPersistedIntegratedRecords() throws {
        let schema = Schema([
            LearningGoal.self,
            LearningTask.self,
            FocusSession.self,
            EnergyCheckIn.self,
            SessionReflection.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(
                    "AnalyticsIntegrationTests",
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
            ]
        )
        let context = container.mainContext
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let task = LearningTask(
            goalID: UUID(),
            title: "Persisted task",
            isCompleted: true,
            completedAt: now
        )
        let session = FocusSession(
            taskID: task.id,
            startedAt: now.addingTimeInterval(-900),
            endedAt: now,
            durationSeconds: 900
        )
        let reflection = SessionReflection(
            taskID: task.id,
            sessionID: session.id,
            energyBefore: 3,
            energyAfter: 4,
            cognitiveLoad: ReflectionCognitiveLoad.balanced.rawValue,
            helpfulFactors: [ReflectionHelpfulFactor.clearExamples.rawValue],
            notes: "Observed",
            createdAt: now
        )
        context.insert(task)
        context.insert(session)
        context.insert(reflection)
        try context.save()

        let savedTasks = try context.fetch(FetchDescriptor<LearningTask>())
        let savedSessions = try context.fetch(FetchDescriptor<FocusSession>())
        let savedReflections = try context.fetch(FetchDescriptor<SessionReflection>())
        let analytics = AnalyticsViewModel(period: .daily, calendar: calendar, now: now)

        #expect(analytics.completedTaskCount(in: savedTasks, during: analytics.selectedRange) == 1)
        #expect(analytics.sessionsCount(in: savedSessions, during: analytics.selectedRange) == 1)
        #expect(analytics.reflectionsInRange(
            savedReflections,
            sessions: savedSessions,
            during: analytics.selectedRange
        ).count == 1)
        #expect(analytics.dailyAnalysis(
            tasks: savedTasks,
            sessions: savedSessions,
            reflections: savedReflections
        ).state == .observed)
    }

    @Test
    func pdfExportProducesAPDFDocument() {
        let report = BioRhythmReportData(
            periodName: "Weekly",
            rangeTitle: "Nov 2 – Nov 8",
            generatedAt: Date(timeIntervalSince1970: 1_000),
            tasksDone: 1,
            sessions: 1,
            reflections: 1,
            netEnergy: 1,
            days: [
                .init(
                    date: Date(timeIntervalSince1970: 900),
                    label: "Mon 2",
                    tasks: 1,
                    energy: 4
                )
            ]
        )

        let pdf = BioRhythmReportBuilder.makePDF(data: report)

        #expect(pdf != nil)
        #expect(pdf?.isEmpty == false)
        #expect(pdf.map { Data($0.prefix(4)) } == Data("%PDF".utf8))
    }
}
