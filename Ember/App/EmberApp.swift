import SwiftUI
import SwiftData
import FirebaseAppCheck
import FirebaseCore

/// Application entry point. Changes to this file are owned by the integration lead.
@main
struct EmberApp: App {
    private let modelContainer: ModelContainer

    init() {
        AppCheck.setAppCheckProviderFactory(EmberAppCheckProviderFactory())
        FirebaseApp.configure()

        do {
            modelContainer = try EmberStorage.makeContainer()
        } catch {
            fatalError("Unable to open Ember's data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
