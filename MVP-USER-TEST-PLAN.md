# Ember MVP user test plan

**Baseline:** `integration/mvp-flow` at `e912e43`. Record the actual commit tested. The automated checks and manual scenarios below cover Ember’s learning flow, from setting a goal to seeing saved activity in Analytics.

## Run the automated checks

Open `Ember.xcodeproj`, choose the **Ember** scheme and an **iPhone Simulator**, then press **⌘U**. The **Test navigator** shows results for `EmberTests` and `EmberUITests`. The UI tests use separate test data and reuse it when they relaunch the app to check persistence.

| Cases | Automated coverage |
| --- | --- |
| 01–02 | UI tests for first setup, adding a task, relaunching, and skipping setup before adding a goal later. |
| 03–04 | Integration tests for renaming and recategorizing goals, preserving their tasks, and saving checklist edits, progress, and deletions. |
| 05 | UI and integration tests for saving **Gentle** as **2/5** and reading it again after relaunch. |
| 06–07 | Focus timer pause and draft recovery checks. Use the manual steps for the physical-device checkpoint and the next-task selection after a finished session. |
| 08 | Integration test for saving a 5-to-2 reflection and reading the three-point drop in Analytics. Use the manual steps for the screen flow and the previous-day check-in. |
| 09 | Integration tests for empty periods and reporting from saved data, plus two documented outstanding issues in the Daily energy chart and Monthly heatmap. The Monthly level-1 rating regression is resolved. |
| 10 | The checklist UI test checks the completion control’s accessibility value. Try VoiceOver and larger text on a device or Simulator to check how the full flow feels. |

Xcode records the two remaining Analytics defects as **known issues**. They stay visible in the report while the rest of the suite runs. The Monthly level-1 rating issue was resolved by PR #29, so its assertion now runs as a normal regression test. When another issue is fixed, remove its `withKnownIssue` wrapper as well. Use the manual prompts to check discoverability and collect participant feedback.

## How to run a session

- Recruit by how people study. Look for someone new to learning apps, someone managing several subjects, someone studying in short bursts, and someone who uses VoiceOver or larger text. A participant can cover more than one scenario. Give them only the scenarios that fit their routine.
- Use an iPhone or iPhone Simulator with test data. Start with an empty app for cases 01 and 02. For the other cases, prepare the stated goals, tasks, and check-ins. Use a separate test install or simulator if you need fresh data.
- Read the **Prompt** first and let the participant try it unaided. Record their first tap, where they hesitated, and any help they needed. Use the **Tester steps** afterward if they get stuck or if you need to verify a specific outcome. At the end, ask what they would use again in a real study session and what would get in their way.
- Record **Pass**, **Fail**, or **Blocked** against the expected result. Separately record whether they finished **Unaided**, **With help**, or **Did not finish**. Log previously reported issues as failures if reproduced. Keep extra checks separate from the main result and record them only when run.

## 01. First-time learner sets up a goal

**Prompt:** “You want to learn basic Python. Set up Ember and give yourself one small thing to do first.”

**Tester steps:** On a fresh install, go to **Sessions → Start my learning setup**. Enter `Learn Python` as a custom goal, optionally pick a category, and tap **Add goal**. Continue through the energy and plan screens, then tap **Start Learning**. Open the goal, choose **Add a task**, enter `Learn variables`, and tap **Add task**. Tap **Done** to close the task editor.

**Pass if:** Sessions shows the custom goal, and opening it shows `Learn variables` as incomplete. The goal and task are still there after relaunch.

## 02. Undecided learner skips setup and returns later

**Prompt:** “You want to look around before deciding what to study. Explore the app, then come back and set a goal when you’re ready.”

**Tester steps:** On a fresh install, start learning setup and choose **I'll calibrate as I go (Skip)** on the goals step. Finish setup, open another tab, and return to **Sessions**. Use **Add learning topic** to add a goal.

**Pass if:** Skipping creates no default goal or task. Sessions offers a way to add a topic later, and the new goal appears after saving.

## 03. Learner juggling subjects reorganizes a goal

**Prompt:** “You’re learning Python and Spanish. Make the Python goal more specific without losing the work you planned.”

**Tester steps:** Prepare two goals, each with one task. In **Sessions**, use **Rename goal** on `Learn Python`. Rename it `Python basics`, choose a different category, and save. Open both goals and check their tasks.

**Pass if:** The updated name and category appear in Sessions. The Python task remains attached to `Python basics` with its original completion state. The Spanish goal and task retain their details.

## 04. Checklist user updates and tracks small tasks

**Prompt:** “Break your goal into two steps. Change one after you realize it’s too broad, then record your progress.”

**Tester steps:** Open a goal with an empty checklist. Add `Read chapter 1` and `Try one exercise`. Edit the first task to `Read pages 1–5` and add a note. Check it off and verify progress shows one of two complete. Expand **Done**, uncheck it, and verify progress returns to zero of two. Try deleting the exercise, cancel once, then repeat and confirm. Relaunch.

