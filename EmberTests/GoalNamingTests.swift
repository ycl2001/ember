import Foundation
import SwiftData
import Testing
@testable import Ember

@MainActor
struct GoalNamingTests {
    @Test
    func createsGoalWithoutCategoryOrSuggestedTopic() throws {
        let container = try makeContainer()
        let viewModel = OnboardingViewModel()
        viewModel.draftGoalName = "  Master conversational French  "

        #expect(viewModel.saveGoalDraft())
        #expect(viewModel.goalDrafts.first?.category == nil)
        #expect(viewModel.advance())
        #expect(viewModel.finish(in: container.mainContext, existingGoals: []))

        let goals = try container.mainContext.fetch(FetchDescriptor<LearningGoal>())
        #expect(goals.count == 1)
        #expect(goals.first?.topic == "Master conversational French")
        #expect(goals.first?.category == nil)
    }

    @Test
    func createsMultipleGoalsWithDifferentCategories() throws {
        let container = try makeContainer()
        let viewModel = OnboardingViewModel()

        viewModel.draftGoalName = "Pass AWS Cloud Practitioner"
        viewModel.draftGoalCategory = .professional
        #expect(viewModel.saveGoalDraft())
        viewModel.draftGoalName = "Understand macroeconomics"
        viewModel.draftGoalCategory = .academic
        #expect(viewModel.saveGoalDraft())
        viewModel.draftGoalName = "Cook five Thai dishes"
        viewModel.draftGoalCategory = .leisure
        #expect(viewModel.saveGoalDraft())
        #expect(viewModel.advance())
        #expect(viewModel.finish(in: container.mainContext, existingGoals: []))

        let goals = try container.mainContext.fetch(FetchDescriptor<LearningGoal>())
        #expect(goals.count == 3)
        #expect(goals.first { $0.topic == "Pass AWS Cloud Practitioner" }?.category == LearningCategory.professional.rawValue)
        #expect(goals.first { $0.topic == "Understand macroeconomics" }?.category == LearningCategory.academic.rawValue)
        #expect(goals.first { $0.topic == "Cook five Thai dishes" }?.category == LearningCategory.leisure.rawValue)
    }

    @Test
    func editsAndRemovesDraftsBeforeContinuing() throws {
        let viewModel = OnboardingViewModel()
        viewModel.draftGoalName = "Learn French"
        #expect(viewModel.saveGoalDraft())
        let first = try #require(viewModel.goalDrafts.first)

        viewModel.editGoalDraft(first)
        viewModel.draftGoalName = "Master conversational French"
        viewModel.draftGoalCategory = .leisure
        #expect(viewModel.saveGoalDraft())
        #expect(viewModel.goalDrafts.first?.name == "Master conversational French")
        #expect(viewModel.goalDrafts.first?.category == .leisure)

        let edited = try #require(viewModel.goalDrafts.first)
        viewModel.removeGoalDraft(edited)
        #expect(viewModel.goalDrafts.isEmpty)
    }

    @Test
    func validationAppearsOnlyAfterInvalidActionAndPreventsDuplicates() {
        let viewModel = OnboardingViewModel()
        #expect(viewModel.goalDraftError == nil)
        #expect(!viewModel.saveGoalDraft())
        #expect(viewModel.goalDraftError != nil)

        viewModel.draftGoalName = "Learn French"
        #expect(viewModel.goalDraftError == nil)
        #expect(viewModel.saveGoalDraft())
        viewModel.draftGoalName = "learn french"
        #expect(!viewModel.saveGoalDraft())
        #expect(viewModel.goalDrafts.count == 1)
    }

    @Test
    func skippingGoalSetupCreatesNoDefaultGoal() throws {
        let container = try makeContainer()
        let viewModel = OnboardingViewModel()
        viewModel.skipGoals()
        #expect(viewModel.finish(in: container.mainContext, existingGoals: []))
        #expect(try container.mainContext.fetch(FetchDescriptor<LearningGoal>()).isEmpty)
    }

    @Test
    func reopeningOnboardingAddsAnotherGoalWithoutDuplicatingExistingOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existing = LearningGoal(topic: "Master conversational French", category: LearningCategory.leisure.rawValue)
        context.insert(existing)
        try context.save()

        let viewModel = OnboardingViewModel()
        viewModel.draftGoalName = "master conversational french"
        #expect(!viewModel.saveGoalDraft(existingGoals: [existing]))
        viewModel.draftGoalName = "Pass the architecture interview"
        viewModel.draftGoalCategory = .professional
        #expect(viewModel.saveGoalDraft(existingGoals: [existing]))
        #expect(viewModel.advance(existingGoals: [existing]))
        #expect(viewModel.finish(in: context, existingGoals: [existing]))

