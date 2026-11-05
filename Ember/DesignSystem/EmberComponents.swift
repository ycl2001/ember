import SwiftUI

struct EmberPageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(EmberTheme.muted)
            Text(title)
                .font(.system(size: 33, weight: .medium, design: .serif))
                .tracking(-0.6)
                .foregroundStyle(EmberTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmberActionRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(EmberTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EmberTheme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
    }
}

struct EmberMetricCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(EmberTheme.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(EmberTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
