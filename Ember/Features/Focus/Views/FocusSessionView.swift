import SwiftUI

/// Member 4 owns this file. Track focus time in a FocusSession record.
struct FocusSessionView: View {
    @State private var viewModel = FocusSessionViewModel()
    var body: some View {
        FeaturePlaceholderView(
            title: "Focus session",
            subtitle: "Start, pause, resume and finish a learning session.",
            symbol: "timer",
            owner: "Member 4"
        )
    }
}
