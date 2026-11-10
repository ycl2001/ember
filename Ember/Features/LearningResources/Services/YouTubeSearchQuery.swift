import Foundation

enum YouTubeSearchQuery {
    static func make(goal: String, task: String) -> String {
        let goal = cleaned(goal)
        let task = cleaned(task)
        let subject: String

        if goal.isEmpty {
            subject = task
        } else if task.isEmpty || task.localizedStandardContains(goal) {
            subject = task.isEmpty ? goal : task
        } else {
            subject = "\(task) \(goal)"
        }

        return "\(subject) tutorial".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleaned(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
