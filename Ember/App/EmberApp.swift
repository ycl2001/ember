import SwiftUI
import SwiftData

/// Application entry point. Changes to this file are owned by the integration lead.
@main
struct EmberApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            LearningGoal.self,
            LearningTask.self,
            EnergyCheckIn.self,
            FocusSession.self,
            SessionReflection.self
        ])
    }
}
