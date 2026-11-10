import SwiftUI
import SwiftData

/// Sessions tab: an "Up next" task, then one card per learning goal.
/// Tapping a goal opens `LearningGoalDetailView` with that goal's checklist.
struct TaskPlannerView: View {
    var onNavigate: (AppRoute) -> Void = { _ in }

    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @Environment(AppNavigation.self) private var navigation: AppNavigation?
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @Query(sort: \LearningTask.createdAt) private var tasks: [LearningTask]
    @State private var viewModel = TaskPlannerViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if hasCompletedOnboarding {
                    EmberPageHeading(
                        eyebrow: "Sessions",
                        title: "Let's build momentum.",
                        subtitle: "Small tasks make learning feel possible."
                    )

                    if goals.isEmpty {
                        MissingLearningGoalState {
                            onNavigate(.onboarding)
                        }
                    } else {
                        upNext
                        learningGoals
                    }
                } else {
                    SessionsOnboardingSetup {
                        onNavigate(.onboarding)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Up next

    @ViewBuilder
    private var upNext: some View {
        if let next = viewModel.nextTask(across: goals, in: tasks) {
            UpNextCard(
                eyebrow: "Up next · \(next.goal.topic)",
                title: next.task.title,
                note: next.task.notes
            ) {
                navigation?.startFocus(taskID: next.task.id)
            }
        } else if tasks.isEmpty {
            CalmNoteCard(
                symbol: "sparkle",
                title: "Plan your first small step",
                detail: "Open a learning goal below and add one task."
            )
        } else {
            CalmNoteCard(
                symbol: "flame.fill",
                title: "Everything's done",
                detail: "Rest is progress too. Add a new task when you're ready."
            )
        }
    }

    // MARK: - Learning goals

    private var learningGoals: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("Learning goals")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { onNavigate(.onboarding) } label: {
                    Label("New goal", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }

            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                let goalTasks = viewModel.tasks(for: goal.id, in: tasks)
                LearningGoalCard(
                    goal: goal,
                    style: LearningGoalStyle(index: index),
                    tasks: goalTasks,
                    nextTask: goalTasks.first { !$0.isCompleted }
                ) {
                    navigation?.openGoal(goal.id)
                }
            }
        }
    }
}

// MARK: - Goal detail

/// One learning goal's checklist: an "Up next" task, remaining tasks with a Focus button each,
/// and a collapsible list of finished tasks.
struct LearningGoalDetailView: View {
    let goalID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation: AppNavigation?
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @Query(sort: \LearningTask.createdAt) private var allTasks: [LearningTask]
    @State private var viewModel = TaskPlannerViewModel()
    @State private var editor: TaskEditor?
    @State private var taskToDelete: LearningTask?
    @State private var showingUpdateError = false
    @State private var showDone = false

