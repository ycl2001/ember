import SwiftUI

/// Member 5 owns this file. Show real SwiftData records in Swift Charts.
struct AnalyticsView: View {
    @State private var viewModel = AnalyticsViewModel()
    var body: some View {
        FeaturePlaceholderView(
            title: "Energy insights",
            subtitle: "Visualise tasks completed and self-reported energy change.",
            symbol: "chart.xyaxis.line",
            owner: "Member 5"
        )
    }
}
