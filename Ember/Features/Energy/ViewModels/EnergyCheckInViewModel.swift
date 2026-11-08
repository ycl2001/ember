import Foundation
import Observation
import SwiftData

enum CognitiveLoad: String, CaseIterable, Identifiable {
    case challenging, balanced, effortless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .challenging: return "Challenging"
        case .balanced: return "Balanced Flow"
        case .effortless: return "Effortless"
        }
    }

    var badge: String {
        switch self {
        case .challenging: return "High Load"
        case .balanced: return "Steady"
        case .effortless: return "Low Load"
        }
    }

    var detail: String {
        switch self {
        case .challenging: return "High cognitive demand, required extra pauses to unpack proofs."
        case .balanced: return "Comfortable flow state, steady comprehension and active recall."
        case .effortless: return "Rapid retention, felt fully prepared for more difficult tasks."
        }
    }

    var symbol: String {
        switch self {
        case .challenging: return "brain.head.profile"
        case .balanced: return "scalemass"
        case .effortless: return "chart.pie"
        }
    }
}

/// Member 2: presentation state for the daily 1-5 check-in.
@MainActor
@Observable
final class EnergyCheckInViewModel {
    var selectedLevel = 3
    var didSave = false
    var errorMessage: String?

    /// Display only for now. EnergyCheckIn has no field for these, so they are not saved.
    var cognitiveLoad: CognitiveLoad?
    private(set) var flowHelpers: Set<String> = []

    static let helperOptions = [
        "Clear examples", "Quiet study space", "Interactive sandbox", "25-min interval"
    ]

    /// The most recent check-in from before this screen opened, used for comparison.
    private(set) var previousLevel: Int?
    private var hasLoadedPrevious = false

    var isValidLevel: Bool { (1...5).contains(selectedLevel) }

    static func label(for level: Int) -> String {
        switch level {
        case 1: return "Rest"
        case 2: return "Low"
        case 3: return "Steady"
        case 4: return "Alert"
        case 5: return "Focused"
        default: return ""
        }
    }

    func select(_ level: Int) {
        selectedLevel = level
        didSave = false
        errorMessage = nil
    }

    func toggleHelper(_ helper: String) {
        if flowHelpers.contains(helper) {
            flowHelpers.remove(helper)
        } else {
            flowHelpers.insert(helper)
        }
    }

    /// Shown next to "Focus Rhythm" on the top card, based on the selected level.
    var cadenceLabel: String {
        switch selectedLevel {
        case 1, 2: return "Gentle Cadence"
        case 3: return "Smooth Cadence"
        default: return "Strong Cadence"
        }
    }

    // MARK: Comparison with the last check-in

    func loadPrevious(from checkIns: [EnergyCheckIn]) {
        guard !hasLoadedPrevious else { return }
        hasLoadedPrevious = true
        previousLevel = checkIns.max { $0.createdAt < $1.createdAt }?.level
    }

    var change: Int? {
        guard let previousLevel else { return nil }
        return selectedLevel - previousLevel
    }

    var changeLabel: String {
        guard let change else { return "First check-in" }
        let unit = abs(change) == 1 ? "level" : "levels"
        let sign = change > 0 ? "+" : ""
        return "Energy change: \(sign)\(change) \(unit)"
    }

    var changeMessage: String {
        guard let change else {
            return "This is your first check-in. Later ones are compared with it so you can see your own pattern."
        }
        let amount = abs(change)
        let unit = amount == 1 ? "level" : "levels"
        if change < 0 {
            return "Your energy is \(amount) \(unit) lower than last time. Steady momentum counts, and a short break can help."
        }
        if change > 0 {
            return "Your energy is \(amount) \(unit) higher than last time. A good moment for a focused task."
        }
        return "Your energy is steady since your last check-in. Nice, consistent momentum."
    }

    // MARK: Saving

    /// Saves a new EnergyCheckIn. Each save adds a new entry.
    func save(in context: ModelContext) {
        guard isValidLevel else { return }

        context.insert(EnergyCheckIn(level: selectedLevel))

        do {
            try context.save()
            didSave = true
            errorMessage = nil
        } catch {
            didSave = false
            errorMessage = "Couldn't save your check-in. Please try again."
        }
    }
}
