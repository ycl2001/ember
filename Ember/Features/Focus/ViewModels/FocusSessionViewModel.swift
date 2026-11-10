import Foundation
import Observation
import SwiftData
import UserNotifications

/// A focus session that was still running or paused when the app closed.
/// Kept on the device only (not in SwiftData), so Analytics never sees half-finished sessions.
struct FocusSessionDraft: Codable, Equatable {
    var taskID: UUID
    var taskTitle: String
    var startedAt: Date
    /// Focused time up to `savedAt`, excluding paused time.
    var focusedSeconds: TimeInterval
    var hasReachedMilestone: Bool
    var milestoneReminderEnabled: Bool
    var savedAt: Date
}

/// Reads and writes the single in-progress `FocusSessionDraft` in UserDefaults.
enum FocusDraftStore {
    private static let key = "focus.inProgressSession"

    static func load() -> FocusSessionDraft? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FocusSessionDraft.self, from: data)
    }

    static func save(_ draft: FocusSessionDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

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

    /// Sends a notification at the 20-min milestone if the phone is locked or the app is
    /// in the background. Remembered between launches.
    private(set) var lockReminderEnabled = UserDefaults.standard.bool(forKey: FocusSessionViewModel.lockReminderKey) {
        didSet { UserDefaults.standard.set(lockReminderEnabled, forKey: Self.lockReminderKey) }
    }
    /// Shown under the reminder toggle when notifications are turned off for Ember.
    private(set) var reminderNotice: String?

    /// A session left unfinished when the app closed, waiting for Resume / Save / Discard.
    private(set) var unfinishedDraft: FocusSessionDraft?

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

    private static let lockReminderKey = "focus.lockReminderEnabled"
    private static let milestoneNotificationID = "ember.focus.milestone"
    /// How often (in seconds) a running session is snapshotted to the device.
    private static let draftSaveInterval = 15

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
        saveDraft()
        scheduleMilestoneReminder()
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
        saveDraft()
        cancelMilestoneReminder()
    }

    func resume() {
        guard phase == .paused else { return }
        segmentStartedAt = .now
        phase = .running
        startTicker()
        saveDraft()
        scheduleMilestoneReminder()
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
            FocusDraftStore.clear()
            cancelMilestoneReminder()
        } catch {
            context.delete(session)
            errorMessage = "Couldn't save this session. Try again."
        }
    }

    /// Throws away the current run without saving anything.
    func discard() {
        stopTicker()
        cancelMilestoneReminder()
        FocusDraftStore.clear()
        resetTiming()
        showMilestoneSheet = false
        phase = .setup
    }

    /// Returns to the setup screen after a finished session.
    func startAnother() {
        stopTicker()
        cancelMilestoneReminder()
        FocusDraftStore.clear()
        resetTiming()
        savedSession = nil
        errorMessage = nil
        phase = .setup
    }

    // MARK: - Unfinished session (app was closed mid-session)

    /// Looks for a session left unfinished last time. Drops it if its task no longer exists.
    func checkForUnfinishedSession(tasks: [LearningTask]) {
        guard phase == .setup else { return }
        guard let draft = FocusDraftStore.load() else {
            unfinishedDraft = nil
            return
        }
        // The session isn't running while it waits for a choice, so no reminder should fire.
        cancelMilestoneReminder()
        if tasks.contains(where: { $0.id == draft.taskID }) {
            unfinishedDraft = draft
        } else {
            FocusDraftStore.clear()
            unfinishedDraft = nil
        }
    }

    /// Continues the unfinished session. Time while the app was closed isn't counted.
    func resumeUnfinished() {
        guard phase == .setup, let draft = unfinishedDraft else { return }
        selectedTaskID = draft.taskID
        activeTaskTitle = draft.taskTitle
        sessionStartedAt = draft.startedAt
        accumulatedSeconds = draft.focusedSeconds
        segmentStartedAt = nil
        hasReachedMilestone = draft.hasReachedMilestone
        milestoneReminderEnabled = draft.milestoneReminderEnabled
        savedSession = nil
        errorMessage = nil
        unfinishedDraft = nil
        isTaskPreselected = false
        phase = .paused
        refresh()
        resume()
    }

    /// Saves the unfinished session as it was when the app closed, then shows the summary.
    func finishUnfinished(in context: ModelContext) {
        guard phase == .setup, let draft = unfinishedDraft else { return }
        let duration = max(0, Int(draft.focusedSeconds))
        let session = FocusSession(
            taskID: draft.taskID,
            startedAt: draft.startedAt,
            endedAt: draft.savedAt,
            durationSeconds: duration
        )
        context.insert(session)
        do {
            try context.save()
            cancelMilestoneReminder()
            FocusDraftStore.clear()
            unfinishedDraft = nil
            selectedTaskID = draft.taskID
            activeTaskTitle = draft.taskTitle
            elapsedSeconds = duration
            hasReachedMilestone = draft.hasReachedMilestone
            savedSession = session
            errorMessage = nil
            phase = .finished
        } catch {
            context.delete(session)
            errorMessage = "Couldn't save this session. Try again."
        }
    }

    func discardUnfinished() {
        cancelMilestoneReminder()
        FocusDraftStore.clear()
        unfinishedDraft = nil
    }

    /// Call when the app goes to the background, so the latest focused time is kept.
    func appWillLeaveForeground() {
        saveDraft()
    }

    private func saveDraft() {
        guard isActive, let taskID = selectedTaskID, let startedAt = sessionStartedAt else { return }
        var focused = accumulatedSeconds
        if let segmentStartedAt {
            focused += Date.now.timeIntervalSince(segmentStartedAt)
        }
        FocusDraftStore.save(FocusSessionDraft(
            taskID: taskID,
            taskTitle: activeTaskTitle,
            startedAt: startedAt,
            focusedSeconds: focused,
            hasReachedMilestone: hasReachedMilestone,
            milestoneReminderEnabled: milestoneReminderEnabled,
            savedAt: .now
        ))
    }

    // MARK: - Lock-screen milestone reminder

    /// Turns the lock-screen reminder on or off. Asks for notification permission the first time.
    func setLockReminder(_ enabled: Bool) async {
        reminderNotice = nil
        guard enabled else {
            lockReminderEnabled = false
            cancelMilestoneReminder()
            return
        }
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert])) ?? false
        lockReminderEnabled = granted
        if granted {
            scheduleMilestoneReminder()
        } else {
            reminderNotice = "Notifications are off for Ember. Turn them on in Settings to use this."
        }
    }

    /// Turns the reminder off if notifications were disabled in iPhone Settings since it was enabled.
    /// Call when Focus opens and whenever the app comes back to the foreground.
    func refreshReminderPermission() async {
        guard lockReminderEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        default:
            lockReminderEnabled = false
            cancelMilestoneReminder()
            reminderNotice = "Notifications are off for Ember. Turn them on in Settings to use this."
        }
    }

    /// Schedules one quiet notification for the moment focused time reaches 20 minutes.
    /// Rescheduled on every resume, so it follows focused time rather than clock time.
    private func scheduleMilestoneReminder() {
        cancelMilestoneReminder()
        guard lockReminderEnabled, milestoneReminderEnabled, phase == .running, !hasReachedMilestone else { return }

        var focused = accumulatedSeconds
        if let segmentStartedAt {
            focused += Date.now.timeIntervalSince(segmentStartedAt)
        }
        let remaining = Double(Self.milestoneSeconds) - focused
        guard remaining > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "20 minutes of focus"
        content.body = activeTaskTitle.isEmpty
            ? "Time for a gentle pacing check in Ember."
            : "Time for a gentle pacing check on “\(activeTaskTitle)”."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: Self.milestoneNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func cancelMilestoneReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.milestoneNotificationID])
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
            var ticks = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refresh()
                ticks += 1
                // Snapshot now and then, in case the app is closed without warning.
                if ticks % Self.draftSaveInterval == 0 {
                    self?.saveDraft()
                }
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
