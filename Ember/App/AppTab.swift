import Foundation

/// The four persistent tabs from the supplied mobile prototype.
enum AppTab: String, CaseIterable, Identifiable {
    case today
    case sessions
    case analytics
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .sessions: "Sessions"
        case .analytics: "Analytics"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.horizon"
        case .sessions: "book.closed"
        case .analytics: "chart.bar.xaxis"
        case .profile: "person.crop.circle"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .today: "sun.horizon.fill"
        case .sessions: "book.closed.fill"
        case .analytics: "chart.bar.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}
