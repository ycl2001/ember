import Testing
import Foundation
import SwiftData
@testable import Ember

@MainActor
struct ReflectionFlowTests {
    @Test
    func navigationCarriesTheCompletedSessionIdentity() {
        let navigation = AppNavigation()
        let sessionID = UUID()

        navigation.openReflection(sessionID: sessionID)

        #expect(navigation.pendingReflectionSessionID == sessionID)
        #expect(navigation.path == [.reflection])
    }

    @Test
    func loadsTheExactCompletedSessionAndItsTask() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let selectedTask = LearningTask(goalID: UUID(), title: "Selected task")
        let otherTask = LearningTask(goalID: UUID(), title: "Other task")
        let selectedSession = FocusSession(
            taskID: selectedTask.id,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_900),
            durationSeconds: 720
        )
        let otherSession = FocusSession(
            taskID: otherTask.id,
            startedAt: Date(timeIntervalSince1970: 2_000),
            endedAt: Date(timeIntervalSince1970: 2_300),
            durationSeconds: 300
        )
        let before = EnergyCheckIn(
            createdAt: Date(timeIntervalSince1970: 900),
            level: 4
        )
        context.insert(selectedTask)
        context.insert(otherTask)
        context.insert(selectedSession)
        context.insert(otherSession)
        context.insert(before)
        try context.save()

        let viewModel = ReflectionViewModel()
        viewModel.load(
            sessionID: selectedSession.id,
            sessions: [otherSession, selectedSession],
            tasks: [otherTask, selectedTask],
            checkIns: [before],
            reflections: []
        )

        #expect(viewModel.summary?.sessionID == selectedSession.id)
        #expect(viewModel.summary?.taskID == selectedTask.id)
        #expect(viewModel.summary?.taskTitle == "Selected task")
        #expect(viewModel.summary?.durationSeconds == 720)
        #expect(viewModel.summary?.durationText == "12 min")
        #expect(viewModel.energyBefore == 4)
    }

    @Test
    func energyValidationAndChangeHandleEveryDirection() {
        let viewModel = ReflectionViewModel()

        viewModel.selectEnergyBefore(4)
        viewModel.selectEnergyAfter(2)
        #expect(viewModel.energySpent == 2)

        viewModel.selectEnergyAfter(5)
        #expect(viewModel.energySpent == -1)

        viewModel.selectEnergyAfter(4)
        #expect(viewModel.energySpent == 0)

        viewModel.selectEnergyAfter(0)
        #expect(viewModel.energyAfter == 4)
        viewModel.selectEnergyAfter(6)
        #expect(viewModel.energyAfter == 4)
    }

    @Test
    func savesStructuredAnswersAndRepeatedSaveIsAnUpsert() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let task = LearningTask(goalID: UUID(), title: "Practice SwiftData")
        let session = FocusSession(
            taskID: task.id,
            startedAt: .now.addingTimeInterval(-600),
            endedAt: .now,
            durationSeconds: 600
        )
        context.insert(task)
        context.insert(session)
        try context.save()

        let viewModel = ReflectionViewModel()
        viewModel.load(
            sessionID: session.id,
            sessions: [session],
            tasks: [task],
            checkIns: [],
            reflections: []
        )
        viewModel.selectedCognitiveLoad = .balanced
        viewModel.selectEnergyBefore(4)
        viewModel.selectEnergyAfter(3)
        viewModel.toggle(.clearExamples)
        viewModel.toggle(.shortFocusIntervals)
        viewModel.notes = "  A short pause helped.  "

        #expect(viewModel.save(in: context))
        viewModel.notes = "Updated note"
        #expect(viewModel.save(in: context))

        let records = try context.fetch(FetchDescriptor<SessionReflection>())
        #expect(records.count == 1)
        #expect(records.first?.sessionID == session.id)
        #expect(records.first?.taskID == task.id)
        #expect(records.first?.energyBefore == 4)
        #expect(records.first?.energyAfter == 3)
        #expect(records.first?.energySpent == 1)
        #expect(records.first?.cognitiveLoad == ReflectionCognitiveLoad.balanced.rawValue)
        #expect(
            Set(records.first?.helpfulFactors ?? [])
                == Set([
                    ReflectionHelpfulFactor.clearExamples.rawValue,
                    ReflectionHelpfulFactor.shortFocusIntervals.rawValue
                ])
        )
        #expect(records.first?.notes == "Updated note")
    }

    @Test
    func handlesMissingSessionWithoutInventingData() throws {
        let viewModel = ReflectionViewModel()
        viewModel.load(
            sessionID: UUID(),
            sessions: [],
            tasks: [],
            checkIns: [],
            reflections: []
        )

        #expect(viewModel.isMissingSession)
        #expect(viewModel.summary == nil)
        #expect(viewModel.energyBefore == nil)
        #expect(!viewModel.canSave)
    }

    @Test
    func reflectionRemainsAvailableAfterReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EmberReflectionTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appending(path: "Reflection.store")
        let schema = reflectionSchema()
        let configuration = ModelConfiguration(
            "ReflectionPersistenceTests",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        var firstContainer: ModelContainer? = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let sessionID = UUID()
        let taskID = UUID()
        firstContainer?.mainContext.insert(
            SessionReflection(
                taskID: taskID,
                sessionID: sessionID,
                energyBefore: 2,
                energyAfter: 4,
                cognitiveLoad: ReflectionCognitiveLoad.effortless.rawValue,
                helpfulFactors: [ReflectionHelpfulFactor.quietStudySpace.rawValue],
                notes: "Persist me"
            )
        )
        try firstContainer?.mainContext.save()
        firstContainer = nil

        let reopenedContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let records = try reopenedContainer.mainContext.fetch(
            FetchDescriptor<SessionReflection>()
        )

        #expect(records.count == 1)
        #expect(records.first?.sessionID == sessionID)
        #expect(records.first?.taskID == taskID)
        #expect(records.first?.energySpent == -2)
        #expect(records.first?.notes == "Persist me")
    }

    @Test
    func analyticsReadsSavedReflectionEnergy() {
        let records = [
            SessionReflection(
                taskID: UUID(),
                sessionID: UUID(),
                energyBefore: 5,
                energyAfter: 3
            ),
            SessionReflection(
                taskID: UUID(),
                sessionID: UUID(),
                energyBefore: 2,
                energyAfter: 4
            )
        ]

        let analytics = AnalyticsViewModel()
        #expect(analytics.netReportedEnergyChange(in: records) == 0)
        #expect(records.count == 2)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: reflectionSchema(),
            configurations: [
                ModelConfiguration(
                    "ReflectionUnitTests",
                    schema: reflectionSchema(),
                    isStoredInMemoryOnly: true
                )
            ]
        )
    }

    private func reflectionSchema() -> Schema {
        Schema([
            LearningGoal.self,
            LearningTask.self,
            FocusSession.self,
            EnergyCheckIn.self,
            SessionReflection.self
        ])
    }
}
