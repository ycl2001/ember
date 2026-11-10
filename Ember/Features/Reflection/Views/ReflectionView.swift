import SwiftUI
import SwiftData

/// Post-session reflection for one explicitly selected, persisted focus session.
struct ReflectionView: View {
    let sessionID: UUID?
    let onSaveReturn: () -> Void
    let onRestorativeBreak: () -> Void
    let onContinueLearning: () -> Void

    @State private var viewModel = ReflectionViewModel()

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FocusSession]
    @Query private var tasks: [LearningTask]
    @Query private var checkIns: [EnergyCheckIn]
    @Query private var reflections: [SessionReflection]

    var body: some View {
        Group {
            if let summary = viewModel.summary {
                reflectionForm(summary: summary)
            } else {
                ReflectionUnavailableView()
            }
        }
        .background(EmberTheme.canvas.ignoresSafeArea())
        .navigationTitle("Session reflection")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessionID) {
            viewModel.load(
                sessionID: sessionID,
                sessions: sessions,
                tasks: tasks,
                checkIns: checkIns,
                reflections: reflections
            )
        }
    }

    private func reflectionForm(summary: ReflectionSessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ReflectionIntroView()

                ReflectionSessionSummaryView(
                    taskTitle: summary.taskTitle,
                    durationText: summary.durationText,
                    isComplete: summary.isComplete,
                    energyBefore: viewModel.energyBefore,
                    hadRecordedEnergyBefore: viewModel.hadRecordedEnergyBefore
                )

                ReflectionCognitiveLoadView(
                    selection: viewModel.selectedCognitiveLoad,
                    onSelect: { viewModel.selectedCognitiveLoad = $0 }
                )

                ReflectionEnergyView(viewModel: viewModel)

                ReflectionHelpfulFactorsView(
                    selection: viewModel.selectedHelpfulFactors,
                    notes: $viewModel.notes,
                    onToggle: viewModel.toggle
                )

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ReflectionCompletionActions(
                isEnabled: viewModel.canSave,
                onSaveReturn: { save(then: onSaveReturn) },
                onRestorativeBreak: { save(then: onRestorativeBreak) },
                onContinueLearning: { save(then: onContinueLearning) }
            )
        }
    }

    private func save(then action: () -> Void) {
        guard viewModel.save(in: modelContext) else { return }
        action()
    }
}

private struct ReflectionIntroView: View {
    var body: some View {
        EmberPageHeading(
            eyebrow: "Session complete",
            title: "Notice what shifted.",
            subtitle: "A quick reflection can help you choose a pace that works for you."
        )
    }
}

private struct ReflectionSessionSummaryView: View {
    let taskTitle: String
    let durationText: String
    let isComplete: Bool
    let energyBefore: Int?
    let hadRecordedEnergyBefore: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReflectionSectionHeading(
                title: "Session summary",
                subtitle: "Your completed focus session"
            )

