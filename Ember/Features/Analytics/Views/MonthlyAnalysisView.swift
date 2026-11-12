///MonthlyAnalysisView

import SwiftUI

// MARK: - Palette (local, so this file doesn't depend on new EmberTheme members)

private enum MonthlyPalette {
    static let ink = Color(red: 0.11, green: 0.18, blue: 0.15)
    static let brown = Color(red: 0.55, green: 0.33, blue: 0.12)
    static let mint = Color(red: 0.85, green: 0.93, blue: 0.87)
    static let mintBadge = Color(red: 0.78, green: 0.92, blue: 0.82)
    static let orange = Color(red: 0.93, green: 0.64, blue: 0.34)
    static let peach = Color(red: 0.98, green: 0.87, blue: 0.78)
    static let grey = Color(red: 0.91, green: 0.91, blue: 0.89)
    static let panel = Color(red: 0.95, green: 0.95, blue: 0.93)
    static let emptyDot = Color(red: 0.94, green: 0.94, blue: 0.93)
}

/// Markdown text where **bold** parts are drawn in a stronger colour than the rest.
private func richText(_ markdown: String, base: Color, strong: Color) -> Text {
    guard var attributed = try? AttributedString(markdown: markdown) else { return Text(markdown) }
    attributed.foregroundColor = base
    let strongRanges = attributed.runs
        .filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        .map(\.range)
    for range in strongRanges {
        attributed[range].foregroundColor = strong
    }
    return Text(attributed)
}

// MARK: - Monthly tab

struct MonthlyAnalysisView: View {
    let analysis: MonthlyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if analysis.state == .sample {
                Label("Showing sample data", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonthlyPalette.brown)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(MonthlyPalette.peach.opacity(0.6), in: Capsule())
            }

            if analysis.state == .insufficient {
                ContentUnavailableView {
                    Label("No analytics for this month", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("Complete a task, finish a focus session, or save a reflection to create an observed result.")
                }
                .frame(maxWidth: .infinity)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        MonthlyStatCardView(eyebrow: "Monthly Activity", card: analysis.streak)
                        MonthlyStatCardView(eyebrow: "Avg Energy", card: analysis.energy)
                    }

                    VStack(spacing: 12) {
                        MonthlyStatCardView(eyebrow: "Monthly Activity", card: analysis.streak)
                        MonthlyStatCardView(eyebrow: "Avg Energy", card: analysis.energy)
                    }
                }

                ReflectiveCadenceCard(eyebrow: analysis.cadenceEyebrow, title: analysis.cadenceTitle)
                SpotMatrixCard(analysis: analysis)

                if !analysis.insights.isEmpty {
                    RhythmSynthesisCard(insights: analysis.insights)
                }
            }
        }
    }
}

// MARK: - Stat cards (Monthly Streak / Avg Energy)

private struct MonthlyStatCardView: View {
    let eyebrow: String
    let card: MonthlyAnalysis.StatCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.footnote.weight(.medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MonthlyPalette.ink.opacity(0.75))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(card.value)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(MonthlyPalette.ink)
                if let unit = card.unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.muted)
                        .lineLimit(1)
                }
            }

            Text(card.caption)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)

            Label(card.badge, systemImage: card.badgeIcon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(badgeForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(badgeBackground, in: Capsule())

            Text(card.footnote)
                .font(.footnote)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var badgeBackground: Color {
        switch card.badgeTone {
        case .mint: return MonthlyPalette.mintBadge
        case .peach: return MonthlyPalette.peach
        case .grey: return MonthlyPalette.grey
        }
    }

    private var badgeForeground: Color {
        switch card.badgeTone {
        case .mint: return Color(red: 0.14, green: 0.33, blue: 0.24)
        case .peach: return MonthlyPalette.brown
        case .grey: return MonthlyPalette.ink
        }
    }
}

// MARK: - Reflective cadence card
// Add an image named "ReflectiveCadence" to Assets.xcassets to show a photo; otherwise a warm gradient is used.

private struct ReflectiveCadenceCard: View {
    let eyebrow: String
    let title: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background

            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(.footnote)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "leaf.fill")
                .font(.body)
                .foregroundStyle(MonthlyPalette.ink)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.9), in: Circle())
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    @ViewBuilder
    private var background: some View {
        if UIImage(named: "ReflectiveCadence") != nil {
            Image("ReflectiveCadence")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [Color(red: 0.40, green: 0.31, blue: 0.20), Color(red: 0.13, green: 0.10, blue: 0.07)],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
        }
    }
}

// MARK: - 4-Week Spot Matrix

private struct SpotMatrixCard: View {
    let analysis: MonthlyAnalysis

    private let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let labelWidth: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("4-Week Spot Matrix")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(MonthlyPalette.ink)
                Spacer()
                Text("Last 4 Weeks")
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(MonthlyPalette.grey.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            }

            Text(analysis.matrixDescription)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            // Weekday header
            HStack(spacing: 0) {
                Color.clear.frame(width: labelWidth, height: 1)
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MonthlyPalette.ink.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // Week rows
            VStack(spacing: 8) {
                ForEach(analysis.weeks) { week in
                    HStack(spacing: 0) {
                        Text(week.label)
                            .font(.footnote)
                            .foregroundStyle(EmberTheme.muted)
                            .frame(width: labelWidth, alignment: .leading)

                        ForEach(week.cells) { cell in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(
                                        EmberEnergyScale.color(for: cell.level)
                                            ?? MonthlyPalette.emptyDot
                                    )
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Circle().stroke(EmberTheme.primary, lineWidth: 1)
                                    }
                                Text(cell.day, format: .number.precision(.integerLength(2)))
                                    .font(.footnote)
                                    .foregroundStyle(EmberTheme.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Day \(cell.day)")
                            .accessibilityValue(
                                cell.level.map { "Average after-session energy \($0) of 5" }
                                    ?? "No energy observation"
                            )
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(MonthlyPalette.panel, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            // Legend
            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                spacing: 10
            ) {
                ForEach(analysis.legend) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                EmberEnergyScale.color(for: item.level)
                                    ?? MonthlyPalette.emptyDot
                            )
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle().stroke(EmberTheme.primary, lineWidth: 1)
                            }
                        HStack(spacing: 4) {
                            Text("Level \(item.level) \(item.name)")
                                .foregroundStyle(MonthlyPalette.ink)
                            Text("(\(item.days) days)")
                                .foregroundStyle(EmberTheme.muted)
                        }
                        .font(.footnote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonthlyPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Monthly Rhythm Synthesis

private struct RhythmSynthesisCard: View {
    let insights: [MonthlyAnalysis.Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundStyle(MonthlyPalette.ink)
                Text("Monthly Rhythm Synthesis")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(MonthlyPalette.ink)
            }

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(insight.tone == .mint ? MonthlyPalette.ink : MonthlyPalette.brown)
                        .frame(width: 40, height: 40)
                        .background(
                            insight.tone == .mint ? MonthlyPalette.mint : MonthlyPalette.peach,
                            in: RoundedRectangle(cornerRadius: 10)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonthlyPalette.ink)
                        richText(insight.body, base: EmberTheme.muted, strong: MonthlyPalette.ink)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MonthlyPalette.panel, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}
