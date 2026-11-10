///AnalyticsActions

import SwiftUI

// MARK: - AnalyticsViewModel: report data + calibration

extension AnalyticsViewModel {

    /// Snapshot of the selected period, used to render the PDF.
    /// Monthly reports are grouped into weekly rows so they fit on one page.
    func reportData(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [EnergyRecord]
    ) -> BioRhythmReportData {
        let range = selectedRange
        let inRange = reflectionsInRange(reflections, during: range)
        let points = chartPoints(tasks: tasks, reflections: reflections, during: range)

        let days: [BioRhythmReportData.Day]
        if period == .monthly {
            days = weeklyReportDays(from: points)
        } else {
            days = dailyReportDays(from: points)
        }

        return BioRhythmReportData(
            periodName: period.rawValue,
            rangeTitle: rangeTitle(range),
            termText: termText(),
            generatedAt: Date(),
            tasksDone: completedTaskCount(in: tasks, during: range),
            sessions: sessionsCount(in: sessions, during: range),
            reflections: inRange.count,
            netEnergy: netReportedEnergyChange(in: inRange),
            days: days
        )
    }

    private func dailyReportDays(from points: [ChartPoint]) -> [BioRhythmReportData.Day] {
        var result: [BioRhythmReportData.Day] = []
        for p in points {
            let label: String = p.date.formatted(.dateTime.weekday(.abbreviated).day())
            result.append(
                BioRhythmReportData.Day(
                    date: p.date,
                    label: label,
                    tasks: p.tasksCompleted,
                    energy: p.energy
                )
            )
        }
        return result
    }

    private func weeklyReportDays(from points: [ChartPoint]) -> [BioRhythmReportData.Day] {
        var result: [BioRhythmReportData.Day] = []
        var start = 0

        while start < points.count {
            let end = min(start + 7, points.count)
            let chunk = Array(points[start..<end])
            start = end

            guard let first = chunk.first, let last = chunk.last else { continue }

            let energies: [Double] = chunk.map { $0.energy }.filter { $0 != 0 }
            let avgEnergy: Double = energies.isEmpty ? 0 : energies.reduce(0, +) / Double(energies.count)
            let totalTasks: Int = chunk.reduce(0) { $0 + $1.tasksCompleted }

            let startText: String = first.date.formatted(.dateTime.month(.abbreviated).day())
            let endText: String = last.date.formatted(.dateTime.day())

            result.append(
                BioRhythmReportData.Day(
                    date: first.date,
                    label: "\(startText) – \(endText)",
                    tasks: totalTasks,
                    energy: avgEnergy
                )
            )
        }
        return result
    }

    /// Recommendation for tomorrow, based on your strongest weekdays over the last 4 weeks.
    func calibrateTomorrow(tasks: [LearningTask], reflections: [EnergyRecord]) -> String {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else {
            return "Couldn't work out tomorrow's date. Please try again."
        }

        let peak = strongestWeekdays(tasks: tasks, reflections: reflections, lookbackDays: 28)
        guard !peak.isEmpty else {
            return "Not enough data yet. Complete a few tasks and log reflections, then calibrate again."
        }

        let tomorrowName = tomorrow.formatted(.dateTime.weekday(.wide))
        let peakNames = peak.map { cal.weekdaySymbols[$0 - 1] }.joined(separator: " & ")

        if peak.contains(cal.component(.weekday, from: tomorrow)) {
            return "\(tomorrowName) is one of your strongest days. Put your most demanding tasks in the morning and take a 5–10 min break after every 25 min of deep focus."
        } else {
            return "\(tomorrowName) is usually lighter for you. Plan review-style or lighter tasks, and save deep work for \(peakNames)."
        }
    }

    /// Recommendation for next month, based on your strongest weekdays over the last 8 weeks.
    func calibrateNextMonth(tasks: [LearningTask], reflections: [EnergyRecord]) -> String {
        let cal = Calendar.current
        let peak = strongestWeekdays(tasks: tasks, reflections: reflections, lookbackDays: 56)
        guard !peak.isEmpty else {
            return "Not enough data yet. Keep logging tasks and reflections, then calibrate again."
        }
        let peakNames = peak.map { cal.weekdaySymbols[$0 - 1] }.joined(separator: " & ")
        return "Your strongest days lately are \(peakNames). Next month, book your most demanding work on those days and keep 5–10 min recovery pauses between deep sessions."
    }

