# Ember navigation contract — freeze before parallel feature work

Source: Midnight Momentum Ver3 testing HTML, rebranded to Ember.

## Four persistent bottom tabs

| Tab | Root SwiftUI view | Navigation behaviour | Owner |
| --- | --- | --- | --- |
| Today | `DashboardView` | Energy check-in and learning goals are pushed; tap "See tasks" to switch to Sessions | PM / Integration |
| Sessions | `TaskPlannerView` | Start a focus session as a detail flow; allow navigation to onboarding | Member 3 |
| Analytics | `AnalyticsView` | Daily/weekly/monthly analytics will live inside this tab | Member 5 |
| Profile | `ProfileView` | Learning preferences, links to goals and energy check-ins | PM / Integration |

Onboarding/energy check-in/focus/reflection are **not** bottom tabs. The original HTML contains 15 prototype screens, grouped as Journey, Onboarding, Learning, Insights and Settings. The outer desktop walkthrough is not the mobile navigation pattern.

## Navigation code contract

- `AppTab` describes the four persistent tabs and icons.
- `AppNavigation` owns `selectedTab` and `path` and exposes `select`/`push`.
- `RootView` switches the tab-root views and maps existing `AppRoute` detail destinations.
- `EmberTabBar` is shared chrome: change it only after agreement with integration lead.
- `DashboardView` is the Today tab. Do not recreate a developer route menu.
- Feature developers must keep initial View type names. If adding a new screen, coordinate its route and Xcode project file entry.
- No API, cloud, AI, or video player is connected. Any charts must derive from persisted data, not sample text.

## Visual acceptance checklist

- Launch shows **Today** with energy and momentum cards, not developer navigation rows.
- Bottom tabs read **Today · Sessions · Analytics · Profile**.
- Switching tabs updates the highlighted destination without stacking multiple copies of a page.
- Today > Check in now opens the energy-check-in view; back returns to Today.
- Today > See tasks switches to the Sessions tab.
- Profile > Learning goals opens onboarding; back returns to Profile.
- Detail flows do not contain a duplicate bottom tab bar.
- App still compiles under SwiftUI + SwiftData on iOS 17+.

This is the navigation/screen-layout foundation. Feature implementation still belongs to each owner.
