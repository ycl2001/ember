import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIAvailability: Equatable, Hashable {
    case available
    case notSupported
    case notEnabled
    case notReady
    case unknown

    static var current: AIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .notSupported
            case .unavailable(.appleIntelligenceNotEnabled):
                return .notEnabled
            case .unavailable(.modelNotReady):
                return .notReady
            case .unavailable:
                return .unknown
            }
        }
        #endif
        return .notSupported
    }
}

struct WeeklyInsight: Equatable {
    let headline: String
    let summary: String
    let suggestion: String
}

enum ScopeChange: Equatable {
    case smaller
    case keep
    case bigger
}

struct ScopeSuggestion: Equatable {
    let change: ScopeChange
    let reason: String
    let focusTaskTitle: String
    let revisedTasks: [String]
}

@MainActor
protocol EmberAIGenerating {
    func weeklyInsight(from summary: EnergySummary) async throws -> WeeklyInsight
    func scopeSuggestion(energyLevel: Int, tasks: [String]) async throws -> ScopeSuggestion
}

final class EmberAIService {
    private let availabilityProvider: () -> AIAvailability
    private let generator: (any EmberAIGenerating)?

    init(
        availabilityProvider: @escaping () -> AIAvailability = { AIAvailability.current },
        generator: (any EmberAIGenerating)? = nil
    ) {
        self.availabilityProvider = availabilityProvider
        self.generator = generator
    }

    @MainActor
    var availability: AIAvailability {
        availabilityProvider()
    }

    @MainActor
    func weeklyInsight(from summary: EnergySummary) async throws -> WeeklyInsight? {
        guard availability == .available, summary.hasEnoughData else { return nil }
        if let generator {
            return try await generator.weeklyInsight(from: summary)
        }
        return try await systemGenerator()?.weeklyInsight(from: summary)
    }

    @MainActor
    func scopeSuggestion(energyLevel: Int, tasks: [String]) async throws -> ScopeSuggestion? {
        guard availability == .available, (1...5).contains(energyLevel), !tasks.isEmpty else { return nil }
        if let generator {
            return try await generator.scopeSuggestion(energyLevel: energyLevel, tasks: tasks)
        }
        return try await systemGenerator()?.scopeSuggestion(energyLevel: energyLevel, tasks: tasks)
    }

    @MainActor
    private func systemGenerator() -> (any EmberAIGenerating)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelGenerator()
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct GeneratedWeeklyInsight {
    @Guide(description: "A short, friendly title, maximum 6 words")
    var headline: String

    @Guide(description: "Two or three brief sentences explaining only patterns present in the supplied data. No medical claims.")
    var summary: String

    @Guide(description: "One concrete, small suggestion for next week")
    var suggestion: String
}

@available(iOS 26.0, *)
@Generable
private enum GeneratedScopeChange {
    case smaller
    case keep
    case bigger
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedScopeSuggestion {
    var change: GeneratedScopeChange

    @Guide(description: "One short sentence explaining the suggestion and today's energy")
    var reason: String

    @Guide(description: "The exact title of the unfinished task these steps relate to, copied from the supplied list. Empty when keeping the plan.")
    var focusTaskTitle: String

    @Guide(description: "For smaller, 2 or 3 short substeps. For bigger, exactly 1 optional stretch task. Empty when keeping the plan.", .maximumCount(3))
    var revisedTasks: [String]
}

@available(iOS 26.0, *)
@MainActor
private final class FoundationModelGenerator: EmberAIGenerating {
    private let instructions = """
    You are a gentle study-planning assistant inside a student app called Ember.
    Use only the data supplied by the learner. Be concise and encouraging.
    Never make medical or mental-health claims.
    """

    func weeklyInsight(from summary: EnergySummary) async throws -> WeeklyInsight {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: "Write a weekly learning-energy insight using only this data:\n\(summary.promptText)",
            generating: GeneratedWeeklyInsight.self
        )
        return WeeklyInsight(
            headline: response.content.headline,
            summary: response.content.summary,
            suggestion: response.content.suggestion
        )
    }

    func scopeSuggestion(energyLevel: Int, tasks: [String]) async throws -> ScopeSuggestion {
        let taskList = tasks.prefix(10).map { "- \($0)" }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: """
            Today's energy is \(energyLevel) out of 5. Levels 1-2 are low, 3 is steady, and 4-5 are high.
            These are the selected goal's unfinished tasks:
            \(taskList)

            For low energy choose smaller and create 2-3 small substeps of one supplied task.
            For steady energy choose keep when the current plan already fits.
            For high energy choose bigger and create exactly one optional stretch task.
            Never rename, replace, or delete a supplied task. Keep new titles under 80 characters.
            """,
            generating: GeneratedScopeSuggestion.self
        )
        let change: ScopeChange = switch response.content.change {
        case .smaller: .smaller
        case .keep: .keep
        case .bigger: .bigger
        }
        return ScopeSuggestion(
            change: change,
            reason: response.content.reason,
            focusTaskTitle: response.content.focusTaskTitle,
            revisedTasks: response.content.revisedTasks
        )
    }
}
#endif

struct AIBadge: View {
    var body: some View {
        Label("AI-assisted", systemImage: "sparkles")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("AI-assisted on this device")
    }
}
