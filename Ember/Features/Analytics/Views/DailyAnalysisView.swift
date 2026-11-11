import SwiftUI

private enum DailyPalette {
    static let ink = Color(red: 0.11, green: 0.18, blue: 0.15)
    static let heroBackground = Color(red: 0.04, green: 0.10, blue: 0.08)
    static let sparkline = Color(red: 0.72, green: 0.80, blue: 0.75)
    static let orange = Color(red: 0.93, green: 0.64, blue: 0.34)
    static let brown = Color(red: 0.55, green: 0.33, blue: 0.12)
    static let mint = Color(red: 0.85, green: 0.93, blue: 0.87)
    static let mintBadge = Color(red: 0.78, green: 0.92, blue: 0.82)
    static let green = Color(red: 0.55, green: 0.75, blue: 0.62)
    static let peach = Color(red: 0.98, green: 0.87, blue: 0.78)
    static let grey = Color(red: 0.91, green: 0.91, blue: 0.89)
    static let panel = Color(red: 0.95, green: 0.95, blue: 0.93)
}
struct DailyAnalysisView: View {
    let analysis: DailyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            switch analysis.state {
            case .sample:
                Label("Illustrative sample data", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DailyPalette.brown)
            case .insufficient:
                ContentUnavailableView {
                    Label("No analytics for this day", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Complete a task, finish a focus session, or save a reflection to create an observed result.")
                }
                .frame(maxWidth: .infinity)
            case .observed:
                observedContent
            }
        }
    }

    private var observedContent: some View {
        Group {
            DailyHeroCard(hero: analysis.hero)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    windowSectionTitle
                    Spacer(minLength: 12)
                    windowCount
                }
                VStack(alignment: .leading, spacing: 4) {
                    windowSectionTitle
                    windowCount
                }
            }

            VStack(spacing: 16) {
                ForEach(analysis.windows) { window in
                    DailyWindowCard(window: window)
                }
            }

            if let friction = analysis.friction {
                DailyEnergyChangeCard(observation: friction)
            }
        }
    }

    private var windowSectionTitle: some View {
        Text("Observed learning windows")
            .font(.title3.weight(.medium))
            .foregroundStyle(EmberTheme.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private var windowCount: some View {
        Text("\(analysis.windows.count) \(analysis.windows.count == 1 ? "interval" : "intervals") recorded")
            .font(.footnote)
            .foregroundStyle(EmberTheme.muted)
    }
}

private struct DailyHeroCard: View {
    let hero: DailyAnalysis.Hero

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    headline
                    Spacer(minLength: 0)
                    score
                }
                VStack(alignment: .leading, spacing: 6) {
                    headline
                    score
                }
            }

            Text(LocalizedStringKey(hero.body))
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if hero.curve.count > 1 {
                DailySparkline(values: hero.curve, peakIndex: hero.peakIndex)
                    .frame(height: 56)
                    .padding(.top, 4)
                    .accessibilityLabel("Hourly observed energy or activity trend")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DailyPalette.heroBackground, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private var headline: some View {
        Label(hero.headline, systemImage: "chart.line.uptrend.xyaxis")
            .font(.footnote.weight(.semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.9))
    }

    @ViewBuilder
    private var score: some View {
        if let score = hero.scoreText {
            Text(score)
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(.white)
        }
    }
}

private struct DailySparkline: View {
    let values: [Double]
    let peakIndex: Int

    var body: some View {
        GeometryReader { geometry in
            let points = points(in: geometry.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for index in 1..<points.count {
                        let previous = points[index - 1]
                        let current = points[index]
                        let midpoint = CGPoint(
                            x: (previous.x + current.x) / 2,
                            y: (previous.y + current.y) / 2
                        )
                        path.addQuadCurve(to: midpoint, control: previous)
                    }
                    if let last = points.last {
                        path.addLine(to: last)
                    }
                }
                .stroke(
                    DailyPalette.sparkline,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                ForEach(dotIndices(count: points.count), id: \.self) { index in
                    Circle()
                        .fill(index == peakIndex ? DailyPalette.orange : DailyPalette.sparkline)
                        .frame(width: index == peakIndex ? 12 : 8, height: index == peakIndex ? 12 : 8)
                        .position(points[index])
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let padding = 8.0
        let width = size.width - padding * 2
        let height = size.height - padding * 2
        return values.enumerated().map { index, value in
            CGPoint(
                x: padding + width * Double(index) / Double(values.count - 1),
                y: padding + height * (1 - min(max(value, 0), 1))
            )
        }
    }

    private func dotIndices(count: Int) -> [Int] {
        Set([peakIndex, count * 2 / 3, count - 1])
            .filter { $0 >= 0 && $0 < count }
            .sorted()
    }
}

private struct DailyWindowCard: View {
    let window: DailyAnalysis.Window

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 0)
                    badge
                }
                VStack(alignment: .leading, spacing: 8) {
                    heading
                    badge
                }
            }

            Text(LocalizedStringKey(window.summary))
                .font(.body)
                .foregroundStyle(DailyPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !window.chips.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { chips }
                    VStack(alignment: .leading, spacing: 8) { chips }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var heading: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(DailyPalette.ink)
                .frame(width: 44, height: 44)
                .background(iconBackground, in: Circle())
                .accessibilityHidden(true)

            Text(window.title)
                .font(.headline)
                .foregroundStyle(DailyPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var badge: some View {
        Text(window.badge)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(badgeForeground)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(badgeColor, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(window.chips) { chip in
            Label {
                Text(chip.text)
                    .foregroundStyle(EmberTheme.muted)
            } icon: {
                Image(systemName: chip.icon)
                    .foregroundStyle(chip.icon.contains("checkmark") ? DailyPalette.green : DailyPalette.ink)
            }
            .font(.footnote)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(DailyPalette.grey.opacity(0.7), in: Capsule())
        }
    }

    private var iconName: String {
        switch window.kind {
        case .morning: "sun.max.fill"
        case .afternoon: "clock.fill"
        case .evening: "moon.fill"
        }
    }

    private var iconBackground: Color {
        switch window.tone {
        case .peak: DailyPalette.mint
        case .steady: DailyPalette.peach
        case .recovery, .neutral: DailyPalette.grey
        }
    }

    private var badgeColor: Color {
        switch window.tone {
        case .peak: DailyPalette.mintBadge
        case .steady: DailyPalette.peach
        case .recovery, .neutral: DailyPalette.grey
        }
    }

    private var badgeForeground: Color {
        window.tone == .steady ? DailyPalette.brown : DailyPalette.ink
    }
}

private struct DailyEnergyChangeCard: View {
    let observation: DailyAnalysis.Friction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 0)
                    statusBadge
                }
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    statusBadge
                }
            }

            Text(observation.body)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: observation.reserve) {
                Text("Average after-session energy")
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
            }
            .tint(DailyPalette.heroBackground)
            .accessibilityValue(observation.status)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DailyPalette.panel, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var heading: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.title3)
                .foregroundStyle(DailyPalette.ink)
                .frame(width: 48, height: 48)
                .background(DailyPalette.mint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Energy reflection")
                    .font(.footnote)
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(EmberTheme.muted)
                Text(observation.headline)
                    .font(.headline)
                    .foregroundStyle(DailyPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var statusBadge: some View {
        Text(observation.status)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DailyPalette.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(observation.isProtected ? DailyPalette.mint : DailyPalette.peach, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}
