import Foundation
import Observation
import SwiftData

/// UserDefaults keys for onboarding answers that have no SwiftData model yet.
/// Other features can read these without any change to the shared models.
enum OnboardingStorage {
    static let peakWindowKey = "onboarding.peakWindow"
    static let commitmentKey = "onboarding.dailyCommitment"
    static let drainsKey = "onboarding.energyDrains"
    static let microSprintKey = "onboarding.microSprintPackaging"
    static let cognitiveResetKey = "onboarding.cognitiveReset"
    static let completedKey = "onboarding.completed"
}

// MARK: - Options shown on the onboarding screens

enum LearningCategory: String, CaseIterable, Identifiable {
    case academic, professional, leisure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .academic: return "Academic"
        case .professional: return "Professional"
        case .leisure: return "Leisure"
        }
    }

    var summary: String {
        switch self {
        case .academic: return "University coursework, degree subjects, exams, or research papers."
        case .professional: return "Career advancement, certifications, technical skills, or licensing."
        case .leisure: return "Personal passions, culinary arts, creative design, sports & wellness."
        }
    }

    var topics: [String] {
        switch self {
        case .academic: return ["CS & Systems", "Research & Thesis", "Economics"]
        case .professional: return ["Certifications", "System Craft", "Technical Boards"]
        case .leisure: return ["Cooking & Culinary", "UI/UX Design", "Sports & Fitness"]
        }
    }
}

enum DailyCommitment: String, CaseIterable, Identifiable {
    case bitesized, steady, immersion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bitesized: return "Bite-Sized"
        case .steady: return "Steady"
        case .immersion: return "Immersion"
        }
    }

    var rangeLabel: String {
        switch self {
        case .bitesized: return "15–20 min/day"
        case .steady: return "35–45 min/day"
        case .immersion: return "60+ min/day"
        }
    }

    var detail: String {
        switch self {
        case .bitesized:
            return "Ideal for high-friction topics and busy academic schedules. Protects baseline habit without cognitive drain."
        case .steady:
            return "Balanced dual-block pacing with integrated 5-minute cognitive reset buffer."
        case .immersion:
            return "Deep focus blocks with thematic recall exercises and comprehensive retention synthesis."
        }
    }

    /// Length of each learn or practice block in the sample blueprint.
    var sprintMinutes: Int {
        switch self {
        case .bitesized: return 10
        case .steady: return 20
        case .immersion: return 30
        }
    }

    var isRecommended: Bool { self == .bitesized }
}

enum PeakWindow: String, CaseIterable, Identifiable {
    case morning, midday, evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning Clarity"
        case .midday: return "Midday Steady"
        case .evening: return "Evening Deep Work"
        }
    }

    var timeRange: String {
        switch self {
        case .morning: return "8:00 AM – 11:30 AM"
        case .midday: return "12:00 PM – 4:00 PM"
        case .evening: return "7:00 PM – 10:30 PM"
        }
    }

    var compactRange: String {
        switch self {
        case .morning: return "8:00–11:30 AM"
        case .midday: return "12:00–4:00 PM"
        case .evening: return "7:00–10:30 PM"
        }
    }

    var badge: String {
        switch self {
        case .morning: return "Peak Focus L5"
        case .midday: return "Steady Intellect L3–4"
        case .evening: return "Calm Flow L4"
        }
    }

    var detail: String {
        switch self {
        case .morning: return "Best for deep conceptual synthesis, heavy math & demanding problem sets."
        case .midday: return "Consistent cadence for lab drills, exercises, and structured revision modules."
        case .evening: return "Solitary immersion free from daytime notifications and campus rush."
        }
    }

    var symbol: String {
        switch self {
        case .morning: return "sun.max"
        case .midday: return "cloud.sun"
        case .evening: return "moon"
        }
    }

    /// First task of the day starts 30 minutes into the window (minutes after midnight).
    var startMinutes: Int {
        switch self {
        case .morning: return 8 * 60 + 30
        case .midday: return 12 * 60 + 30
        case .evening: return 19 * 60 + 30
        }
    }

    var focusPhrase: String {
        switch self {
        case .morning: return "Morning peak focus"
        case .midday: return "Midday steady focus"
        case .evening: return "Evening calm focus"
        }
    }

    var levelPhrase: String {
        switch self {
        case .morning: return "Level 5 Deep"
        case .midday: return "Level 3"
        case .evening: return "Level 4"
        }
    }
}

