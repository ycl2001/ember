import WidgetKit
import SwiftUI

// Goes in the widget extension (replace the contents of the template's EmberWidget.swift).
// Widget target only.

// MARK: - Palette (matches the Ember look; EmberTheme isn't shared with the widget target)

private enum WidgetPalette {
    static let cream = Color(red: 0.957, green: 0.945, blue: 0.918)
    static let ink   = Color(red: 0.047, green: 0.141, blue: 0.094)
    static let muted = Color(red: 0.36,  green: 0.42,  blue: 0.38)
    static let mint  = Color(red: 0.55,  green: 0.71,  blue: 0.62)
    static let amber = Color(red: 0.91,  green: 0.65,  blue: 0.35)
}

// MARK: - Timeline

struct FocusEntry: TimelineEntry {
    let date: Date
    let state: FocusWidgetState
}

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: .now, state: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        let state = context.isPreview ? FocusWidgetState.preview : FocusWidgetStore.load()
        completion(FocusEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        // One entry. The app asks WidgetKit to reload whenever the session changes,
        // and the timer text counts by itself in between.
        let entry = FocusEntry(date: .now, state: FocusWidgetStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - View

struct FocusWidgetView: View {
    let state: FocusWidgetState
    @Environment(\.widgetFamily) private var family

    private var timerSize: CGFloat { family == .systemSmall ? 34 : 46 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(flameColor)
                Text(statusLabel)
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(WidgetPalette.muted)
            }

            Spacer(minLength: 0)

            timerView

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(WidgetPalette.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(WidgetPalette.cream, for: .widget)
        .widgetURL(URL(string: "ember://focus"))
    }

    @ViewBuilder
    private var timerView: some View {
        switch state.status {
        case .running:
            if let start = state.timerStartDate {
                // Counts up on its own, no refreshes needed.
                Text(start, style: .timer)
                    .font(.system(size: timerSize, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        case .paused:
            Text(FocusWidgetState.format(state.pausedSeconds))
                .font(.system(size: timerSize, weight: .medium, design: .serif))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.ink.opacity(0.55))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        case .idle:
            Text("Ready to focus")
                .font(.system(size: family == .systemSmall ? 22 : 28, weight: .medium, design: .serif))
                .foregroundStyle(WidgetPalette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
        }
    }

    private var statusLabel: String {
        switch state.status {
        case .running: return "FOCUSING"
        case .paused: return "PAUSED"
        case .idle: return "EMBER"
        }
    }

    private var subtitle: String {
        switch state.status {
        case .running: return state.taskTitle
        case .paused: return "Paused · \(state.taskTitle)"
        case .idle: return FocusWidgetStore.debugInfo
        }
    }

    private var flameColor: Color {
        switch state.status {
        case .running: return WidgetPalette.mint
        case .paused: return WidgetPalette.amber
        case .idle: return WidgetPalette.muted.opacity(0.5)
        }
    }
}

// MARK: - Widget

struct EmberFocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: FocusWidgetState.kind, provider: FocusProvider()) { entry in
            FocusWidgetView(state: entry.state)
        }
        .configurationDisplayName("Focus session")
        .description("See your current focus time at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    EmberFocusWidget()
} timeline: {
    FocusEntry(date: .now, state: .preview)
    FocusEntry(date: .now, state: .idle)
}
