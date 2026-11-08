import SwiftUI

// MARK: - Step 1: Focus & Goals

struct OnboardingGoalsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FlowTitle(
                title: "What are you striving to learn?",
                subtitle: "Momentum breaks large curricula into friction-free daily stepping stones calibrated to your baseline stamina."
            )

            VStack(spacing: 12) {
                ForEach(LearningCategory.allCases) { category in
                    categoryCard(category)
                }
            }

            customTopicSection
            commitmentSection
        }
    }

    private func categoryCard(_ category: LearningCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                viewModel.selectedCategory = category
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(category.title)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(FlowPalette.ink)
                        if isSelected {
                            FlowPill(text: "Primary Focus",
                                     background: FlowPalette.mint,
                                     foreground: FlowPalette.mintText,
                                     showsDot: true)
                        }
                        Spacer(minLength: 0)
                        FlowCheck(isSelected: isSelected)
                    }
                    Text(category.summary)
                        .font(.subheadline)
                        .foregroundStyle(FlowPalette.secondaryInk)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)

            WrappingLayout(spacing: 8) {
                ForEach(category.topics, id: \.self) { topic in
                    FlowTag(title: topic, isSelected: viewModel.isSelected(topic: topic)) {
                        viewModel.toggleTopic(topic, in: category)
                    }
                }
            }
        }
        .flowSelectable(selected: isSelected)
    }

    private var customTopicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewModel.isAddingCustomTopic.toggle()
            } label: {
                Label("Add custom topic or syllabus", systemImage: "plus.circle")
                    .font(.headline)
                    .foregroundStyle(FlowPalette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if viewModel.isAddingCustomTopic {
                HStack(spacing: 8) {
                    TextField("e.g. Network Fundamentals", text: $viewModel.customTopic)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { viewModel.addCustomTopic() }

                    Button("Add") { viewModel.addCustomTopic() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FlowPalette.forest)
                        .disabled(!viewModel.canAddCustomTopic)
                }
                .padding(14)
                .background(FlowPalette.card, in: RoundedRectangle(cornerRadius: 12))
            }

            if !viewModel.customTopics.isEmpty {
                WrappingLayout(spacing: 8) {
                    ForEach(viewModel.customTopics, id: \.self) { topic in
                        FlowTag(title: topic, isSelected: viewModel.isSelected(topic: topic)) {
                            viewModel.toggleTopic(topic, in: viewModel.selectedCategory)
                        }
                    }
                }
            }
        }
    }

    private var commitmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowTitle(
                title: "Daily Focus Commitment",
                subtitle: "Paced deliberate intervals guard against burnout.",
                compact: true
            )

            ForEach(DailyCommitment.allCases) { option in
                commitmentCard(option)
            }
        }
        .padding(.top, 8)
    }

    private func commitmentCard(_ option: DailyCommitment) -> some View {
        let isSelected = viewModel.commitment == option

        return Button {
            viewModel.commitment = option
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("\(option.title) (\(option.rangeLabel))")
                        .font(.headline)
                        .foregroundStyle(FlowPalette.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    FlowCheck(isSelected: isSelected, isRadio: true)
                }
                if option.isRecommended {
                    FlowPill(text: "Recommended",
                             background: FlowPalette.peach,
                             foreground: FlowPalette.brown)
                }
                Text(option.detail)
                    .font(.subheadline)
                    .foregroundStyle(FlowPalette.secondaryInk)
                    .multilineTextAlignment(.leading)
            }
            .flowSelectable(selected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Step 2: Circadian Rhythm

struct OnboardingRhythmStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FlowPill(text: "Circadian Resonance",
                     background: FlowPalette.surface,
                     foreground: FlowPalette.ink,
                     systemImage: "moon")

            FlowTitle(
                title: "When is your natural peak energy?",
                subtitle: "Momentum schedules challenging conceptual synthesis into your highest-stamina circadian window."
            )

            VStack(spacing: 12) {
                ForEach(PeakWindow.allCases) { window in
                    windowCard(window)
                }
            }

            drainsSection
            protectorsSection
            dynamicBalanceCard
        }
    }

    // MARK: Peak window cards

    private func windowCard(_ window: PeakWindow) -> some View {
        let isSelected = viewModel.peakWindow == window
        let primary: Color = isSelected ? Color.white : FlowPalette.ink
        let secondary: Color = isSelected ? Color.white.opacity(0.8) : FlowPalette.secondaryInk
        let iconBackground: Color = isSelected ? Color.white.opacity(0.14) : FlowPalette.chip
        let badgeBackground: Color = isSelected ? FlowPalette.mint : FlowPalette.chip
        let badgeText: Color = isSelected ? FlowPalette.mintText : FlowPalette.secondaryInk
        let cardFill: Color = isSelected ? FlowPalette.deep : FlowPalette.surface

        return Button {
            viewModel.peakWindow = window
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: window.symbol)
                    .font(.title3)
                    .foregroundStyle(primary)
                    .frame(width: 44, height: 44)
                    .background(iconBackground, in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(window.title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(primary)
                        .multilineTextAlignment(.leading)
                    Text(window.timeRange)
                        .font(.subheadline)
                        .foregroundStyle(secondary)
                    Text(window.detail)
                        .font(.subheadline)
                        .foregroundStyle(primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    FlowPill(text: window.badge, background: badgeBackground, foreground: badgeText)
                    FlowCheck(isSelected: isSelected, onDark: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Drains

    private var drainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowHeading(title: "What drains your cognitive battery?", systemImage: "battery.25")

            Text("Select friction triggers so Momentum can intentionally micro-chunk these assignments.")
                .font(.subheadline)
                .foregroundStyle(FlowPalette.secondaryInk)

            WrappingLayout(spacing: 10) {
                ForEach(EnergyDrain.allCases) { drain in
                    FlowChip(
                        title: drain.title,
                        systemImage: drain.symbol,
                        tag: drain.tag,
                        tagTint: drain == .debugging ? FlowPalette.orange : FlowPalette.mint,
                        isSelected: viewModel.drains.contains(drain)
                    ) {
                        viewModel.toggleDrain(drain)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: Protectors

    private var protectorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowHeading(title: "Momentum Protectors", systemImage: "shield", trailing: "Adaptive Care")

            protectorCard(
                title: "Micro-Sprint Packaging",
                tag: "8–12m",
                tagBackground: FlowPalette.peach,
                tagForeground: FlowPalette.brown,
                detail: "Break large curricula into bite-sized 8-12 min tasks to prevent overwhelm.",
                isOn: $viewModel.microSprintEnabled
            )

            protectorCard(
                title: "3-Minute Cognitive Reset",
                tag: "Breathe",
                tagBackground: FlowPalette.mint,
                tagForeground: FlowPalette.mintText,
                detail: "Prompt 20-20-20 eye rests & breathing between deep sprints to restore baseline.",
                isOn: $viewModel.cognitiveResetEnabled
            )
        }
        .padding(.top, 8)
    }

    private func protectorCard(
        title: String,
        tag: String,
        tagBackground: Color,
        tagForeground: Color,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(FlowPalette.ink)
                    FlowPill(text: tag, background: tagBackground, foreground: tagForeground)
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(FlowPalette.forest)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var dynamicBalanceCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(FlowPalette.orange)

            (Text("Dynamic Balance: ").bold().foregroundStyle(FlowPalette.ink)
             + Text("High friction tasks paired with your selected peak will trigger automated Pomodoro recalibrations.")
                .foregroundStyle(FlowPalette.secondaryInk))
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Step 3: Adaptive Blueprint

struct OnboardingBlueprintStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FlowPill(text: "Neural Calibration Complete",
                     background: FlowPalette.mint,
                     foreground: FlowPalette.mintText,
                     systemImage: "sparkles")

            VStack(alignment: .leading, spacing: 8) {
                Text("Your stamina-aligned study blueprint is ready.")
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundStyle(FlowPalette.ink)
                subtitleText
            }

            cadenceCard
            protectorsCard
        }
    }

    private var subtitleText: Text {
        Text("Synthesizing your ").foregroundStyle(FlowPalette.secondaryInk)
        + Text("\(viewModel.peakWindow.title) peak").bold().foregroundStyle(FlowPalette.ink)
        + Text(" (\(viewModel.peakWindow.compactRange)) with ").foregroundStyle(FlowPalette.secondaryInk)
        + Text(viewModel.topicsSummary)
            .italic()
            .font(.system(.body, design: .serif))
            .foregroundStyle(FlowPalette.brown)
        + Text(".").foregroundStyle(FlowPalette.secondaryInk)
    }

    // MARK: Target cadence

    private var cadenceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(FlowPalette.orange).frame(width: 8, height: 8)
                FlowSectionLabel(text: "Target cadence: optimal cognitive window")
                Spacer(minLength: 8)
                FlowPill(text: "Active Sync",
                         background: FlowPalette.chip,
                         foreground: FlowPalette.secondaryInk,
                         systemImage: "arrow.triangle.2.circlepath")
            }

            HStack(spacing: 12) {
                statCard(symbol: "clock",
                         label: "Target Sprint",
                         value: "\(viewModel.totalMinutes)",
                         unit: "mins total")
                statCard(symbol: "checkmark.shield",
                         label: "Burnout Risk",
                         value: "\(viewModel.burnoutRiskPercent)%",
                         unit: "balanced")
            }

            FlowSectionLabel(text: "Scheduled micro-tasks for today")
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(viewModel.blueprintBlocks) { block in
                    blockRow(block)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func statCard(symbol: String, label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: symbol)
                .font(.footnote)
                .foregroundStyle(FlowPalette.secondaryInk)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundStyle(FlowPalette.ink)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }
        }
        .flowCard()
    }

    private func blockRow(_ block: BlueprintBlock) -> some View {
        let isBuffer = block.kind == .reset
        let badgeBackground: Color = block.kind == .learn ? FlowPalette.mint : FlowPalette.chip
        let badgeText: Color = block.kind == .learn ? FlowPalette.mintText : FlowPalette.secondaryInk
        let iconBackground: Color = isBuffer ? FlowPalette.brown : FlowPalette.forest

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(for: block.kind))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(iconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(block.title)
                        .font(.headline)
                        .foregroundStyle(FlowPalette.ink)
                        .multilineTextAlignment(.leading)
                    FlowPill(text: block.badge, background: badgeBackground, foreground: badgeText)
                }
                Text(block.detail)
                    .font(.subheadline)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isBuffer ? FlowPalette.chip : FlowPalette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Protectors

    private var protectorsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowHeading(title: "Synthesized Protectors Active", systemImage: "shield")

            ForEach(viewModel.protectors) { item in
                HStack(alignment: .top, spacing: 12) {
                    FlowCheck(isSelected: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FlowPalette.ink)
                        Text(item.detail)
                            .font(.subheadline)
                            .foregroundStyle(FlowPalette.secondaryInk)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlowPalette.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func symbol(for kind: BlueprintBlock.Kind) -> String {
        switch kind {
        case .learn: return "chevron.left.forwardslash.chevron.right"
        case .reset: return "wind"
        case .practice: return "keyboard"
        }
    }
}
