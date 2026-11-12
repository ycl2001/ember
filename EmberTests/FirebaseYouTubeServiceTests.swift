import FirebaseFunctions
import Foundation
import Testing
@testable import Ember

struct FirebaseYouTubeServiceTests {
    @Test
    func sendsExistingGoalAndTaskInputsAndCachesTheResponse() async throws {
        let caller = YouTubeRecommendationCallerStub(
            response: try responseWithOneVideo()
        )
        let service = FirebaseYouTubeService(caller: caller)
        let request = VideoRecommendationRequest(
            goalID: UUID(),
            taskID: UUID(),
            goalTitle: "Learn SwiftUI",
            taskTitle: "Understand NavigationStack"
        )

        let first = try await service.recommendations(for: request)
        let second = try await service.recommendations(for: request)
        let requests = await caller.requests

        #expect(first == second)
        #expect(first.first?.id == "dQw4w9WgXcQ")
        #expect(requests.count == 1)
        #expect(
            requests.first == YouTubeRecommendationCallableRequest(
                request: request
            )
        )
        #expect(requests.first?.q == request.searchQuery)
        #expect(requests.first?.maxResults == 5)
    }

    @Test
    func preservesAnEmptyCallableResponse() async throws {
        let caller = YouTubeRecommendationCallerStub(
            response: YouTubeVideoListResponse(items: [])
        )
        let service = FirebaseYouTubeService(caller: caller)

        let videos = try await service.recommendations(for: request())

        #expect(videos.isEmpty)
    }

    @Test(arguments: [
        (FunctionsErrorCode.invalidArgument, YouTubeServiceError.invalidRequest),
        (FunctionsErrorCode.resourceExhausted, YouTubeServiceError.quotaExceeded),
        (FunctionsErrorCode.dataLoss, YouTubeServiceError.invalidResponse),
        (FunctionsErrorCode.deadlineExceeded, YouTubeServiceError.unavailable),
        (FunctionsErrorCode.unavailable, YouTubeServiceError.unavailable),
        (FunctionsErrorCode.unauthenticated, YouTubeServiceError.unavailable)
    ])
    func mapsCallableErrors(
        code: FunctionsErrorCode,
        expected: YouTubeServiceError
    ) {
        let error = NSError(domain: FunctionsErrorDomain, code: code.rawValue)

        #expect(
            FirebaseYouTubeRecommendationCaller.serviceError(for: error)
                == expected
        )
    }

    @Test
    func mapsNonFirebaseFailuresToUnavailable() {
        let error = URLError(.notConnectedToInternet)

        #expect(
            FirebaseYouTubeRecommendationCaller.serviceError(for: error)
                == .unavailable
        )
    }

    private func request() -> VideoRecommendationRequest {
        VideoRecommendationRequest(
            goalID: UUID(),
            taskID: UUID(),
            goalTitle: "Learn SwiftUI",
            taskTitle: "Understand NavigationStack"
        )
    }

    private func responseWithOneVideo() throws -> YouTubeVideoListResponse {
        let data = Data(
            """
            {
              "items": [{
                "id": "dQw4w9WgXcQ",
                "snippet": {
                  "title": "NavigationStack basics",
                  "description": "A focused tutorial",
                  "channelTitle": "Swift Lessons",
                  "thumbnails": {
                    "medium": {
                      "url": "https://example.com/thumb.jpg"
                    }
                  }
                },
                "contentDetails": {
                  "duration": "PT12M5S"
                }
              }]
            }
            """.utf8
        )
        return try JSONDecoder().decode(
            YouTubeVideoListResponse.self,
            from: data
        )
    }
}

private actor YouTubeRecommendationCallerStub: YouTubeRecommendationCalling {
    private(set) var requests: [YouTubeRecommendationCallableRequest] = []
    private let response: YouTubeVideoListResponse

    init(response: YouTubeVideoListResponse) {
        self.response = response
    }

    func call(
        _ request: YouTubeRecommendationCallableRequest
    ) async throws -> YouTubeVideoListResponse {
        requests.append(request)
        return response
    }
}
