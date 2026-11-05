import Foundation
import Observation

/// Integration-owned navigation state. Feature screens should not own global tab selection.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .today
    var path: [AppRoute] = []

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
}
