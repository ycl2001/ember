import Foundation

/// Calls an Ember-owned proxy. The proxy, not the app, holds the YouTube API key.
actor YouTubeProxyService: YouTubeServing {
    private let baseURL: URL
    private let session: URLSession
    private var cache: [VideoRecommendationRequest: [YouTubeVideo]] = [:]

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func recommendations(for request: VideoRecommendationRequest) async throws -> [YouTubeVideo] {
        if let cached = cache[request] {
            return cached
        }
        try Task.checkCancellation()

        guard var components = URLComponents(
            url: baseURL.appending(path: "v1/youtube/recommendations"),
            resolvingAgainstBaseURL: false
        ) else {
            throw YouTubeServiceError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "goal", value: request.goalTitle),
            URLQueryItem(name: "task", value: request.taskTitle),
            URLQueryItem(name: "q", value: request.searchQuery),
            URLQueryItem(name: "maxResults", value: "5")
        ]
        guard let url = components.url else { throw YouTubeServiceError.invalidResponse }

        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 15
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: urlRequest)
            try Task.checkCancellation()
            guard let httpResponse = response as? HTTPURLResponse else {
                throw YouTubeServiceError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200..<300:
                let videos = try JSONDecoder().decode(YouTubeVideoListResponse.self, from: data).videos
                cache[request] = videos
                return videos
            case 429:
                throw YouTubeServiceError.quotaExceeded
            default:
                throw YouTubeServiceError.unavailable
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as YouTubeServiceError {
            throw error
        } catch is DecodingError {
            throw YouTubeServiceError.invalidResponse
        } catch {
            throw YouTubeServiceError.unavailable
        }
    }
}
