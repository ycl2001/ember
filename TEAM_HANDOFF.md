# Team kickoff: Friday 6 November 2026

The HTML is a visual and interaction reference, not the iOS implementation.

## Final MVP

1. New learner creates a learning topic.
2. Learner logs daily energy (1–5).
3. Learner creates or checks off learning tasks.
4. Learner starts, pauses and completes a timed focus session.
5. Learner logs after-session energy (1–5).
6. Insights use *actual saved records* to show learning completion and energy change.

## Acceptance criteria by owner

- **Member 2 (Onboarding / Energy):** non-empty learning topic saved; energy 1–5 check-in saved with date; relaunch retains records.
- **Member 3 (Checklist):** add/edit/remove task associated to goal; check/uncheck; completed count correct; relaunch retains state.
- **Member 4 (Focus):** timer starts, pauses, resumes and finishes; duration excludes paused time; linked task ID; 20-minute prompt optional only if time permits.
- **Member 5 (Reflection / Insights):** submit before/after energy and optional notes for a task/session; charts derive from persisted records; empty state shown when no data.
- **You (Foundation / Integration):** app launches, all screens routed, records share the same model types, PR review, full walkthrough, no crash on relaunch.

## Strict integration rules

- Discuss changing any file in `Core/Models/` with PM before coding; merge the contract change before dependent PRs.
- Do not rename `OnboardingView`, `EnergyCheckInView`, `TaskPlannerView`, `FocusSessionView`, `ReflectionView`, or `AnalyticsView`.
- One branch per feature owner. Avoid editing shared Xcode project unless assigned.
- Open draft PRs early, merge small verified changes, add simulator screenshots and a short test checklist.
- If behind schedule, cut advanced pacing logic and visual polish before compromising basic storage and full journey.

## First kickoff message to team

> The Ember SwiftUI foundation is in https://github.com/ycl2001/ember. Please branch from `main`, keep changes inside your assigned `Features/` folder, and use the shared SwiftData models as agreed. First PRs are due Monday 9 Nov; feature freeze Tuesday evening, regression Wednesday, final build Thursday 12 Nov. Please flag any model or route change before modifying the shared files.


## Navigation-first change (6 Nov)

The original prototype has **four tabs: Today, Sessions, Analytics, Profile**. Do not recreate the previous six-route debugging dashboard. Each team member builds within their existing feature's `Views/` and `ViewModels/`; routes and the shared bottom bar are frozen under PM/integration ownership. See `NAVIGATION.md`.
