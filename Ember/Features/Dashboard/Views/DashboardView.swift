import SwiftUI
import SwiftData

/// Today's native dashboard, based on the prototype's Today tab (not a developer route list).
struct DashboardView: View {
    let onNavigate: (AppRoute) -> Void
    let onSelectTab: (AppTab) -> Void
    @State private var viewModel = DashboardViewModel()

    @Query private var goals: [LearningGoal]
    @Query private var tasks: [LearningTask]

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

                FeelingPickerCard()

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
}
