import Foundation

struct YouTubeChapter: Identifiable, Equatable, Hashable, Sendable {
    let startSeconds: Int
    let title: String

    var id: Int { startSeconds }

    var timestampText: String {
        let hours = startSeconds / 3_600
        let minutes = (startSeconds % 3_600) / 60
        let seconds = startSeconds % 60
        if hours > 0 {
            return "\(hours):\(Self.padded(minutes)):\(Self.padded(seconds))"
        }
        return "\(minutes):\(Self.padded(seconds))"
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
