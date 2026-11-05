import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID
    var taskID: UUID
    var startedAt: Date
    var endedAt: Date?
    /// Recorded study time, excluding paused time.
    var durationSeconds: Int

    init(id: UUID = UUID(), taskID: UUID, startedAt: Date = .now,
         endedAt: Date? = nil, durationSeconds: Int = 0) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
    }
}
