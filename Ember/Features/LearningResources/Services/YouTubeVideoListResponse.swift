import Foundation

/// The subset of the official `videos.list` response returned by Ember's backend proxy.
struct YouTubeVideoListResponse: Decodable, Sendable {
    let items: [Item]

    struct Item: Decodable, Sendable {
        let id: String
        let snippet: Snippet
        let contentDetails: ContentDetails
    }

    struct Snippet: Decodable, Sendable {
        let title: String
        let description: String
        let channelTitle: String
        let thumbnails: Thumbnails
    }

    struct Thumbnails: Decodable, Sendable {
        let medium: Thumbnail?
        let high: Thumbnail?
        let `default`: Thumbnail?

        var preferred: Thumbnail? { high ?? medium ?? `default` }
    }

    struct Thumbnail: Decodable, Sendable {
        let url: URL
    }

    struct ContentDetails: Decodable, Sendable {
        let duration: String
    }

    var videos: [YouTubeVideo] {
        items.prefix(5).compactMap { item in
            guard YouTubeVideoURLBuilder.isValidVideoID(item.id) else { return nil }
            return YouTubeVideo(
                id: item.id,
                title: item.snippet.title,
                channelTitle: item.snippet.channelTitle,
                description: item.snippet.description,
                thumbnailURL: item.snippet.thumbnails.preferred?.url,
                durationSeconds: YouTubeDurationParser.seconds(from: item.contentDetails.duration)
            )
        }
    }
}
