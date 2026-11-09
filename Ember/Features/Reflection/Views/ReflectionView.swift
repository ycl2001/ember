import SwiftUI
import SwiftData

/// Save a Session Reflection after a focus session.
struct ReflectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Start with a no-op saveAction; rebind onAppear when we can capture context safely.
    @State private var viewModel = ReflectionViewModel { _, _, _, _ in }

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
                        // TODO: present an alert/toast if desired
                        print("Failed to save reflection: \(error)")
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle("Session reflection")
        .onAppear {
            // Rebind with a closure that captures modelContext.
            viewModel = ReflectionViewModel(
                energyBefore: viewModel.energyBefore,
                energyAfter: viewModel.energyAfter,
                notes: viewModel.notes
            ) { before, after, notes, createdAt in
                let record = EnergyRecord(
                    createdAt: createdAt,
                    energyBefore: before,
                    energyAfter: after,
                    notes: notes
                )
                context.insert(record)
                try context.save()
            }
        }
    }
}
