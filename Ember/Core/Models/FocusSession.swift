import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID
    var taskID: UUID
    /// Snapshot retained so historical sessions remain understandable after task deletion.
    var taskTitle: String?
    var startedAt: Date
    var endedAt: Date?
    /// Recorded study time, excluding paused time.
    var durationSeconds: Int

    init(id: UUID = UUID(), taskID: UUID, taskTitle: String? = nil, startedAt: Date = .now,
         endedAt: Date? = nil, durationSeconds: Int = 0) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
    }
}
