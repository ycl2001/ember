import Foundation

struct VideoRecommendationRequest: Identifiable, Hashable, Sendable {
    let goalID: UUID
    let taskID: UUID
    let goalTitle: String
    let taskTitle: String

    var id: UUID { taskID }

    var searchQuery: String {
        YouTubeSearchQuery.make(goal: goalTitle, task: taskTitle)
    }
}
