import SwiftUI
import SwiftData

/// Today's native dashboard, based on the prototype's Today tab (not a developer route list).
struct DashboardView: View {
    let onNavigate: (AppRoute) -> Void
    let onSelectTab: (AppTab) -> Void
    @State private var viewModel = DashboardViewModel()

    @Query private var goals: [LearningGoal]
    @Query private var tasks: [LearningTask]
    @Query(sort: \EnergyCheckIn.createdAt, order: .reverse) private var checkIns: [EnergyCheckIn]

    private var latestEnergy: EnergyCheckIn? { checkIns.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("EMBER")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2.6)
                            .foregroundStyle(EmberTheme.muted)
                        Text("Your day, your rhythm.")
                            .font(.system(size: 30, weight: .medium, design: .serif))
                            .foregroundStyle(EmberTheme.primary)
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .foregroundStyle(EmberTheme.primary)
                        .font(.system(size: 25))
                        .frame(width: 50, height: 50)
                        .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 17))
                }

                energyCard

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Today's momentum")
                            .font(.system(size: 22, weight: .medium, design: .serif))
                            .foregroundStyle(EmberTheme.primary)
                        Spacer()
                        Button("See tasks") { onSelectTab(.sessions) }
                            .font(.caption.weight(.semibold))
                    }
                    HStack(spacing: 10) {
                        EmberMetricCard(value: "\(goals.count)", label: "Learning goals")
                        EmberMetricCard(value: "\(viewModel.completedCount(in: tasks))/\(tasks.count)", label: "Tasks complete")
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text("Your next step")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundStyle(EmberTheme.primary)
                    if let firstTask = tasks.first(where: { !$0.isCompleted }) {
                        VStack(alignment: .leading, spacing: 13) {
                            Text(firstTask.title)
                                .font(.headline)
                                .foregroundStyle(EmberTheme.primary)
                            Text("One small task is enough to make progress.")
                                .font(.caption)
                                .foregroundStyle(EmberTheme.muted)
                            Button {
                                onSelectTab(.sessions)
                            } label: {
                                Label("Open checklist", systemImage: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(13)
                                    .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(18)
                        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
                    } else {
                        EmberActionRow(
                            title: goals.isEmpty ? "Choose what you want to learn" : "Plan your next learning task",
                            subtitle: goals.isEmpty ? "Start with a topic that sparks your curiosity." : "Break a learning goal into small steps.",
                            symbol: "sparkle"
                        ) {
                            goals.isEmpty ? onNavigate(.onboarding) : onSelectTab(.sessions)
                        }
                    }
                }

                EmberActionRow(
                    title: "Explore your energy insights",
                    subtitle: "See how learning and energy change over time.",
                    symbol: "chart.xyaxis.line"
                ) { onSelectTab(.analytics) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 22)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ENERGY FLOW STATE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(EmberTheme.mint)
                    Text(latestEnergy.map { "Energy \($0.level) / 5" } ?? "How's your energy?")
                        .font(.system(size: 29, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                    Text(latestEnergy == nil ? "Check in before planning your day." : "Your latest self-reported energy check-in.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer(minLength: 8)
                Image(systemName: "battery.75percent")
                    .font(.system(size: 24))
                    .foregroundStyle(EmberTheme.amber)
            }
            Button {
                onNavigate(.energyCheckIn)
            } label: {
                HStack {
                    Text(latestEnergy == nil ? "Check in now" : "Update energy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(13)
                .foregroundStyle(EmberTheme.primary)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("today_energy_checkin")
        }
        .padding(20)
        .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 24))
    }
}
