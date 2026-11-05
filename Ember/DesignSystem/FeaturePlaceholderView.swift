import SwiftUI

/// Replace a feature placeholder in its owning file; keep the type name unchanged.
struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let symbol: String
    let owner: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(EmberTheme.primary)
                .padding(26)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 28))
            Text(title)
                .font(.system(size: 29, weight: .medium, design: .serif))
                .foregroundStyle(EmberTheme.primary)
            Text(subtitle)
                .foregroundStyle(EmberTheme.muted)
                .multilineTextAlignment(.center)
            Text("Assigned to: \(owner)")
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white, in: Capsule())
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EmberTheme.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
