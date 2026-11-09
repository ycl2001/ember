import SwiftUI
import SwiftData
import Charts

/// Stable Analytics tab shell with period filtering and chart card.
struct AnalyticsView: View {
    @State private var viewModel = AnalyticsViewModel()

    @Query private var tasks: [LearningTask]
    @Query private var sessions: [FocusSession]
    @Query private var reflections: [EnergyRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                // Top Heading
                EmberPageHeading(
                    eyebrow: "Analytics",
                    title: "Energy & Task Analytics",
                    subtitle: "Discover how cognitive fatigue, recovery pauses, and intentional task pacing correlate with your completion rate."
                )

                // Period Picker
                periodPicker

                // Range pill row
                rangePill

                // Metrics row
                metricsRow

                // Featured Insight Card (placeholder)
                featuredInsightCard

                // Chart Card
                chartCard

                // Tip card
                tipCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Period Picker (Daily / Weekly, wrapped in a capsule and centered)

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(AnalyticsViewModel.Period.allCases) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.updatePeriod(p)
                    }
                } label: {
                    Text(p.rawValue)
                        .font(.callout.weight(p == viewModel.period ? .semibold : .regular))
                        .foregroundStyle(EmberTheme.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 22)
                        .background(
                            p == viewModel.period ? EmberTheme.surface : Color.clear,
                            in: Capsule()
                        )
                        .shadow(
                            color: p == viewModel.period ? .black.opacity(0.06) : .clear,
                            radius: 3, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EmberTheme.muted.opacity(0.12), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Range Pill

    private var rangePill: some View {
        HStack(spacing: 8) {
            Text(viewModel.rangeTitle(viewModel.selectedRange))
                .font(.subheadline)
                .foregroundStyle(EmberTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("•")
                .foregroundStyle(EmberTheme.muted)
            Text(viewModel.termText())
                .font(.subheadline)
                .foregroundStyle(EmberTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Label(viewModel.calibrationBadgeText(), systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(red: 0.85, green: 0.93, blue: 0.87), in: Capsule())
                .foregroundStyle(EmberTheme.primary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        let inRangeReflections = viewModel.reflectionsInRange(reflections, during: viewModel.selectedRange)
        let tasksDone = viewModel.completedTaskCount(in: tasks, during: viewModel.selectedRange)
        let sessionsDone = viewModel.sessionsCount(in: sessions, during: viewModel.selectedRange)

        return HStack(spacing: 10) {
            EmberMetricCard(value: "\(tasksDone)", label: "Tasks done")
            EmberMetricCard(value: "\(sessionsDone)", label: "Sessions")
            EmberMetricCard(value: "\(inRangeReflections.count)", label: "Reflections")
        }
        .padding(.top, 6)
    }

    // MARK: - Featured Insight

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

    // MARK: - Chart

    private var chartCard: some View {
        let points = viewModel.chartPoints(tasks: tasks, reflections: reflections, during: viewModel.selectedRange)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Biorhythm overlay")
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)
                    Text("Energy Curve vs Tasks Finished")
                        .font(.headline)
                        .foregroundStyle(EmberTheme.primary)
                }
                Spacer()
            }

            Chart {
                ForEach(points) { p in
                    LineMark(
                        x: .value("Day", p.date),
                        y: .value("Energy Δ", p.energy)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(EmberTheme.primary)

                    BarMark(
                        x: .value("Day", p.date),
                        y: .value("Tasks", p.tasksCompleted)
                    )
                    .foregroundStyle(EmberTheme.primary.opacity(0.5))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(EmberTheme.muted.opacity(0.5))
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tip

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
                .foregroundStyle(Color(red: 0.55, green: 0.33, blue: 0.12))

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
