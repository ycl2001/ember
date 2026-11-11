import Foundation

actor FirebaseYouTubeService: YouTubeServing {
    private let caller: any YouTubeRecommendationCalling
    private var cache: [VideoRecommendationRequest: [YouTubeVideo]] = [:]

    init(
        caller: any YouTubeRecommendationCalling =
            FirebaseYouTubeRecommendationCaller()
    ) {
        self.caller = caller
    }

    func recommendations(
        for request: VideoRecommendationRequest
    ) async throws -> [YouTubeVideo] {
        if let cached = cache[request] {
            return cached
        }

        try Task.checkCancellation()
        let response = try await caller.call(
            YouTubeRecommendationCallableRequest(request: request)
        )
        try Task.checkCancellation()

        let videos = response.videos
        cache[request] = videos
        return videos
    }
}
