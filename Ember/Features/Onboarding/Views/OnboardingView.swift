import SwiftUI
import SwiftData

/// Member 2 owns this file. Three-step onboarding: goals, peak energy, blueprint.
struct OnboardingView: View {
    private let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LearningGoal.createdAt, order: .reverse) private var goals: [LearningGoal]
    @State private var viewModel = OnboardingViewModel()

    /// `onFinish` runs after the goals and answers are saved, so the parent can switch screens.
    init(onFinish: @escaping () -> Void = {}) {
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowTopBar(
                title: "Learning setup",
                showsClose: false,
                showsAvatar: false,
                onLeading: goBack
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressSection
                    stepContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            footer
        }
        .background(FlowPalette.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.2), value: viewModel.step)
    }

    // MARK: Sections

    private var progressSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text(viewModel.step.eyebrow)
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(viewModel.step == .goals ? FlowPalette.brown : FlowPalette.ink)
                Spacer()
                Text(viewModel.step.percentLabel)
                    .font(.footnote)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }
            FlowProgressBar(progress: viewModel.step.progress)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .goals:
            OnboardingGoalsStep(viewModel: viewModel, existingGoals: goals)
        case .rhythm:
            OnboardingRhythmStep(viewModel: viewModel)
        case .blueprint:
            OnboardingBlueprintStep(viewModel: viewModel)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: primaryAction) {
                FlowButtonLabel(
                    title: viewModel.primaryTitle,
                    systemImage: viewModel.step == .blueprint ? "checkmark" : "arrow.right"
                )
            }
            .buttonStyle(FlowPrimaryButtonStyle())

            switch viewModel.step {
            case .goals:
                Button("I'll calibrate as I go (Skip)") {
                    viewModel.skipGoals()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FlowPalette.ink)
            case .rhythm:
                Text("Step 2 of 3 • Customizing algorithmic study sequence")
                    .font(.footnote)
                    .foregroundStyle(FlowPalette.secondaryInk)
            case .blueprint:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(FlowPalette.background)
    }

    // MARK: Actions

    private func primaryAction() {
        if viewModel.step == .blueprint {
            finish()
        } else {
            viewModel.advance(existingGoals: goals)
        }
    }

    private func goBack() {
        if !viewModel.goBack() {
            dismiss()
        }
    }

    private func finish() {
        if viewModel.finish(in: modelContext, existingGoals: goals) {
            onFinish()
            dismiss()
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: LearningGoal.self, inMemory: true)
}
