import SwiftData
import SwiftUI

enum ScopeSuggestionPolicy {
    static func acceptedTitles(
        from suggestion: ScopeSuggestion,
        energyLevel: Int,
        existingTitles: [String]
    ) -> [String] {
        guard (1...5).contains(energyLevel), suggestion.change != .keep else { return [] }
        if energyLevel <= 2 && suggestion.change != .smaller { return [] }
        if energyLevel >= 4 && suggestion.change != .bigger { return [] }

        let limit = suggestion.change == .smaller ? 3 : 1
        let existing = Set(existingTitles.map(normalizedKey))
        var seen = Set<String>()
        var result: [String] = []
        for rawTitle in suggestion.revisedTasks {
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizedKey(title)
            guard !title.isEmpty, title.count <= 80,
                  !existing.contains(key), seen.insert(key).inserted else { continue }
            result.append(title)
            if result.count == limit { break }
        }
        if suggestion.change == .smaller && result.count < 2 { return [] }
        return result
    }

    private static func normalizedKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct ScopeSuggestionRequest: Hashable {
    let goalID: UUID
    let energyLevel: Int?
    let unfinishedTaskSignatures: [String]
    let availability: AIAvailability
    let isActive: Bool
}

struct ScopeSuggestionCard: View {
    let goalID: UUID
    let tasks: [LearningTask]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \EnergyCheckIn.createdAt, order: .reverse) private var checkIns: [EnergyCheckIn]
    @State private var suggestion: ScopeSuggestion?
    @State private var isHandled = false
    @State private var saveFailed = false
    @State private var lastAttemptedRequest: ScopeSuggestionRequest?
    private let ai = EmberAIService()

    private var unfinishedTasks: [LearningTask] {
        tasks.filter { !$0.isCompleted && $0.goalID == goalID }
    }

    private var todayEnergyLevel: Int? {
        checkIns.first { Calendar.current.isDateInToday($0.createdAt) }?.level
    }

    private var request: ScopeSuggestionRequest {
        ScopeSuggestionRequest(
            goalID: goalID,
            energyLevel: todayEnergyLevel,
            unfinishedTaskSignatures: unfinishedTasks.map { "\($0.id.uuidString):\($0.title)" },
            availability: ai.availability,
            isActive: scenePhase == .active
        )
    }

    private var handledKey: String {
        let day = Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)
        return "ai-scope-suggestion-handled-\(goalID.uuidString)-\(day)"
    }

    var body: some View {
        Group {
            if let suggestion,
               let energyLevel = todayEnergyLevel,
               !isHandled {
                let titles = ScopeSuggestionPolicy.acceptedTitles(
                    from: suggestion,
                    energyLevel: energyLevel,
                    existingTitles: tasks.map(\.title)
                )
                if !titles.isEmpty {
                    suggestionCard(suggestion, titles: titles)
                        .alert("Couldn't add suggestions", isPresented: $saveFailed) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("Your checklist wasn't changed. Please try again.")
                        }
            }
            }
        }
        .task(id: request) {
            guard request.isActive else { return }
            await loadSuggestion()
        }
    }

    private func suggestionCard(_ suggestion: ScopeSuggestion, titles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(suggestion.change == .smaller ? "Lighter plan for today" : "Room for a stretch")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                Spacer()
                AIBadge()
            }

            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.primary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(titles, id: \.self) { title in
                    Label(title, systemImage: suggestion.change == .smaller ? "arrow.turn.down.right" : "plus")
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.muted)
                }
            }

            HStack(spacing: 10) {
                Button("Add to checklist") {
                    addToChecklist(titles)
                }
                .buttonStyle(.borderedProminent)
                .tint(EmberTheme.primary)

                Button("Not now") {
                    markHandled()
                }
                .buttonStyle(.plain)
                .foregroundStyle(EmberTheme.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
    }

    private func loadSuggestion() async {
        isHandled = EmberStorage.defaults.bool(forKey: handledKey)
        guard lastAttemptedRequest != request else { return }
        lastAttemptedRequest = request
        suggestion = nil
        guard !isHandled,
              let energyLevel = todayEnergyLevel,
              !unfinishedTasks.isEmpty else { return }
        do {
            suggestion = try await ai.scopeSuggestion(
                energyLevel: energyLevel,
                tasks: unfinishedTasks.map(\.title)
            )
        } catch is CancellationError {
            lastAttemptedRequest = nil
            return
        } catch {
            suggestion = nil
        }
    }

    private func addToChecklist(_ titles: [String]) {
        guard !titles.isEmpty else { return }
        for title in titles {
            modelContext.insert(
                LearningTask(goalID: goalID, title: title, isAIGenerated: true)
            )
        }
        do {
            try modelContext.save()
            markHandled()
        } catch {
            modelContext.rollback()
            saveFailed = true
        }
    }

    private func markHandled() {
        EmberStorage.defaults.set(true, forKey: handledKey)
        isHandled = true
    }
}
