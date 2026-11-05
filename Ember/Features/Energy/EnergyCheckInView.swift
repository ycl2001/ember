import SwiftUI

/// Member 2 owns this file. Save a 1–5 EnergyCheckIn to SwiftData.
struct EnergyCheckInView: View {
    var body: some View {
        FeaturePlaceholderView(
            title: "Daily energy",
            subtitle: "Log today's self-reported energy on a scale of 1 to 5.",
            symbol: "battery.75percent",
            owner: "Member 2"
        )
    }
}