    /// Weekday numbers (1 = Sunday ... 7 = Saturday), strongest first, max 2.
    /// Uses completed tasks per weekday when completion dates are available,
    /// otherwise falls back to average self-reported energy per weekday.
    private func strongestWeekdays(
        tasks: [LearningTask],
        reflections: [EnergyRecord],
        lookbackDays: Int
    ) -> [Int] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -lookbackDays, to: cal.startOfDay(for: Date())) else {
            return []
        }
        let interval = DateInterval(start: start, end: Date())

        var taskCounts: [Int: Int] = [:]
        for task in tasks where task.isCompleted {
            if let d = DailyModelAdapter.completionDate(task), interval.contains(d) {
                taskCounts[cal.component(.weekday, from: d), default: 0] += 1
            }
        }
        if !taskCounts.isEmpty {
            let rankedByTasks = taskCounts.sorted { a, b in
                a.value != b.value ? a.value > b.value : a.key < b.key
            }
            return rankedByTasks.prefix(2).map { $0.key }
        }

        var energy: [Int: [Double]] = [:]
        for r in reflections where interval.contains(r.createdAt) {
            let fraction = 1 - Double(r.energySpent) / DailyAnalysisConfig.energyScaleMax
            energy[cal.component(.weekday, from: r.createdAt), default: []].append(fraction)
        }

        var averages: [(day: Int, avg: Double)] = []
        for (day, values) in energy {
            let avg = values.reduce(0, +) / Double(values.count)
            averages.append((day: day, avg: avg))
        }
        averages.sort { a, b in
            a.avg != b.avg ? a.avg > b.avg : a.day < b.day
        }
        return averages.prefix(2).map { $0.day }
    }
}

// MARK: - Buttons

struct AnalyticsActionButtons: View {
    let period: AnalyticsViewModel.Period
    let viewModel: AnalyticsViewModel
    let tasks: [LearningTask]
    let sessions: [FocusSession]
    let reflections: [EnergyRecord]

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    @State private var document = BioRhythmPDFDocument()
    @State private var showExporter = false

    private let buttonGrey = Color(red: 0.91, green: 0.91, blue: 0.90)

    var body: some View {
        VStack(spacing: 8) {
            if period == .monthly {
                // Monthly: Calibrate is the primary (dark) button, Export is secondary (to match daily/weekly)
                primaryButton("Calibrate Next Month's Plan", action: calibrate)
                secondaryButton("Export Monthly Bio-Rhythm PDF", action: exportReport) {
                    pdfIcon
                }
            } else {
                primaryButton("Calibrate Tomorrow's Schedule", action: calibrate)
                secondaryButton("Download Bio-Rhythm Report (PDF)", action: exportReport) {
                    pdfIcon
                }
            }
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
            defaultFilename: period == .monthly ? "BioRhythm-Monthly-Report" : "BioRhythm-Report"
        ) { _ in }
    }

    // MARK: Button styles

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(EmberTheme.primary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton<Icon: View>(
        _ title: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                Text(title)
            }
            .font(.body.weight(.medium))
            .foregroundStyle(EmberTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(buttonGrey, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// Document icon with a small "PDF" label cut into the bottom.
    private var pdfIcon: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
            Text("PDF")
                .font(.system(size: 6, weight: .heavy))
                .foregroundStyle(buttonGrey)
                .offset(y: -3)
        }
    }

    // MARK: Actions

    private func calibrate() {
        if period == .monthly {
            alertTitle = "Next Month's Plan"
            alertMessage = viewModel.calibrateNextMonth(tasks: tasks, reflections: reflections)
        } else {
            alertTitle = "Tomorrow's Schedule"
            alertMessage = viewModel.calibrateTomorrow(tasks: tasks, reflections: reflections)
        }
        showAlert = true
        // TODO: if your tasks have a scheduled/due date, move tasks here based on the recommendation.
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
