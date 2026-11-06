import SwiftUI
import SwiftData

/// Sessions tab layout shell. Member 3 will implement task CRUD within this stable tab.
struct TaskPlannerView: View {
    var onNavigate: (AppRoute) -> Void = { _ in }
    @State private var viewModel = TaskPlannerViewModel()
    @Query private var goals: [LearningGoal]
    @Query private var tasks: [LearningTask]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                EmberPageHeading(
                    eyebrow: "Sessions",
                    title: "Let's build momentum.",
                    subtitle: "Small tasks make learning feel possible."
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Learning goals")
                            .font(.headline)
                            .foregroundStyle(EmberTheme.primary)
                        Spacer()
                        Button { onNavigate(.onboarding) } label: {
                            Label("Add topic", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    if goals.isEmpty {
                        Text("No topics yet. Choose something you'd enjoy learning.")
                            .font(.subheadline)
                            .foregroundStyle(EmberTheme.muted)
                    } else {
                        ForEach(goals, id: \.id) { goal in
                            Label(goal.topic, systemImage: "book.closed")
                                .font(.subheadline)
                                .foregroundStyle(EmberTheme.primary)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(18)
                .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("Today's small tasks")
                            .font(.system(size: 22, weight: .medium, design: .serif))
                            .foregroundStyle(EmberTheme.primary)
                        Spacer()
                        Text("\(viewModel.completedCount(in: tasks))/\(tasks.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EmberTheme.muted)
                    }
                    ProgressView(
                        value: Double(viewModel.completedCount(in: tasks)),
                        total: Double(max(tasks.count, 1))
                    )
                    .tint(EmberTheme.primary)

                    if tasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.system(size: 30))
                                .foregroundStyle(EmberTheme.primary)
                                .frame(width: 68, height: 68)
                                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 19))
                            Text("Your checklist starts here")
                                .font(.headline)
                                .foregroundStyle(EmberTheme.primary)
                            Text("Add a learning goal first. Your task-planning tools will live in this space.")
                                .font(.subheadline)
                                .foregroundStyle(EmberTheme.muted)
                                .multilineTextAlignment(.center)
                            Button("Choose a learning goal") { onNavigate(.onboarding) }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EmberTheme.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(tasks, id: \.id) { task in
                            HStack(spacing: 11) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? EmberTheme.primary : EmberTheme.muted)
                                Text(task.title)
                                    .font(.subheadline)
                                    .foregroundStyle(EmberTheme.primary)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(EmberTheme.separator)
                        }
                        Button { onNavigate(.focus) } label: {
                            HStack {
                                Text("Start a focus session")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(15)
                            .foregroundStyle(.white)
                            .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }
                .padding(18)
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
