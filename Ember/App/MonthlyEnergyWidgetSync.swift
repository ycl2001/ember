import OSLog
import SwiftData
import SwiftUI
import WidgetKit

/// Publishes the reflection data the Home Screen widget needs, without sharing Ember's database.
struct MonthlyEnergyWidgetSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var sessions: [FocusSession]
    @Query private var reflections: [SessionReflection]

    private let logger = Logger(subsystem: "com.ycl2001.ember", category: "MonthlyEnergyWidget")

    func body(content: Content) -> some View {
        let observations = AnalyticsViewModel.monthlyEnergyObservations(sessions: sessions, reflections: reflections)
        content
            .onChange(of: observations, initial: true) { _, updated in
                publish(updated)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    publish(observations)
                }
            }
    }

    private func publish(_ observations: [MonthlyEnergyObservation]) {
        do {
            if try MonthlyEnergyWidgetData.save(observations) {
                WidgetCenter.shared.reloadTimelines(ofKind: MonthlyEnergyWidgetData.kind)
            }
        } catch {
            logger.error("Could not publish monthly energy data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
