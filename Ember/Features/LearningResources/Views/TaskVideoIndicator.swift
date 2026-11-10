import SwiftUI

struct TaskVideoIndicator: View {
    let reference: TaskVideoReference
    let taskTitle: String
    var onDark = false
    let onFindVideo: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch reference {
        case .mentioned:
            Button(action: onFindVideo) {
                Image(systemName: "play.rectangle")
                    .font(.subheadline)
                    .foregroundStyle(onDark ? EmberTheme.mint : EmberTheme.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Find learning video for \(taskTitle)")
            .accessibilityHint("Shows video recommendations")
        case .linked(let url):
            Button {
                openURL(url)
            } label: {
                Image(systemName: "play.rectangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(onDark ? EmberTheme.mint : EmberTheme.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open linked video for \(taskTitle)")
            .accessibilityHint("Opens YouTube")
        }
    }
}
