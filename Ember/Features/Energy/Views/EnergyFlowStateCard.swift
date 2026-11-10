import SwiftUI
import SwiftData

/// Dark summary card showing the latest saved energy check-in.
/// Used on Profile. Pass `onUpdate` to show the "Update energy" button.
struct EnergyFlowStateCard: View {
    private let onUpdate: (() -> Void)?

    @Query(sort: \EnergyCheckIn.createdAt, order: .reverse) private var checkIns: [EnergyCheckIn]

    init(onUpdate: (() -> Void)? = nil) {
        self.onUpdate = onUpdate
    }

    var body: some View {
        let latest = checkIns.first

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ENERGY FLOW STATE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(EmberTheme.mint)
                    Text(latest.map { "Energy \($0.level) / 5" } ?? "How's your energy?")
                        .font(.system(size: 29, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                    Text(latest == nil
                         ? "Pick how you're feeling on Today to log your first check-in."
                         : "Your latest self-reported energy check-in.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer(minLength: 8)
                Image(systemName: EnergyCheckInViewModel.batterySymbol(for: latest?.level))
                    .font(.system(size: 24))
                    .foregroundStyle(EmberTheme.amber)
            }

            if let onUpdate {
                Button(action: onUpdate) {
                    HStack {
                        Text(latest == nil ? "Check in now" : "Update energy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(13)
                    .foregroundStyle(EmberTheme.primary)
                    .background(EmberTheme.mint, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("profile_energy_update")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    EnergyFlowStateCard(onUpdate: {})
        .padding()
        .modelContainer(for: EnergyCheckIn.self, inMemory: true)
}
