import Foundation
import SwiftData
import Testing
@testable import Ember

@MainActor
struct AIInsightsTests {
    @Test
    func energySummaryUsesOnlyRealCheckInsInTheSevenDayWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 18))!
        let checkIns = [
            EnergyCheckIn(createdAt: calendar.date(byAdding: .day, value: -6, to: now)!, level: 2),
            EnergyCheckIn(createdAt: calendar.date(byAdding: .day, value: -4, to: now)!, level: 3),
            EnergyCheckIn(createdAt: calendar.date(byAdding: .day, value: -2, to: now)!, level: 4),
            EnergyCheckIn(createdAt: calendar.date(byAdding: .day, value: -1, to: now)!, level: 5),
            EnergyCheckIn(createdAt: now.addingTimeInterval(-60), level: 5),
            EnergyCheckIn(createdAt: calendar.date(byAdding: .day, value: -7, to: now)!, level: 1)
        ]

        let summary = EnergySummary.make(from: checkIns, now: now, calendar: calendar)

        #expect(summary.checkInCount == 5)
        #expect(summary.activeDays == 5)
        #expect(summary.hasEnoughData)
        #expect(summary.gentleCount == 1)
        #expect(summary.steadyCount == 1)
        #expect(summary.highFocusCount == 3)
    }

    @Test
    func fallbackTextIsDeterministicWhenAIIsUnavailable() async throws {
        let summary = enoughDataSummary()
        let generator = StubAIGenerator()
        let service = EmberAIService(
            availabilityProvider: { .notSupported },
            generator: generator
        )

        let first = summary.fallbackText
        let second = summary.fallbackText
        let insight = try await service.weeklyInsight(from: summary)

        #expect(first == second)
        #expect(insight == nil)
        #expect(generator.weeklyRequestCount == 0)
    }

    @Test
    func availableServiceReturnsGeneratedInsight() async throws {
        let generator = StubAIGenerator()
        let service = EmberAIService(
            availabilityProvider: { .available },
            generator: generator
        )

        let insight = try await service.weeklyInsight(from: enoughDataSummary())

        #expect(insight?.headline == "A steady rhythm")
        #expect(generator.weeklyRequestCount == 1)
    }

    @Test
    func scopePolicyEnforcesEnergyRulesAndRejectsEmptyOrDuplicateTitles() {
        let lowEnergy = ScopeSuggestion(
            change: .smaller,
            reason: "Keep it gentle.",
            focusTaskTitle: "Read chapter",
            revisedTasks: [" Read two pages ", "", "read two pages", "Write one note", "Extra"]
        )
        let highEnergyWrongShape = ScopeSuggestion(
            change: .smaller,
            reason: "",
            focusTaskTitle: "Read chapter",
            revisedTasks: ["One", "Two"]
        )

        #expect(ScopeSuggestionPolicy.acceptedTitles(
            from: lowEnergy,
            energyLevel: 2,
            existingTitles: ["Read chapter"]
        ) == ["Read two pages", "Write one note", "Extra"])
        #expect(ScopeSuggestionPolicy.acceptedTitles(
            from: highEnergyWrongShape,
            energyLevel: 5,
            existingTitles: []
        ).isEmpty)
    }

    @Test
    func existingAndAIGeneratedTaskFlagsSurviveStoreReopen() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ember-ai-task-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let goalID = UUID()

        do {
            let container = try makeContainer(at: storeURL)
            container.mainContext.insert(LearningTask(goalID: goalID, title: "Existing task"))
            container.mainContext.insert(
                LearningTask(goalID: goalID, title: "Suggested task", isAIGenerated: true)
            )
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: storeURL)
        let tasks = try reopened.mainContext.fetch(
            FetchDescriptor<LearningTask>(sortBy: [SortDescriptor(\.title)])
        )

        #expect(tasks.map(\.title) == ["Existing task", "Suggested task"])
        #expect(tasks.map(\.isAIGenerated) == [false, true])
    }

    private func enoughDataSummary() -> EnergySummary {
        EnergySummary(
            periodDays: 7,
            checkInCount: 5,
            activeDays: 3,
            averageLevel: 3,
            gentleCount: 1,
            steadyCount: 3,
            highFocusCount: 1,
            buckets: [],
            bestBucket: nil,
            trend: .steady
        )
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([
            LearningGoal.self,
            LearningTask.self,
            EnergyCheckIn.self,
            FocusSession.self,
            SessionReflection.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

@MainActor
private final class StubAIGenerator: EmberAIGenerating {
    var weeklyRequestCount = 0

    func weeklyInsight(from summary: EnergySummary) async throws -> WeeklyInsight {
        weeklyRequestCount += 1
        return WeeklyInsight(
            headline: "A steady rhythm",
            summary: "Your recorded energy stayed steady.",
            suggestion: "Begin with one small task."
        )
    }

    func scopeSuggestion(energyLevel: Int, tasks: [String]) async throws -> ScopeSuggestion {
        ScopeSuggestion(
            change: .keep,
            reason: "Your current plan fits.",
            focusTaskTitle: "",
            revisedTasks: []
        )
    }
}
