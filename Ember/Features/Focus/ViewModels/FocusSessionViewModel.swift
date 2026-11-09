import Foundation
import Observation
import SwiftData

/// Member 4: focus timer state machine.
///
/// Elapsed time is derived from `Date` stamps rather than counted ticks, so the timer
/// stays correct when the app is backgrounded or the device is locked. Paused time is
/// never counted. The 1-second ticker only refreshes the on-screen value.
@MainActor
@Observable
final class FocusSessionViewModel {
    enum Phase: Equatable {
        case setup
        case running
        case paused
        case finished
    }

    /// Length of the optional pacing checkpoint (20 minutes).
    static let milestoneSeconds = 20 * 60

    // MARK: - Public state

    private(set) var phase: Phase = .setup
    private(set) var elapsedSeconds = 0

    var selectedTaskID: UUID?
    /// Title captured at start so the summary still has it if the task changes later.
    private(set) var activeTaskTitle = ""

    var milestoneReminderEnabled = true
    var showMilestoneSheet = false
    private(set) var hasReachedMilestone = false

    private(set) var savedSession: FocusSession?
    var errorMessage: String?

    var isRunning: Bool { phase == .running }
    var isActive: Bool { phase == .running || phase == .paused }
    var canFinish: Bool { isActive && elapsedSeconds > 0 }

    var formattedElapsedTime: String {
        Self.format(elapsedSeconds)
    }

    /// Progress around the ring: fills toward the 20-min milestone, then loops each 20 minutes.
    var ringProgress: Double {
        guard elapsedSeconds > 0 else { return 0 }
        let lap = elapsedSeconds % Self.milestoneSeconds
        if lap == 0 { return 1 }
        return Double(lap) / Double(Self.milestoneSeconds)
    }

    var focusedMinutesText: String {
        let minutes = elapsedSeconds / 60
        return minutes < 1 ? "<1m" : "\(minutes)m"
    }

    var milestoneStatusText: String {
        if hasReachedMilestone { return "Checkpoint reached. Keep a steady pace." }
        let remaining = max(0, Self.milestoneSeconds - elapsedSeconds)
        // Whole minutes only, so this line doesn't tick every second.
        let minutes = max(1, Int((Double(remaining) / 60).rounded(.up)))
        return "Check-in in \(minutes) min"
    }

    // MARK: - Ember visuals

    /// Seconds per ember dot under the timer.
    static let emberDotInterval = 5 * 60
    static let emberDotCount = milestoneSeconds / emberDotInterval

    /// How many of the ember dots are lit (one per 5 focused minutes, capped at 4).
    var litEmberDots: Int {
        min(Self.emberDotCount, elapsedSeconds / Self.emberDotInterval)
    }

    /// 0 → 1 over the first 20 minutes; drives the flame's mint-to-amber warmth.
    var emberWarmth: Double {
        min(1, Double(elapsedSeconds) / Double(Self.milestoneSeconds))
    }

    // MARK: - Private timing

    private var sessionStartedAt: Date?
    private var segmentStartedAt: Date?
    private var accumulatedSeconds: TimeInterval = 0
    private var ticker: Task<Void, Never>?

    // MARK: - Setup

    /// True when the task arrived pre-chosen (from a goal's checklist or "Up next").
    /// The setup screen then shows just that task, with a "Change task" option.
    var isTaskPreselected = false

    /// Applies a task chosen before Focus opened. Ignored once a session has started.
    func preselect(taskID: UUID, from tasks: [LearningTask]) {
        guard phase == .setup, tasks.contains(where: { $0.id == taskID }) else { return }
        selectedTaskID = taskID
        isTaskPreselected = true
    }

    /// Shows the full task list again.
    func changeTask() {
        isTaskPreselected = false
    }

    /// Keeps the selection valid: picks the first incomplete task when nothing valid is selected.
    func ensureSelection(from tasks: [LearningTask]) {
        guard phase == .setup else { return }
        if let id = selectedTaskID, tasks.contains(where: { $0.id == id }) { return }
        selectedTaskID = tasks.first?.id
        isTaskPreselected = false
    }

    // MARK: - Timer controls

    func start(task: LearningTask) {
        guard phase == .setup else { return }
        selectedTaskID = task.id
        activeTaskTitle = task.title
        sessionStartedAt = .now
        segmentStartedAt = .now
        accumulatedSeconds = 0
        elapsedSeconds = 0
        hasReachedMilestone = false
        savedSession = nil
        errorMessage = nil
        phase = .running
        startTicker()
    }

    func pause() {
        guard phase == .running else { return }
        if let segmentStartedAt {
            accumulatedSeconds += Date.now.timeIntervalSince(segmentStartedAt)
        }
        segmentStartedAt = nil
        stopTicker()
        phase = .paused
        refresh()
    }

    func resume() {
        guard phase == .paused else { return }
        segmentStartedAt = .now
        phase = .running
        startTicker()
    }

    func togglePause() {
        isRunning ? pause() : resume()
    }

    /// Recomputes elapsed time from the stored dates. Call on each tick and when the app
    /// returns to the foreground.
    func refresh() {
        var total = accumulatedSeconds
        if let segmentStartedAt {
            total += Date.now.timeIntervalSince(segmentStartedAt)
        }
        elapsedSeconds = max(0, Int(total))

        if milestoneReminderEnabled,
           !hasReachedMilestone,
           phase == .running,
           elapsedSeconds >= Self.milestoneSeconds {
            hasReachedMilestone = true
            pause()
            showMilestoneSheet = true
        }
    }

    // MARK: - Milestone sheet actions

    func takeBreak() {
        // Timer is already paused by the milestone; leave it paused during the break.
        showMilestoneSheet = false
    }

    func keepGoing() {
        showMilestoneSheet = false
        resume()
    }

    // MARK: - Finish / discard

    /// Stops the timer and persists a `FocusSession`. Duration excludes paused time.
    func finish(in context: ModelContext) {
        guard isActive, let taskID = selectedTaskID, let startedAt = sessionStartedAt else { return }
        if phase == .running { pause() }
        refresh()
        showMilestoneSheet = false

        let session = FocusSession(
            taskID: taskID,
            startedAt: startedAt,
            endedAt: .now,
            durationSeconds: elapsedSeconds
        )
        context.insert(session)
        do {
            try context.save()
            savedSession = session
            phase = .finished
        } catch {
            context.delete(session)
            errorMessage = "Couldn't save this session. Try again."
        }
    }

    /// Throws away the current run without saving anything.
    func discard() {
        stopTicker()
        resetTiming()
        showMilestoneSheet = false
        phase = .setup
    }

    /// Returns to the setup screen after a finished session.
    func startAnother() {
        stopTicker()
        resetTiming()
        savedSession = nil
        errorMessage = nil
        phase = .setup
    }

    // MARK: - Task completion

    func setTask(_ task: LearningTask, completed: Bool, in context: ModelContext) {
        task.isCompleted = completed
        task.completedAt = completed ? .now : nil
        do {
            try context.save()
        } catch {
            errorMessage = "Couldn't update the task. Try again."
        }
    }

    // MARK: - Helpers

    private func resetTiming() {
        sessionStartedAt = nil
        segmentStartedAt = nil
        accumulatedSeconds = 0
        elapsedSeconds = 0
        hasReachedMilestone = false
    }

    private func startTicker() {
        stopTicker()
        refresh()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