    private var goalIndex: Int? { goals.firstIndex { $0.id == goalID } }
    private var goal: LearningGoal? { goalIndex.map { goals[$0] } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let goal, let goalIndex {
                    content(goal: goal, index: goalIndex)
                } else {
                    CalmNoteCard(
                        symbol: "questionmark.folder",
                        title: "This goal isn't available",
                        detail: "It may have been removed. Go back to see your learning goals."
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(EmberTheme.canvas.ignoresSafeArea())
        .navigationTitle(goal?.topic ?? "Learning goal")
        .navigationBarTitleDisplayMode(.inline)
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
        .sensoryFeedback(.selection, trigger: allTasks.filter(\.isCompleted).count)
    }

    @ViewBuilder
    private func content(goal: LearningGoal, index: Int) -> some View {
        let style = LearningGoalStyle(index: index)
        let tasks = viewModel.tasks(for: goal.id, in: allTasks)
        let todo = tasks.filter { !$0.isCompleted }
        let done = tasks.filter(\.isCompleted)

        header(goal: goal, index: index, style: style, done: done.count, total: tasks.count)

        if let upNext = todo.first {
            UpNextCard(eyebrow: "Up next", title: upNext.title, note: upNext.notes, leading: {
                checkButton(for: upNext, onDark: true)
            }) {
                navigation?.startFocus(taskID: upNext.id)
            }
            .contextMenu { taskMenu(for: upNext) }
        } else if tasks.isEmpty {
            CalmNoteCard(
                symbol: "sparkle",
                title: "Add your first task",
                detail: "One small, concrete step toward \(goal.topic)."
            )
        } else {
            CalmNoteCard(
                symbol: "flame.fill",
                title: "Goal complete",
                detail: "Every task here is done. Add a new one when you're ready."
            )
        }

        VStack(alignment: .leading, spacing: 0) {
            if todo.count > 1 {
                sectionLabel("To do")
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                ForEach(todo.dropFirst(), id: \.id) { task in
                    todoRow(task)
                    Divider().overlay(EmberTheme.separator)
                }
            }
            addTaskRow(goalID: goal.id)
        }
        .padding(.horizontal, 14)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))

        if !done.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.snappy) { showDone.toggle() }
                } label: {
                    HStack {
                        sectionLabel("Done (\(done.count))")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EmberTheme.muted)
                            .rotationEffect(.degrees(showDone ? 180 : 0))
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showDone ? "Hide done tasks" : "Show \(done.count) done tasks")

                if showDone {
                    ForEach(done, id: \.id) { task in
                        doneRow(task)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        }
    }

    private func header(goal: LearningGoal, index: Int, style: LearningGoalStyle, done: Int, total: Int) -> some View {
        HStack(alignment: .center, spacing: 13) {
            LearningGoalTile(style: style, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("Learning goal \(index + 1)")
                Text(goal.topic)
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            GoalProgressRing(done: done, total: total)
        }
    }

    private func todoRow(_ task: LearningTask) -> some View {
        HStack(spacing: 11) {
            checkButton(for: task, onDark: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                if !task.notes.isEmpty {
                    Label(task.notes, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)
                        .lineLimit(1)
                        .labelStyle(NoteLabelStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                navigation?.startFocus(taskID: task.id)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EmberTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(EmberTheme.mint, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start focus on \(task.title)")
        }
        .frame(minHeight: 52)
        .contextMenu { taskMenu(for: task) }
    }

    private func doneRow(_ task: LearningTask) -> some View {
        HStack(spacing: 11) {
            checkButton(for: task, onDark: false)
            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .strikethrough(true, color: EmberTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 48)
        .contextMenu { taskMenu(for: task) }
    }

    private func addTaskRow(goalID: UUID) -> some View {
        Button {
            viewModel.prepareEditor(for: nil, goals: goals)
            viewModel.draftGoalID = goalID
            editor = TaskEditor(task: nil)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EmberTheme.muted)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(EmberTheme.muted, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                    .frame(width: 44, height: 44)
                Text("Add a task")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.muted)
                Spacer()
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkButton(for task: LearningTask, onDark: Bool) -> some View {
        Button {
            updateChecklist { try viewModel.toggleCompletion(of: task, in: modelContext) }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(onDark ? EmberTheme.mint : EmberTheme.muted, lineWidth: 1.5)
                    .opacity(task.isCompleted ? 0 : 1)
                if task.isCompleted {
                    Circle().fill(EmberTheme.primary)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityValue(task.isCompleted ? "Completed" : "Incomplete")
        .accessibilityHint(task.isCompleted ? "Marks task incomplete" : "Marks task complete")
    }

    @ViewBuilder
    private func taskMenu(for task: LearningTask) -> some View {
        Button {
            viewModel.prepareEditor(for: task, goals: goals)
            editor = TaskEditor(task: task)
        } label: {
            Label("Edit task", systemImage: "pencil")
        }
        Button(role: .destructive) { taskToDelete = task } label: {
            Label("Delete task", systemImage: "trash")
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(EmberTheme.muted)
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

// MARK: - Goal styling and shared pieces

/// Icon and tint for a goal, assigned by its position so no extra data needs storing.
struct LearningGoalStyle {
    let symbol: String
    let tint: Color

    private static let palette: [(String, Color)] = [
        ("graduationcap", EmberTheme.mint),
        ("briefcase", EmberTheme.amber.opacity(0.32)),
        ("leaf", EmberTheme.separator),
        ("sparkles", EmberTheme.amber.opacity(0.18)),
        ("book.closed", EmberTheme.mint.opacity(0.6)),
        ("paintpalette", EmberTheme.separator.opacity(0.7))
    ]

    init(index: Int) {
        let entry = Self.palette[((index % Self.palette.count) + Self.palette.count) % Self.palette.count]
        symbol = entry.0
        tint = entry.1
    }
}

struct LearningGoalTile: View {
    let style: LearningGoalStyle
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: style.symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(EmberTheme.primary)
            .frame(width: size, height: size)
            .background(style.tint, in: RoundedRectangle(cornerRadius: size * 0.31))
            .accessibilityHidden(true)
    }
}

private struct LearningGoalCard: View {
    let goal: LearningGoal
    let style: LearningGoalStyle
    let tasks: [LearningTask]
    let nextTask: LearningTask?
    let onOpen: () -> Void

    private var doneCount: Int { tasks.filter(\.isCompleted).count }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 13) {
                LearningGoalTile(style: style)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(goal.topic)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(EmberTheme.primary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(doneCount)/\(tasks.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EmberTheme.muted)
                            .monospacedDigit()
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)
                        .lineLimit(1)
                    SegmentedProgress(done: doneCount, total: tasks.count)
                        .padding(.top, 4)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EmberTheme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
            .contentShape(RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.topic)
        .accessibilityValue("\(doneCount) of \(tasks.count) tasks done. \(subtitle)")
        .accessibilityHint("Opens this goal's checklist")
        .accessibilityAddTraits(.isButton)
    }

    private var subtitle: String {
        if let nextTask { return "Next: \(nextTask.title)" }
        return tasks.isEmpty ? "No tasks yet" : "All tasks done"
    }
}

/// One segment per task for small checklists; a plain bar once there are too many to count.
private struct SegmentedProgress: View {
    let done: Int
    let total: Int

    var body: some View {
        Group {
            if total == 0 {
                Capsule().fill(EmberTheme.separator)
            } else if total <= 10 {
                HStack(spacing: 3) {
                    ForEach(0..<total, id: \.self) { index in
                        Capsule().fill(index < done ? EmberTheme.primary : EmberTheme.separator)
                    }
                }
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(EmberTheme.separator)
                        Capsule()
                            .fill(EmberTheme.primary)
                            .frame(width: proxy.size.width * CGFloat(done) / CGFloat(total))
                    }
                }
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.4), value: done)
        .accessibilityHidden(true)
    }
}

private struct GoalProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle().stroke(EmberTheme.separator, lineWidth: 4)
            Circle()
                .trim(from: 0, to: total == 0 ? 0 : CGFloat(done) / CGFloat(total))
                .stroke(EmberTheme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(total)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(EmberTheme.primary)
                .monospacedDigit()
        }
        .frame(width: 46, height: 46)
        .animation(.easeInOut(duration: 0.4), value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) tasks done")
    }
}

/// The dark "Up next" card with one Start focus action.
private struct UpNextCard<Leading: View>: View {
    let eyebrow: String
    let title: String
    var note: String = ""
    let leading: Leading
    let onStart: () -> Void

    init(eyebrow: String, title: String, note: String = "",
         @ViewBuilder leading: () -> Leading,
         onStart: @escaping () -> Void) {
        self.eyebrow = eyebrow
        self.title = title
        self.note = note
        self.leading = leading()
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(EmberTheme.mint)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(EmberTheme.amber)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                leading
                Text(title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !note.isEmpty {
                Label(note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(2)
                    .labelStyle(NoteLabelStyle())
            }
            Button(action: onStart) {
                Label("Start focus", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start focus on \(title)")
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 22))
    }
}

private extension UpNextCard where Leading == EmptyView {
    init(eyebrow: String, title: String, note: String = "", onStart: @escaping () -> Void) {
        self.init(eyebrow: eyebrow, title: title, note: note, leading: { EmptyView() }, onStart: onStart)
    }
}

/// Small icon + text with tight spacing, used for task notes.
struct NoteLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            configuration.icon.font(.system(size: 10, weight: .semibold))
            configuration.title
        }
    }
}

private struct CalmNoteCard: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(symbol == "flame.fill" ? EmberTheme.amber : EmberTheme.primary)
                .frame(width: 42, height: 42)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(EmberTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
    }
}

private struct SessionsOnboardingSetup: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SessionsSetupHeading()
            SessionsSetupInvitation(onStart: onStart)
        }
    }
}