        #expect(try context.fetch(FetchDescriptor<LearningGoal>()).count == 2)
    }

    @Test
    func renameAndRecategoriseUpdateGoalInPlaceAndPreserveRelatedRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let goal = LearningGoal(topic: "Certifications", category: LearningCategory.professional.rawValue)
        let task = LearningTask(goalID: goal.id, title: "Study IAM", isCompleted: true, completedAt: .now)
        let session = FocusSession(taskID: task.id, endedAt: .now, durationSeconds: 600)
        let reflection = SessionReflection(
            taskID: task.id,
            sessionID: session.id,
            energyBefore: 4,
            energyAfter: 3,
            notes: "Kept my focus"
        )
        context.insert(goal)
        context.insert(task)
        context.insert(session)
        context.insert(reflection)
        try context.save()
        let originalID = goal.id

        let viewModel = TaskPlannerViewModel()
        viewModel.prepareGoalRename(goal)
        viewModel.draftGoalName = "Pass AWS Cloud Practitioner"
        viewModel.draftGoalCategory = .academic
        try viewModel.renameGoal(goal, goals: [goal], in: context)

        #expect(goal.id == originalID)
        #expect(goal.topic == "Pass AWS Cloud Practitioner")
        #expect(goal.category == LearningCategory.academic.rawValue)
        #expect(task.goalID == originalID)
        #expect(task.isCompleted)
        #expect(try context.fetch(FetchDescriptor<FocusSession>()).first?.id == session.id)
        #expect(try context.fetch(FetchDescriptor<SessionReflection>()).first?.id == reflection.id)
    }

    @Test
    func renameRejectsEmptyAndDuplicateNames() throws {
        let container = try makeContainer()
        let first = LearningGoal(topic: "First goal")
        let second = LearningGoal(topic: "Second goal")
        container.mainContext.insert(first)
        container.mainContext.insert(second)

        let viewModel = TaskPlannerViewModel()
        viewModel.prepareGoalRename(first)
        viewModel.draftGoalName = "  "
        #expect(throws: (any Error).self) {
            try viewModel.renameGoal(first, goals: [first, second], in: container.mainContext)
        }
        viewModel.draftGoalName = "second GOAL"
        #expect(throws: (any Error).self) {
            try viewModel.renameGoal(first, goals: [first, second], in: container.mainContext)
        }
        #expect(first.topic == "First goal")
    }

    @Test
    func sessionsGroupsCategorisedAndUncategorisedGoals() {
        let goals = [
            LearningGoal(topic: "Write a thesis", category: LearningCategory.academic.rawValue),
            LearningGoal(topic: "Earn a certification", category: LearningCategory.professional.rawValue),
            LearningGoal(topic: "Learn pottery")
        ]

        let groups = TaskPlannerViewModel().groupedGoals(goals)

        #expect(groups.map(\.title) == ["Academic", "Professional", "Uncategorised"])
        #expect(groups.flatMap(\.goals).count == 3)
    }

    @Test
    func renamedAndRecategorisedGoalPersistsAfterReopeningSwiftData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EmberGoalNaming-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Goals.store")
        let goalID = UUID()

        do {
            let container = try makeContainer(url: storeURL)
            let goal = LearningGoal(id: goalID, topic: "Certifications")
            container.mainContext.insert(goal)
            try container.mainContext.save()
            let viewModel = TaskPlannerViewModel()
            viewModel.prepareGoalRename(goal)
            viewModel.draftGoalName = "Pass AWS Cloud Practitioner"
            viewModel.draftGoalCategory = .professional
            try viewModel.renameGoal(goal, goals: [goal], in: container.mainContext)
        }

        let reopened = try makeContainer(url: storeURL)
        let goals = try reopened.mainContext.fetch(FetchDescriptor<LearningGoal>())
        #expect(goals.count == 1)
        #expect(goals.first?.id == goalID)
        #expect(goals.first?.topic == "Pass AWS Cloud Practitioner")
        #expect(goals.first?.category == LearningCategory.professional.rawValue)
    }

    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([
            LearningGoal.self,
            LearningTask.self,
            EnergyCheckIn.self,
            FocusSession.self,
            SessionReflection.self
        ])
        let configuration = if let url {
            ModelConfiguration("GoalNamingTests", schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            ModelConfiguration("GoalNamingTests", schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
