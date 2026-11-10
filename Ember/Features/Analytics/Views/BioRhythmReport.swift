///BioRhythmReport

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Report data (built from AnalyticsViewModel, see AnalyticsActions.swift)

struct BioRhythmReportData {
    struct Day: Identifiable {
        let date: Date
        let label: String    // "Tue 10" for daily/weekly, "Nov 2 – 8" for monthly week blocks
        let tasks: Int
        let energy: Double   // average self-reported energy spent (0 = no reflections)
        var id: Date { date }
    }

    let periodName: String
    let rangeTitle: String
    let termText: String
    let generatedAt: Date
    let tasksDone: Int
    let sessions: Int
    let reflections: Int
    let netEnergy: Int
    let days: [Day]

    /// The (up to) two days with the most completed tasks.
    var peakDays: [Day] {
        Array(days.filter { $0.tasks > 0 }.sorted { $0.tasks > $1.tasks }.prefix(2))
    }
}

// MARK: - Printable report (A4, fixed light colours so the PDF never depends on dark mode)

struct BioRhythmReportView: View {
    let data: BioRhythmReportData

    private let ink = Color(red: 0.11, green: 0.18, blue: 0.15)
    private let muted = Color(red: 0.42, green: 0.45, blue: 0.43)
    private let accent = Color(red: 0.55, green: 0.33, blue: 0.12)
    private let orange = Color(red: 0.93, green: 0.64, blue: 0.34)
    private let darkOrange = Color(red: 0.62, green: 0.36, blue: 0.14)
    private let mint = Color(red: 0.85, green: 0.93, blue: 0.87)
    private let panel = Color(red: 0.96, green: 0.96, blue: 0.94)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            metrics
            dailyBreakdown
            insights
            Spacer(minLength: 0)
            footer
        }
        .padding(40)
        .frame(width: 595, height: 842, alignment: .topLeading) // A4 in points
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BIO-RHYTHM REPORT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(accent)
            Text("Energy & Task Analytics")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
            Text("\(data.periodName) · \(data.rangeTitle) · \(data.termText)")
                .font(.system(size: 12))
                .foregroundStyle(muted)
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metricCard(value: "\(data.tasksDone)", label: "Tasks done")
            metricCard(value: "\(data.sessions)", label: "Sessions")
            metricCard(value: "\(data.reflections)", label: "Reflections")
            metricCard(value: "\(data.netEnergy)", label: "Net energy change")
        }
    }

    private func metricCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundStyle(ink)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private var dailyBreakdown: some View {
        let maxTasks = max(data.days.map(\.tasks).max() ?? 0, 1)
        let peakDates = Set(data.peakDays.map(\.date))
        let barWidth: CGFloat = 200

        return VStack(alignment: .leading, spacing: 10) {
            Text(data.periodName == "Monthly" ? "Weekly breakdown" : "Daily breakdown")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(ink)

            HStack {
                Text(data.periodName == "Monthly" ? "Week" : "Day").frame(width: 90, alignment: .leading)
                Text("Tasks completed").frame(width: barWidth + 30, alignment: .leading)
                Text("Avg energy spent").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(muted)

            ForEach(data.days) { day in
                let isPeak = peakDates.contains(day.date)
                HStack {
                    Text(day.label)
                        .font(.system(size: 11, weight: isPeak ? .bold : .regular))
                        .foregroundStyle(ink)
                        .frame(width: 90, alignment: .leading)

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isPeak ? darkOrange : orange)
                            .frame(width: max(barWidth * CGFloat(day.tasks) / CGFloat(maxTasks), day.tasks > 0 ? 4 : 0),
                                   height: 10)
                        Text("\(day.tasks)")
                            .font(.system(size: 11))
                            .foregroundStyle(ink)
                    }
                    .frame(width: barWidth + 30, alignment: .leading)

                    Text(day.energy != 0 ? String(format: "%.1f", day.energy) : "–")
                        .font(.system(size: 11))
                        .foregroundStyle(muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What the data says")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(ink)

            ForEach(Array(insightLines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(accent).frame(width: 5, height: 5).padding(.top, 5)
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mint.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        HStack {
            Text("Generated \(data.generatedAt.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            Text("Positive energy change = lower energy afterward; negative = more energised.")
        }
        .font(.system(size: 8))
        .foregroundStyle(muted)
    }

    // MARK: Insight text (all derived from the numbers above, nothing invented)

    private var insightLines: [String] {
        var lines: [String] = []

        let peaks = data.peakDays
        if peaks.isEmpty {
            lines.append("No completed tasks were recorded in this period.")
        } else {
            let names = peaks
                .sorted { $0.date < $1.date }
                .map(\.label)
                .joined(separator: " & ")
            let peakTotal = peaks.reduce(0) { $0 + $1.tasks }
            let total = data.days.reduce(0) { $0 + $1.tasks }
            lines.append("Most productive: \(names) — \(peakTotal) of \(total) daily-tracked tasks were finished on \(peaks.count == 1 ? "that day" : "those days").")
        }

        if data.reflections == 0 {
            lines.append("No energy reflections were logged, so the energy curve is not available for this period.")
        } else if data.netEnergy > 0 {
            lines.append("Net self-reported energy change is +\(data.netEnergy): you tended to feel more drained after sessions.")
        } else if data.netEnergy < 0 {
            lines.append("Net self-reported energy change is \(data.netEnergy): you tended to feel more energised after sessions.")
        } else {
            lines.append("Net self-reported energy change is 0: sessions left your energy roughly unchanged.")
        }

        if data.sessions > 0 {
            let ratio = Double(data.tasksDone) / Double(data.sessions)
            lines.append("You completed \(String(format: "%.1f", ratio)) tasks per focus session across \(data.sessions) sessions.")
        }

        return lines
    }
}

// MARK: - PDF builder

@MainActor
enum BioRhythmReportBuilder {
    /// Renders the report view into PDF data (single A4 page, vector text).
    static func makePDF(data: BioRhythmReportData) -> Data? {
        let renderer = ImageRenderer(content: BioRhythmReportView(data: data))
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var succeeded = false
        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            renderInContext(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            succeeded = true
        }
        return succeeded ? (pdfData as Data) : nil
    }
}

// MARK: - FileDocument wrapper so .fileExporter can save it to Files

struct BioRhythmPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
