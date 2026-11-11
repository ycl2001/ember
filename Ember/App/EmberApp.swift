import SwiftUI
import SwiftData

/// Application entry point. Changes to this file are owned by the integration lead.
@main
struct EmberApp: App {
    private let modelContainer: ModelContainer

    init() {
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
