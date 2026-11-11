///WeeklyAnalysisView

import SwiftUI
import Charts

// MARK: - Chart styling

private enum ChartStyle {
    static let eyebrow = Color(red: 0.55, green: 0.33, blue: 0.12)
    static let line = Color(red: 0.11, green: 0.18, blue: 0.15)

    static let barGradient = LinearGradient(
        colors: [Color(red: 0.93, green: 0.64, blue: 0.34), Color(red: 0.95, green: 0.70, blue: 0.42)],
        startPoint: .top, endPoint: .bottom
    )
    static let peakBarGradient = LinearGradient(
        colors: [Color(red: 0.80, green: 0.47, blue: 0.20), Color(red: 0.49, green: 0.28, blue: 0.10)],
        startPoint: .top, endPoint: .bottom
    )
    static let peakBand = LinearGradient(
        colors: [Color(red: 0.98, green: 0.88, blue: 0.80), Color(red: 0.98, green: 0.88, blue: 0.80).opacity(0)],
        startPoint: .top, endPoint: .bottom
    )
    static let areaGradient = LinearGradient(
        colors: [line.opacity(0.16), line.opacity(0)],
        startPoint: .top, endPoint: .bottom
    )
    static let dayPill = Color(red: 0.90, green: 0.94, blue: 0.91)
}

/// Chart-ready day: values normalised to 0...1 so energy and tasks can share one axis.
private struct ChartDay: Identifiable {
    let date: Date
    let energy: Double
    let tasks: Double
    let rawTasks: Int
    var isPeak = false
    var id: Date { date }
}

// MARK: - Weekly tab

