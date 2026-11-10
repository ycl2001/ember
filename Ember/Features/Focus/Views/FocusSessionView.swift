import SwiftUI
import SwiftData
import UIKit

/// Member 4 owns this file. Track focus time in a FocusSession record.
///
/// Flow: choose a task → running ⇄ paused (optional 20-min checkpoint) → saved summary
/// → mark task complete / go to Reflection.
struct FocusSessionView: View {
    @State private var viewModel = FocusSessionViewModel()
    @State private var showDiscardConfirm = false
    @State private var showDiscardUnfinishedConfirm = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// Optional so the view also works in previews without the app shell.
    @Environment(AppNavigation.self) private var navigation: AppNavigation?

    @Query(sort: \LearningTask.createdAt) private var allTasks: [LearningTask]
    @Query(sort: \LearningGoal.createdAt) private var goals: [LearningGoal]

    private var openTasks: [LearningTask] { allTasks.filter { !$0.isCompleted } }

    private var selectedTask: LearningTask? {
        guard let id = viewModel.selectedTaskID else { return nil }
        return allTasks.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switch viewModel.phase {
                case .setup:
                    setupContent
                case .running, .paused:
                    activeContent
                case .finished:
                    summaryContent
                }

                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .navigationTitle("Focus session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isActive)
        .toolbar {
            if viewModel.isActive {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") { showDiscardConfirm = true }
                }
            }
        }
        .confirmationDialog(
            "End this session?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            if viewModel.canFinish {
                Button("Save and finish") { viewModel.finish(in: modelContext) }
            }
            Button("Discard session", role: .destructive) { viewModel.discard() }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text("Saving keeps your focused time for reflection and insights.")
        }
        .sheet(isPresented: $viewModel.showMilestoneSheet) {
            milestoneSheet
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
                .interactiveDismissDisabled()
        }
        .animation(.snappy, value: viewModel.phase)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.phase)
        .sensoryFeedback(.success, trigger: viewModel.hasReachedMilestone) { _, reached in reached }
        .onAppear {
            viewModel.checkForUnfinishedSession(tasks: allTasks)
            // A task chosen on the Sessions screen arrives through AppNavigation; use it once.
            if let taskID = navigation?.pendingFocusTaskID {
                viewModel.preselect(taskID: taskID, from: openTasks)
                navigation?.pendingFocusTaskID = nil
            }
            viewModel.ensureSelection(from: openTasks)
        }
        .onChange(of: openTasks.map(\.id)) { viewModel.ensureSelection(from: openTasks) }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: viewModel.refresh()
            case .inactive, .background: viewModel.appWillLeaveForeground()
            @unknown default: break
            }
        }
        .onChange(of: viewModel.isRunning) { _, running in
            // Keep the screen awake only while the timer is actually running.
            UIApplication.shared.isIdleTimerDisabled = running
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        if let draft = viewModel.unfinishedDraft {
            EmberPageHeading(
                eyebrow: "Welcome back",
                title: "Pick up where you left off?",
                subtitle: "Your last session was still open when Ember closed."
            )
            unfinishedSessionCard(draft)
        } else {
            readyToStartContent
        }
    }

    @ViewBuilder
    private var readyToStartContent: some View {
        EmberPageHeading(
            eyebrow: "Ready when you are",
            title: "One task, full attention.",
            subtitle: "Pick what you'll work on. Paused time isn't counted."
        )

        if openTasks.isEmpty {
            emptyState
        } else if viewModel.isTaskPreselected, let task = selectedTask, !task.isCompleted {
            preselectedTaskCard(task)
            milestoneToggleCard
        } else {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Choose a task")
                ForEach(openTasks, id: \.id) { task in
                    taskRow(task)
                }
            }

            milestoneToggleCard
        }
    }

    private func taskRow(_ task: LearningTask) -> some View {
        let isSelected = task.id == viewModel.selectedTaskID
        return Button {
            viewModel.selectedTaskID = task.id
        } label: {
            HStack(spacing: 13) {
                LearningGoalTile(style: goalStyle(for: task), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let topic = goalTopic(for: task) {
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? EmberTheme.primary : EmberTheme.separator)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
            .overlay {
                RoundedRectangle(cornerRadius: 19)
                    .strokeBorder(isSelected ? EmberTheme.primary : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The task chosen on the Sessions screen, shown on its own with a way to switch.
    private func preselectedTaskCard(_ task: LearningTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Your task")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 13) {
                    LearningGoalTile(style: goalStyle(for: task), size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        if let topic = goalTopic(for: task) {
                            Text(topic.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(EmberTheme.muted)
                        }
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EmberTheme.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !task.notes.isEmpty {
                            Label(task.notes, systemImage: "note.text")
                                .font(.caption)
                                .foregroundStyle(EmberTheme.muted)
                                .labelStyle(NoteLabelStyle())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(EmberTheme.primary)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 12)

                Divider().overlay(EmberTheme.separator)

                Button {
                    withAnimation(.snappy) { viewModel.changeTask() }
                } label: {
                    Label("Change task", systemImage: "arrow.left.arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EmberTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(14)
            .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
            .overlay {
                RoundedRectangle(cornerRadius: 19)
                    .strokeBorder(EmberTheme.primary, lineWidth: 1.5)
            }
        }
    }

    private func goalTopic(for task: LearningTask) -> String? {
        goals.first { $0.id == task.goalID }?.topic
    }

    private func goalStyle(for task: LearningTask) -> LearningGoalStyle {
        LearningGoalStyle(index: goals.firstIndex { $0.id == task.goalID } ?? 0)
    }

    /// Dark card offering to resume, save or discard a session left open when the app closed.
    private func unfinishedSessionCard(_ draft: FocusSessionDraft) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("UNFINISHED SESSION · \(draft.savedAt.formatted(.relative(presentation: .named)).uppercased())")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(EmberTheme.mint)
            Text(draft.taskTitle)
                .font(.system(size: 21, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 12) {
                Text(FocusSessionViewModel.format(Int(draft.focusedSeconds)))
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("focused so far\npaused time not counted")
                    .font(.caption)
                    .foregroundStyle(EmberTheme.mint)
            }

            Button { viewModel.resumeUnfinished() } label: {
                Label("Resume session", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)

            HStack(spacing: 9) {
                Button { viewModel.finishUnfinished(in: modelContext) } label: {
                    Text("Save as finished")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.35)))
                }
                Button { showDiscardUnfinishedConfirm = true } label: {
                    Text("Discard")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.2)))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 22))
        .confirmationDialog(
            "Discard this session?",
            isPresented: $showDiscardUnfinishedConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard session", role: .destructive) { viewModel.discardUnfinished() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The \(FocusSessionViewModel.format(Int(draft.focusedSeconds))) you focused won't be saved.")
        }
    }

    private var milestoneToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            milestoneToggle
            if viewModel.milestoneReminderEnabled {
                Divider().overlay(EmberTheme.separator)
                lockReminderToggle
            }
        }
        .padding(13)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        .animation(.snappy, value: viewModel.milestoneReminderEnabled)
    }

    /// Optional notification at 20 focused minutes, for when the phone is locked.
    private var lockReminderToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { viewModel.lockReminderEnabled },
                set: { newValue in Task { await viewModel.setLockReminder(newValue) } }
            )) {
                HStack(spacing: 13) {
                    Image(systemName: "bell")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(EmberTheme.primary)
                        .frame(width: 40, height: 40)
                        .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Remind me when locked")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EmberTheme.primary)
                        Text(viewModel.lockReminderEnabled
                             ? "You'll get one quiet notification."
                             : "Asks permission the first time.")
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                    }
                }
            }
            .tint(EmberTheme.primary)

            if let notice = viewModel.reminderNotice {
                Label(notice, systemImage: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(EmberTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var milestoneToggle: some View {
        Toggle(isOn: $viewModel.milestoneReminderEnabled) {
            HStack(spacing: 13) {
                Image(systemName: "flag")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(EmberTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(EmberTheme.amber.opacity(0.28), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("20-min check-in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                    Text("A gentle pause to check your pacing.")
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)
                }
            }
        }
        .tint(EmberTheme.primary)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 48, height: 48)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 15))
            Text("Plan a task to focus on")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(EmberTheme.primary)
            Text("Focus sessions are linked to a learning task. Add one in your checklist first.")
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                navigation?.select(.sessions)
            } label: {
                primaryLabel("Open checklist", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
    }

    // MARK: - Running / paused

    @ViewBuilder
    private var activeContent: some View {
        HStack(spacing: 10) {
            statusChip(viewModel.isRunning ? "In progress" : "Paused",
                       systemImage: viewModel.isRunning ? "circle.fill" : "pause.fill")
            Text(viewModel.activeTaskTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EmberTheme.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))

        timerRing
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

        if viewModel.milestoneReminderEnabled {
            HStack(spacing: 12) {
                Image(systemName: viewModel.hasReachedMilestone ? "checkmark.circle.fill" : "flag")
                    .foregroundStyle(EmberTheme.primary)
                    .frame(width: 32, height: 32)
                    .background(EmberTheme.mint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Energy gauge active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                    Text(viewModel.milestoneStatusText)
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)
                }
                Spacer()
            }
            .padding(13)
            .background(EmberTheme.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(EmberTheme.separator, lineWidth: 12)
            Circle()
                .trim(from: 0, to: viewModel.ringProgress)
                .stroke(
                    viewModel.isRunning ? EmberTheme.amber : EmberTheme.muted.opacity(0.5),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.ringProgress)
            VStack(spacing: 6) {
                breathingEmber
                Text(viewModel.formattedElapsedTime)
                    .font(.system(size: 46, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(EmberTheme.primary)
                emberDots
                Text(viewModel.isRunning ? "FOCUSING" : "PAUSED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(EmberTheme.muted)
                    .padding(.top, 2)
            }
        }
        .frame(width: 250, height: 250)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focused time \(viewModel.formattedElapsedTime), \(viewModel.isRunning ? "running" : "paused")")
        .accessibilityValue("\(viewModel.litEmberDots) of \(FocusSessionViewModel.emberDotCount) embers lit")
    }

    /// A flame that slowly "breathes" (4-second cycle) while focusing, warms from mint to
    /// amber over 20 minutes, and cools to grey when paused. Breathing is skipped when
    /// Reduce Motion is on.
    private var breathingEmber: some View {
        let shouldBreathe = viewModel.isRunning && !reduceMotion
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: !shouldBreathe)) { context in
            let phase = shouldBreathe ? Self.breathPhase(at: context.date) : 1.0
            Image(systemName: "flame.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(emberColor)
                .opacity(viewModel.isRunning ? 0.7 + 0.3 * phase : 0.9)
                .scaleEffect(viewModel.isRunning ? 0.94 + 0.1 * phase : 1)
        }
        .animation(.easeInOut(duration: 0.6), value: viewModel.isRunning)
        .accessibilityHidden(true)
    }

    /// 0 → 1 → 0 over a 4-second breathing cycle.
    private static func breathPhase(at date: Date) -> Double {
        let cycleSeconds = 4.0
        let angle = date.timeIntervalSinceReferenceDate * 2.0 * Double.pi / cycleSeconds
        return (sin(angle) + 1.0) / 2.0
    }

    private var emberColor: Color {
        guard viewModel.isRunning else { return Self.emberGrey }
        return Self.blend(Self.emberMint, Self.emberAmber, viewModel.emberWarmth)
    }

    /// One dot per 5 focused minutes.
    private var emberDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<FocusSessionViewModel.emberDotCount, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.litEmberDots
                          ? (viewModel.isRunning ? EmberTheme.amber : Self.emberGrey.opacity(0.8))
                          : EmberTheme.separator)
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: viewModel.litEmberDots)
        .accessibilityHidden(true)
    }

    // Ember palette (RGB 0–1). Mint is a slightly deeper tone than EmberTheme.mint so the
    // flame stays visible on the light ring background.
    private static let emberMint = (r: 127.0 / 255, g: 184.0 / 255, b: 154.0 / 255)
    private static let emberAmber = (r: 233.0 / 255, g: 172.0 / 255, b: 107.0 / 255)
    private static let emberGrey = Color(red: 176 / 255, green: 184 / 255, blue: 178 / 255)

    private static func blend(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double),
        _ t: Double
    ) -> Color {
        Color(red: a.r + (b.r - a.r) * t,
              green: a.g + (b.g - a.g) * t,
              blue: a.b + (b.b - a.b) * t)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summaryContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 28))
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 66, height: 66)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 22))
            Text("Nice work. Session saved.")
                .font(.system(size: 29, weight: .medium, design: .serif))
                .foregroundStyle(EmberTheme.primary)
                .multilineTextAlignment(.center)
            Text(viewModel.activeTaskTitle)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)

        HStack(spacing: 10) {
            EmberMetricCard(value: viewModel.focusedMinutesText, label: "Focused time")
            EmberMetricCard(value: viewModel.hasReachedMilestone ? "1" : "0", label: "Checkpoints")
        }

        if let task = selectedTask {
            Toggle(isOn: Binding(
                get: { task.isCompleted },
                set: { viewModel.setTask(task, completed: $0, in: modelContext) }
            )) {
                Label {
                    Text("Mark task complete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                } icon: {
                    Image(systemName: "checkmark.square")
                        .foregroundStyle(EmberTheme.primary)
                }
            }
            .tint(EmberTheme.primary)
            .padding(14)
            .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        }

        Text("Take a moment to note how your energy shifted. It helps Ember suggest a steadier pace.")
            .font(.caption)
            .foregroundStyle(EmberTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Bottom actions

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 9) {
            switch viewModel.phase {
            case .setup:
                if viewModel.unfinishedDraft == nil, let task = selectedTask, !openTasks.isEmpty {
                    Button { viewModel.start(task: task) } label: {
                        primaryLabel("Start focusing", systemImage: "play.fill")
                    }
                }
            case .running, .paused:
                Button { viewModel.togglePause() } label: {
                    primaryLabel(viewModel.isRunning ? "Pause" : "Resume",
                                 systemImage: viewModel.isRunning ? "pause.fill" : "play.fill")
                }
                Button { viewModel.finish(in: modelContext) } label: {
                    secondaryLabel("Finish session")
                }
                .disabled(!viewModel.canFinish)
                .opacity(viewModel.canFinish ? 1 : 0.5)
            case .finished:
                Button {
                    navigation?.push(.reflection)
                } label: {
                    primaryLabel("Reflect on your energy", systemImage: "arrow.right")
                }
                Button { viewModel.startAnother() } label: {
                    secondaryLabel("Start another session")
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(EmberTheme.canvas)
    }

    // MARK: - Milestone sheet

    private var milestoneSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusChip("20 min milestone", systemImage: "flag.fill", tint: EmberTheme.amber.opacity(0.3))
            VStack(alignment: .leading, spacing: 6) {
                Text("Pacing checkpoint")
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                Text("You've focused for 20 minutes. The timer is paused while you decide how to continue.")
                    .font(.subheadline)
                    .foregroundStyle(EmberTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button { viewModel.takeBreak() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "eye")
                        .font(.system(size: 18, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restorative eye break")
                            .font(.subheadline.weight(.semibold))
                        Text("Stay paused, rest your eyes, resume when ready.")
                            .font(.caption)
                            .foregroundStyle(EmberTheme.muted)
                    }
                    Spacer()
                    Text("5 min")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(EmberTheme.surface, in: Capsule())
                }
                .foregroundStyle(EmberTheme.primary)
                .padding(14)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button { viewModel.keepGoing() } label: {
                primaryLabel("Keep going", systemImage: "play.fill")
            }
            .buttonStyle(.plain)

            Button("Finish here") { viewModel.finish(in: modelContext) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EmberTheme.muted)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(EmberTheme.canvas.ignoresSafeArea())
    }

    // MARK: - Small building blocks

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundStyle(EmberTheme.muted)
    }

    private func statusChip(_ text: String, systemImage: String, tint: Color = EmberTheme.mint) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .labelStyle(.titleAndIcon)
            .imageScale(.small)
            .foregroundStyle(EmberTheme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
            .fixedSize()
    }

    private func primaryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(13)
            .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(EmberTheme.primary)
    }
}

#Preview("With sample tasks") {
    let container = try! ModelContainer(
        for: LearningGoal.self, LearningTask.self, FocusSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let goal = LearningGoal(topic: "CS & Systems")
    container.mainContext.insert(goal)
    let goalID = goal.id
    for title in ["Read chapter 3: Hash tables", "Practice 5 SQL joins", "Watch lecture 4"] {
        container.mainContext.insert(LearningTask(goalID: goalID, title: title))
    }
    return NavigationStack {
        FocusSessionView()
    }
    .modelContainer(container)
}

#Preview("Empty state") {
    NavigationStack {
        FocusSessionView()
    }
    .modelContainer(for: [LearningGoal.self, LearningTask.self, FocusSession.self], inMemory: true)
}
