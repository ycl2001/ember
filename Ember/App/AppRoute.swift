import Foundation

/// Stable route identifiers. Feature developers should not rename these routes.
enum AppRoute: String, CaseIterable, Hashable {
    case onboarding
    case energyCheckIn
    case planner
    case goalDetail
    case focus
    case reflection
    case analytics

    var title: String {
        switch self {
        case .onboarding: "Learning goals"
        case .energyCheckIn: "Daily energy"
        case .planner: "Today's checklist"
        case .goalDetail: "Learning goal"
        case .focus: "Focus session"
        case .reflection: "Session reflection"
        case .analytics: "Energy insights"
        }
    }

    var subtitle: String {
        switch self {
        case .onboarding: "Choose what you want to learn"
        case .energyCheckIn: "Check in on your energy (1–5)"
        case .planner: "Break your goal into small steps"
        case .goalDetail: "Tasks for one learning goal"
        case .focus: "Spend time on one learning task"
        case .reflection: "Reflect on your energy after a task"
        case .analytics: "See patterns across your sessions"
        }
    }

    var systemImage: String {
        switch self {
        case .onboarding: "target"
        case .energyCheckIn: "battery.75percent"
        case .planner: "checklist"
        case .goalDetail: "list.bullet.rectangle"
        case .focus: "timer"
        case .reflection: "heart.text.square"
        case .analytics: "chart.xyaxis.line"
        }
    }
}
