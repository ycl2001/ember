import Foundation
import Observation
import SwiftData

enum ReflectionCognitiveLoad: String, CaseIterable, Identifiable {
    case challenging
    case balanced
    case effortless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .challenging: "Challenging"
        case .balanced: "Balanced Flow"
        case .effortless: "Effortless"
        }
    }

    var subtitle: String {
        switch self {
        case .challenging: "High cognitive load"
        case .balanced: "Steady"
        case .effortless: "Low cognitive load"
        }
    }

    var symbol: String {
        switch self {
        case .challenging: "mountain.2"
        case .balanced: "water.waves"
        case .effortless: "wind"
        }
    }
}

enum ReflectionHelpfulFactor: String, CaseIterable, Identifiable {
    case clearExamples
    case quietStudySpace
    case interactivePractice
    case shortFocusIntervals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearExamples: "Clear examples"
        case .quietStudySpace: "Quiet study space"
        case .interactivePractice: "Interactive practice"
        case .shortFocusIntervals: "Short focus intervals"
        }
    }

    var symbol: String {
        switch self {
        case .clearExamples: "lightbulb"
        case .quietStudySpace: "speaker.slash"
        case .interactivePractice: "hand.tap"
        case .shortFocusIntervals: "timer"
        }
    }
}

struct ReflectionSessionSummary: Equatable {
    let sessionID: UUID
    let taskID: UUID
    let taskTitle: String
    let durationSeconds: Int
    let isComplete: Bool

    var durationText: String {
        let hours = durationSeconds / 3_600
        let minutes = (durationSeconds % 3_600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours) hr \(minutes) min" : "\(hours) hr"
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(max(1, seconds)) sec"
    }
}

/// Reflection form state, exact-session loading, validation and idempotent persistence.
@MainActor
@Observable
final class ReflectionViewModel {
    private(set) var summary: ReflectionSessionSummary?
    private(set) var isMissingSession = false
    private(set) var hadRecordedEnergyBefore = false

    var selectedCognitiveLoad: ReflectionCognitiveLoad?
    var energyBefore: Int?
    var energyAfter: Int?
    var selectedHelpfulFactors: Set<ReflectionHelpfulFactor> = []
    var notes = ""
    var errorMessage: String?

    private var loadedSessionID: UUID?

    var energySpent: Int? {
        guard let energyBefore, let energyAfter else { return nil }
        return energyBefore - energyAfter
    }

    var canSave: Bool {
        summary != nil
            && selectedCognitiveLoad != nil
            && Self.isValidEnergy(energyBefore)
            && Self.isValidEnergy(energyAfter)
    }

    func load(
        sessionID: UUID?,
        sessions: [FocusSession],
        tasks: [LearningTask],
        checkIns: [EnergyCheckIn],
        reflections: [SessionReflection]
    ) {
        guard loadedSessionID != sessionID || summary == nil else { return }
        loadedSessionID = sessionID
        errorMessage = nil
        isMissingSession = false

        guard let sessionID,
              let session = sessions.first(where: { $0.id == sessionID }) else {
            summary = nil
            isMissingSession = true
            return
        }

        let taskTitle = tasks.first(where: { $0.id == session.taskID })?.title
            ?? session.taskTitle
            ?? "Deleted task"

        summary = ReflectionSessionSummary(
            sessionID: session.id,
            taskID: session.taskID,
            taskTitle: taskTitle,
            durationSeconds: session.durationSeconds,
            isComplete: session.endedAt != nil
        )

        if let existing = reflections.first(where: { $0.sessionID == session.id }) {
            energyBefore = existing.energyBefore
            energyAfter = existing.energyAfter
            selectedCognitiveLoad = existing.cognitiveLoad.flatMap(ReflectionCognitiveLoad.init(rawValue:))
            selectedHelpfulFactors = Set(
                (existing.helpfulFactors ?? []).compactMap(ReflectionHelpfulFactor.init(rawValue:))
            )
            notes = existing.notes
            hadRecordedEnergyBefore = true
            return
        }

        let preSessionCheckIn = checkIns
            .filter { $0.createdAt <= session.startedAt && Self.isValidEnergy($0.level) }
            .max { $0.createdAt < $1.createdAt }

        energyBefore = preSessionCheckIn?.level
        hadRecordedEnergyBefore = preSessionCheckIn != nil
        energyAfter = nil
        selectedCognitiveLoad = nil
        selectedHelpfulFactors = []
        notes = ""
    }

    func selectEnergyBefore(_ value: Int) {
        guard Self.isValidEnergy(value) else { return }
        energyBefore = value
    }

    func selectEnergyAfter(_ value: Int) {
        guard Self.isValidEnergy(value) else { return }
        energyAfter = value
    }

    func toggle(_ factor: ReflectionHelpfulFactor) {
        if selectedHelpfulFactors.contains(factor) {
            selectedHelpfulFactors.remove(factor)
        } else {
            selectedHelpfulFactors.insert(factor)
        }
    }

    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard let summary,
              let selectedCognitiveLoad,
              let energyBefore,
              let energyAfter,
              Self.isValidEnergy(energyBefore),
              Self.isValidEnergy(energyAfter) else {
            errorMessage = "Complete the session-feel and energy questions before saving."
            return false
        }

        do {
            let sessionID = summary.sessionID
            let descriptor = FetchDescriptor<SessionReflection>(
                predicate: #Predicate { $0.sessionID == sessionID }
            )
            let existing = try context.fetch(descriptor).first
            let reflection = existing ?? SessionReflection(
                taskID: summary.taskID,
                sessionID: sessionID,
                energyBefore: energyBefore,
                energyAfter: energyAfter
            )

            reflection.taskID = summary.taskID
            reflection.energyBefore = energyBefore
            reflection.energyAfter = energyAfter
            reflection.cognitiveLoad = selectedCognitiveLoad.rawValue
            reflection.helpfulFactors = selectedHelpfulFactors
                .map(\.rawValue)
                .sorted()
            reflection.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

            if existing == nil {
                context.insert(reflection)
            }
            try context.save()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Your reflection couldn't be saved. Please try again."
            return false
        }
    }

    static func isValidEnergy(_ value: Int?) -> Bool {
        guard let value else { return false }
        return (1...5).contains(value)
    }
}