enum EnergyDrain: String, CaseIterable, Identifiable {
    case denseReading, debugging, passiveLectures, openEndedEssays, contextSwitching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .denseReading: return "Dense long-form reading"
        case .debugging: return "Debugging & runtime errors"
        case .passiveLectures: return "Passive lectures (>15m)"
        case .openEndedEssays: return "Open-ended essay synthesis"
        case .contextSwitching: return "Unplanned context-switching"
        }
    }

    var tag: String {
        switch self {
        case .denseReading: return "Cognitive load"
        case .debugging: return "Frustration"
        case .passiveLectures: return "Low agency"
        case .openEndedEssays: return "Decision fatigue"
        case .contextSwitching: return "Distraction"
        }
    }

    var symbol: String {
        switch self {
        case .denseReading: return "book"
        case .debugging: return "chevron.left.forwardslash.chevron.right"
        case .passiveLectures: return "dot.radiowaves.left.and.right"
        case .openEndedEssays: return "doc.text"
        case .contextSwitching: return "shuffle"
        }
    }
}

struct BlueprintBlock: Identifiable {
    enum Kind { case learn, reset, practice }

    let kind: Kind
    let title: String
    let detail: String
    let minutes: Int
    /// Start time like "8:30 AM", or "Buffer" for the reset block.
    let badge: String

    var id: String { title }
}

struct ProtectorItem: Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}

// MARK: - View model