**Pass if:** The title and note save. The progress count follows each change, and the task moves between the open and completed lists. The exercise disappears only after confirmation. After relaunch, the edited task remains incomplete and the exercise is gone.

## 05. Busy learner logs a quick low-energy check-in

**Prompt:** “You’re tired and only have a minute. Record how you feel and find where Ember saved it.”

**Tester steps:** Start with no check-ins today, or with **Steady** selected. On **Today**, tap **Gentle**. Open **Profile**, then relaunch the app and check both screens again.

**Pass if:** Today confirms the save and highlights **Gentle**. Profile shows the latest rating as **2/5**. Both screens still reflect the check-in after relaunch on the same day.

## 06. Interrupted learner pauses and resumes focus

**Prompt:** “Start studying one task, pause when you’re interrupted, then finish. Check how much study time Ember recorded.”

**Tester steps:** Prepare two incomplete tasks, A and B. Use **Start focus → Start focusing** for A. Run for about 10 seconds, pause for 20 seconds, then resume for another 10 seconds and tap **Finish session**. On the summary, mark A complete and choose **Start another session**. With B as the only open task, tap **Start focusing** without tapping B first.

**Pass if:** A’s summary shows the correct task and about 20 seconds of focused time. The timer stays still during the pause. The next run starts B and A remains complete.

**Extra checkpoint check:** With the **20-min check-in** enabled, lock the test iPhone before minute 20 and reopen it after minute 20. At the checkpoint, the timer should be paused with roughly 20 minutes recorded. Use a physical device for this check and record the actual time shown.

## 07. Returning learner recovers an unfinished session

**Prompt:** “You closed Ember halfway through studying. Open it again and pick up where you stopped.”

**Tester steps:** Start focus on a test task and pause after at least 10 seconds. Note the displayed time, force-quit Ember, wait 15 seconds, and relaunch. In **Sessions**, find the recovery card and tap **Resume session**. Finish the session.

**Pass if:** The recovery card identifies the original task. The resumed timer starts from the saved focused time, excluding the time the app was closed. Finishing removes the recovery card and saves one completed session.

## 08. Reflective learner records a change in energy

**Prompt:** “You felt focused before studying and tired afterward. Record that change and find it in Ember.”

**Tester steps:** On **Today**, choose **High Focus** for a 5/5 check-in. Complete one focus session and choose **Reflect on your energy**. Verify the summary refers to the session you just finished. Choose a session-feel answer, set after-session energy to **2/5**, and tap **Save & Return**. Check **Analytics → Daily** after relaunch.

**Pass if:** Reflection shows **5/5** before and **2/5** after. With only this reflection today, Daily shows after-session energy of **2/5** and a drop of **3 points**, including after relaunch.

**Extra baseline check:** On a test install with only a previous-day check-in, finish a session and open Reflection. The learner should be able to enter or correct their before-session rating for today.

## 09. Progress-oriented learner checks that Analytics matches their activity

**Prompt:** “Check what Ember says you did this week and what it knows about your energy. Tell us what you think the chart is showing.”

**Tester steps:** On a clean test install, check **Analytics → Daily**, **Weekly**, and **Monthly** before logging activity. Then save one focus session with a **2/5** after-session reflection. In a different hour on the same day, complete one task without logging another reflection. Use daytime hours, such as 10 a.m. and 11 a.m., and start a few minutes before the hour if you need to run the checks close together. Return to Analytics and compare it with that written record.

**Pass if:** Empty periods show an empty state. Weekly counts one completed task and one session. Monthly shows an average of **2/5** from one reflection. In Daily, the task-only hour does not create an energy peak or rating.

**Extra heatmap checks:** The resolved level-1 regression is covered by an automated test: a day with one **1/5** reflection must display level 1. One known issue remains in this area: when the **Last 4 Weeks** grid includes days from the previous month, a reflection on one of those days should appear in its cell. Use existing dated test records or run across a month boundary.

## 10. Learner uses VoiceOver or larger text

**Prompt:** “Find a task, mark it complete, and log how you feel using your usual accessibility settings.”

**Tester steps:** Prepare one goal and one incomplete task. Run once with **VoiceOver**, then separately with an accessibility text size in **Settings → Accessibility → Display & Text Size → Larger Text**. In Ember, navigate to **Sessions**, open the goal, complete the task, and log a check-in on **Today**.

**Pass if:** VoiceOver announces the tab and task names, identifies controls, and conveys the task’s completion state after activation. At the larger text size, the task, check-in choices, and essential buttons remain readable and usable, including by scrolling when needed.

## Results log

Record the device, iOS version, commit, and date once per session. Use a participant ID and test data. Record any extra checks on a separate row.

| Case | Participant ID | Result | Assistance | Observed result or friction | Evidence / issue link |
| --- | --- | --- | --- | --- | --- |
|  |  | Pass / Fail / Blocked | Unaided / With help / Did not finish |  |  |

After testing, prioritize failures that block the main learning flow, lose saved work, or misreport time or energy. Group repeated usability problems by the step where participants got stuck.
