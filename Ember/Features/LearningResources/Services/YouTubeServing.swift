import Foundation

protocol YouTubeServing: Sendable {
    func recommendations(for request: VideoRecommendationRequest) async throws -> [YouTubeVideo]
}

enum YouTubeServiceError: LocalizedError, Equatable {
    case notConfigured
    case invalidRequest
    case invalidResponse
    case unavailable
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Video recommendations aren't configured for this build. Your checklist is still available."
        case .invalidRequest:
            "This learning goal or task can't be used for video recommendations."
        case .invalidResponse:
            "YouTube returned an unexpected response. Please try again later."
        case .unavailable:
            "Video recommendations couldn't be reached. Check your connection and try again."
        case .quotaExceeded:
            "Video recommendations have reached today's limit. Please try again tomorrow."
        }
    }
}
