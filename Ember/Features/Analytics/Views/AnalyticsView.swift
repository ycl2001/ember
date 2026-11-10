import SwiftUI
import SwiftData

/// Analytics tab shell: heading, period picker, range pill, then the content for the selected period.
/// Daily / Weekly / Monthly content lives in its own file (see DailyAnalysisView, WeeklyAnalysisView, MonthlyAnalysisView).
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

                // Range pill row (hidden on Daily)
                if viewModel.period != .daily {
                    rangePill
                }

                // Content for the selected period
                content

                // Action buttons (calibrate + PDF report), labels change per period
                AnalyticsActionButtons(
                    period: viewModel.period,
                    viewModel: viewModel,
                    tasks: tasks,
                    sessions: sessions,
                    reflections: reflections
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Content per period

    @ViewBuilder
    private var content: some View {
        switch viewModel.period {
        case .daily:
            VStack(alignment: .leading, spacing: 23) {
                metricsRow
                DailyAnalysisView(
                    analysis: viewModel.dailyAnalysis(tasks: tasks, sessions: sessions, reflections: reflections)
                )
            }
        case .weekly:
            VStack(alignment: .leading, spacing: 23) {
                metricsRow
                WeeklyAnalysisView(viewModel: viewModel, tasks: tasks, reflections: reflections)
            }
        case .monthly:
            MonthlyAnalysisView(
                analysis: viewModel.monthlyAnalysis(tasks: tasks, sessions: sessions, reflections: reflections)
            )
        }
    }

    // MARK: - Period Picker (full-width, equal segments)

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(AnalyticsViewModel.Period.allCases) { p in
                let selected = p == viewModel.period
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.updatePeriod(p)
                    }
                } label: {
                    Text(p.rawValue)
                        .font(.callout.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? EmberTheme.primary : EmberTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? EmberTheme.surface : Color.clear, in: Capsule())
                        .shadow(color: selected ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EmberTheme.muted.opacity(0.12), in: Capsule())
        .frame(maxWidth: .infinity)
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

    // MARK: - Metrics Row (Daily + Weekly)

    private var metricsRow: some View {
        let tasksDone = viewModel.completedTaskCount(in: tasks, during: viewModel.selectedRange)
        let sessionsDone = viewModel.sessionsCount(in: sessions, during: viewModel.selectedRange)

        return HStack(spacing: 10) {
            EmberMetricCard(value: "\(tasksDone)", label: "Tasks done")
            EmberMetricCard(value: "\(sessionsDone)", label: "Sessions")
        }
        .padding(.top, 6)
    }
}
