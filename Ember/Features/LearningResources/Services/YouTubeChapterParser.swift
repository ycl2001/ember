import Foundation

enum YouTubeChapterParser {
    static func chapters(in description: String, durationSeconds: Int? = nil) -> [YouTubeChapter] {
        var seenStarts = Set<Int>()
        let candidates = description
            .split(whereSeparator: \.isNewline)
            .compactMap { chapter(from: String($0), durationSeconds: durationSeconds) }
            .filter { seenStarts.insert($0.startSeconds).inserted }
        guard candidates.count >= 3, candidates.first?.startSeconds == 0 else { return [] }
        guard zip(candidates, candidates.dropFirst()).allSatisfy({ next in
            next.1.startSeconds - next.0.startSeconds >= 10
        }) else { return [] }
        if let durationSeconds,
           let lastStart = candidates.last?.startSeconds,
           durationSeconds - lastStart < 10 {
            return []
        }
        return candidates
    }

    static func suggestedChapter(
        in chapters: [YouTubeChapter],
        goal: String,
        task: String
    ) -> YouTubeChapter? {
        let taskTerms = significantTerms(in: task)
        guard !taskTerms.isEmpty else { return nil }
        let goalTerms = significantTerms(in: goal)

        return chapters
            .compactMap { chapter -> (YouTubeChapter, Double)? in
                let chapterText = normalized(chapter.title)
                let compactChapterText = chapterText.filter { $0.isLetter || $0.isNumber }
                let taskMatches = taskTerms.count { term in
                    chapterText.split(separator: " ").contains(Substring(term))
                        || compactChapterText.contains(term.filter { $0.isLetter || $0.isNumber })
                }
                let confidence = Double(taskMatches) / Double(taskTerms.count)
                guard confidence >= 0.5, taskMatches > 0 else { return nil }
                let goalMatches = goalTerms.count { term in
                    compactChapterText.contains(term.filter { $0.isLetter || $0.isNumber })
                }
                return (chapter, confidence + Double(goalMatches) * 0.01)
            }
            .max { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.0.startSeconds > rhs.0.startSeconds : lhs.1 < rhs.1
            }?.0
    }

    private static func chapter(from line: String, durationSeconds: Int?) -> YouTubeChapter? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "•-"))
            .trimmingCharacters(in: .whitespaces)
        guard let separator = trimmed.firstIndex(where: \.isWhitespace) else { return nil }

        let timestamp = String(trimmed[..<separator])
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]()"))
        let title = String(trimmed[separator...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-–—:| "))
        guard !title.isEmpty, let startSeconds = parseTimestamp(timestamp) else { return nil }
        if let durationSeconds, startSeconds >= durationSeconds { return nil }
        return YouTubeChapter(startSeconds: startSeconds, title: title)
    }

    private static func parseTimestamp(_ value: String) -> Int? {
        let components = value.split(separator: ":").compactMap { Int($0) }
        guard components.count == value.split(separator: ":").count else { return nil }
        switch components.count {
        case 2:
            guard components[1] < 60 else { return nil }
            return components[0] * 60 + components[1]
        case 3:
            guard components[1] < 60, components[2] < 60 else { return nil }
            return components[0] * 3_600 + components[1] * 60 + components[2]
        default:
            return nil
        }
    }

    private static func significantTerms(in value: String) -> [String] {
        let ignored = Set(["a", "an", "and", "basics", "for", "how", "learn", "learning", "of", "the", "to", "understand", "with"])
        return normalized(value)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !ignored.contains($0) }
    }

    private static func normalized(_ value: String) -> String {
        var spaced = ""
        var previousWasLowercase = false
        for character in value {
            if character.isUppercase && previousWasLowercase {
                spaced.append(" ")
            }
            spaced.append(character)
            previousWasLowercase = character.isLowercase
        }
        return spaced.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { result, character in
                if character != " " || result.last != " " { result.append(character) }
            }
    }
}
