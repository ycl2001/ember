import SwiftUI

/// Consumer-facing empty state until the assigned teammate replaces the feature View.
struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let symbol: String
    let owner: String

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: symbol)
                .font(.system(size: 35))
                .foregroundStyle(EmberTheme.primary)
                .padding(25)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 25))
            Text(title)
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundStyle(EmberTheme.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EmberTheme.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