            Label(taskTitle, systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(EmberTheme.primary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(EmberTheme.separator)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    summaryMetric(title: "Focused time", value: durationText)
                    summaryMetric(title: "Status", value: isComplete ? "Complete" : "Ended")
                    summaryMetric(
                        title: "Energy before",
                        value: hadRecordedEnergyBefore ? energyText : "Not recorded"
                    )
                }

                VStack(spacing: 10) {
                    summaryMetric(title: "Focused time", value: durationText)
                    summaryMetric(title: "Status", value: isComplete ? "Complete" : "Ended")
                    summaryMetric(
                        title: "Energy before",
                        value: hadRecordedEnergyBefore ? energyText : "Not recorded"
                    )
                }
            }
        }
        .padding(18)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }

    private var energyText: String {
        guard let energyBefore else { return "Not recorded" }
        return "\(energyBefore) of 5"
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(EmberTheme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EmberTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReflectionCognitiveLoadView: View {
    let selection: ReflectionCognitiveLoad?
    let onSelect: (ReflectionCognitiveLoad) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReflectionSectionHeading(
                title: "How did this session feel?",
                subtitle: "Choose the closest match."
            )

            ForEach(ReflectionCognitiveLoad.allCases) { option in
                let isSelected = selection == option
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(
                                isSelected ? EmberTheme.primary : EmberTheme.mint,
                                in: RoundedRectangle(cornerRadius: 13)
                            )
                            .foregroundStyle(isSelected ? .white : EmberTheme.primary)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(EmberTheme.muted)
                        }
                        .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? EmberTheme.primary : EmberTheme.muted)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(EmberTheme.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                isSelected ? EmberTheme.primary : EmberTheme.separator,
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.title), \(option.subtitle)")
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct ReflectionEnergyView: View {
    @Bindable var viewModel: ReflectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ReflectionSectionHeading(
                title: "How much energy do you have now?",
                subtitle: "Use your own sense of energy, from 1 low to 5 high."
            )

            if !viewModel.hadRecordedEnergyBefore {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First, how much energy did you have before?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EmberTheme.primary)
                    Text("No pre-session check-in was found.")
                        .font(.caption)
                        .foregroundStyle(EmberTheme.muted)

                    EmberEnergyRatingPicker(
                        title: "Energy before",
                        selectedLevel: viewModel.energyBefore,
                        onSelect: { viewModel.energyBefore = $0 }
                    )
                }
            } else if let energyBefore = viewModel.energyBefore {
                Label("Before this session: \(energyBefore) of 5", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EmberTheme.primary)
            }

            EmberEnergyRatingPicker(
                title: "Energy now",
                selectedLevel: viewModel.energyAfter,
                onSelect: { viewModel.energyAfter = $0 }
            )

            if let energySpent = viewModel.energySpent {
                ReflectionEnergyFeedback(energySpent: energySpent)
            }
        }
        .padding(18)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ReflectionEnergyFeedback: View {
    let energySpent: Int

    var body: some View {
        Label(feedback, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .foregroundStyle(EmberTheme.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EmberTheme.mint.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }

    private var feedback: String {
        if energySpent > 0 {
            return "You reported \(energySpent) point\(energySpent == 1 ? "" : "s") less energy afterward."
        }
        if energySpent < 0 {
            let gain = abs(energySpent)
            return "You reported \(gain) point\(gain == 1 ? "" : "s") more energy afterward."
        }
        return "You reported the same energy before and after."
    }

    private var symbol: String {
        if energySpent > 0 { return "arrow.down.right" }
        if energySpent < 0 { return "arrow.up.right" }
        return "arrow.right"
    }
}

private struct ReflectionHelpfulFactorsView: View {
    let selection: Set<ReflectionHelpfulFactor>
    @Binding var notes: String
    let onToggle: (ReflectionHelpfulFactor) -> Void

    private let columns = [GridItem(.adaptive(minimum: 135), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReflectionSectionHeading(
                title: "What helped your session flow?",
                subtitle: "Choose any that fit."
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(ReflectionHelpfulFactor.allCases) { factor in
                    let isSelected = selection.contains(factor)
                    Button {
                        onToggle(factor)
                    } label: {
                        Label(factor.title, systemImage: factor.symbol)
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(
                                isSelected ? EmberTheme.mint : EmberTheme.surface,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .foregroundStyle(EmberTheme.primary)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        isSelected ? EmberTheme.primary : EmberTheme.separator,
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            TextField("Anything else you noticed?", text: $notes, axis: .vertical)
                .font(.body)
                .lineLimit(3...6)
                .padding(12)
                .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(EmberTheme.separator)
                }
                .accessibilityLabel("Anything else you noticed?")
        }
    }
}

private struct ReflectionSectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(EmberTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ReflectionCompletionActions: View {
    let isEnabled: Bool
    let onSaveReturn: () -> Void
    let onRestorativeBreak: () -> Void
    let onContinueLearning: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onSaveReturn) {
                Label("Save & Return", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(.white)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    secondaryButton(
                        title: "Restorative Break",
                        symbol: "leaf",
                        action: onRestorativeBreak
                    )
                    secondaryButton(
                        title: "Continue Learning",
                        symbol: "arrow.right",
                        action: onContinueLearning
                    )
                }

                VStack(spacing: 8) {
                    secondaryButton(
                        title: "Restorative Break",
                        symbol: "leaf",
                        action: onRestorativeBreak
                    )
                    secondaryButton(
                        title: "Continue Learning",
                        symbol: "arrow.right",
                        action: onContinueLearning
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(EmberTheme.canvas)
    }

    private func secondaryButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 13))
                .foregroundStyle(EmberTheme.primary)
        }
    }
}

private struct ReflectionUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Session unavailable", systemImage: "exclamationmark.circle")
        } description: {
            Text("This reflection needs the completed focus session it came from. The session may have been removed.")
        }
    }
}

private enum EmberEnergyRatingPalette {
    static let card = Color.white
    static let selected = EmberTheme.mint
    static let text = EmberTheme.primary
    static let secondaryText = EmberTheme.muted
    static let border = EmberTheme.separator
    static let low = Color(red: 0.15, green: 0.39, blue: 0.92)
    static let lowMedium = Color(red: 1.0, green: 0.57, blue: 0.16)
    static let medium = Color(red: 0.54, green: 0.29, blue: 0.05)
    static let high = Color(red: 0.02, green: 0.12, blue: 0.10)
}

private struct EmberEnergyRatingPicker: View {
    let title: String
    let selectedLevel: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EmberEnergyRatingPalette.text)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    ratingButton(level)
                }
            }
        }
    }

    private func ratingButton(_ level: Int) -> some View {
        let isSelected = selectedLevel == level

        return Button {
            onSelect(level)
        } label: {
            VStack(spacing: 6) {
                Text("\(level)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(EmberEnergyRatingPalette.text)

                Circle()
                    .fill(dotColor(for: level))
                    .frame(width: 9, height: 9)

                Text(label(for: level))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? EmberEnergyRatingPalette.text
                            : EmberEnergyRatingPalette.secondaryText
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? EmberEnergyRatingPalette.selected
                    : EmberEnergyRatingPalette.card,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected
                            ? EmberEnergyRatingPalette.text
                            : EmberEnergyRatingPalette.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), energy \(level) of 5, \(label(for: level))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func label(for level: Int) -> String {
        switch level {
        case 1: "Low"
        case 2: "Light"
        case 3: "Steady"
        case 4: "Good"
        default: "High"
        }
    }

    private func dotColor(for level: Int) -> Color {
        switch level {
        case 1: EmberEnergyRatingPalette.low
        case 2: EmberEnergyRatingPalette.lowMedium
        case 3: EmberEnergyRatingPalette.medium
        default: EmberEnergyRatingPalette.high
        }
    }
}
