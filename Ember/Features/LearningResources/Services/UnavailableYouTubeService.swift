import Foundation

struct UnavailableYouTubeService: YouTubeServing {
    func recommendations(for request: VideoRecommendationRequest) async throws -> [YouTubeVideo] {
        throw YouTubeServiceError.notConfigured
    }
}
