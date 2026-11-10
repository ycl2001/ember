import SwiftUI
import FoundationModels

// MARK: - 1. Availability

enum AIAvailability {
    case available
    case notSupported          // device can never run it
    case notEnabled            // user hasn't turned on Apple Intelligence
    case notReady              // model still downloading
    case unknown

    static var current: AIAvailability {
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

    var isAvailable: Bool { self == .available }
}

// MARK: - 2. Structured outputs (guided generation)

/// Weekly insight shown on the Analytics page.
@Generable
struct WeeklyInsight {
    @Guide(description: "A short, friendly title, max 6 words")
    var headline: String

    @Guide(description: "2-3 sentences explaining the pattern in the data. Supportive tone. No medical claims.")
    var summary: String

    @Guide(description: "One concrete, small suggestion for next week", .count(1))
    var suggestions: [String]
}

/// Checklist scope suggestion for the Session page.
@Generable
enum ScopeChange {
    case smaller
    case keep
    case bigger
}

@Generable
struct ScopeSuggestion {
    var change: ScopeChange

    @Guide(description: "One short sentence explaining why, mentioning today's energy")
    var reason: String

    @Guide(description: "Exact title of the unfinished task these steps relate to, copied from the list. Empty if keep.")
    var focusTaskTitle: String

    @Guide(description: "smaller: 2-3 short sub-steps of the focus task. bigger: 1 optional stretch task. keep: empty.", .maximumCount(3))
    var revisedTasks: [String]
}



// MARK: - 4. AI service

@MainActor
final class EmberAIService {
    private let instructions = """
    You are a gentle study-planning assistant inside a student app called Ember.
    Use only the data provided. Keep a warm, encouraging tone.
    Never give medical or mental-health advice. Be brief.
    """

    func weeklyInsight(from summary: EnergySummary) async throws -> WeeklyInsight? {
        guard AIAvailability.current.isAvailable, summary.hasEnoughData else { return nil }

        // New session per request keeps the context small.
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: "Write a weekly insight from this data:\n\(summary.promptText)",
            generating: WeeklyInsight.self
        )
        return response.content
    }

    func scopeSuggestion(energyLevel: Int, tasks: [String]) async throws -> ScopeSuggestion? {
        guard AIAvailability.current.isAvailable, !tasks.isEmpty else { return nil }

        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Today's energy: \(energyLevel) out of 5 (1-2 low, 3 steady, 4-5 high).
        Unfinished tasks:
        \(tasks.prefix(10).map { "- \($0)" }.joined(separator: "\n"))

        Decide whether today's plan should be smaller, keep, or bigger.
        - Low energy: smaller. Give 2-3 tiny sub-steps of the most demanding task.
        - Steady energy: keep.
        - High energy: bigger. Give 1 optional stretch task.
        Keep every task title under 8 words.
        """
        let response = try await session.respond(to: prompt, generating: ScopeSuggestion.self)
        return response.content
    }
}

// MARK: - 5. AI badge

struct AIBadge: View {
    var label: String = "AI-assisted"

    var body: some View {
        Label(label, systemImage: "sparkles")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("Generated with AI on this device")
    }
}

