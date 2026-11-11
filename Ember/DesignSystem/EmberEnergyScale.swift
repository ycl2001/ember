import SwiftUI

/// The shared presentation scale for Ember's self-reported 1–5 energy ratings.
enum EmberEnergyScale {
    enum Tone: Int, CaseIterable {
        case red = 1
        case orange = 2
        case brown = 3
        case blue = 4
        case green = 5

        var color: Color {
            switch self {
            case .red: .red
            case .orange: .orange
            case .brown: .brown
            case .blue: .blue
            case .green: .green
            }
        }
    }

    static func tone(for rating: Int?) -> Tone? {
        guard let rating else { return nil }
        return Tone(rawValue: rating)
    }

    static func color(for rating: Int?) -> Color? {
        tone(for: rating)?.color
    }

    static func rating(for average: Double?) -> Int? {
        guard let average, average.isFinite, (1...5).contains(average) else {
            return nil
        }
        return Int(average.rounded(.toNearestOrAwayFromZero))
    }

    static func color(for average: Double?) -> Color? {
        color(for: rating(for: average))
    }
}