/// Member 2: state, validation, and saving for the 3-step onboarding flow.
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case goals = 1, rhythm, blueprint

        var title: String { "Onboarding Step \(rawValue)" }

        var eyebrow: String {
            switch self {
            case .goals: return "STEP 1 OF 3 • FOCUS & GOALS"
            case .rhythm: return "STEP 2 OF 3 • CIRCADIAN RHYTHM"
            case .blueprint: return "STEP 3 OF 3 • ADAPTIVE BLUEPRINT"
            }
        }

        var progress: Double {
            switch self {
            case .goals: return 0.33
            case .rhythm: return 0.66
            case .blueprint: return 1.0
            }
        }

        var percentLabel: String {
            switch self {
            case .goals: return "33% Complete"
            case .rhythm: return "66% Complete"
            case .blueprint: return "100% COMPLETE"
            }
        }
    }

    var step: Step = .goals

    // Step 1
    var selectedCategory: LearningCategory = .academic
    private(set) var selectedTopics: [String] = []
    private(set) var customTopics: [String] = []
    var customTopic = ""
    var isAddingCustomTopic = false
    var commitment: DailyCommitment = .bitesized
    private(set) var skippedGoals = false

    // Step 2
    var peakWindow: PeakWindow = .morning
    private(set) var drains: Set<EnergyDrain> = []
    var microSprintEnabled = true
    var cognitiveResetEnabled = true

    var errorMessage: String?

    // MARK: Navigation

    var primaryTitle: String {
        switch step {
        case .goals: return "Continue to Circadian Energy"
        case .rhythm: return "Continue to Plan Blueprint"
        case .blueprint: return "Start Learning"
        }
    }

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        if step == .goals {
            skippedGoals = false
        }
        errorMessage = nil
        step = next
    }

    /// Returns false when already on the first step, so the caller can close the flow.
    func goBack() -> Bool {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return false }
        errorMessage = nil
        step = previous
        return true
    }

    func skipGoals() {
        skippedGoals = true
        errorMessage = nil
        step = .rhythm
    }

    // MARK: Step 1

    func isSelected(topic: String) -> Bool {
        selectedTopics.contains(topic)
    }

    func toggleTopic(_ topic: String, in category: LearningCategory) {
        selectedCategory = category
        if let index = selectedTopics.firstIndex(of: topic) {
            selectedTopics.remove(at: index)
        } else {
            selectedTopics.append(topic)
        }
    }

    var trimmedCustomTopic: String {
        customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAddCustomTopic: Bool {
        !trimmedCustomTopic.isEmpty
    }

    func addCustomTopic() {
        let name = trimmedCustomTopic
        guard !name.isEmpty else { return }

        let alreadyAdded = selectedTopics.contains {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }
        if !alreadyAdded {
            customTopics.append(name)
            selectedTopics.append(name)
        }
        customTopic = ""
    }

    /// Topics that become goals. If no chip is picked, the chosen category is used.
    /// Empty when the learner skipped Step 1.
    var goalTopics: [String] {
        if skippedGoals { return [] }
        if selectedTopics.isEmpty { return [selectedCategory.title] }
        return selectedTopics
    }

    // MARK: Step 2

    func toggleDrain(_ drain: EnergyDrain) {
        if drains.contains(drain) {
            drains.remove(drain)
        } else {
            drains.insert(drain)
        }
    }

    // MARK: Step 3 (blueprint preview built from the answers)

    var primaryTopic: String {
        goalTopics.first ?? "your first goal"
    }

    var topicsSummary: String {
        guard let first = goalTopics.first else { return "your first learning goal" }
        let extra = goalTopics.count - 1
        return extra > 0 ? "\(first) and \(extra) more" : first
    }

    var blueprintBlocks: [BlueprintBlock] {
        var blocks: [BlueprintBlock] = []
        var cursor = peakWindow.startMinutes
        let sprint = commitment.sprintMinutes

        blocks.append(BlueprintBlock(
            kind: .learn,
            title: "Learn: \(primaryTopic)",
            detail: "\(sprint) min • \(peakWindow.focusPhrase) • \(peakWindow.levelPhrase)",
            minutes: sprint,
            badge: clock(cursor)
        ))
        cursor += sprint

        if cognitiveResetEnabled {
            blocks.append(BlueprintBlock(
                kind: .reset,
                title: "3-Min Somatic Eye Reset",
                detail: "3 min • Vagal breathing & sensory cooldown",
                minutes: 3,
                badge: "Buffer"
            ))
            cursor += 3
        }

        blocks.append(BlueprintBlock(
            kind: .practice,
            title: "Practice: \(primaryTopic)",
            detail: "\(sprint) min • Hands-on active recall drill • Level 4",
            minutes: sprint,
            badge: clock(cursor)
        ))

        return blocks
    }

    var totalMinutes: Int {
        blueprintBlocks.reduce(0) { $0 + $1.minutes }
    }

    /// Placeholder shown on the blueprint card until real analytics exist.
    var burnoutRiskPercent: Int { 0 }

    let protectors = [
        ProtectorItem(title: "Pre-task energy check-in",
                      detail: "Dialed to dynamic 3-second rapid bio-rating"),
        ProtectorItem(title: "Burnout trigger warning",
                      detail: "Safeguard auto-locks sprint sessions when acute fatigue is signaled")
    ]

    private func clock(_ minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let suffix = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let paddedMinute = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hour12):\(paddedMinute) \(suffix)"
    }

    // MARK: Saving

    /// Creates a LearningGoal for each new topic and stores the other answers.
    /// Returns true when everything was saved.
    func finish(in context: ModelContext, existingGoals: [LearningGoal]) -> Bool {
        for topic in goalTopics {
            let exists = existingGoals.contains {
                $0.topic.caseInsensitiveCompare(topic) == .orderedSame
            }
            if !exists {
                context.insert(LearningGoal(topic: topic))
            }
        }

        do {
            try context.save()
        } catch {
            errorMessage = "Couldn't save your goals. Please try again."
            return false
        }

        let defaults = UserDefaults.standard
        defaults.set(peakWindow.rawValue, forKey: OnboardingStorage.peakWindowKey)
        defaults.set(commitment.rawValue, forKey: OnboardingStorage.commitmentKey)
        defaults.set(drains.map(\.rawValue).sorted(), forKey: OnboardingStorage.drainsKey)
        defaults.set(microSprintEnabled, forKey: OnboardingStorage.microSprintKey)
        defaults.set(cognitiveResetEnabled, forKey: OnboardingStorage.cognitiveResetKey)
        defaults.set(true, forKey: OnboardingStorage.completedKey)

        errorMessage = nil
        return true
    }
}
