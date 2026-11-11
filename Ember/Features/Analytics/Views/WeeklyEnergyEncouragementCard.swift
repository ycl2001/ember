import SwiftUI

struct WeeklyEnergyEncouragementCard: View {
    let encouragement: WeeklyEnergyEncouragement

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    icon
                    copy
                }

                VStack(alignment: .leading, spacing: 12) {
                    icon
                    copy
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Average after-session energy (1–5)")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(EmberTheme.muted)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(encouragement.metricValue)
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)

                    if encouragement.average != nil {
                        Text("/ 5")
                            .font(.subheadline)
                            .foregroundStyle(EmberTheme.muted)
                    }
                }

                Text(encouragement.observationNote)
                    .font(.footnote)
                    .foregroundStyle(EmberTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EmberTheme.surface, in: .rect(cornerRadius: 14))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.muted.opacity(0.1), in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }

    private var icon: some View {
        Image(systemName: encouragement.symbol)
            .font(.title3)
            .foregroundStyle(EmberTheme.primary)
            .frame(width: 44, height: 44)
            .background(EmberTheme.mint, in: .rect(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(encouragement.title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(EmberTheme.primary)
                .accessibilityAddTraits(.isHeader)

            Text(encouragement.message)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
