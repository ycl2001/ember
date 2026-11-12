import SwiftUI

struct VideoRecommendationSheet: View {
    let request: VideoRecommendationRequest

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VideoRecommendationViewModel

    init(
        request: VideoRecommendationRequest,
        service: any YouTubeServing = YouTubeServiceFactory.makeDefault()
    ) {
        self.request = request
        _viewModel = State(initialValue: VideoRecommendationViewModel(request: request, service: service))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Finding relevant videos…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let videos):
                    results(videos)
                case .empty:
                    unavailable(
                        title: "No videos found",
                        detail: "Try again later or keep learning with your checklist.",
                        symbol: "play.slash"
                    )
                case .failed(let message):
                    unavailable(title: "Videos unavailable", detail: message, symbol: "wifi.exclamationmark")
                }
            }
            .background(EmberTheme.canvas.ignoresSafeArea())
            .navigationTitle("Learning videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .preferredColorScheme(.light)
        .task { await viewModel.load() }
    }

    private func results(_ videos: [YouTubeVideo]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(request.goalTitle)
                        .font(.footnote)
                        .foregroundStyle(EmberTheme.muted)
                    Text(request.taskTitle)
                        .font(.system(.title2, design: .serif, weight: .medium))
                        .foregroundStyle(EmberTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                ForEach(videos) { video in
                    VideoRecommendationCard(
                        video: video,
                        suggestedChapter: viewModel.suggestedChapter(for: video)
                    )
                }
            }
            .padding(20)
        }
    }

    private func unavailable(title: String, detail: String, symbol: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        } actions: {
            Button("Try again") {
                Task { await viewModel.load(forceRefresh: true) }
            }
            .buttonStyle(.borderedProminent)
            .tint(EmberTheme.primary)
        }
    }
}
