import Foundation

struct YouTubeVideo: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let channelTitle: String
    let description: String
    let thumbnailURL: URL?
    let durationSeconds: Int?

    var durationText: String? {
        guard let durationSeconds else { return nil }
        let hours = durationSeconds / 3_600
        let minutes = (durationSeconds % 3_600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return "\(hours):\(Self.padded(minutes)):\(Self.padded(seconds))"
        }
        return "\(minutes):\(Self.padded(seconds))"
    }

    var chapters: [YouTubeChapter] {
        YouTubeChapterParser.chapters(in: description, durationSeconds: durationSeconds)
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
