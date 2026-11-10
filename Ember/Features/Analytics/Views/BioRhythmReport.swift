import SwiftUI
import UniformTypeIdentifiers

struct BioRhythmReportData {
    struct Day: Identifiable {
        let date: Date
        let label: String
        let tasks: Int
        let energy: Double?

        var id: Date { date }
    }

    let periodName: String
    let rangeTitle: String
    let generatedAt: Date
    let tasksDone: Int
    let sessions: Int
    let reflections: Int
    let netEnergy: Int
    let days: [Day]

    var busiestDays: [Day] {
        Array(days.filter { $0.tasks > 0 }.sorted { $0.tasks > $1.tasks }.prefix(2))
    }
}
struct BioRhythmReportView: View {
    let data: BioRhythmReportData

    private let ink = Color(red: 0.11, green: 0.18, blue: 0.15)
    private let muted = Color(red: 0.42, green: 0.45, blue: 0.43)
    private let accent = Color(red: 0.55, green: 0.33, blue: 0.12)
    private let orange = Color(red: 0.93, green: 0.64, blue: 0.34)
    private let mint = Color(red: 0.85, green: 0.93, blue: 0.87)
    private let panel = Color(red: 0.96, green: 0.96, blue: 0.94)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            metrics
            breakdown
            insights
            Spacer(minLength: 0)
            footer
        }
        .padding(40)
        .frame(width: 595, height: 842, alignment: .topLeading)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMBER ANALYTICS REPORT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(accent)
            Text("Energy & Task Analytics")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
            Text("\(data.periodName) · \(data.rangeTitle)")
                .font(.system(size: 12))
                .foregroundStyle(muted)
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metricCard(value: "\(data.tasksDone)", label: "Tasks done")
            metricCard(value: "\(data.sessions)", label: "Sessions")
            metricCard(value: "\(data.reflections)", label: "Reflections")
            metricCard(value: signed(data.netEnergy), label: "Net energy change")
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
        .background(panel, in: .rect(cornerRadius: 10))
    }

    private var breakdown: some View {
        let maximumTasks = max(data.days.map(\.tasks).max() ?? 0, 1)
        let busiestDates = Set(data.busiestDays.map(\.date))
        return VStack(alignment: .leading, spacing: 10) {
            Text(data.periodName == "Monthly" ? "Weekly breakdown" : "Daily breakdown")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(ink)

            HStack {
                Text(data.periodName == "Monthly" ? "Week" : "Day")
                    .frame(width: 90, alignment: .leading)
                Text("Tasks completed")
                    .frame(width: 230, alignment: .leading)
                Text("Avg energy after")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(muted)

            ForEach(data.days) { day in
                HStack {
                    Text(day.label)
                        .font(.system(size: 11, weight: busiestDates.contains(day.date) ? .bold : .regular))
                        .foregroundStyle(ink)
                        .frame(width: 90, alignment: .leading)

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(orange)
                            .frame(
                                width: max(200 * Double(day.tasks) / Double(maximumTasks), day.tasks > 0 ? 4 : 0),
                                height: 10
                            )
                        Text("\(day.tasks)")
                            .font(.system(size: 11))
                            .foregroundStyle(ink)
                    }
                    .frame(width: 230, alignment: .leading)

                    if let energy = day.energy {
                        Text(energy, format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 11))
                            .foregroundStyle(muted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("–")
                            .font(.system(size: 11))
                            .foregroundStyle(muted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: .rect(cornerRadius: 12))
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What the saved data says")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(ink)

            ForEach(Array(insightLines.enumerated()), id: \.offset) { _, line in
                Label {
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mint.opacity(0.55), in: .rect(cornerRadius: 12))
    }

    private var footer: some View {
        HStack {
            Text("Generated \(data.generatedAt.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            Text("Energy change is after-session minus before-session rating.")
        }
        .font(.system(size: 8))
        .foregroundStyle(muted)
    }

    private var insightLines: [String] {
        var lines: [String] = []
        if data.busiestDays.isEmpty {
            lines.append("No completed tasks were saved in this period.")
        } else {
            let labels = data.busiestDays.sorted { $0.date < $1.date }.map(\.label).formatted()
            let busiestCount = data.busiestDays.reduce(0) { $0 + $1.tasks }
            lines.append("\(labels) contained \(busiestCount) of \(data.tasksDone) completed tasks.")
        }

        if data.reflections == 0 {
            lines.append("No energy reflections were saved, so no energy result is shown.")
        } else if data.netEnergy > 0 {
            lines.append("Net reported energy change was +\(data.netEnergy), meaning energy was higher after the recorded sessions overall.")
        } else if data.netEnergy < 0 {
            lines.append("Net reported energy change was \(data.netEnergy), meaning energy was lower after the recorded sessions overall.")
        } else {
            lines.append("Net reported energy change was 0 across the saved reflections.")
        }
        return lines
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

@MainActor
enum BioRhythmReportBuilder {
    static func makePDF(data: BioRhythmReportData) -> Data? {
        let renderer = ImageRenderer(content: BioRhythmReportView(data: data))
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }

        var succeeded = false
        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
            succeeded = true
        }
        return succeeded ? pdfData as Data : nil
    }
}

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
