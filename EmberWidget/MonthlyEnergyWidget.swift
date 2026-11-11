import SwiftUI
import WidgetKit

@main
struct MonthlyEnergyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MonthlyEnergyWidgetData.kind, provider: MonthlyEnergyProvider()) { entry in
            MonthlyEnergyWidgetView(entry: entry)
        }
        .configurationDisplayName("Ember Energy")
        .description("See your average after-session energy for each day in the four-week grid.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct MonthlyEnergyEntry: TimelineEntry {
    let date: Date
    let grid: MonthlyEnergyGrid

    var hasRatings: Bool {
        grid.weeks.contains { week in week.contains { $0.level != nil } }
    }
}

private struct MonthlyEnergyProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthlyEnergyEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthlyEnergyEntry) -> Void) {
        if context.isPreview {
            completion(previewEntry())
        } else {
            completion(entry(for: .now, observations: MonthlyEnergyWidgetData.load(), calendar: .current))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyEnergyEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let observations = MonthlyEnergyWidgetData.load()
        let startOfToday = calendar.startOfDay(for: now)
        let upcomingDays = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfToday) }
        let entries = ([now] + upcomingDays).map { entry(for: $0, observations: observations, calendar: calendar) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func previewEntry() -> MonthlyEnergyEntry {
        let now = Date.now
        let calendar = Calendar.current
        let samples = [(0, 4), (1, 5), (3, 3), (4, 2), (6, 4), (8, 3), (9, 5), (12, 4),
                       (14, 1), (15, 3), (17, 4), (19, 2), (20, 3)]
        let observations = samples.compactMap { offset, level -> MonthlyEnergyObservation? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return MonthlyEnergyObservation(date: date, level: level)
        }
        return entry(for: now, observations: observations, calendar: calendar)
    }

    private func entry(
        for date: Date,
        observations: [MonthlyEnergyObservation],
        calendar: Calendar
    ) -> MonthlyEnergyEntry {
        MonthlyEnergyEntry(
            date: date,
            grid: MonthlyEnergyGrid(observations: observations, asOf: date, calendar: calendar)
        )
    }
}

private struct MonthlyEnergyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: MonthlyEnergyEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                VStack(alignment: .leading, spacing: 4) {
                    Text("4-Week Energy")
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel("Four-week after-session energy")
                        .accessibilityAddTraits(.isHeader)

                    EnergyWidgetMatrix(grid: entry.grid, palette: palette)
                        .privacySensitive()

