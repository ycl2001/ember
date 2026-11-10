import SwiftUI

struct VideoRecommendationCard: View {
    let video: YouTubeVideo
    let suggestedChapter: YouTubeChapter?

    @Environment(\.openURL) private var openURL
    @State private var selectedStartSeconds = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 7) {
                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(video.channelTitle)
                    if let durationText = video.durationText {
                        Text(durationText)
                            .accessibilityLabel("Duration \(durationText)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)

                chapterControl

                Button("Watch video", systemImage: "arrow.up.right.square", action: watchVideo)
                    .buttonStyle(.borderedProminent)
                    .tint(EmberTheme.primary)
                    .frame(minHeight: 44)
            }
            .padding([.horizontal, .bottom], 16)
        }
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        .onAppear {
            if let suggestedChapter {
                selectedStartSeconds = suggestedChapter.startSeconds
            }
        }
    }

    private var thumbnail: some View {
        AsyncImage(url: video.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    EmberTheme.mint
                    Image(systemName: "play.rectangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(EmberTheme.primary)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chapterControl: some View {
        if video.chapters.isEmpty {
            Label("No verified timestamp available — Watch from beginning", systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(EmberTheme.muted)
        } else {
            Menu {
                Button("Watch from beginning") { selectedStartSeconds = 0 }
                ForEach(video.chapters) { chapter in
                    Button("\(chapter.timestampText) — \(chapter.title)") {
                        selectedStartSeconds = chapter.startSeconds
                    }
                }
            } label: {
                Label(selectedChapterLabel, systemImage: "clock.arrow.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityHint("Creator-provided chapters. Choose where the video starts.")

            if suggestedChapter != nil {
                Text("Suggested from creator-provided chapter metadata.")
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
            } else {
                Text("No sufficiently relevant chapter was found. Watch from the beginning or choose a creator-provided chapter.")
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
            }
        }
    }

    private var selectedChapterLabel: String {
        guard selectedStartSeconds > 0,
              let chapter = video.chapters.first(where: { $0.startSeconds == selectedStartSeconds }) else {
            return "Watch from beginning"
        }
        return "Start at \(chapter.timestampText) — \(chapter.title)"
    }

    private func watchVideo() {
        guard let url = YouTubeVideoURLBuilder.url(
            videoID: video.id,
            startSeconds: selectedStartSeconds
        ) else { return }
        openURL(url)
    }
}
