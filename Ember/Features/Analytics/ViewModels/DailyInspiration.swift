import Foundation

enum DailyInspiration {
    struct Quote: Equatable {
        let text: String
        let author: String
    }

    static let quotes = [
        Quote(
            text: "Well done is better than well said.",
            author: "Benjamin Franklin"
        ),
        Quote(
            text: "Energy and persistence conquer all things.",
            author: "Benjamin Franklin"
        )
    ]

    static func quote(for date: Date, calendar: Calendar = .current) -> Quote {
        guard !quotes.isEmpty else {
            return Quote(text: "Keep learning at a pace that works for you.", author: "Ember")
        }

        let localDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1)
        ) ?? localDay
        let dayOffset = calendar.dateComponents(
            [.day],
            from: referenceDay,
            to: localDay
        ).day ?? 0
        let index = ((dayOffset % quotes.count) + quotes.count) % quotes.count
        return quotes[index]
    }
}
