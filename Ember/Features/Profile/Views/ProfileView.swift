import SwiftUI
import SwiftData

/// Profile is the fourth tab in the original HTML prototype.
struct ProfileView: View {
    let onNavigate: (AppRoute) -> Void
    @State private var viewModel = ProfileViewModel()
    @Query private var goals: [LearningGoal]
    @Query private var checkIns: [EnergyCheckIn]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                EmberPageHeading(
                    eyebrow: "Profile",
                    title: "Your learning space.",
                    subtitle: viewModel.subtitle
                )

                HStack(spacing: 13) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(EmberTheme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ember learner")
                            .font(.headline)
                            .foregroundStyle(EmberTheme.primary)
                        Text("Your progress stays on this device for now.")
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                    }
                    Spacer()
                }
                .padding(18)
                .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))

                EnergyFlowStateCard { onNavigate(.energyCheckIn) }

                HStack(spacing: 10) {
                    EmberMetricCard(value: "\(goals.count)", label: "Learning goals")
                    EmberMetricCard(value: "\(checkIns.count)", label: "Energy check-ins")
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text("Your preferences")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundStyle(EmberTheme.primary)
                    EmberActionRow(
                        title: "Learning goals",
                        subtitle: "Choose and revisit topics you want to explore.",
                        symbol: "target"
                    ) { onNavigate(.onboarding) }
                }

                Text("Ember · Learn with your energy, not against it.")
                    .font(.caption)
                    .foregroundStyle(EmberTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
