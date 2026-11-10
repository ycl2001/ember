import Foundation
import SwiftData

@Model
final class SessionReflection {
    var id: UUID
    var taskID: UUID
    var sessionID: UUID
    var energyBefore: Int
    var energyAfter: Int
    /// Stable raw value from `ReflectionCognitiveLoad`.
    var cognitiveLoad: String?
    /// Stable raw values from `ReflectionHelpfulFactor`.
    var helpfulFactors: [String]?
    var notes: String
    var createdAt: Date

    /// Positive means self-reported energy decreased; negative means energy increased.
    var energySpent: Int { energyBefore - energyAfter }

    init(id: UUID = UUID(), taskID: UUID, sessionID: UUID,
         energyBefore: Int, energyAfter: Int,
         cognitiveLoad: String? = nil, helpfulFactors: [String]? = nil,
         notes: String = "",
         createdAt: Date = .now) {
        self.id = id
        self.taskID = taskID
        self.sessionID = sessionID
        self.energyBefore = min(5, max(1, energyBefore))
        self.energyAfter = min(5, max(1, energyAfter))
        self.cognitiveLoad = cognitiveLoad
        self.helpfulFactors = helpfulFactors
        self.notes = notes
        self.createdAt = createdAt
    }
}
