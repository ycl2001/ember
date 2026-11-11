import Foundation
import FirebaseAppCheck
import FirebaseCore

/// Selects Firebase App Check providers without allowing debug attestation in production builds.
final class EmberAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG && targetEnvironment(simulator)
        AppCheckDebugProvider(app: app)
        #else
        AppAttestProvider(app: app)
        #endif
    }
}
