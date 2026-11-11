import Foundation
import Observation

enum VideoRecommendationState: Equatable {
    case idle
    case loading
    case loaded([YouTubeVideo])
    case empty
    case failed(String)
}

@MainActor
@Observable
final class VideoRecommendationViewModel {
    let request: VideoRecommendationRequest
    private(set) var state: VideoRecommendationState = .idle

    private let service: any YouTubeServing
    private var hasRequested = false

    init(request: VideoRecommendationRequest, service: any YouTubeServing) {
        self.request = request
        self.service = service
    }

    func load(forceRefresh: Bool = false) async {
        guard forceRefresh || !hasRequested else { return }
        hasRequested = true
        state = .loading

        do {
            let videos = try await service.recommendations(for: request)
            try Task.checkCancellation()
            state = videos.isEmpty ? .empty : .loaded(videos)
        } catch is CancellationError {
            hasRequested = false
            state = .idle
        } catch {
            state = .failed(
                (error as? LocalizedError)?.errorDescription
                    ?? "Video recommendations couldn't be loaded. Please try again."
            )
        }
    }

    func suggestedChapter(for video: YouTubeVideo) -> YouTubeChapter? {
        YouTubeChapterParser.suggestedChapter(
            in: video.chapters,
            goal: request.goalTitle,
            task: request.taskTitle
        )
    }
}
