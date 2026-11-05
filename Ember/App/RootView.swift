import SwiftUI

/// Single integration point for feature routes.
/// Feature owners replace their own placeholder views in Features/*.
struct RootView: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            DashboardView { route in
                path.append(route)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .onboarding: OnboardingView()
                case .energyCheckIn: EnergyCheckInView()
                case .planner: TaskPlannerView()
                case .focus: FocusSessionView()
                case .reflection: ReflectionView()
                case .analytics: AnalyticsView()
                }
            }
        }
        .tint(EmberTheme.primary)
    }
}
