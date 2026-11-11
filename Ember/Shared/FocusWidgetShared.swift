import Foundation
import WidgetKit

// Suggested location: a new "Shared" group.
// IMPORTANT: tick BOTH targets (Ember and EmberWidgetExtension) in File Inspector > Target Membership.

/// What the Home Screen widget needs to know about the focus session.
struct FocusWidgetState: Codable, Equatable {
    static let kind = "EmberFocusWidget"

    enum Status: String, Codable {
        case idle, running, paused
    }

    var status: Status
    var taskTitle: String
    /// Running only: "now minus focused time so far". Because paused time is excluded from
    /// focused time, `Text(timerStartDate, style: .timer)` counts the right amount by itself.
    var timerStartDate: Date?
    /// Paused only: focused seconds so far, shown as static text.
    var pausedSeconds: Int

    static let idle = FocusWidgetState(status: .idle, taskTitle: "", timerStartDate: nil, pausedSeconds: 0)

    /// Sample data for the widget gallery and previews.
    static var preview: FocusWidgetState {
        FocusWidgetState(
            status: .running,
            taskTitle: "Network fundamentals",
            timerStartDate: Date.now.addingTimeInterval(-20 * 60),
            pausedSeconds: 0
        )
    }

    /// Same format as FocusSessionViewModel.format.
    static func format(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Reads and writes the state in the App Group, so the app and the widget see the same data.
enum FocusWidgetStore {
    /// Must match the App Group you add under Signing & Capabilities, on BOTH targets.
    static var debugInfo: String {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return "NO GROUP ACCESS"
        }
        return defaults?.data(forKey: key) == nil ? "Group OK, no data" : "Group OK, data found"
    }
    static let appGroupID = "group.au.edu.uts.ember"

    private static let key = "focus.widgetState"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func load() -> FocusWidgetState {
        guard let data = defaults?.data(forKey: key),
              let state = try? JSONDecoder().decode(FocusWidgetState.self, from: data) else {
            return .idle
        }
        return state
    }

    /// App only: saves the state and asks WidgetKit to redraw.
    static func save(_ state: FocusWidgetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        guard data != defaults?.data(forKey: key) else { return }
        defaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: FocusWidgetState.kind)
    }
}

/// Called by FocusSessionViewModel on start / pause / resume / finish / discard.
enum FocusWidgetBridge {
    static func publishRunning(taskTitle: String, focusedSeconds: TimeInterval) {
        FocusWidgetStore.save(FocusWidgetState(
            status: .running,
            taskTitle: taskTitle,
            timerStartDate: Date.now.addingTimeInterval(-focusedSeconds),
            pausedSeconds: 0
        ))
    }

    static func publishPaused(taskTitle: String, focusedSeconds: TimeInterval) {
        FocusWidgetStore.save(FocusWidgetState(
            status: .paused,
            taskTitle: taskTitle,
            timerStartDate: nil,
            pausedSeconds: max(0, Int(focusedSeconds))
        ))
    }

    static func clear() {
        FocusWidgetStore.save(.idle)
    }
}