private struct SessionsSetupHeading: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(EmberTheme.muted)

                Text("Setup required")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(EmberTheme.mint, in: Capsule())
            }

            Text("Let's build momentum.")
                .font(.system(size: 33, weight: .medium, design: .serif))
                .tracking(-0.6)
                .foregroundStyle(EmberTheme.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("A few quick choices will shape a learning checklist that fits you.")
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionsSetupInvitation: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "book.pages")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 72, height: 72)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("What would you like to learn?")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                    .multilineTextAlignment(.center)

                Text("Set up your first learning session in three simple steps.")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                SessionsSetupStep(
                    number: 1,
                    title: "Learning goals",
                    detail: "Choose a topic you want to make progress on."
                )
                SessionsSetupStep(
                    number: 2,
                    title: "Energy rhythm",
                    detail: "Share when focused learning feels most natural."
                )
                SessionsSetupStep(
                    number: 3,
                    title: "Learning plan",
                    detail: "Review a practical starting plan, then build your checklist."
                )
            }

            Button(action: onStart) {
                HStack {
                    Text("Start my learning setup")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 54)
                .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct SessionsSetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 30, height: 30)
                .background(EmberTheme.mint, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(EmberTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MissingLearningGoalState: View {
    let onAddTopic: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 64, height: 64)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)

            Text("Add a learning goal first")
                .font(.headline)
                .foregroundStyle(EmberTheme.primary)

            Text("Choose a topic before creating your first checklist task.")
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .multilineTextAlignment(.center)

            Button(action: onAddTopic) {
                Label("Add learning topic", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
    }
}

/// Ember-styled sheet for adding or editing a task inside one learning goal.
/// New tasks: the goal is fixed (shown as a chip), and "Add task" keeps the sheet open
/// so several small steps can be added in a row. Editing: same sheet, with a
/// "Move to another goal" option.
private struct TaskEditorView: View {
    @Bindable var viewModel: TaskPlannerViewModel
    let task: LearningTask?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]
    @FocusState private var focusedField: Field?
    @State private var justAdded: [String] = []
    @State private var errorMessage: String?
    @State private var addedCount = 0

    private enum Field { case title, notes }

    private var isEditing: Bool { task != nil }
    private var isTitleFocused: Bool { focusedField == .title }

    private static let starterIdeas = [
        "Read one chapter",
        "Do 5 practice questions",
        "Watch one lecture",
        "Review my notes"
    ]

    private var goalIndex: Int? { goals.firstIndex { $0.id == viewModel.draftGoalID } }
    private var goalName: String {
        goalIndex.map { goals[$0].topic } ?? "Choose a goal"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar

                VStack(alignment: .leading, spacing: 9) {
                    Text(isEditing ? "TASK IN" : "NEW TASK FOR")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(EmberTheme.muted)
                    goalChip
                }

                titleField

                if !isEditing && viewModel.draftTaskTitle.isEmpty {
                    starterIdeas
                }

                notesBox

                Button(action: submit) {
                    Label(isEditing ? "Save changes" : "Add task",
                          systemImage: isEditing ? "checkmark" : "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 13))
                        .opacity(viewModel.canSaveTask ? 1 : 0.4)
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }

                if !justAdded.isEmpty {
                    justAddedList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.never)
        .background(EmberTheme.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(EmberTheme.surface)
        .sensoryFeedback(.success, trigger: addedCount)
        .task {
            // Focusing during the sheet's slide-in can be ignored, so wait for it to settle.
            try? await Task.sleep(for: .milliseconds(350))
            focusedField = .title
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button(justAdded.isEmpty ? "Cancel" : "Done") { dismiss() }
                .font(.subheadline.weight(justAdded.isEmpty ? .regular : .semibold))
                .foregroundStyle(justAdded.isEmpty ? EmberTheme.muted : EmberTheme.primary)
                .frame(minHeight: 44)
            Spacer()
            Text(isEditing ? "Edit task" : "New task")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EmberTheme.primary)
            Spacer()
            // Keeps the title centred.
            Text(justAdded.isEmpty ? "Cancel" : "Done")
                .font(.subheadline)
                .hidden()
        }
    }

    @ViewBuilder
    private var goalChip: some View {
        let chip = HStack(spacing: 7) {
            Image(systemName: LearningGoalStyle(index: goalIndex ?? 0).symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(goalName)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            if isEditing && goals.count > 1 {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(EmberTheme.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(LearningGoalStyle(index: goalIndex ?? 0).tint, in: Capsule())

        if isEditing && goals.count > 1 {
            Menu {
                Section("Move to another goal") {
                    ForEach(goals, id: \.id) { goal in
                        Button {
                            viewModel.draftGoalID = goal.id
                        } label: {
                            if goal.id == viewModel.draftGoalID {
                                Label(goal.topic, systemImage: "checkmark")
                            } else {
                                Text(goal.topic)
                            }
                        }
                    }
                }
            } label: {
                chip
            }
            .accessibilityLabel("Goal: \(goalName). Move to another goal")
        } else {
            chip
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Goal: \(goalName)")
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("What's one small step?", text: $viewModel.draftTaskTitle)
                .font(.system(size: 23, weight: .medium, design: .serif))
                .foregroundStyle(EmberTheme.primary)
                .textInputAutocapitalization(.sentences)
                .submitLabel(isEditing ? .done : .next)
                .focused($focusedField, equals: .title)
                .onSubmit(submit)
                .onChange(of: viewModel.draftTaskTitle) { errorMessage = nil }
            Rectangle()
                .fill(isTitleFocused ? EmberTheme.primary : EmberTheme.separator)
                .frame(height: 1.5)
                .animation(.easeInOut(duration: 0.2), value: isTitleFocused)
            Text("Keep it short and doable in one session.")
                .font(.caption)
                .foregroundStyle(EmberTheme.muted)
        }
    }

    /// Optional notes for the task (pages, links, reminders), shown in the checklist and Focus.
    private var notesBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                Text("Optional")
                    .font(.caption2)
                Spacer()
            }
            .foregroundStyle(EmberTheme.muted)

            TextField(
                "Pages, links or anything to remember",
                text: $viewModel.draftNotes,
                axis: .vertical
            )
            .font(.subheadline)
            .foregroundStyle(EmberTheme.primary)
            .lineLimit(3...6)
            .focused($focusedField, equals: .notes)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(EmberTheme.canvas.clipShape(RoundedRectangle(cornerRadius: 14)))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(focusedField == .notes ? EmberTheme.primary : EmberTheme.separator,
                                  lineWidth: focusedField == .notes ? 1.5 : 1)
            }
            .animation(.easeInOut(duration: 0.2), value: focusedField)
            .accessibilityLabel("Notes, optional")
        }
    }

    private var starterIdeas: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Self.starterIdeas, id: \.self) { idea in
                    Button {
                        viewModel.draftTaskTitle = idea
                        focusedField = .title
                    } label: {
                        Text(idea)
                            .font(.footnote)
                            .foregroundStyle(EmberTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white, in: Capsule())
                            .overlay(Capsule().strokeBorder(EmberTheme.separator))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    private var justAddedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("JUST ADDED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(EmberTheme.muted)
                .padding(.bottom, 4)
            ForEach(Array(justAdded.enumerated()), id: \.offset) { _, title in
                HStack(spacing: 10) {
                    Image(systemName: "circle")
                        .foregroundStyle(EmberTheme.muted)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.primary)
                    Spacer()
                }
                .frame(minHeight: 40)
                Divider().overlay(EmberTheme.separator)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func submit() {
        guard viewModel.canSaveTask else {
            errorMessage = "Write a task first."
            focusedField = .title
            return
        }
        let title = viewModel.draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try viewModel.saveTask(task, goals: goals, in: modelContext)
            if isEditing {
                dismiss()
            } else {
                // Stay open for the next small step.
                withAnimation(.snappy) { justAdded.insert(title, at: 0) }
                addedCount += 1
                viewModel.draftTaskTitle = ""
                viewModel.draftNotes = ""
                focusedField = .title
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
