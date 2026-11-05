# Ember architecture — feature-first MVVM

## Structure and naming

- **Model:** `Ember/Core/Models/*.swift` holds shared `@Model` SwiftData entities. There is exactly **one** persistent definition per domain entity.
- **View:** `Ember/Features/<Feature>/Views/<FeatureName>View.swift` is the SwiftUI screen.
- **ViewModel:** `Ember/Features/<Feature>/ViewModels/<FeatureName>ViewModel.swift` owns presentation state, validation and interactions. All feature ViewModels use `@MainActor @Observable` (iOS 17+).
- **App:** `Ember/App/` contains the app entry point, shared route enum, and navigation root. It is integration-lead-owned.
- **DesignSystem:** `Ember/DesignSystem/` holds reusable style tokens and components.

Only add `Features/<Feature>/Models/` for feature-private DTOs or non-persisted models if truly necessary. **Do not copy or re-declare** `LearningTask`, `EnergyCheckIn`, etc. inside features.

## Ownership (five people total)

| Owner | Folders | Branch |
| --- | --- | --- |
| You, PM + Integration | `App/`, `Core/Models/`, `DesignSystem/`, `Features/Dashboard/`, `.xcodeproj` | `chore/mvvm-architecture` |
| Member 2 | `Features/Onboarding/`, `Features/Energy/` | `feat/onboarding-energy` |
| Member 3 | `Features/Planner/` | `feat/task-planner` |
| Member 4 | `Features/Focus/` | `feat/focus-session` |
| Member 5 | `Features/Reflection/`, `Features/Analytics/` | `feat/reflection-analytics` |

## Responsibilities

- **Model:** represents persistent data and domain constraints; `@Model` classes are shared. Maintain original property names to avoid breaking feature PRs.
- **View:** renders UI and binds to ViewModel state; avoid persistence rules and business calculations in `body`.
- **ViewModel:** validates input, calculates progress/energy deltas, manages screen state, invokes persistence services. For this sprint, SwiftData reads may stay as `@Query` on Views, then pass the fetched objects to ViewModels for derived summaries. Do not put `@Query` inside an `@Observable` ViewModel.
- **Integration lead:** owns `RootView.swift`, shared models, project file, SwiftData container, and architectural changes.

## Example pattern

```swift
import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack {
            TextField("Learning topic", text: $viewModel.topic)
            Button("Continue") {
                // Have the ViewModel create a LearningGoal via an injected repository
                // or a clearly defined save method, then handle navigation.
            }
            .disabled(!viewModel.canCreateGoal)
        }
    }
}
```

## Model contracts frozen for sprint

`LearningGoal`, `LearningTask`, `EnergyCheckIn`, `FocusSession`, `SessionReflection` live only in `Core/Models`. The target remains iOS 17+ with SwiftUI and SwiftData. The prototype screens remain placeholder views; these scaffolding changes do not implement feature behaviour or perform a simulator build.

## Integration order

1. Merge `chore/mvvm-architecture` into `main` first; tell teammates to rebase their feature branches onto updated `main`.
2. Member 2/3/4/5 implement in their own `Views/` and `ViewModels/` files.
3. PRs must include a simulator build status, test/acceptance checklist, and any request to change `Core/Models`.
4. Freeze feature work Tuesday 10 Nov; integration and regression Wednesday 11 Nov; demo Thursday 12 Nov.
