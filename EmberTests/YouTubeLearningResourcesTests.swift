import Foundation
import Testing
@testable import Ember

@MainActor
struct YouTubeLearningResourcesTests {
    @Test
    func queryUsesTheAssociatedGoalAndTask() {
        let goalID = UUID()
        let taskID = UUID()
        let request = VideoRecommendationRequest(
            goalID: goalID,
            taskID: taskID,
            goalTitle: "  Learn SwiftUI ",
            taskTitle: "Understand   NavigationStack"
        )

        #expect(request.goalID == goalID)
        #expect(request.taskID == taskID)
        #expect(request.searchQuery == "Understand NavigationStack Learn SwiftUI tutorial")
    }

    @Test
    func queryAvoidsRepeatingTheGoal() {
        #expect(
            YouTubeSearchQuery.make(goal: "SwiftUI", task: "SwiftUI NavigationStack")
                == "SwiftUI NavigationStack tutorial"
        )
    }

    @Test
    func similarTaskNamesRemainAssociatedWithTheirOwnGoals() {
        let taskTitle = "Build navigation"
        let first = VideoRecommendationRequest(
            goalID: UUID(),
            taskID: UUID(),
            goalTitle: "Learn SwiftUI",
            taskTitle: taskTitle
        )
        let second = VideoRecommendationRequest(
            goalID: UUID(),
            taskID: UUID(),
            goalTitle: "Learn web development",
            taskTitle: taskTitle
        )

        #expect(first != second)
        #expect(first.searchQuery == "Build navigation Learn SwiftUI tutorial")
        #expect(second.searchQuery == "Build navigation Learn web development tutorial")
    }

    @Test
    func renamingATaskInvalidatesItsRequestCacheKey() {
        let goalID = UUID()
        let taskID = UUID()
        let original = VideoRecommendationRequest(
            goalID: goalID,
            taskID: taskID,
            goalTitle: "Learn SwiftUI",
            taskTitle: "Navigation"
        )
        let renamed = VideoRecommendationRequest(
            goalID: goalID,
            taskID: taskID,
            goalTitle: "Learn SwiftUI",
            taskTitle: "Understand NavigationStack"
        )
        let cache = [original: 1]

        #expect(original.id == renamed.id)
        #expect(original != renamed)
        #expect(cache[renamed] == nil)
    }

    @Test(arguments: [
        "Watch video on IAM",
        "Check VID before class",
        "ViDeO",
        "vid"
    ])
    func detectsStandaloneVideoKeywordsCaseInsensitively(notes: String) {
        #expect(TaskVideoReference.detect(in: notes) == .mentioned)
    }

    @Test(arguments: [
        "",
        "Review chapter 3",
        "Individual study",
        "provide examples",
        "video2",
        "avid learner"
    ])
    func ignoresEmptyNotesAndUnrelatedSubstrings(notes: String) {
        #expect(TaskVideoReference.detect(in: notes) == nil)
    }

    @Test(arguments: [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=43s",
        "https://youtu.be/dQw4w9WgXcQ?t=43",
        "https://youtube.com/shorts/dQw4w9WgXcQ?feature=share"
    ])
    func detectsSupportedYouTubeLinks(notes: String) {
        guard case .linked(let url) = TaskVideoReference.detect(in: notes) else {
            Issue.record("Expected a linked video")
            return
        }

        #expect(url.absoluteString == notes)
    }

    @Test(arguments: [
        "https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
        "https://notyoutube.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/watch?v=too-short",
        "https://youtu.be/bad/path/here",
        "https://youtube.com/shorts/invalid",
        "http://youtube.com/watch?v=dQw4w9WgXcQ"
    ])
    func rejectsMalformedOrMisleadingYouTubeLinks(notes: String) {
        #expect(TaskVideoReference.detect(in: notes) == nil)
    }

    @Test
    func changingNotesUpdatesTheDetectedIndicator() {
        #expect(TaskVideoReference.detect(in: "Review chapter 3") == nil)
        #expect(TaskVideoReference.detect(in: "Review the video") == .mentioned)

        guard case .linked = TaskVideoReference.detect(
            in: "Use https://youtu.be/dQw4w9WgXcQ?t=90"
        ) else {
            Issue.record("Expected edited notes to expose their linked video")
            return
        }
    }

    @Test
    func detectingAnIndicatorDoesNotRequestRecommendations() async {
        let service = MockYouTubeService(behavior: .empty)

        _ = TaskVideoReference.detect(in: "Watch video before class")

        #expect(await service.callCount == 0)
    }

    @Test
    func decodesOfficialVideoMetadataResponse() throws {
        let data = Data(
            """
            {
              "items": [{
                "id": "dQw4w9WgXcQ",
                "snippet": {
                  "title": "NavigationStack basics",
                  "description": "00:00 Intro\\n03:20 NavigationStack basics\\n08:45 Passing data",
                  "channelTitle": "Swift Lessons",
                  "thumbnails": {
                    "medium": { "url": "https://example.com/thumb.jpg" }
                  }
                },
                "contentDetails": { "duration": "PT12M5S" }
              }]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(YouTubeVideoListResponse.self, from: data)

        #expect(response.videos.count == 1)
        #expect(response.videos.first?.channelTitle == "Swift Lessons")
        #expect(response.videos.first?.durationSeconds == 725)
        #expect(response.videos.first?.chapters.count == 3)
    }

    @Test(arguments: [
        ("PT1H2M3S", 3_723),
        ("PT15M", 900),
        ("P1DT1S", 86_401)
    ])
    func parsesISO8601Durations(value: String, expected: Int) {
        #expect(YouTubeDurationParser.seconds(from: value) == expected)
    }

    @Test(arguments: ["", "15M", "PT", "PT1X", "P1M"])
    func rejectsMalformedDurations(value: String) {
        #expect(YouTubeDurationParser.seconds(from: value) == nil)
    }

    @Test
    func extractsOnlyValidCreatorTimestamps() {
        let chapters = YouTubeChapterParser.chapters(
            in: """
            00:00 Introduction
            03:20 - NavigationStack basics
            08:75 Invalid seconds
            not a chapter
            10:00 Passing data
            40:00 Beyond the video
            """,
            durationSeconds: 1_800
        )

        #expect(chapters.map(\.startSeconds) == [0, 200, 600])
        #expect(chapters.last?.title == "Passing data")
    }

    @Test
    func missingOrMalformedChapterListsAreNotTrusted() {
        #expect(YouTubeChapterParser.chapters(in: "03:20 A timestamp mention").isEmpty)
        #expect(
            YouTubeChapterParser.chapters(
                in: "00:00 Intro\n00:05 Too short\nnot-a-time Topic"
            ).isEmpty
        )
    }

    @Test
    func relevantChapterUsesCreatorMetadata() {
        let chapters = [
            YouTubeChapter(startSeconds: 0, title: "Introduction"),
            YouTubeChapter(startSeconds: 200, title: "NavigationStack basics"),
            YouTubeChapter(startSeconds: 525, title: "Passing data")
        ]

        let suggestion = YouTubeChapterParser.suggestedChapter(
            in: chapters,
            goal: "Learn SwiftUI",
            task: "Understand NavigationStack"
        )

        #expect(suggestion?.startSeconds == 200)
    }

    @Test
    func lowConfidenceChapterFallsBackToVideoStart() {
        let suggestion = YouTubeChapterParser.suggestedChapter(
            in: [YouTubeChapter(startSeconds: 200, title: "Animations and transitions")],
            goal: "Learn SwiftUI",
            task: "Understand NavigationStack"
        )

        #expect(suggestion == nil)
    }

    @Test
    func validatesVideoIDsAndBuildsTimestampURL() {
        #expect(YouTubeVideoURLBuilder.isValidVideoID("dQw4w9WgXcQ"))
        #expect(!YouTubeVideoURLBuilder.isValidVideoID("bad/id"))
        let url = YouTubeVideoURLBuilder.url(videoID: "dQw4w9WgXcQ", startSeconds: 200)
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        #expect(components?.queryItems?.contains(URLQueryItem(name: "v", value: "dQw4w9WgXcQ")) == true)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "t", value: "200s")) == true)
    }

    @Test
    func emptyAndFailureResponsesBecomeNonBlockingStates() async {
        let request = request()
        let emptyModel = VideoRecommendationViewModel(
            request: request,
            service: MockYouTubeService(behavior: .empty)
        )
        await emptyModel.load()
        #expect(emptyModel.state == .empty)

        let failureModel = VideoRecommendationViewModel(
            request: request,
            service: MockYouTubeService(behavior: .failure)
        )
        await failureModel.load()
        guard case .failed = failureModel.state else {
            Issue.record("Expected a visible failure state")
            return
        }
    }

    @Test
    func cancellationDoesNotBecomeAnError() async {
        let viewModel = VideoRecommendationViewModel(
            request: request(),
            service: MockYouTubeService(behavior: .suspend)
        )
        let loadTask = Task { await viewModel.load() }
        await Task.yield()
        loadTask.cancel()
        await loadTask.value

        #expect(viewModel.state == .idle)
    }

    @Test
    func repeatedLoadsDoNotDuplicateRequests() async {
        let service = MockYouTubeService(behavior: .empty)
        let viewModel = VideoRecommendationViewModel(request: request(), service: service)

        await viewModel.load()
        await viewModel.load()

        #expect(await service.callCount == 1)
    }

    private func request() -> VideoRecommendationRequest {
        VideoRecommendationRequest(
            goalID: UUID(),
            taskID: UUID(),
            goalTitle: "Learn SwiftUI",
            taskTitle: "Understand NavigationStack"
        )
    }
}

private actor MockYouTubeService: YouTubeServing {
    enum Behavior: Sendable {
        case empty
        case failure
        case suspend
    }

    private(set) var callCount = 0
    private let behavior: Behavior

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func recommendations(for request: VideoRecommendationRequest) async throws -> [YouTubeVideo] {
        callCount += 1
        switch behavior {
        case .empty:
            return []
        case .failure:
            throw YouTubeServiceError.unavailable
        case .suspend:
            try await Task.sleep(for: .seconds(30))
            return []
        }
    }
}
