import Foundation

struct WeeklyEnergyEncouragement: Equatable {
    let average: Double?
    let reflectionCount: Int
    let title: String
    let message: String
    let symbol: String

    var metricValue: String {
        guard let average else { return "No observations" }
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    var observationNote: String {
        switch reflectionCount {
        case 0:
            "Save a post-session reflection to see a weekly energy observation."
        case 1:
            "Early observation from one saved reflection."
        default:
            "Based on \(reflectionCount) saved reflections."
        }
    }

    static func make(average: Double?, reflectionCount: Int) -> WeeklyEnergyEncouragement {
        guard let average,
              average.isFinite,
              (1...5).contains(average),
              reflectionCount > 0 else {
            return WeeklyEnergyEncouragement(
                average: nil,
                reflectionCount: 0,
                title: "Weekly energy check-in",
                message: "There is not enough after-session energy data for this week yet.",
                symbol: "info.circle"
            )
        }

        switch average {
        case ..<2:
            return WeeklyEnergyEncouragement(
                average: average,
                reflectionCount: reflectionCount,
                title: "Gentle check-in",
                message: "Your recent learning sessions have left you with low energy. What is one activity that helps you feel happier or more comfortable?",
                symbol: "heart"
            )
        case ..<3:
            return WeeklyEnergyEncouragement(
                average: average,
                reflectionCount: reflectionCount,
                title: "Energising activity",
                message: "Consider choosing a small learning activity that usually leaves you feeling more energised.",
                symbol: "sparkles"
            )
        case ...4:
            return WeeklyEnergyEncouragement(
                average: average,
                reflectionCount: reflectionCount,
                title: "Maintain momentum",
                message: "You're maintaining steady energy. Notice which learning activities help you sustain your progress.",
                symbol: "figure.walk"
            )
        default:
            return WeeklyEnergyEncouragement(
                average: average,
                reflectionCount: reflectionCount,
                title: "Positive affirmation",
                message: "You've reported strong energy after your recent learning sessions. Keep recognising what works for you!",
                symbol: "sun.max"
            )
        }
    }
}

extension AnalyticsViewModel {
    func weeklyEnergyEncouragement(
        reflections: [SessionReflection],
        sessions: [FocusSession]
    ) -> WeeklyEnergyEncouragement {
        let observations = reflectionsInRange(
            reflections,
            sessions: sessions,
            during: selectedRange
        )
        return WeeklyEnergyEncouragement.make(
            average: averageAfterSessionEnergy(in: observations),
            reflectionCount: observations.count
        )
    }
}
