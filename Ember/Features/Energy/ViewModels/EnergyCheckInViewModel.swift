import Foundation
import Observation
import SwiftData

/// The three "How are you feeling" options on Today. Each one saves a 1-5 energy level.
enum FeelingOption: String, CaseIterable, Identifiable {
    case gentle, steady, highFocus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .steady: return "Steady"
        case .highFocus: return "High Focus"
        }
    }

    var subtitle: String {
        switch self {
        case .gentle: return "Audio & rest"
        case .steady: return "Notes"
        case .highFocus: return "Research"
        }
    }

    var symbol: String {
        switch self {
        case .gentle: return "moon.fill"
        case .steady: return "water.waves"
        case .highFocus: return "sun.max.fill"
        }
    }

    /// Level saved when the learner taps this option. Change the mapping here if needed.
    var level: Int {
        switch self {
        case .gentle: return 2
        case .steady: return 3
        case .highFocus: return 5
        }
    }

    /// Maps a saved level back to an option: 1-2 Gentle, 3 Steady, 4-5 High Focus.
    static func matching(level: Int) -> FeelingOption {
        switch level {
        case ...2: return .gentle
        case 3: return .steady
        default: return .highFocus
        }
    }
}

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

/// Member 2: state and saving for the Today picker and the full energy check-in screen.
@MainActor
@Observable
final class EnergyCheckInViewModel {
    var errorMessage: String?
    private(set) var savedMessage: String?

    // Full check-in screen
    var selectedLevel = 3
    var didSave = false

    /// Display only for now. EnergyCheckIn has no field for these, so they are not saved.
    var cognitiveLoad: CognitiveLoad?
    private(set) var flowHelpers: Set<String> = []

    static let helperOptions = [
        "Clear examples", "Quiet study space", "Interactive sandbox", "25-min interval"
    ]

    /// The latest saved level from before the screen opened, used for the Before and After card.
    private(set) var previousLevel: Int?
    private var hasLoadedPrevious = false

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

    static func batterySymbol(for level: Int?) -> String {
        switch level {
        case 2?: return "battery.50percent"
        case 3?: return "battery.75percent"
        case 4?, 5?: return "battery.100percent"
        default: return "battery.25percent"
        }
    }

    // MARK: Today picker

    /// Saves a check-in for the tapped option. Tapping the option that is already
    /// active today does nothing, so double taps don't create duplicate entries.
    /// Returns true when a new check-in was saved.
    @discardableResult
    func record(_ option: FeelingOption, latest: EnergyCheckIn?, in context: ModelContext) -> Bool {
        if let latest,
           Calendar.current.isDateInToday(latest.createdAt),
           FeelingOption.matching(level: latest.level) == option {
            return false
        }

        let message = "Saved. " + Self.describeChange(from: latest?.level, to: option.level)
        context.insert(EnergyCheckIn(level: option.level))

        do {
            try context.save()
            savedMessage = message
            errorMessage = nil
            return true
        } catch {
            savedMessage = nil
            errorMessage = "Couldn't save your check-in. Please try again."
            return false
        }
    }

    // MARK: Full check-in screen

    func selectLevel(_ level: Int) {
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

    /// Loads the latest saved level once, and starts the selection on it.
    func loadPrevious(from checkIns: [EnergyCheckIn]) {
        guard !hasLoadedPrevious else { return }
        hasLoadedPrevious = true
        previousLevel = checkIns.max { $0.createdAt < $1.createdAt }?.level
        if let previousLevel {
            selectedLevel = previousLevel
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

    var changeLabel: String {
        guard let previousLevel else { return "First check-in" }
        let change = selectedLevel - previousLevel
        let unit = abs(change) == 1 ? "level" : "levels"
        if change < 0 { return "Energy used: \(change) \(unit)" }
        if change > 0 { return "Energy gained: +\(change) \(unit)" }
        return "Energy steady"
    }

    var changeMessage: String {
        Self.describeChange(from: previousLevel, to: selectedLevel)
    }

    /// Saves a new EnergyCheckIn for the selected level.
    func saveSelectedLevel(in context: ModelContext) {
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

    // MARK: Shared

    private static func describeChange(from previous: Int?, to new: Int) -> String {
        guard let previous else {
            return "This is your first check-in. Later ones are compared with it so you can see your own pattern."
        }
        let change = new - previous
        let amount = abs(change)
        let unit = amount == 1 ? "level" : "levels"
        if change < 0 {
            return "Your energy is \(amount) \(unit) lower than last time. A lighter task or a short break can help."
        }
        if change > 0 {
            return "Your energy is \(amount) \(unit) higher than last time. A good moment for a focused task."
        }
        return "Your energy is steady since your last check-in."
    }
}
