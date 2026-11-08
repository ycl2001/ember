import SwiftUI
import SwiftData

struct TaskPlannerView: View {
    var onNavigate: (AppRoute) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @Query(sort: \LearningTask.createdAt, order: .reverse) private var tasks: [LearningTask]
    @State private var viewModel = TaskPlannerViewModel()
    @State private var editor: TaskEditor?
    @State private var taskToDelete: LearningTask?
    @State private var showingUpdateError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                EmberPageHeading(
                    eyebrow: "Sessions",
                    title: "Let's build momentum.",
                    subtitle: "Small tasks make learning feel possible."
                )

                learningGoals
                checklist
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editor) { editor in
            TaskEditorView(viewModel: viewModel, task: editor.task)
        }
        .alert(
            "Delete task?",
            isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            ),
            presenting: taskToDelete
        ) { task in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                updateChecklist { try viewModel.deleteTask(task, in: modelContext) }
            }
        } message: { task in
            Text("“\(task.title)” will be removed from your checklist.")
        }
        .alert("Couldn't update checklist", isPresented: $showingUpdateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes couldn't be saved. Please try again.")
        }
    }

    private var learningGoals: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Learning goals")
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                Spacer()
                Button { onNavigate(.onboarding) } label: {
                    Label("Add topic", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
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
    }

    private var checklist: some View {
        let completedCount = viewModel.completedCount(in: tasks)

        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Your checklist")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(completedCount)/\(tasks.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EmberTheme.muted)
                    .accessibilityHidden(true)
            }

            ProgressView(value: Double(completedCount), total: Double(max(tasks.count, 1)))
                .tint(EmberTheme.primary)
                .accessibilityLabel("Checklist progress")
                .accessibilityValue("\(completedCount) of \(tasks.count) tasks complete")

            if !goals.isEmpty {
                Button { openEditor() } label: {
                    Label("Add task", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }

            if tasks.isEmpty {
                emptyChecklist
            } else {
                ForEach(tasks, id: \.id) { task in
                    taskRow(task)
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

    private var emptyChecklist: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 30))
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 68, height: 68)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 19))
                .accessibilityHidden(true)
            Text("Your checklist starts here")
                .font(.headline)
                .foregroundStyle(EmberTheme.primary)
            Text(goals.isEmpty ? "Add a learning topic to start planning tasks." : "Add one small step toward a learning goal.")
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func taskRow(_ task: LearningTask) -> some View {
        let topic = goals.first(where: { $0.id == task.goalID })?.topic ?? "Unavailable topic"

        return HStack(spacing: 8) {
            Button {
                updateChecklist { try viewModel.toggleCompletion(of: task, in: modelContext) }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isCompleted ? EmberTheme.primary : EmberTheme.muted)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EmberTheme.primary)
                            .strikethrough(task.isCompleted)
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(task.isCompleted ? "Completed" : "Incomplete")
            .accessibilityHint(task.isCompleted ? "Marks task incomplete" : "Marks task complete")

            Menu {
                Button { openEditor(for: task) } label: {
                    Label("Edit task", systemImage: "pencil")
                }
                Button(role: .destructive) { taskToDelete = task } label: {
                    Label("Delete task", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(EmberTheme.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(task.title)")
        }
    }

    private func openEditor(for task: LearningTask? = nil) {
        viewModel.prepareEditor(for: task, goals: goals)
        editor = TaskEditor(task: task)
    }

    private func updateChecklist(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            showingUpdateError = true
        }
    }

    private struct TaskEditor: Identifiable {
        let id = UUID()
        let task: LearningTask?
    }
}

private struct TaskEditorView: View {
    @Bindable var viewModel: TaskPlannerViewModel
    let task: LearningTask?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task title", text: $viewModel.draftTaskTitle)
                    .textInputAutocapitalization(.sentences)

                Picker("Learning topic", selection: $viewModel.draftGoalID) {
                    if let originalGoalID = task?.goalID,
                       !goals.contains(where: { $0.id == originalGoalID }) {
                        Text("Unavailable topic").tag(Optional(originalGoalID))
                    }
                    if viewModel.draftGoalID == nil {
                        Text("Select a topic").tag(nil as UUID?)
                    }
                    ForEach(goals, id: \.id) { goal in
                        Text(goal.topic).tag(Optional(goal.id))
                    }
                }
            }
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!viewModel.canSaveTask)
                }
            }
        }
        .alert("Couldn't save task", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func save() {
        do {
            try viewModel.saveTask(task, goals: goals, in: modelContext)
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
        }
    }
}
