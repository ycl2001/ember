# Ember — teammate Analytics layout reference (not build sources)

Source: user-supplied `Emberv2.zip`. Extracted without changing the original Swift files.
Target branch: `feat/analytics-layout-sync` created from `origin/integration/mvp-flow`.

## Contents

- `Views/DailyAnalysisView.swift`: teammate's Daily cards, Bio-Windows, Friction and Study Environment concept.
- `Views/WeeklyAnalysisView.swift`: teammate's chart styling, peak-day visual treatment, featured insight and suggestion cards.
- `Views/MonthlyAnalysisView.swift`: teammate's Monthly cards, cadence banner, spot matrix, synthesis.
- `SupportingModels/{DailyAnalysis,WeeklyAnalysis,MonthlyAnalysis}.swift`: original data structures included **for reference only** to understand view interfaces; do not register these in the Ember target.

## Integration rules

1. These files intentionally live under `docs/analytics-layout-reference/` and are **not intended to compile** in the app. Do not drag this folder into Ember's Xcode target.
2. Maintain the real `Ember/Features/Analytics/Views/{DailyAnalysisView,WeeklyAnalysisView,MonthlyAnalysisView}.swift` and current `AnalyticsViewModel.swift` as the starting point. Apply selected presentation ideas incrementally.
3. Keep `SessionReflection`, existing `LearningTask`, `FocusSession` and current `AnalyticsViewModel` APIs. Do not restore `EnergyRecord` or placeholders that return `nil`.
4. Preserve empty and insufficient-data states; never show sample-derived or fabricated insights as observed data.
5. In the teammate's Weekly view, the 34% improvement and `CS240` Wednesday 9 AM suggestion are hardcoded illustrative claims. **Do not copy them into production UI**. Likewise, Daily Study Environment content is static, not observed.
6. The original views reference `analysis.isSample`, while the current integrated models use `analysis.state`. The Weekly view expects `[EnergyRecord]`, but the integrated app uses `[SessionReflection]`. Direct replacement will not compile.
7. Monthly's main composition is similar to integration; prioritize Daily/Weekly styling.
8. Avoid replacing the whole `Ember.xcodeproj/project.pbxproj`, renaming files into duplicate app targets, or touching signing.

## Suggested sequence

1. Audit the Daily hero/window/energy card styling and port only what can be grounded in `DailyAnalysis`.
2. Audit Weekly chart gradients/peak-day styling, adapting the integrated `[SessionReflection]`-based chart and pattern computations.
3. Compare Monthly typography/cadence, and only port genuine visual improvements.
4. Compile and test each tab, dark mode, 44-point touch targets, empty-state and real-data states.
5. Open a **draft PR** against `integration/mvp-flow` when the implemented changes have been validated.

## Initial safe import on a Mac

Run in your existing Ember repository only when `git status --porcelain` is empty:

```bash
git fetch origin
git switch -c feat/analytics-layout-sync origin/integration/mvp-flow
unzip -o ~/Downloads/ember-analytics-layout-reference.zip -d .
git add docs/analytics-layout-reference
git commit -m "chore: add teammate analytics layout references"
git push -u origin feat/analytics-layout-sync
```

This first commit adds **reference files only**, so Ember app behavior remains unchanged. After that, modify real Analytics views in the same branch to port design changes.
