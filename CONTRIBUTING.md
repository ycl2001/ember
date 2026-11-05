# Contributing to Ember (6–12 November 2026)

Five-person Xcode sprint. Do not start your feature until `main` contains the validated iOS foundation.

## Assignments

- **Integration lead:** `App/`, `Core/Models/`, `DesignSystem/`, `.xcodeproj`, and PR integration.
- **Member 2:** `Features/Onboarding/`, `Features/Energy/` — `feat/onboarding-energy`.
- **Member 3:** `Features/Planner/` — `feat/task-planner`.
- **Member 4:** `Features/Focus/` — `feat/focus-session`.
- **Member 5:** `Features/Reflection/`, `Features/Analytics/` — `feat/reflection-analytics`.

## Working agreements

1. Discuss changes to models and navigation with the integration lead before modifying shared files.
2. Keep each PR small; include a screenshot, tested flows, and any persistence limitations.
3. Use local SwiftData for MVP. No authentication, cloud storage, or AI integration required.
4. First feature PRs by Monday 9 Nov; feature freeze Tuesday 10 Nov evening.
5. Wednesday 11 Nov is reserved for integration, Xcode simulator testing, and fixes. Final deadline Thursday 12 Nov.
6. Do not push directly to `main` after the initial validated foundation.

## MVP acceptance journey

Enter a learning topic → save daily energy (1–5) → create/complete a task → use focus timer → reflect on energy → see real saved data in Insights. All stored data should survive app relaunch.
