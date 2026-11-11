import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @State private var viewModel = AnalyticsViewModel()

    @Query private var tasks: [LearningTask]
    @Query private var sessions: [FocusSession]
    @Query private var reflections: [SessionReflection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                EmberPageHeading(
                    eyebrow: "Analytics",
                    title: "Energy & Task Analytics",
                    subtitle: "Review saved tasks, focus sessions, and before-and-after energy reflections."
                )

                periodPicker

                if viewModel.period != .daily {
                    rangeSummary
                }

                selectedAnalysis

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

    @ViewBuilder
    private var selectedAnalysis: some View {
        switch viewModel.period {
        case .daily:
            DailyAnalysisView(
                analysis: viewModel.dailyAnalysis(
                    tasks: tasks,
                    sessions: sessions,
                    reflections: reflections
                )
            )
        case .weekly:
            VStack(alignment: .leading, spacing: 23) {
                metricsRow
                WeeklyAnalysisView(
                    viewModel: viewModel,
                    tasks: tasks,
                    sessions: sessions,
                    reflections: reflections
                )
            }
        case .monthly:
            MonthlyAnalysisView(
                analysis: viewModel.monthlyAnalysis(
                    tasks: tasks,
                    sessions: sessions,
                    reflections: reflections
                )
            )
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(AnalyticsViewModel.Period.allCases) { period in
                let isSelected = period == viewModel.period
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.updatePeriod(period)
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? EmberTheme.primary : EmberTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isSelected ? EmberTheme.surface : .clear, in: Capsule())
                        .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(EmberTheme.muted.opacity(0.12), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    private var rangeSummary: some View {
        Label(viewModel.rangeTitle(viewModel.selectedRange), systemImage: "calendar")
            .font(.subheadline)
            .foregroundStyle(EmberTheme.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            EmberMetricCard(
                value: "\(viewModel.completedTaskCount(in: tasks, during: viewModel.selectedRange))",
                label: "Tasks done"
            )
            EmberMetricCard(
                value: "\(viewModel.sessionsCount(in: sessions, during: viewModel.selectedRange))",
                label: "Sessions"
            )
        }
        .padding(.top, 6)
    }
}
