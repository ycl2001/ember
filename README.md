# Ember — native iOS starter (EMB-01 / EMB-02)


This is a **SwiftUI + SwiftData** Xcode project starter based on the uploaded 15-screen HTML prototype. It is a native app, **not** an HTML wrapper. It intentionally includes a working navigation shell and **four-tab application shell and feature placeholders** so that teammates can replace their own screens independently. The app is not the completed MVP. The SwiftUI views are deliberately placeholders, not finished functionality.

## Open and run in Xcode

1. Unzip the archive, then double-click `Ember.xcodeproj` (not individual Swift files).
2. Select scheme **Ember**, destination **an iOS 17 or newer iPhone Simulator**.
3. Press **⌘R**. You should see a dashboard titled *Small steps. Steady momentum.* and a persistent four-tab navigation bar (Today, Sessions, Analytics, Profile).
4. If you want to run on your **own iPhone**, open the project target → **Signing & Capabilities**, select your Team and change the bundle identifier to one available to you. Simulator builds typically do not need a signing team.
5. Commit this folder as the initial `main` baseline **before** teammates create branches.

**Verification disclaimer:** Swift source was syntax-parsed and the project file was structurally checked in a Linux environment. The iOS app cannot be compiled or launched here; run it in your Xcode simulator to confirm the actual iOS build.

## Architecture

- `App/`: SwiftUI app entry point and centralized route switch; dashboard lives in `Features/Dashboard/`.
- `Core/Models/`: common persistent `@Model` SwiftData types. One owner edits these.
- `DesignSystem/`: shared colour tokens and an interim placeholder component.
- `Features/`: each teammate owns `Views/` and `ViewModels/` under their feature. Replace placeholder bodies without renaming view types.
- `Assets.xcassets`: accent colour.

SwiftData `.modelContainer(for:)` lives in **EmberApp.swift** and is available to child views via the environment. Feature owners can use `@Environment(\.modelContext)` and `@Query` to read/write records.

### Shared model contract (freeze on Friday)

| Model | Fields | Used by |
|---|---|---|
| `LearningGoal` | `id`, `topic`, `createdAt` | Onboarding, Planner |
| `LearningTask` | `id`, `goalID`, `title`, `isCompleted`, `createdAt`, `completedAt` | Planner, Focus, Insights |
| `EnergyCheckIn` | `id`, `createdAt`, `level` (1–5) | Energy, Reflection, Insights |
| `FocusSession` | `id`, `taskID`, `startedAt`, `endedAt`, `durationSeconds` | Focus, Reflection, Insights |
| `SessionReflection` | `id`, `taskID`, `sessionID`, `energyBefore`, `energyAfter`, `notes`, `createdAt`; computed `energySpent` | Reflection, Insights |

**Important:** These are simple flat IDs instead of SwiftData model-to-model relationships to reduce integration risk within a one-week sprint. When adding a record, call `modelContext.insert(model)` and `try modelContext.save()`; feature owners should handle save errors. For task-level energy comparison, record an energy-before value at session start (or explicitly use the most recent daily check-in), then capture the energy-after value in reflection. A positive `energySpent` means lower self-reported energy after the activity.

## Branch/ownership matrix

| Member | Branch | Owns | First PR due |
|---|---|---|---|
| You — PM / Integration | `chore/project-foundation` | `App/*`, `Core/*`, `DesignSystem/*`, Xcode project and integration | Fri 6 Nov |
| Member 2 | `feat/onboarding-energy` | `Features/Onboarding/*`, `Features/Energy/*` | Mon 9 Nov |
| Member 3 | `feat/task-planner` | `Features/Planner/*` | Mon 9 Nov |
| Member 4 | `feat/focus-session` | `Features/Focus/*` | Mon 9 Nov |
| Member 5 | `feat/reflection-analytics` | `Features/Reflection/*`, `Features/Analytics/*` | Mon 9 Nov |

## GitHub repository and collaboration

**Repository:** https://github.com/ycl2001/ember (already created; inspected as empty on 6 November 2026).

Verify the app builds in Xcode, then upload this foundation as the first commit:

```bash
cd /path/to/Ember-Xcode-Starter
git init
git branch -M main
git add .
git commit -m "chore: initialise Ember SwiftUI foundation"
git remote add origin https://github.com/ycl2001/ember.git
git push -u origin main
```

If you have already cloned the repository, copy **the contents** of this folder into that clone instead of running `git init` again. Do not force-push or overwrite existing commits.

Each teammate then:

```bash
git clone https://github.com/ycl2001/ember.git
cd ember
git checkout -b feat/onboarding-energy   # replace with your own feature branch
# edit only the feature folder you own, commit and push
git push -u origin feat/onboarding-energy
```

Open GitHub pull requests into `main` and obtain at least one review. Keep changes to `RootView.swift`, `EmberApp.swift`, shared models and the Xcode project under the integration lead's ownership. For new Swift files, the integration lead adds them to the Xcode target (Xcode > Add Files to "Ember"); existing placeholder files are registered already.

## Sprint gates

- **6 Nov:** integration lead validates the app, pushes the foundation and freezes the shared model/route contract.
- **9 Nov:** first PR from all feature owners (screens may still be visually rough).
- **10 Nov evening:** freeze features, integrate core workflow.
- **11 Nov:** fix regressions, check SwiftData persistence after force quit/relaunch.
- **12 Nov:** run demo and submit.

## Demo acceptance flow

Create `Learn Python` → log energy 4/5 → check off `Learn variables` after a 10-minute focus session → reflect energy 2/5 → view a *self-reported* 2-point energy drop on Insights. Keep video discovery and AI generation out of the MVP until this works.


## Navigation-first foundation (6 November)

The initial developer-facing six-route menu has been replaced with the mobile prototype's four primary tabs. The tab bar is `DesignSystem/EmberTabBar.swift`, the tab metadata is `App/AppTab.swift`, and app-level navigation is `App/AppNavigation.swift` + `RootView.swift`. The real Today screen is now the Dashboard feature, and a new Profile feature exists. Sessions and Analytics have stable native content shells, not six debugging links.

**Feature developers:** Don't modify `App/`, `DesignSystem/EmberTabBar.swift`, or the selected tab routes. To trigger a detail flow from your view, use the existing `onNavigate` callback if present (for example, `onNavigate(.focus)` in `TaskPlannerView`). There is no production service wiring in these shells yet.

Apply the included `Ember-Navigation-MVVM.patch` on top of `chore/mvvm-architecture`, not the old `main` starter. Build in Xcode before merging.