                    if entry.hasRatings {
                        EnergyWidgetScale(palette: palette)
                    } else {
                        Text("Save a reflection")
                            .font(.caption2)
                            .foregroundStyle(palette.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .privacySensitive()
                    }
                }
            case .systemLarge:
                VStack(alignment: .leading, spacing: 8) {
                    EnergyWidgetHeading(compact: false, hasRatings: entry.hasRatings, palette: palette)
                    EnergyWidgetMatrix(grid: entry.grid, palette: palette)
                        .privacySensitive()
                    EnergyWidgetScale(palette: palette)
                        .padding(.top, 2)
                }
            default:
                HStack(spacing: 12) {
                    EnergyWidgetHeading(compact: true, hasRatings: entry.hasRatings, palette: palette)
                        .frame(width: 108, alignment: .leading)
                    VStack(spacing: 5) {
                        EnergyWidgetMatrix(grid: entry.grid, palette: palette)
                            .privacySensitive()
                        EnergyWidgetScale(palette: palette)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { palette.surface }
        .widgetURL(MonthlyEnergyWidgetData.reportURL)
    }

    private var palette: EnergyWidgetPalette {
        EnergyWidgetPalette(isDark: colorScheme == .dark)
    }
}

private struct EnergyWidgetHeading: View {
    let compact: Bool
    let hasRatings: Bool
    let palette: EnergyWidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(compact ? "4-Week Energy" : "4-Week Spot Matrix")
                .font(.system(compact ? .title3 : .title2, design: .serif).weight(.semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(compact ? 2 : 1)
                .minimumScaleFactor(0.72)
                .accessibilityAddTraits(.isHeader)
            Text(hasRatings ? "Average after-session energy" : "Save a reflection to see your energy here.")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(palette.muted)
                .lineLimit(compact ? 4 : 2)
                .minimumScaleFactor(0.72)
                .privacySensitive()
        }
    }
}

private struct EnergyWidgetMatrix: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.widgetFamily) private var family
    let grid: MonthlyEnergyGrid
    let palette: EnergyWidgetPalette

    private var showsDates: Bool { family == .systemLarge }

    var body: some View {
        VStack(spacing: showsDates ? 4 : 2) {
            HStack(spacing: 0) {
                if showsDates { Color.clear.frame(width: 25, height: 1) }
                ForEach(weekdayLetters.indices, id: \.self) { index in
                    Text(weekdayLetters[index])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 5)
            .accessibilityHidden(true)

            ForEach(grid.weeks.indices, id: \.self) { index in
                HStack(spacing: 0) {
                    if showsDates {
                        Text("W\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(palette.muted)
                            .frame(width: 25, alignment: .leading)
                            .accessibilityHidden(true)
                    }

                    ForEach(grid.weeks[index], id: \.date) { day in
                        EnergyWidgetDay(day: day, palette: palette)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, showsDates ? 3 : 1)
                .frame(maxHeight: .infinity)
                .background(palette.row, in: RoundedRectangle(cornerRadius: showsDates ? 10 : 5))
            }
        }
    }

    private var weekdayLetters: [String] {
        let letters = calendar.veryShortStandaloneWeekdaySymbols
        return Array(letters.dropFirst()) + letters.prefix(1)
    }
}

private struct EnergyWidgetDay: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let day: MonthlyEnergyGrid.Day
    let palette: EnergyWidgetPalette

    private var dotSize: CGFloat {
        switch family {
        case .systemSmall: 10
        case .systemLarge: 19
        default: 13
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                Circle()
                    .fill(palette.fill(for: day.level))
                    .widgetAccentable(day.level != nil)
                if let level = day.level, differentiateWithoutColor || renderingMode != .fullColor {
                    Text(level, format: .number)
                        .font(.system(size: family == .systemLarge ? 11 : 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(palette.ink(on: level))
                }
            }
            .frame(width: dotSize, height: dotSize)

            if family == .systemLarge {
                Text(day.date, format: .dateTime.day(.twoDigits))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(day.level.map { Text("Energy \($0) out of 5") } ?? Text("No reflection"))
    }
}

private struct EnergyWidgetScale: View {
    let palette: EnergyWidgetPalette

    var body: some View {
        HStack(spacing: 4) {
            Text("1")
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(palette.fill(for: level))
                    .frame(width: 7, height: 7)
            }
            Text("5")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(palette.muted)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Energy scale, 1 is lowest and 5 is highest")
    }
}

private struct EnergyWidgetPalette {
    let isDark: Bool

    var surface: Color {
        isDark ? Color(red: 0.08, green: 0.13, blue: 0.11) : Color(red: 1, green: 0.99, blue: 0.97)
    }

    var ink: Color {
        isDark ? Color(red: 0.89, green: 0.95, blue: 0.91) : Color(red: 0.09, green: 0.19, blue: 0.15)
    }

    var muted: Color {
        isDark ? Color(red: 0.68, green: 0.78, blue: 0.72) : Color(red: 0.29, green: 0.38, blue: 0.34)
    }

    var row: Color {
        isDark ? Color(red: 0.14, green: 0.20, blue: 0.17) : Color(red: 0.95, green: 0.96, blue: 0.93)
    }

    func fill(for level: Int?) -> Color {
        switch level {
        case 1: Color(red: 0.91, green: 0.68, blue: 0.61)
        case 2: Color(red: 1.00, green: 0.85, blue: 0.74)
        case 3: Color(red: 0.97, green: 0.64, blue: 0.32)
        case 4: Color(red: 0.59, green: 0.80, blue: 0.72)
        case 5: isDark ? Color(red: 0.41, green: 0.67, blue: 0.55) : ink
        default: isDark ? .white.opacity(0.12) : Color(red: 0.88, green: 0.90, blue: 0.86)
        }
    }

    func ink(on level: Int) -> Color {
        level == 5 && !isDark ? .white : Color(red: 0.09, green: 0.19, blue: 0.15)
    }
}
