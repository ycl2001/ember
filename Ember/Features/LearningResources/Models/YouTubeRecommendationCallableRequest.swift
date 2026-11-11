import Foundation

struct YouTubeRecommendationCallableRequest: Encodable, Equatable, Sendable {
    let goal: String
    let task: String
    let q: String
    let maxResults: Int

    init(request: VideoRecommendationRequest, maxResults: Int = 5) {
        goal = request.goalTitle
        task = request.taskTitle
        q = request.searchQuery
        self.maxResults = maxResults
    }
}
