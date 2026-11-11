import Charts
import SwiftUI

private enum WeeklyChartStyle {
    static let line = Color(red: 0.11, green: 0.18, blue: 0.15)
    static let bar = Color(red: 0.93, green: 0.64, blue: 0.34)
    static let highlight = Color(red: 0.85, green: 0.93, blue: 0.87)
}
private struct WeeklyChartDay: Identifiable {
    let date: Date
    let energy: Double?
    let rawEnergy: Double?
    let tasks: Double
    let rawTasks: Int
    let isHighlighted: Bool

    var id: Date { date }
}

struct WeeklyAnalysisView: View {
    let viewModel: AnalyticsViewModel
    let tasks: [LearningTask]
    let sessions: [FocusSession]
    let reflections: [SessionReflection]

    @State private var selectedChartDate: Date?

    private var points: [AnalyticsViewModel.ChartPoint] {
        viewModel.chartPoints(
            tasks: tasks,
            sessions: sessions,
            reflections: reflections,
            during: viewModel.selectedRange
        )
    }

    private var inRangeReflections: [SessionReflection] {
        viewModel.reflectionsInRange(
            reflections,
            sessions: sessions,
            during: viewModel.selectedRange
        )
    }

    private var hasObservedActivity: Bool {
        points.contains { $0.tasksCompleted > 0 || $0.energy != nil }
            || viewModel.sessionsCount(in: sessions, during: viewModel.selectedRange) > 0
    }

    var body: some View {
        if hasObservedActivity {
            VStack(alignment: .leading, spacing: 23) {
                observedSummaryCard
                chartCard
                WeeklyEnergyEncouragementCard(
                    encouragement: viewModel.weeklyEnergyEncouragement(
                        reflections: reflections,
                        sessions: sessions
                    )
                )
                patternCard
            }
        } else {
            ContentUnavailableView {
                Label("No analytics for this week", systemImage: "chart.xyaxis.line")
            } description: {
                Text("Complete tasks, finish focus sessions, and save reflections to build an observed weekly chart.")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var observedSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Observed Weekly Data")
                .font(.caption.smallCaps())
                .foregroundStyle(EmberTheme.muted)

            if let average = viewModel.averageAfterSessionEnergy(in: inRangeReflections) {
                Text("After-Session Energy")
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                Text("\(inRangeReflections.count) reflection\(inRangeReflections.count == 1 ? "" : "s") averaged \(average.formatted(.number.precision(.fractionLength(1)))) out of 5 after focus sessions.")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            } else {
                Text("Energy Pattern Needs Reflections")
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                Text("Task and session activity is available, but no saved energy reflections fall in this week.")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: .rect(cornerRadius: 16))
    }

    private var chartDays: [WeeklyChartDay] {
        let maximumTasks = Double(points.map(\.tasksCompleted).max() ?? 0)
        let rankedEnergyDates = Set(
            points.compactMap { point -> (Date, Double)? in
                guard let energy = point.energy else { return nil }
                return (point.date, energy)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map(\.0)
        )

        return points.map { point in
            WeeklyChartDay(
                date: point.date,
                energy: point.energy.map { $0 / 5 },
                rawEnergy: point.energy,
                tasks: maximumTasks > 0 ? Double(point.tasksCompleted) / maximumTasks : 0,
                rawTasks: point.tasksCompleted,
                isHighlighted: rankedEnergyDates.contains(point.date)
            )
        }
    }

    private var chartCard: some View {
        let days = chartDays
        return VStack(alignment: .leading, spacing: 14) {
            Text("Energy and Completed Tasks")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(EmberTheme.primary)

            Text("Energy uses the average after-session rating for each day. Task bars are scaled to the busiest day in this range.")
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.date),
                        y: .value("Completed tasks", day.tasks),
                        width: .fixed(14)
                    )
                    .foregroundStyle(WeeklyChartStyle.bar)
                    .cornerRadius(5)
                }

                ForEach(days.filter { $0.energy != nil }) { day in
                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("After-session energy", day.energy ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(.init(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(WeeklyChartStyle.line)

                    PointMark(
                        x: .value("Day", day.date),
                        y: .value("After-session energy", day.energy ?? 0)
                    )
                    .symbol {
                        Circle()
                            .fill(
                                EmberEnergyScale.color(for: day.rawEnergy)
                                    ?? WeeklyChartStyle.highlight
                            )
                            .overlay {
                                Circle()
                                    .stroke(EmberTheme.primary, lineWidth: 2)
                            }
                            .frame(width: day.isHighlighted ? 14 : 12, height: day.isHighlighted ? 14 : 12)
                    }
                    .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue(
                        "Average after-session energy \((day.rawEnergy ?? 0).formatted(.number.precision(.fractionLength(1)))) out of 5"
                    )
                }

                if let selectedDay = selectedChartDay(in: days),
                   let rawEnergy = selectedDay.rawEnergy {
                    RuleMark(x: .value("Selected day", selectedDay.date))
                        .foregroundStyle(EmberTheme.separator)
                        .annotation(position: .top, spacing: 8) {
                            VStack(spacing: 2) {
                                Text(selectedDay.date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption.weight(.semibold))
                                Text(rawEnergy, format: .number.precision(.fractionLength(1)))
                                    .font(.footnote.weight(.semibold))
                                Text("of 5")
                                    .font(.caption)
                            }
                            .foregroundStyle(EmberTheme.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 9)
                            .background(EmberTheme.surface, in: .rect(cornerRadius: 10))
                        }
                }
            }
            .frame(height: 240)
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 1]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let fraction = value.as(Double.self) {
                            Text(fraction * 5, format: .number.precision(.fractionLength(1)))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: days.map(\.date)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedChartDate)

            HStack(spacing: 20) {
                Label("After-session energy", systemImage: "circle.fill")
                    .foregroundStyle(WeeklyChartStyle.line)
                Label("Completed tasks", systemImage: "square.fill")
                    .foregroundStyle(WeeklyChartStyle.bar)
            }
            .font(.footnote)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: .rect(cornerRadius: 24))
    }

    private func selectedChartDay(in days: [WeeklyChartDay]) -> WeeklyChartDay? {
        guard let selectedChartDate else { return nil }
        return days
            .filter { $0.rawEnergy != nil }
            .min {
                abs($0.date.timeIntervalSince(selectedChartDate))
                    < abs($1.date.timeIntervalSince(selectedChartDate))
            }
    }

    private var patternCard: some View {
        let pattern = viewModel.observedPattern(
            sessions: sessions,
            reflections: reflections,
            lookbackDays: 28
        )
        return VStack(alignment: .leading, spacing: 8) {
            Label(pattern.title, systemImage: pattern.hasEnoughData ? "chart.line.uptrend.xyaxis" : "info.circle")
                .font(.headline)
                .foregroundStyle(EmberTheme.primary)
            Text(pattern.message)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.muted.opacity(0.1), in: .rect(cornerRadius: 24))
    }
}
