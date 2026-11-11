import Foundation
import SwiftData

enum EmberStorage {
    static let defaults: UserDefaults = {
        #if DEBUG
        if let testID {
            guard let defaults = UserDefaults(suiteName: "ember.ui-tests.\(testID.uuidString)") else {
                fatalError("Unable to open Ember UI test preferences.")
            }
            return defaults
        }
        #endif
        return .standard
    }()

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            LearningGoal.self,
            LearningTask.self,
            EnergyCheckIn.self,
            FocusSession.self,
            SessionReflection.self
        ])
        #if DEBUG
        if let testID {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ember-ui-\(testID.uuidString).store")
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: configuration)
        }
        #endif
        return try ModelContainer(for: schema)
    }

    #if DEBUG
    // A test reuses its ID on relaunch. Other tests and normal launches have separate stores.
    private static let testID = ProcessInfo.processInfo.environment["EMBER_UI_TEST_ID"]
        .flatMap(UUID.init(uuidString:))
    #endif
}
