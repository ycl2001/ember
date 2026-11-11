import SwiftUI
import SwiftData

/// Member 2 owns this file. Saves a 1-5 EnergyCheckIn to SwiftData.
/// Layout follows the Post Session Reflection design.
struct EnergyCheckInView: View {
    private let onContinueLearning: () -> Void
    private let onTakeBreak: () -> Void
    private let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EnergyCheckIn.createdAt, order: .reverse) private var checkIns: [EnergyCheckIn]
    @Query(sort: \LearningGoal.createdAt, order: .reverse) private var goals: [LearningGoal]
    @State private var viewModel = EnergyCheckInViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Each closure runs after the check-in is saved, so the parent can navigate.
    init(
        onContinueLearning: @escaping () -> Void = {},
        onTakeBreak: @escaping () -> Void = {},
        onFinish: @escaping () -> Void = {}
    ) {
        self.onContinueLearning = onContinueLearning
        self.onTakeBreak = onTakeBreak
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowTopBar(
                title: "Energy Check-In",
                leadingSymbol: "xmark",
                showsClose: false,
                centersTitle: true,
                onLeading: { dismiss() }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sessionCard

                    FlowTitle(
                        title: "How did this session feel?",
                        subtitle: "Calibrate your cognitive rhythm to sustain momentum without exhaustion."
                    )

                    cognitiveLoadSection
                    energyCard
                    helpersSection
                    quoteCard
                    nextSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(FlowPalette.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear {
            viewModel.loadPrevious(from: checkIns)
        }
    }

    // MARK: Top card

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FlowPill(text: "DAILY CHECK-IN",
                         background: FlowPalette.mint,
                         foreground: FlowPalette.mintText,
                         showsDot: true)
                Spacer()
                Text(Date.now, format: .dateTime.day().month(.abbreviated))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(FlowPalette.secondaryInk)
            }

            Text(goals.first?.topic ?? "Today's learning")
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(FlowPalette.ink)

            HStack(spacing: 8) {
                Label("Focus Rhythm", systemImage: "leaf.fill")
                    .foregroundStyle(FlowPalette.mintText)
                Circle()
                    .fill(FlowPalette.chip)
                    .frame(width: 5, height: 5)
                Label(viewModel.cadenceLabel, systemImage: "water.waves")
                    .foregroundStyle(FlowPalette.brown)
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Cognitive load

    private var cognitiveLoadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FlowSectionLabel(text: "Session cognitive load")
                Spacer()
                Text("\(viewModel.cognitiveLoad == nil ? 0 : 1) of 3 Selected")
                    .font(.footnote)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }

            ForEach(CognitiveLoad.allCases) { load in
                loadCard(load)
            }
        }
    }

    private func loadCard(_ load: CognitiveLoad) -> some View {
        let isSelected = viewModel.cognitiveLoad == load
        let iconBackground: Color = isSelected ? FlowPalette.orange : FlowPalette.chip
        let badgeColors = badgeColors(for: load)

        return Button {
            viewModel.cognitiveLoad = load
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: load.symbol)
                    .font(.title3)
                    .foregroundStyle(FlowPalette.ink)
                    .frame(width: 52, height: 52)
                    .background(iconBackground, in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(load.title)
                            .font(.headline)
                            .foregroundStyle(FlowPalette.ink)
                        Spacer(minLength: 8)
                        FlowPill(text: load.badge,
                                 background: badgeColors.background,
                                 foreground: badgeColors.foreground)
                    }
                    Text(load.detail)
                        .font(.subheadline)
                        .foregroundStyle(FlowPalette.secondaryInk)
                        .multilineTextAlignment(.leading)
                }
            }
            .flowSelectableInverted(selected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func badgeColors(for load: CognitiveLoad) -> (background: Color, foreground: Color) {
        switch load {
        case .challenging: return (FlowPalette.redSoft, FlowPalette.red)
        case .balanced: return (FlowPalette.peach, FlowPalette.brown)
        case .effortless: return (FlowPalette.chip, FlowPalette.secondaryInk)
        }
    }

    // MARK: Energy

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            FlowTitle(
                title: "How much energy do you have now?",
                subtitle: "Tap to select your current self-reported energy:",
                compact: true
            )

            LazyVGrid(columns: energyColumns, spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    levelTile(level)
                }
            }

            comparisonCard
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func levelTile(_ level: Int) -> some View {
        let isSelected = viewModel.selectedLevel == level
        let label = EnergyCheckInViewModel.label(for: level)

        return Button {
            viewModel.select(level)
        } label: {
            VStack(spacing: 8) {
                Text("\(level)")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(FlowPalette.ink)
                Circle()
                    .fill(EmberEnergyScale.color(for: level) ?? FlowPalette.secondaryInk)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().stroke(FlowPalette.ink, lineWidth: 1)
                    }
                Text(label)
                    .font(.footnote.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? FlowPalette.ink : FlowPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? FlowPalette.chip : FlowPalette.card,
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Energy \(level), \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var energyColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 5
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if let previous = viewModel.previousLevel {
                        Text("Before: \(previous)/5 → After: \(viewModel.selectedLevel)/5")
                    } else {
                        Text("Now: \(viewModel.selectedLevel)/5")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FlowPalette.ink)

                Spacer(minLength: 8)

                FlowPill(text: viewModel.changeLabel,
                         background: FlowPalette.peach,
                         foreground: FlowPalette.brown)
            }

            Text(viewModel.changeMessage)
                .font(.subheadline)
                .foregroundStyle(FlowPalette.secondaryInk)
        }
        .flowCard()
    }

    // MARK: Helpers and quote

    private var helpersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(FlowPalette.orange)
                FlowSectionLabel(text: "What helped your session flow?")
            }

            WrappingLayout(spacing: 8) {
                ForEach(EnergyCheckInViewModel.helperOptions, id: \.self) { helper in
                    FlowChip(
                        title: helper,
                        showsCheck: true,
                        isSelected: viewModel.flowHelpers.contains(helper)
                    ) {
                        viewModel.toggleHelper(helper)
                    }
                }
            }
        }
    }

    private var quoteCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max")
                .font(.title3)
                .foregroundStyle(FlowPalette.brown)
                .frame(width: 48, height: 48)
                .background(FlowPalette.peach.opacity(0.6), in: Circle())

            Text("“Small, regular completions protect long-term mental vigor far better than heroic single days.”")
                .font(.system(.callout, design: .serif))
                .italic()
                .foregroundStyle(FlowPalette.secondaryInk)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Next actions

    private var nextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowSectionLabel(text: "What would you like to do next?")

            actionCard(
                title: "Continue Learning",
                subtitle: "Start next 15-min practice set or review",
                fill: FlowPalette.orange,
                leadingSymbol: "play.fill",
                trailingSymbol: "arrow.right"
            ) {
                complete(onContinueLearning)
            }

            actionCard(
                title: "Take a Restorative Break",
                subtitle: "Log progress, rest eyes & refresh your focus",
                fill: FlowPalette.mint,
                leadingSymbol: "pause.fill",
                trailingSymbol: "moon"
            ) {
                complete(onTakeBreak)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                complete(onFinish)
            } label: {
                Label("Save & Return to Dashboard", systemImage: "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FlowPalette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionCard(
        title: String,
        subtitle: String,
        fill: Color,
        leadingSymbol: String,
        trailingSymbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: leadingSymbol)
                    .font(.title3)
                    .foregroundStyle(FlowPalette.ink)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.6), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(FlowPalette.ink)

                Spacer(minLength: 0)

                Image(systemName: trailingSymbol)
                    .foregroundStyle(FlowPalette.ink)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    /// Saves the check-in, then runs the chosen action and closes the screen.
    private func complete(_ action: () -> Void) {
        viewModel.save(in: modelContext)
        guard viewModel.didSave else { return }
        action()
        dismiss()
    }
}

private extension View {
    /// Post Session Reflection style: the selected card is grey, the others are white.
    func flowSelectableInverted(selected: Bool) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? FlowPalette.surface : FlowPalette.card,
                        in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(selected ? 0 : 0.05), radius: 6, y: 2)
    }
}

#Preview {
    EnergyCheckInView()
        .modelContainer(for: [EnergyCheckIn.self, LearningGoal.self], inMemory: true)
}
