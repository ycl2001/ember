import FirebaseFunctions
import Foundation

protocol YouTubeRecommendationCalling: Sendable {
    func call(
        _ request: YouTubeRecommendationCallableRequest
    ) async throws -> YouTubeVideoListResponse
}

struct FirebaseYouTubeRecommendationCaller: YouTubeRecommendationCalling {
    private let callable: Callable<
        YouTubeRecommendationCallableRequest,
        YouTubeVideoListResponse
    >

    init(
        functions: Functions = Functions.functions(region: "australia-southeast1")
    ) {
        var callable: Callable<
            YouTubeRecommendationCallableRequest,
            YouTubeVideoListResponse
        > = functions.httpsCallable(
            "getYouTubeRecommendations",
            requestAs: YouTubeRecommendationCallableRequest.self,
            responseAs: YouTubeVideoListResponse.self
        )
        callable.timeoutInterval = 20
        self.callable = callable
    }

    func call(
        _ request: YouTubeRecommendationCallableRequest
    ) async throws -> YouTubeVideoListResponse {
        do {
            return try await callable(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch is DecodingError {
            throw YouTubeServiceError.invalidResponse
        } catch {
            throw Self.serviceError(for: error)
        }
    }

    static func serviceError(for error: Error) -> YouTubeServiceError {
        let error = error as NSError
        guard error.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: error.code) else {
            return .unavailable
        }

        switch code {
        case .invalidArgument:
            return .invalidRequest
        case .resourceExhausted:
            return .quotaExceeded
        case .dataLoss:
            return .invalidResponse
        default:
            return .unavailable
        }
    }
}
