import SwiftUI
import SwiftData

/// Stable Analytics tab shell; Member 5 adds period filtering and charts later.
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
                    title: "Your learning energy.",
                    subtitle: "Understand your progress and how each session feels."
                )

                HStack(spacing: 10) {
                    EmberMetricCard(value: "\(viewModel.completedTaskCount(in: tasks))", label: "Tasks done")
                    EmberMetricCard(value: "\(sessions.filter { $0.endedAt != nil }.count)", label: "Sessions")
                    EmberMetricCard(value: "\(reflections.count)", label: "Reflections")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Energy & task analytics")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundStyle(EmberTheme.primary)
                    if reflections.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 36))
                                .foregroundStyle(EmberTheme.primary)
                            Text("Your pattern will grow with you")
                                .font(.headline)
                                .foregroundStyle(EmberTheme.primary)
                            Text("After your first focus session and reflection, your energy insights will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(EmberTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 43)
                    } else {
                        Text("Net self-reported energy change")
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                        Text("\(viewModel.netReportedEnergyChange(in: reflections))")
                            .font(.system(size: 40, weight: .medium, design: .serif))
                            .foregroundStyle(EmberTheme.primary)
                        Text("Positive means lower energy afterward; negative means more energised. Member 5 will add charts by day, week and month.")
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
