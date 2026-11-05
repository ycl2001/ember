import SwiftUI

/// Member 2 owns this file. Implement topic selection and creation of LearningGoal.
struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    var body: some View {
        FeaturePlaceholderView(
            title: "Learning goals",
            subtitle: "Select a topic and create a learning goal.",
            symbol: "target",
            owner: "Member 2"
        )
    }
}
