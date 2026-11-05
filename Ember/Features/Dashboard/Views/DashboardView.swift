import SwiftUI
import SwiftData

/// Integration dashboard: immediately confirms the app and SwiftData load.
struct DashboardView: View {
    let onNavigate: (AppRoute) -> Void
    @State private var viewModel = DashboardViewModel()

    @Query private var goals: [LearningGoal]
    @Query private var tasks: [LearningTask]
    @Query private var checkIns: [EnergyCheckIn]


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("EMBER")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(EmberTheme.muted)
                    Text("Small steps.\nSteady momentum.")
                        .font(.system(size: 36, weight: .medium, design: .serif))
                        .foregroundStyle(EmberTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Learn with your energy, not against it.")
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.muted)
                }
                HStack(spacing: 10) {
                    metric("Goals", value: "\(goals.count)")
                    metric("Completed", value: "\(viewModel.completedCount(in: tasks))/\(tasks.count)")
                    metric("Check-ins", value: "\(checkIns.count)")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your learning journey")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                    ForEach(AppRoute.allCases, id: \.self) { route in
                        Button {
                            onNavigate(route)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: route.systemImage)
                                    .font(.system(size: 19))
                                    .frame(width: 34)
                                    .foregroundStyle(EmberTheme.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.title)
                                        .font(.headline)
                                        .foregroundStyle(EmberTheme.primary)
                                    Text(route.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(EmberTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(EmberTheme.muted)
                            }
                            .padding(16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("route_\(route.rawValue)")
                    }
                }
                Text("Foundation build · The four teammates replace these feature placeholders in their own folders.")
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
            }
            .padding(22)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metric(_ name: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(EmberTheme.primary)
            Text(name)
                .font(.caption2)
                .foregroundStyle(EmberTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}
