import Foundation
import Observation

/// Integration-owned navigation state. Feature screens should not own global tab selection.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .today
    var path: [AppRoute] = []

    /// The learning goal shown by `AppRoute.goalDetail`.
    var selectedGoalID: UUID?
    /// A task chosen before opening Focus. `FocusSessionView` reads it once, then clears it.
    var pendingFocusTaskID: UUID?

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
}
