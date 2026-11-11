import SwiftUI

/// The actual app shell: four bottom tabs with detail flows pushed above them.
/// Feature developers own the contents of the destination views, not this router.
struct RootView: View {
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @State private var navigation: AppNavigation
    @State private var monthlyReportRequest: UUID?

    init() {
        let navigation = AppNavigation()
        if !UserDefaults.standard.bool(forKey: OnboardingStorage.completedKey) {
            navigation.selectedTab = .sessions
        }
        _navigation = State(initialValue: navigation)
    }

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
        .modifier(MonthlyEnergyWidgetSync())
        .onOpenURL(perform: openWidgetReport)
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
            AnalyticsView(initialPeriod: monthlyReportRequest == nil ? .weekly : .monthly)
                .id(monthlyReportRequest)
        case .profile:
            ProfileView(onNavigate: { navigation.push($0) })
        }
    }

    private func openWidgetReport(_ url: URL) {
        guard url == MonthlyEnergyWidgetData.reportURL else { return }
        monthlyReportRequest = UUID()
        navigation.select(.analytics)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .onboarding:
            OnboardingView(onFinish: completeOnboarding)
        case .energyCheckIn:
            EnergyCheckInView()
        case .planner:
            TaskPlannerView(onNavigate: { navigation.push($0) })
        case .goalDetail:
            LearningGoalDetailView(goalID: navigation.selectedGoalID)
        case .focus:
            FocusSessionView()
        case .reflection:
            ReflectionView(
                sessionID: navigation.pendingReflectionSessionID,
                onSaveReturn: { finishReflection(on: .today) },
                onRestorativeBreak: { finishReflection(on: .sessions) },
                onContinueLearning: { finishReflection(on: .sessions) }
            )
        case .analytics:
            AnalyticsView()
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        navigation.selectedTab = .sessions
    }

    private func finishReflection(on tab: AppTab) {
        navigation.pendingReflectionSessionID = nil
        navigation.popToTab(tab)
    }
}