struct WeeklyAnalysisView: View {
    let viewModel: AnalyticsViewModel
    let tasks: [LearningTask]
    let reflections: [EnergyRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            featuredInsightCard
            chartCard
            tipCard
        }
    }

    // MARK: Featured insight

    private var featuredInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Circadian Resonance")
                .font(.caption.smallCaps())
                .foregroundStyle(EmberTheme.muted)
            Text("Mindful Cadence Peak")
                .font(.headline)
                .foregroundStyle(EmberTheme.primary)
            Text("Your synthesis endurance peaked Tue & Thu during the 9:30 morning block.")
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Chart

    /// Normalises the view model's points and flags the strongest days as "peak".
    private func makeChartDays(from points: [AnalyticsViewModel.ChartPoint]) -> [ChartDay] {
        guard !points.isEmpty else { return [] }

        let energies = points.map(\.energy)
        let minE = energies.min() ?? 0
        let maxE = energies.max() ?? 0
        let maxT = Double(points.map(\.tasksCompleted).max() ?? 0)

        var days = points.map { p in
            ChartDay(
                date: p.date,
                energy: maxE > minE ? 0.2 + 0.75 * (p.energy - minE) / (maxE - minE) : 0.5,
                tasks: maxT > 0 ? 0.8 * Double(p.tasksCompleted) / maxT : 0,
                rawTasks: p.tasksCompleted
            )
        }

        // Peak = top two days by combined energy + tasks, ignoring days with no tasks.
        let peakDates = Set(
            days.filter { $0.rawTasks > 0 }
                .sorted { ($0.tasks + $0.energy) > ($1.tasks + $1.energy) }
                .prefix(2)
                .map(\.date)
        )
        for i in days.indices where peakDates.contains(days[i].date) {
            days[i].isPeak = true
        }
        return days
    }

    private func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var chartCard: some View {
        let points = viewModel.chartPoints(tasks: tasks, reflections: reflections, during: viewModel.selectedRange)
        
        let days = makeChartDays(from: points)
        let hasEnergy = points.contains { $0.energy != 0 }
        let peaks = days.filter(\.isPeak)
        let peakDates = Set(peaks.map(\.date))
        let totalTasks = days.reduce(0) { $0 + $1.rawTasks }
        let peakTasks = peaks.reduce(0) { $0 + $1.rawTasks }

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Biorhythm overlay")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(ChartStyle.eyebrow)
                    Text("Energy Curve vs Tasks Finished")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                }
                Spacer()
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundStyle(EmberTheme.muted)
            }

            // Summary line
            if totalTasks > 0, !peaks.isEmpty {
                let names = peaks.map { weekday($0.date) }.joined(separator: " & ")
                Text("\(names) Peak Windows: ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                + Text("\(peakTasks) of \(totalTasks) tasks were finished on your highest-energy days.")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            } else {
                Text("Finish tasks and log reflections to see how your energy lines up with your output.")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
            }

            // Chart
            Chart {
                // Highlight bands behind peak days
                ForEach(days.filter(\.isPeak)) { d in
                    RectangleMark(
                        x: .value("Day", d.date),
                        yStart: .value("Base", 0),
                        yEnd: .value("Top", 1.08),
                        width: .fixed(38)
                    )
                    .foregroundStyle(ChartStyle.peakBand)
                    .cornerRadius(10)
                }

                // Task bars
                ForEach(days) { d in
                    BarMark(
                        x: .value("Day", d.date),
                        y: .value("Tasks", d.tasks),
                        width: .fixed(14)
                    )
                    .foregroundStyle(d.isPeak ? ChartStyle.peakBarGradient : ChartStyle.barGradient)
                    .cornerRadius(5)
                }

                // Energy curve (only when there are reflections)
                if hasEnergy {
                    ForEach(days) { d in
                        AreaMark(
                            x: .value("Day", d.date),
                            y: .value("Energy", d.energy),
                            series: .value("Series", "Area")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(ChartStyle.areaGradient)
                    }

                    ForEach(days) { d in
                        LineMark(
                            x: .value("Day", d.date),
                            y: .value("Energy", d.energy),
                            series: .value("Series", "Line")
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(ChartStyle.line)
                    }

                    ForEach(days) { d in
                        PointMark(
                            x: .value("Day", d.date),
                            y: .value("Energy", d.energy)
                        )
                        .symbol {
                            Circle()
                                .fill(d.isPeak ? ChartStyle.line : Color.white)
                                .overlay(
                                    Circle().stroke(d.isPeak ? Color.white : ChartStyle.line, lineWidth: 2.5)
                                )
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            .frame(height: 240)
            .chartYScale(domain: 0...1.1)
            .chartXScale(range: .plotDimension(padding: 22))
            .chartYAxis {
                AxisMarks(values: [0.3, 0.6, 0.9]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(EmberTheme.muted.opacity(0.25))
                }
            }
            .chartXAxis {
                AxisMarks(values: days.map(\.date)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let isPeak = peakDates.contains(date)
                            Text(weekday(date))
                                .font(.subheadline.weight(isPeak ? .bold : .regular))
                                .foregroundStyle(EmberTheme.primary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(isPeak ? ChartStyle.dayPill : Color.clear, in: Capsule())
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ChartStyle.line)
                        .frame(width: 12, height: 12)
                    Text("Cognitive Energy")
                }
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ChartStyle.barGradient)
                        .frame(width: 12, height: 12)
                    Text("Tasks Completed")
                }
            }
            .font(.footnote)
            .foregroundStyle(EmberTheme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Tip

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top section: icon + title + body
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "brain")
                    .font(.title3)
                    .foregroundStyle(EmberTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.85, green: 0.93, blue: 0.87), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pacing Protection Works")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                    Text("When you take a 5–10 min restorative pause after 25 mins of deep focus, your afternoon completion rate climbs by **34%** without cognitive depletion.")
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.muted)
                }
            }

            // Suggested adjustment box
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Suggested Adjustment")
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                } icon: {
                    Image(systemName: "slider.horizontal.3")
                }
                .foregroundStyle(ChartStyle.eyebrow)

                Text("Shift high-complexity **CS240 Problem Sets** to Wednesday 9:00 AM (Projected Energy: 94%).")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.muted.opacity(0.1), in: RoundedRectangle(cornerRadius: 24))
    }
}

