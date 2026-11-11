import Foundation

enum TaskVideoReference: Equatable, Sendable {
    case mentioned
    case linked(URL)

    static func detect(in notes: String) -> TaskVideoReference? {
        if let url = linkedVideoURL(in: notes) {
            return .linked(url)
        }

        let words = notes
            .split { !$0.isLetter && !$0.isNumber }
            .map { $0.lowercased() }

        return words.contains("video") || words.contains("vid") ? .mentioned : nil
    }

    private static func linkedVideoURL(in notes: String) -> URL? {
        let boundaryCharacters = CharacterSet(charactersIn: #""'()[]{}<>,.;"#)

        for rawToken in notes.split(whereSeparator: \.isWhitespace) {
            let candidate = String(rawToken).trimmingCharacters(in: boundaryCharacters)
            guard let url = URL(string: candidate),
                  let validatedURL = YouTubeVideoURLBuilder.validatedVideoURL(url) else {
                continue
            }
            return validatedURL
        }

        return nil
    }
}
