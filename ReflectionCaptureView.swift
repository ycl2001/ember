import SwiftUI
import SwiftData

struct ReflectionCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm = ReflectionViewModel { before, after, notes, createdAt in
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
                Stepper("Before: \(vm.energyBefore)", value: $vm.energyBefore, in: 1...5)
                Stepper("After: \(vm.energyAfter)", value: $vm.energyAfter, in: 1...5)
                Text(vm.reflectionPrompt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Section("Notes") {
                TextField("What influenced your energy?", text: $vm.notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section {
                Button("Save") {
                    guard vm.canSave else { return }
                    do {
                        try vm.save()
                        dismiss()
                    } catch {
                        // Handle error (e.g., show an alert)
                    }
                }
                .disabled(!vm.canSave)
            }
        }
        .navigationTitle("Reflect")
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: EnergyRecord.self, configurations: config)
        return NavigationStack {
            ReflectionCaptureView()
        }
        .modelContainer(container)
    } catch {
        return Text("Preview unavailable: \(String(describing: error))")
    }
}
