///DailyAnalysisView

import SwiftUI

// MARK: - Palette (local, so this file doesn't depend on new EmberTheme members)

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

// MARK: - Daily tab

struct DailyAnalysisView: View {
    let analysis: DailyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            if analysis.isSample {
                Label("Showing sample data", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DailyPalette.brown)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(DailyPalette.peach.opacity(0.6), in: Capsule())
            }

            DailyHeroCard(hero: analysis.hero)

            HStack(alignment: .firstTextBaseline) {
                Text("Observed Bio-Windows")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(EmberTheme.primary)
                Spacer()
                Text("\(analysis.windows.count) \(analysis.windows.count == 1 ? "interval" : "intervals") recorded")
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
            }

            VStack(spacing: 16) {
                ForEach(analysis.windows) { window in
                    DailyWindowCard(window: window)
                }
            }

            if let friction = analysis.friction {
                DailyFrictionCard(friction: friction)
            }

            StudyEnvironmentCard()
        }
    }
}

// MARK: - Hero card

private struct DailyHeroCard: View {
    let hero: DailyAnalysis.Hero

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(hero.headline, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let score = hero.scoreText {
                    Text(score)
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                }
            }

            Text(LocalizedStringKey(hero.body))
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            DailySparkline(values: hero.curve, peakIndex: hero.peakIndex)
                .frame(height: 56)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DailyPalette.heroBackground, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct DailySparkline: View {
    let values: [Double]
    let peakIndex: Int

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            if pts.count > 1 {
                ZStack {
                    Path { path in
                        path.move(to: pts[0])
                        for i in 1..<pts.count {
                            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2,
                                              y: (pts[i - 1].y + pts[i].y) / 2)
                            path.addQuadCurve(to: mid, control: pts[i - 1])
                        }
                        path.addLine(to: pts[pts.count - 1])
                    }
                    .stroke(DailyPalette.sparkline,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    ForEach(dotIndices(count: pts.count), id: \.self) { i in
                        Circle()
                            .fill(i == peakIndex ? DailyPalette.orange : DailyPalette.sparkline)
                            .frame(width: i == peakIndex ? 12 : 8, height: i == peakIndex ? 12 : 8)
                            .position(pts[i])
                    }
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let pad: CGFloat = 8
        let w = size.width - pad * 2
        let h = size.height - pad * 2
        return values.enumerated().map { i, v in
            CGPoint(
                x: pad + w * CGFloat(i) / CGFloat(values.count - 1),
                y: pad + h * (1 - CGFloat(min(max(v, 0), 1)))
            )
        }
    }

    private func dotIndices(count: Int) -> [Int] {
        Set([peakIndex, count * 2 / 3, count - 1])
            .filter { $0 >= 0 && $0 < count }
            .sorted()
    }
}

// MARK: - Window card (morning / afternoon / evening)

private struct DailyWindowCard: View {
    let window: DailyAnalysis.Window

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DailyPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(iconBackground, in: Circle())

                Text(window.title)
                    .font(.headline)
                    .foregroundStyle(DailyPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                Text(window.badge)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(badgeForeground)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(badgeBackground, in: Capsule())
                    .fixedSize()
            }

            Text(LocalizedStringKey(window.summary))
                .font(.body)
                .foregroundStyle(DailyPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !window.chips.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { chipViews }
                    VStack(alignment: .leading, spacing: 8) { chipViews }
                }
            }

            if let note = window.note {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: note.icon)
                        .foregroundStyle(DailyPalette.brown)
                    (Text(note.lead).foregroundStyle(EmberTheme.muted)
                     + Text(note.highlight).bold().foregroundStyle(DailyPalette.brown)
                     + Text(".").foregroundStyle(EmberTheme.muted))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DailyPalette.panel, in: RoundedRectangle(cornerRadius: 12))
            }

            if let footer = window.footer {
                HStack(spacing: 8) {
                    Circle().fill(DailyPalette.green).frame(width: 8, height: 8)
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(EmberTheme.muted)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    @ViewBuilder
    private var chipViews: some View {
        ForEach(window.chips) { chip in
            HStack(spacing: 6) {
                Image(systemName: chip.icon)
                    .foregroundStyle(chip.icon.contains("checkmark") ? DailyPalette.green : DailyPalette.ink)
                Text(chip.text)
                    .foregroundStyle(EmberTheme.muted)
            }
            .font(.footnote)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(DailyPalette.grey.opacity(0.7), in: Capsule())
        }
    }

    private var iconName: String {
        switch window.kind {
        case .morning: return "sun.max.fill"
        case .afternoon: return "clock.fill"
        case .evening: return "moon.fill"
        }
    }

    private var iconBackground: Color {
        switch window.tone {
        case .peak: return DailyPalette.mint
        case .steady: return DailyPalette.peach
        case .recovery, .neutral: return DailyPalette.grey
        }
    }

    private var badgeBackground: Color {
        switch window.tone {
        case .peak: return DailyPalette.mintBadge
        case .steady: return DailyPalette.peach
        case .recovery, .neutral: return DailyPalette.grey
        }
    }

    private var badgeForeground: Color {
        window.tone == .steady ? DailyPalette.brown : DailyPalette.ink
    }
}

// MARK: - Friction factor card

private struct DailyFrictionCard: View {
    let friction: DailyAnalysis.Friction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "brain")
                    .font(.title3)
                    .foregroundStyle(DailyPalette.ink)
                    .frame(width: 48, height: 48)
                    .background(DailyPalette.mint, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Friction Factor")
                        .font(.footnote)
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(EmberTheme.muted)
                    Text(friction.headline)
                        .font(.headline)
                        .foregroundStyle(DailyPalette.ink)
                }

                Spacer(minLength: 0)

                Text(friction.status)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DailyPalette.ink)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(friction.isProtected ? DailyPalette.mintBadge : DailyPalette.peach, in: Capsule())
                    .fixedSize()
            }

            Text(friction.body)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                HStack {
                    Text("Cognitive Reserve Retained")
                        .font(.footnote)
                        .foregroundStyle(EmberTheme.muted)
                    Spacer()
                    Text("\(Int((friction.reserve * 100).rounded()))%")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DailyPalette.ink)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DailyPalette.grey)
                        Capsule()
                            .fill(DailyPalette.heroBackground)
                            .frame(width: geo.size.width * CGFloat(friction.reserve))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DailyPalette.panel, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - Study environment card
// Add an image named "StudyAmbient" to Assets.xcassets to show a photo; otherwise a warm gradient is used.

private struct StudyEnvironmentCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background

            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Study Environment")
                    .font(.caption.weight(.medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Quiet Study Sanctuary Ambient")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var background: some View {
        if UIImage(named: "StudyAmbient") != nil {
            Image("StudyAmbient")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.27, blue: 0.18), Color(red: 0.14, green: 0.10, blue: 0.07)],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
        }
    }
}
