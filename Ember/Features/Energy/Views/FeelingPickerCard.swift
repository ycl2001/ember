import SwiftUI
import SwiftData

/// "How are you feeling" card with three options. Tapping one saves an EnergyCheckIn,
/// so the Energy flow state card on Profile updates straight away.
/// Highlights the option that matches today's latest check-in.
struct FeelingPickerCard: View {
    private let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EnergyCheckIn.createdAt, order: .reverse) private var checkIns: [EnergyCheckIn]
    @State private var viewModel = EnergyCheckInViewModel()

    /// `onSaved` runs after a new check-in is saved.
    init(onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
    }

    /// The option matching the latest check-in, only if it was logged today.
    private var activeOption: FeelingOption? {
        guard let latest = checkIns.first,
              Calendar.current.isDateInToday(latest.createdAt) else { return nil }
        return FeelingOption.matching(level: latest.level)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(FlowPalette.brown)
                Text("HOW ARE YOU FEELING")
                    .font(.headline)
                    .tracking(0.6)
                    .foregroundStyle(FlowPalette.ink)
            }

            HStack(spacing: 10) {
                ForEach(FeelingOption.allCases) { option in
                    tile(option)
                }
            }

            statusText
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
        .animation(.easeInOut(duration: 0.15), value: activeOption)
    }

    // MARK: Tiles

    private func tile(_ option: FeelingOption) -> some View {
        let isSelected = activeOption == option
        let selectedFill: Color = option == .highFocus ? FlowPalette.orange : FlowPalette.forest
        let titleColor: Color = isSelected ? Color.white : FlowPalette.ink
        let subtitleColor: Color = isSelected ? Color.white.opacity(0.9) : FlowPalette.secondaryInk
        let fill: Color = isSelected ? selectedFill : FlowPalette.card
        let border: Color = isSelected ? FlowPalette.ink : FlowPalette.chip

        return Button {
            if viewModel.record(option, latest: checkIns.first, in: modelContext) {
                onSaved()
            }
        } label: {
            VStack(spacing: 8) {
                tileIcon(option, isSelected: isSelected)

                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(option.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 4)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(border, lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title), \(option.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tileIcon(_ option: FeelingOption, isSelected: Bool) -> some View {
        let selectedForeground: Color = option == .highFocus ? FlowPalette.brown : FlowPalette.forest
        let foreground: Color = isSelected ? selectedForeground : FlowPalette.secondaryInk
        let background: Color = isSelected ? Color.white : FlowPalette.chip

        return Image(systemName: option.symbol)
            .font(.title3)
            .foregroundStyle(foreground)
            .frame(width: 48, height: 48)
            .background(background, in: Circle())
    }

    // MARK: Status

    @ViewBuilder
    private var statusText: some View {
        if let message = viewModel.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let message = viewModel.savedMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(FlowPalette.mintText)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EnergyFlowStateCard()
        FeelingPickerCard()
    }
    .padding()
    .background(FlowPalette.background)
    .modelContainer(for: EnergyCheckIn.self, inMemory: true)
}
