import SwiftUI
import SwiftData

/// Shows an AI suggestion to make today's checklist smaller or bigger.
/// Suggested location: Features/Focus/Views/ScopeSuggestionCard.swift
///
/// Usage: ScopeSuggestionCard(tasks: tasksForThisGoal)
/// Pass the tasks of ONE learning goal (the checklist the user is looking at).
///
/// Rules enforced in code, not by the model:
/// - nothing runs without an energy check-in today
/// - the AI only ADDS tasks (never edits or deletes the user's own)
/// - at most 3 tasks for "smaller", 1 for "bigger", no empty or duplicate titles
/// - changes are applied only when the user taps Apply
struct ScopeSuggestionCard: View {
    let tasks: [LearningTask]

    @Environment(\.modelContext) private var context
    @Query(sort: \EnergyCheckIn.createdAt, order: .reverse) private var checkIns: [EnergyCheckIn]

    @State private var suggestion: ScopeSuggestion?
    @State private var handled = false
    private let ai = EmberAIService()

    // MARK: Derived values

    private var unfinished: [LearningTask] { tasks.filter { !$0.isCompleted } }

    private var todayLevel: Int? {
        checkIns.first { Calendar.current.isDateInToday($0.createdAt) }?.level
    }

    private var goalKey: String { tasks.first?.goalID.uuidString ?? "none" }

    /// One suggestion per goal per day: remembered after Apply or Dismiss.
    private var handledKey: String {
        let day = Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)
        return "scope-handled-\(goalKey)-\(day)"
    }

    // MARK: Body

    var body: some View {
        Group {
            if let suggestion, !handled, suggestion.change != .keep, !cleanTitles(suggestion).isEmpty {
                card(for: suggestion)
            }
        }
        // Re-runs when today's check-in changes or the goal changes, not on every task tick.
        .task(id: "\(todayLevel ?? 0)-\(goalKey)") {
            await load()
        }
    }

    // MARK: UI

    private func card(for s: ScopeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.change == .smaller ? "Lighter plan for today" : "Room for a stretch")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(EmberTheme.primary)
                Spacer()
                AIBadge()
            }

            Text(s.reason)
                .font(.subheadline)
                .foregroundStyle(EmberTheme.primary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(cleanTitles(s), id: \.self) { title in
                    Label(title, systemImage: s.change == .smaller ? "arrow.turn.down.right" : "plus")
                        .font(.subheadline)
                        .foregroundStyle(EmberTheme.muted)
                }
            }

            HStack(spacing: 10) {
                Button {
                    apply(s)
                } label: {
                    Text("Add to checklist")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(EmberTheme.primary, in: Capsule())
                }

                Button("Not now") {
                    markHandled()
                }
                .font(.subheadline)
                .foregroundStyle(EmberTheme.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.surface, in: RoundedRectangle(cornerRadius: 19))
    }

    // MARK: Logic

    private func load() async {
        handled = UserDefaults.standard.bool(forKey: handledKey)
        guard !handled, let level = todayLevel, !unfinished.isEmpty else {
            suggestion = nil
            return
        }
        suggestion = try? await ai.scopeSuggestion(
            energyLevel: level,
            tasks: unfinished.map(\.title)
        )
    }

    /// Model output cleaned up: trimmed, no empties, no duplicates, capped.
    private func cleanTitles(_ s: ScopeSuggestion) -> [String] {
        let limit = s.change == .smaller ? 3 : 1
        let existing = Set(tasks.map { $0.title.lowercased() })
        var seen = Set<String>()
        var result: [String] = []
        for raw in s.revisedTasks {
            let title = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            let key = title.lowercased()
            guard !title.isEmpty, !existing.contains(key), seen.insert(key).inserted else { continue }
            result.append(title)
            if result.count == limit { break }
        }
        return result
    }

    private func apply(_ s: ScopeSuggestion) {
        let titles = cleanTitles(s)
        guard s.change != .keep, !titles.isEmpty, let fallback = unfinished.first else {
            markHandled()
            return
        }
        // Attach to the focus task's goal if the model named one, else the first unfinished task's goal.
        let goalID = unfinished.first { $0.title == s.focusTaskTitle }?.goalID ?? fallback.goalID

        for title in titles {
            context.insert(LearningTask(goalID: goalID, title: title, isAIGenerated: true))
        }
        try? context.save()
        markHandled()
    }

    private func markHandled() {
        UserDefaults.standard.set(true, forKey: handledKey)
        handled = true
    }
}
