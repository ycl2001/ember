import Foundation
import Observation

/// Integration-owned navigation state. Feature screens should not own global tab selection.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .today
    var path: [AppRoute] = []
    var analyticsPeriod: AnalyticsViewModel.Period = .weekly

    /// The learning goal shown by `AppRoute.goalDetail`.
    var selectedGoalID: UUID?
    /// A task chosen before opening Focus. `FocusSessionView` reads it once, then clears it.
    var pendingFocusTaskID: UUID?
    /// The exact completed session Reflection should load.
    var pendingReflectionSessionID: UUID?

    func select(_ tab: AppTab) {
        path.removeAll()
        selectedTab = tab
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func popToTab(_ tab: AppTab) {
        select(tab)
    }

    /// Opens a learning goal's checklist.
    func openGoal(_ goalID: UUID) {
        selectedGoalID = goalID
        push(.goalDetail)
    }

    /// Opens Focus with `taskID` already chosen (pass nil to let the learner pick).
    func startFocus(taskID: UUID?) {
        pendingFocusTaskID = taskID
        push(.focus)
    }

    /// Opens Reflection for the completed session that was just persisted.
    func openReflection(sessionID: UUID) {
        pendingReflectionSessionID = sessionID
        push(.reflection)
    }

    /// Routes the two URLs exposed by Ember's widgets. Assigning the complete path keeps
    /// repeated taps idempotent for cold, background, and already-running launches.
    @discardableResult
    func handleWidgetURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "ember" else { return false }

        switch (url.host?.lowercased(), url.pathComponents.filter { $0 != "/" }) {
        case ("focus", []):
            pendingFocusTaskID = nil
            path = [.focus]
            return true
        case ("analytics", ["monthly"]):
            analyticsPeriod = .monthly
            select(.analytics)
            return true
        default:
            return false
        }
    }
}
