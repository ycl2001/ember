import SwiftUI
import SwiftData

// MARK: - AnalyticsViewModel: report data + tomorrow calibration

extension AnalyticsViewModel {

    /// Snapshot of whatever period/range is currently selected, used to render the PDF.
    func reportData(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [EnergyRecord]
    ) -> BioRhythmReportData {
        let range = selectedRange
        let inRange = reflectionsInRange(reflections, during: range)
        let points = chartPoints(tasks: tasks, reflections: reflections, during: range)

        return BioRhythmReportData(
            periodName: period.rawValue,
            rangeTitle: rangeTitle(range),
            termText: termText(),
            generatedAt: Date(),
            tasksDone: completedTaskCount(in: tasks, during: range),
            sessions: sessionsCount(in: sessions, during: range),
            reflections: inRange.count,
            netEnergy: netReportedEnergyChange(in: inRange),
            days: points.map {
                BioRhythmReportData.Day(date: $0.date, tasks: $0.tasksCompleted, energy: $0.energy)
            }
        )
    }

    /// Looks at the last 4 weeks, finds the weekdays where you finish the most tasks,
    /// and returns a recommendation for tomorrow based on that.
    func calibrateTomorrow(tasks: [LearningTask], reflections: [EnergyRecord]) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard
            let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
            let lookbackStart = cal.date(byAdding: .day, value: -28, to: today)
        else {
            return "Couldn't work out tomorrow's date. Please try again."
        }

        let range = DateInterval(start: lookbackStart, end: tomorrow)
        let points = chartPoints(tasks: tasks, reflections: reflections, during: range)

        // Total completed tasks per weekday (1 = Sunday ... 7 = Saturday)
        var byWeekday: [Int: Int] = [:]
        for p in points {
            byWeekday[cal.component(.weekday, from: p.date), default: 0] += p.tasksCompleted
        }

        let ranked = byWeekday
            .filter { $0.value > 0 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }

        guard !ranked.isEmpty else {
            return "Not enough data yet. Complete a few tasks and log reflections, then calibrate again."
        }

        let peakWeekdays = ranked.prefix(2).map(\.key)
        let peakNames = peakWeekdays.map { cal.weekdaySymbols[$0 - 1] }.joined(separator: " & ")
        let tomorrowName = tomorrow.formatted(.dateTime.weekday(.wide))

        if peakWeekdays.contains(cal.component(.weekday, from: tomorrow)) {
            return "\(tomorrowName) is one of your strongest days. Put your most demanding tasks in the morning and take a 5–10 min break after every 25 min of deep focus."
        } else {
            return "\(tomorrowName) is usually lighter for you. Plan review-style or lighter tasks, and save deep work for \(peakNames)."
        }
    }
}

// MARK: - Buttons

struct AnalyticsActionButtons: View {
    let viewModel: AnalyticsViewModel
    let tasks: [LearningTask]
    let sessions: [FocusSession]
    let reflections: [EnergyRecord]

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    @State private var document = BioRhythmPDFDocument()
    @State private var showExporter = false

    var body: some View {
        VStack(spacing: 12) {
            // Calibrate
            Button(action: calibrate) {
                HStack(spacing: 10) {
                    Text("Calibrate Tomorrow's Schedule")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            // Download PDF
            Button(action: exportReport) {
                Label("Download Bio-Rhythm Report (PDF)", systemImage: "arrow.down.doc.fill")
                    .font(.headline)
                    .foregroundStyle(EmberTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(EmberTheme.muted.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: document,
            contentType: .pdf,
            defaultFilename: "BioRhythm-Report"
        ) { _ in }
    }

    // MARK: Actions

    private func calibrate() {
        alertTitle = "Tomorrow's Schedule"
        alertMessage = viewModel.calibrateTomorrow(tasks: tasks, reflections: reflections)
        showAlert = true
        // TODO: if your tasks have a scheduled/due date, move tomorrow's tasks here
        // based on the recommendation.
    }

    private func exportReport() {
        let data = viewModel.reportData(tasks: tasks, sessions: sessions, reflections: reflections)
        if let pdf = BioRhythmReportBuilder.makePDF(data: data) {
            document = BioRhythmPDFDocument(data: pdf)
            showExporter = true
        } else {
            alertTitle = "Report unavailable"
            alertMessage = "The PDF couldn't be created. Please try again."
            showAlert = true
        }
    }
}
