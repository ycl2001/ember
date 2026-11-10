import SwiftUI

extension AnalyticsViewModel {
    func reportData(
        tasks: [LearningTask],
        sessions: [FocusSession],
        reflections: [SessionReflection]
    ) -> BioRhythmReportData {
        let range = selectedRange
        let observations = reflectionsInRange(reflections, sessions: sessions, during: range)
        let points = chartPoints(
            tasks: tasks,
            sessions: sessions,
            reflections: reflections,
            during: range
        )
        let reportDays = period == .monthly
            ? weeklyReportDays(from: points)
            : dailyReportDays(from: points)

        return BioRhythmReportData(
            periodName: period.rawValue,
            rangeTitle: rangeTitle(range),
            generatedAt: .now,
            tasksDone: completedTaskCount(in: tasks, during: range),
            sessions: sessionsCount(in: sessions, during: range),
            reflections: observations.count,
            netEnergy: netReportedEnergyChange(in: observations),
            days: reportDays
        )
    }

    private func dailyReportDays(from points: [ChartPoint]) -> [BioRhythmReportData.Day] {
        points.map { point in
            BioRhythmReportData.Day(
                date: point.date,
                label: point.date.formatted(.dateTime.weekday(.abbreviated).day()),
                tasks: point.tasksCompleted,
                energy: point.energy
            )
        }
    }

    private func weeklyReportDays(from points: [ChartPoint]) -> [BioRhythmReportData.Day] {
        stride(from: 0, to: points.count, by: 7).compactMap { start in
            let end = min(start + 7, points.count)
            let chunk = Array(points[start..<end])
            guard let first = chunk.first, let last = chunk.last else { return nil }
            let energies = chunk.compactMap(\.energy)
            let averageEnergy = energies.isEmpty ? nil : energies.reduce(0, +) / Double(energies.count)
            return BioRhythmReportData.Day(
                date: first.date,
                label: "\(first.date.formatted(.dateTime.month(.abbreviated).day())) – \(last.date.formatted(.dateTime.day()))",
                tasks: chunk.reduce(0) { $0 + $1.tasksCompleted },
                energy: averageEnergy
            )
        }
    }
}
struct AnalyticsActionButtons: View {
    let period: AnalyticsViewModel.Period
    let viewModel: AnalyticsViewModel
    let tasks: [LearningTask]
    let sessions: [FocusSession]
    let reflections: [SessionReflection]

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var document = BioRhythmPDFDocument()
    @State private var showExporter = false

    var body: some View {
        VStack(spacing: 8) {
            Button(action: reviewPattern) {
                Label(
                    period == .monthly ? "Review 8-Week Pattern" : "Review 4-Week Pattern",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(EmberTheme.primary, in: .rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button(action: exportReport) {
                Label(
                    period == .monthly ? "Export Monthly Analytics PDF" : "Export Analytics PDF",
                    systemImage: "doc.badge.arrow.up"
                )
                .font(.body.weight(.medium))
                .foregroundStyle(EmberTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(EmberTheme.muted.opacity(0.14), in: .rect(cornerRadius: 10))
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
            defaultFilename: period == .monthly ? "Ember-Monthly-Analytics" : "Ember-Analytics"
        ) { result in
            if case .failure = result {
                alertTitle = "Export failed"
                alertMessage = "The report could not be saved. Please try again."
                showAlert = true
            }
        }
    }

    private func reviewPattern() {
        let pattern = viewModel.observedPattern(
            sessions: sessions,
            reflections: reflections,
            lookbackDays: period == .monthly ? 56 : 28
        )
        alertTitle = pattern.title
        alertMessage = pattern.message
        showAlert = true
    }

    private func exportReport() {
        let report = viewModel.reportData(
            tasks: tasks,
            sessions: sessions,
            reflections: reflections
        )
        guard let data = BioRhythmReportBuilder.makePDF(data: report) else {
            alertTitle = "Report unavailable"
            alertMessage = "The PDF could not be created. Please try again."
            showAlert = true
            return
        }
        document = BioRhythmPDFDocument(data: data)
        showExporter = true
    }
}
