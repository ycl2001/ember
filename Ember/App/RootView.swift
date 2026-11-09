import SwiftUI

/// The actual app shell: four bottom tabs with detail flows pushed above them.
/// Feature developers own the contents of the destination views, not this router.
struct RootView: View {
    @State private var navigation = AppNavigation()

    var body: some View {
        NavigationStack(path: $navigation.path) {
            rootPage
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    EmberTabBar(selected: navigation.selectedTab) { tab in
                        navigation.select(tab)
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                        .toolbar(route == .onboarding ? .hidden : .visible, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(navigation)
        .tint(EmberTheme.primary)
    }

    @ViewBuilder
    private var rootPage: some View {
        switch navigation.selectedTab {
        case .today:
            DashboardView(
                onNavigate: { navigation.push($0) },
                onSelectTab: { navigation.select($0) }
            )
        case .sessions:
            TaskPlannerView(onNavigate: { navigation.push($0) })
        case .analytics:
            AnalyticsView()
        case .profile:
            ProfileView(onNavigate: { navigation.push($0) })
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .onboarding:
            OnboardingView()
        case .energyCheckIn:
            EnergyCheckInView()
        case .planner:
            TaskPlannerView(onNavigate: { navigation.push($0) })
        case .focus:
            FocusSessionView()
        case .reflection:
            ReflectionView()
        case .analytics:
            AnalyticsView()
        }
    }
}
