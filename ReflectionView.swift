import SwiftUI
import SwiftData

/// Member 5 owns this file. Save SessionReflection after a focus session.
struct ReflectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ReflectionViewModel { before, after, notes, createdAt in
        let record = EnergyRecord(
            createdAt: createdAt,
            energyBefore: before,
            energyAfter: after,
            notes: notes
        )
        context.insert(record)
        try context.save()
    }

    var body: some View {
        Form {
            Section("Energy (1–5)") {
                Stepper("Before: \(viewModel.energyBefore)", value: $viewModel.energyBefore, in: 1...5)
                Stepper("After: \(viewModel.energyAfter)", value: $viewModel.energyAfter, in: 1...5)
                Text(viewModel.reflectionPrompt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Section("Notes") {
                TextField("What influenced your energy?", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section {
                Button("Save") {
                    guard viewModel.canSave else { return }
                    do {
                        try viewModel.save()
                        dismiss()
                    } catch {
                        // TODO: present an error alert if desired
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle("Session reflection")
    }
}
