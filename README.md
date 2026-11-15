# EmberAssist 🔥
### Learn with your energy, not against it.

**Ember** is a native iOS learning-energy app designed to help learners turn ambitious goals into manageable steps, check in with their energy, and reflect on what helps them make progress.

Instead of assuming every day is equally productive, Ember brings **learning goals, daily energy, focus sessions and reflection** into one calm workflow.

> Built for the **2026 Apple Foundation Program** · SwiftUI · SwiftData · WidgetKit · Apple Foundation Models

## ✨ Features

| Experience | What it helps you do |
| --- | --- |
| **Learning setup** | Define learning goals and preferences through guided onboarding. |
| **Today** | Record your energy check-in and choose a suitable learning pace. |
| **Sessions & checklists** | Break goals into smaller tasks, add notes and track completion. |
| **Focus sessions** | Focus on one task, pause or resume, and save progress. |
| **Reflection** | Record how a learning session affected your self-reported energy. |
| **Analytics** | Explore daily, weekly and monthly learning activity and energy patterns. |
| **Home Screen widgets** | See focus status and recent energy patterns without opening the app. |
| **AI-assisted guidance** | Receive weekly insights and optional checklist suggestions on supported devices. |
| **Learning resources** | Discover relevant YouTube videos through a protected backend. |

### The Ember learning loop

**Set a goal → Check your energy → Choose a small task → Focus → Reflect → Recognise patterns**

Energy ratings are **self-reported**. Ember is a learning and productivity tool, not a health diagnostic tool.

## 🛠 Tech stack

| Layer | Technologies | Purpose |
| --- | --- | --- |
| **Native iOS** | Swift, SwiftUI, MVVM | Native UI and feature-first application architecture |
| **Local data** | SwiftData, UserDefaults / AppStorage | Persist goals, tasks, energy check-ins, sessions, reflections and settings |
| **Visualisation** | Swift Charts | Learning activity and energy trends |
| **Widgets** | WidgetKit, App Groups | Home Screen widgets and cross-process state snapshots |
| **On-device AI** | Apple Foundation Models | Weekly insights and adaptive checklist suggestions on eligible devices |
| **Secure gateway** | Firebase Cloud Functions, Firebase App Check, App Attest | Validate app requests and forward video searches securely |
| **Video discovery** | Google Cloud Run, YouTube Data API | Retrieve learning resources while keeping API keys server-side |
| **Engineering** | Xcode, XCTest, XCUITest, Git, GitHub | Development, automated testing and team collaboration |

## 🧱 Architecture

Ember uses a **feature-first MVVM structure**. SwiftUI views present state, view models coordinate feature behaviour, and SwiftData models persist learner information locally.

```text
Ember iOS app (SwiftUI + MVVM)
│
├── Goals, check-ins, tasks, focus, reflection
│   └── SwiftData + AppStorage
├── Analytics
│   └── Swift Charts + derived energy observations
├── Apple Foundation Models (supported devices)
│   └── On-device insights + optional checklist suggestions
├── WidgetKit extension
│   └── App Group snapshots for Focus and Monthly Energy
└── YouTube recommendations
    └── Firebase callable function (App Check enforced)
        └── IAM-protected Google Cloud Run proxy
            └── YouTube Data API
```

Both widgets share one `EmberWidgetExtension` target. They consume **App Group snapshots**, rather than opening the app's SwiftData store directly.

### Repository structure

```text
Ember.xcodeproj/             Xcode project
Ember/
  App/                     App lifecycle, routing, storage, widget sync
  Core/                    Shared models and on-device AI
  DesignSystem/            Theme and reusable UI components
  Features/                Onboarding, Today, Planner, Focus, Reflection, Analytics
  Shared/                  Widget-support code
EmberShared/                Shared cross-target utilities
EmberWidgetExtension/       Focus and Monthly Energy widgets
EmberTests/                 Unit and integration tests
EmberUITests/               UI tests
functions/                  Firebase callable function gateway
backend/youtube-proxy/      Cloud Run YouTube proxy
```

## 🚀 Getting started

### Prerequisites

- A Mac with a compatible recent version of **Xcode** and an iPhone Simulator runtime.
- The project's configured minimum deployment target is **iOS 17**.
- Firebase configuration for app launch and protected video recommendations.
- For actual Foundation Models generation: an **eligible device running iOS 26+**, with Apple Intelligence enabled and the system model available. Unavailable environments use deterministic fallback behaviour.

### Open the iOS app

```bash
git clone https://github.com/ycl2001/ember.git
cd ember
open Ember.xcodeproj
```

Choose the **Ember** scheme and a compatible iPhone Simulator, then press **⌘R** in Xcode.

### Firebase and signing

`EmberApp.swift` configures Firebase during app startup. To use your own Firebase project, add the appropriate **`GoogleService-Info.plist`** and include it in the app target.

Firebase App Check uses the **debug provider for DEBUG simulator builds only**, and **App Attest** for device builds. Register your simulator debug token before calling protected Cloud Functions. Production device builds also require compatible signing and capabilities.

The existing project contains UTS app and widget bundle identifiers and an App Group entitlement. Running on your own device or distributing with a different team may require appropriate provisioning, bundle IDs, App Group configuration and App Attest settings. Do not change these blindly.

### YouTube backend (optional)

Video discovery uses **two backend components**:

1. `functions/` — a Firebase callable function (`getYouTubeRecommendations`) with App Check enforced.
2. `backend/youtube-proxy/` — an IAM-protected Cloud Run service that calls the YouTube Data API with a server-side key.

You need your own Firebase / Google Cloud project configuration, service accounts, authorisations and YouTube API credentials. See the [YouTube proxy README](backend/youtube-proxy/README.md) for its tests and deployment details.

**Never commit API keys, service-account private keys or other secrets.**

## 🧪 Testing

The repository includes unit and integration tests in `EmberTests/` and UI tests in `EmberUITests/`. With the **Ember** scheme selected, press **⌘U** in Xcode to run its test suite.

Key regression areas include onboarding and saved learning goals, energy selection, task planning, focus session recovery, reflection history, daily/weekly/monthly analytics, widget synchronisation and deep links, AI availability and fallback, and Firebase/YouTube request handling.

**AI verification limitation:** Deterministic fallback and injected generation have been tested, but actual Foundation Models generation still requires confirmation on an eligible device with Apple Intelligence available. A successful simulator build alone does not demonstrate successful model generation.

## 🔒 Privacy-conscious design

- Goals, tasks, check-ins, focus sessions and reflections are stored locally with **SwiftData**.
- Supported Apple Intelligence generation uses **on-device Foundation Models**.
- AI-generated checklist suggestions are **opt-in**: no tasks are added until the learner accepts them.
- YouTube discovery sends relevant goal/task query text through the configured backend; the YouTube API key is not embedded in the iOS app.
- Account sign-in and cross-device synchronisation are **future plans**, not current features.

## 🗺 Future plans

- **Secure accounts and sync** — Keep learning progress across devices.
- **Video timestamps** — Jump directly to helpful moments in learning videos.
- **Learning community** — Share progress, encouragement and ideas.

## 🤝 Collaboration

Ember was developed collaboratively for the **2026 Apple Foundation Program**, using feature branches, pull requests, integration branches, code reviews and automated tests.

You can explore [Issues](https://github.com/ycl2001/ember/issues) and [Pull Requests](https://github.com/ycl2001/ember/pulls).

---

**Small steps. Better energy. Steady progress.**
[README.md](https://github.com/user-attachments/files/34887644/README.md)

