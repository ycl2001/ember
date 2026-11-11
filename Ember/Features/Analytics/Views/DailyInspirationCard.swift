import SwiftUI

struct DailyInspirationCard: View {
    let quote: DailyInspiration.Quote

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title3)
                .foregroundStyle(EmberTheme.primary)
                .frame(width: 44, height: 44)
                .background(EmberTheme.mint, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text("Daily Inspiration")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(EmberTheme.muted)
                    .accessibilityAddTraits(.isHeader)

                Text("“\(quote.text)”")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(EmberTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EmberTheme.muted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }
}
