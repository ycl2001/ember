import SwiftUI

/// Weekly AI insight for the Analytics tab.
/// Suggested location: Features/Analytics/Views/InsightCard.swift
/// Remove the old InsightCard from Core/AI/EmberAI.swift so there is only one.
struct InsightCard: View {
    let summary: EnergySummary

    @State private var insight: WeeklyInsight?
    @State private var isLoading = false
    private let ai = EmberAIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week's insight")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                Spacer()
                if insight != nil {
                    AIBadge()
                }
            }

            if let insight {
                Text(insight.headline)
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                Text(insight.summary)
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.primary)
                if let tip = insight.suggestions.first {
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.muted)
                }
                Text("Generated on this device")
                    .font(.caption)
                    .foregroundStyle(EmberTheme.muted)
            } else if isLoading {
                ProgressView("Preparing your insight…")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            } else {
                // Rule-based fallback: not AI, so no badge.
                Text(summary.fallbackText)
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        // Re-runs when a new check-in is saved.
        .task(id: summary.checkInCount) {
            await loadInsight()
        }
    }

    private func loadInsight() async {
        isLoading = true
        defer { isLoading = false }
        insight = try? await ai.weeklyInsight(from: summary)
    }
}
