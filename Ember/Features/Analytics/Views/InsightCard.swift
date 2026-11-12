import Observation
import SwiftUI

@MainActor
@Observable
private final class WeeklyInsightLoader {
    var insight: WeeklyInsight?
    var isLoading = false

    private let ai: EmberAIService
    private var lastSummary: EnergySummary?
    private var lastAvailability: AIAvailability?

    init(ai: EmberAIService = EmberAIService()) {
        self.ai = ai
    }

    func load(summary: EnergySummary) async {
        let availability = ai.availability
        guard lastSummary != summary || lastAvailability != availability else { return }
        lastSummary = summary
        lastAvailability = availability
        insight = nil

        guard summary.hasEnoughData, availability == .available else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            insight = try await ai.weeklyInsight(from: summary)
        } catch is CancellationError {
            lastSummary = nil
            lastAvailability = nil
        } catch {
            insight = nil
        }
    }
}

private struct WeeklyInsightRequest: Hashable {
    let summary: EnergySummary
    let isActive: Bool
}

struct InsightCard: View {
    let summary: EnergySummary

    @Environment(\.scenePhase) private var scenePhase
    @State private var loader = WeeklyInsightLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week's insight")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                Spacer()
                if loader.insight != nil {
                    AIBadge()
                }
            }

            if let insight = loader.insight {
                Text(insight.headline)
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                Text(insight.summary)
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.primary)
                Text(insight.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
                Text("Generated on this device")
                    .font(.caption)
                    .foregroundStyle(EmberTheme.muted)
            } else if loader.isLoading {
                ProgressView("Preparing your insight…")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            } else {
                Text(summary.fallbackText)
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        .task(id: WeeklyInsightRequest(summary: summary, isActive: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            await loader.load(summary: summary)
        }
    }
}
