import Foundation
import Observation

/// Member 4: timer display state. Implement scheduling/pause/resume in this ViewModel.
@MainActor
@Observable
final class FocusSessionViewModel {
    var elapsedSeconds = 0
    var isRunning = false

    var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
