import SwiftUI

/// Member 5 owns this file. Save SessionReflection after a focus session.
struct ReflectionView: View {
    @State private var viewModel = ReflectionViewModel()
    var body: some View {
        FeaturePlaceholderView(
            title: "Session reflection",
            subtitle: "Record how your energy changed during the task.",
            symbol: "heart.text.square",
            owner: "Member 5"
        )
    }
}
