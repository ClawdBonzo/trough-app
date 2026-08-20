import Foundation
import SwiftData
import UIKit

// MARK: - ExportService

/// Generates local export files (CSV + doctor-visit PDF).
/// Files are written to a temp export folder and shared via the system
/// share sheet only — nothing ever leaves the device unless the user
/// explicitly shares it (CLAUDE.md: strictly on-device, no network).
@MainActor
final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case nothingToExport
        case cannotWriteFile

        var errorDescription: String? {
            switch self {
            case .nothingToExport: return "There is no data to export yet."
            case .cannotWriteFile: return "Could not write the export file."
            }
        }
    }

    // MARK: - Shared formatting

    /// yyyy-MM-dd — first (and unambiguous) format in CSVImportService.detectDateFormat,
    /// so exported files round-trip through import cleanly.
    private static let csvDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var exportDirectory: URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TroughExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Number formatting for CSV cells: no trailing zeros, POSIX decimal point.
    private func csvNumber(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(v))
        }
        var s = String(format: "%.4f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// RFC-4180 escaping — mirrors what CSVImportService.parseRow can read back.
    private func csvField(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
            return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return raw
    }

    private func write(csv rows: [[String]], to filename: String) throws -> URL {
        let text = rows.map { row in row.map(csvField).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
        let url = exportDirectory.appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.cannotWriteFile
        }
        return url
    }

    // MARK: - Check-in CSV

    /// Column headers chosen to exact-match CSVImportService.detectColumns aliases,
    /// so an exported file re-imports with 1.0 mapping confidence.
    /// Extra columns (supplements, notes, …) are ignored by the importer.
    func exportCheckinsCSV(context: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<SDCheckin>(
            predicate: #Predicate { !$0.isSampleData },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let checkins = (try? context.fetch(descriptor)) ?? []
        guard !checkins.isEmpty else { throw ExportError.nothingToExport }

        var rows: [[String]] = [[
            "date", "energy", "mood", "libido", "sleep", "clarity",
            "morningwood", "workout", "trainingperformance", "supplements",
            "bodyweightkg", "bodyfat", "restinghr", "sleephours", "hrv",
            "steps", "notes", "symptoms"
        ]]

        func yesNo(_ b: Bool?) -> String {
            guard let b else { return "" }
            return b ? "yes" : "no"
        }
        func num(_ v: Double?) -> String { v.map(csvNumber) ?? "" }

        for c in checkins {
            rows.append([
                Self.csvDateFormatter.string(from: c.date),
                csvNumber(c.energyScore),
                csvNumber(c.moodScore),
                csvNumber(c.libidoScore),
                csvNumber(c.sleepQualityScore),
                csvNumber(c.mentalClarityScore),
                yesNo(c.morningWood),
                yesNo(c.workoutToday),
                num(c.trainingPerformanceScore),
                c.supplementsTaken ?? "",
                num(c.bodyWeightKg),
                num(c.bodyFatPercent),
                num(c.restingHR),
                num(c.sleepHours),
                num(c.hrv),
                c.stepCount.map(String.init) ?? "",
                c.notes ?? "",
                c.symptoms ?? ""
            ])
        }

        let stamp = Self.fileStampFormatter.string(from: .now)
        return try write(csv: rows, to: "Trough-Checkins-\(stamp).csv")
    }

    // MARK: - Bloodwork CSV

    /// Maps stored marker names to CSV headers that are exact aliases in
    /// CSVImportService.detectColumns. Long-form aliases are used deliberately:
    /// short ones ("psa", "fsh", "ast", "e2", "lh") get fuzzy-stolen by earlier
    /// check-in column definitions and break the round trip.
    static let markerCSVHeaders: [String: String] = [
        "Total Testosterone": "totaltestosterone",
        "Free Testosterone":  "freetestosterone",
        "Estradiol (E2)":     "estradiol",
        "SHBG":               "shbg",
        "Hematocrit":         "hematocrit",
        "Hemoglobin":         "hemoglobin",
        "PSA":                "prostatespecificantigen",
        "LH":                 "luteinizinghormone",
        "FSH":                "folliclestimulatinghormone",
        "Prolactin":          "prolactin",
        "Total Cholesterol":  "totalcholesterol",
        "LDL":                "ldlcholesterol",
        "HDL":                "hdlcholesterol",
        "Triglycerides":      "triglycerides",
        "ALT":                "alanineaminotransferase",
        "AST":                "aspartateaminotransferase",
    ]

    /// Canonical marker display order (BloodworkViewModel section order).
    private var canonicalMarkerOrder: [String] {
        BloodworkViewModel.sections.flatMap { $0.defs.map(\.name) }
    }

    func exportBloodworkCSV(context: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<SDBloodwork>(
            predicate: #Predicate { !$0.isSampleData },
            sortBy: [SortDescriptor(\.drawnAt, order: .forward)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        guard !sessions.isEmpty else { throw ExportError.nothingToExport }

        // Marker names present in the data, in canonical order (unknowns last, alphabetical)
        let present = Set(sessions.flatMap { $0.markers.map(\.markerName) })
        let ordered = canonicalMarkerOrder.filter { present.contains($0) }
            + present.subtracting(canonicalMarkerOrder).sorted()

        var header = ["date", "lab"]
        for name in ordered {
            let base = Self.markerCSVHeaders[name] ?? name
            header += [base, "\(base)_low", "\(base)_high"]
        }
        header += ["notes", "doctornotes"]
        var rows: [[String]] = [header]

        for session in sessions {
            var row = [Self.csvDateFormatter.string(from: session.drawnAt),
                       session.labName ?? ""]
            for name in ordered {
                if let marker = session.markers.first(where: { $0.markerName == name }) {
                    row.append(csvNumber(marker.value))
                    row.append(marker.referenceRangeLow.map(csvNumber) ?? "")
                    row.append(marker.referenceRangeHigh.map(csvNumber) ?? "")
                } else {
                    row += ["", "", ""]
                }
            }
            row.append(session.notes ?? "")
            row.append(session.doctorNotes ?? "")
            rows.append(row)
        }

        let stamp = Self.fileStampFormatter.string(from: .now)
        return try write(csv: rows, to: "Trough-Bloodwork-\(stamp).csv")
    }

    // MARK: - Doctor-visit PDF

    /// A4-ish US-Letter report: protocol summary, bloodwork tables (newest first),
    /// doctor notes, per-marker trend lines, disclaimer footer on every page.
    /// Data presentation only — no interpretation, no health claims.
    func generateDoctorReport(context: ModelContext) throws -> URL {
        let checkupDescriptor = FetchDescriptor<SDBloodwork>(
            predicate: #Predicate { !$0.isSampleData },
            sortBy: [SortDescriptor(\.drawnAt, order: .reverse)]
        )
        let sessions = (try? context.fetch(checkupDescriptor)) ?? []
        guard !sessions.isEmpty else { throw ExportError.nothingToExport }

        let protocolDescriptor = FetchDescriptor<SDProtocol>(
            predicate: #Predicate { $0.isActive && !$0.isSampleData },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let activeProtocols = (try? context.fetch(protocolDescriptor)) ?? []

        let url = exportDirectory
            .appendingPathComponent("Trough-Doctor-Report-\(Self.fileStampFormatter.string(from: .now)).pdf")
        let composer = DoctorReportComposer(
            sessions: sessions,
            activeProtocols: activeProtocols,
            markerOrder: canonicalMarkerOrder
        )
        do {
            try composer.render(to: url)
        } catch {
            throw ExportError.cannotWriteFile
        }
        return url
    }
}

// MARK: - DoctorReportComposer

/// Draws the doctor-visit PDF with UIGraphicsPDFRenderer.
/// Dark-on-white print styling (this document is for printing, not the app theme).
private final class DoctorReportComposer {

    // US Letter, 72 dpi
    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let margin: CGFloat = 54
    private let footerHeight: CGFloat = 56

    private var contentWidth: CGFloat { pageRect.width - margin * 2 }
    private var contentBottom: CGFloat { pageRect.height - margin - footerHeight }

    private let sessions: [SDBloodwork]          // newest first
    private let activeProtocols: [SDProtocol]
    private let markerOrder: [String]

    private var pdf: UIGraphicsPDFRendererContext!
    private var cursorY: CGFloat = 0
    private var pageNumber = 0

    // Print palette
    private let ink = UIColor.black
    private let inkSecondary = UIColor(white: 0.35, alpha: 1)
    private let inkFaint = UIColor(white: 0.55, alpha: 1)
    private let rule = UIColor(white: 0.80, alpha: 1)
    private let outOfRange = UIColor(red: 0.72, green: 0.11, blue: 0.25, alpha: 1)

    init(sessions: [SDBloodwork], activeProtocols: [SDProtocol], markerOrder: [String]) {
        self.sessions = sessions
        self.activeProtocols = activeProtocols
        self.markerOrder = markerOrder
    }

    private let disclaimerText: String = {
        "\(DisclaimerService.standard) \(DisclaimerService.bloodwork)"
    }()

    // MARK: Render

    func render(to url: URL) throws {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Trough — Bloodwork & Protocol Summary",
            kCGPDFContextCreator as String: "Trough"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        try renderer.writePDF(to: url) { ctx in
            pdf = ctx
            beginPage()
            drawHeader()
            drawProtocolSection()
            drawSessions()
            drawTrendSection()
        }
    }

    // MARK: Page management

    private func beginPage() {
        pdf.beginPage()
        pageNumber += 1
        cursorY = margin
        drawFooter()
    }

    /// Ensures `height` points of vertical space, starting a new page if needed.
    private func ensureSpace(_ height: CGFloat) {
        if cursorY + height > contentBottom {
            beginPage()
        }
    }

    private func drawFooter() {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: inkFaint,
            .paragraphStyle: style
        ]
        let text = NSAttributedString(string: disclaimerText, attributes: attrs)
        let rect = CGRect(x: margin, y: pageRect.height - margin - footerHeight + 12,
                          width: contentWidth, height: footerHeight - 16)
        UIColor(white: 0.85, alpha: 1).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: rect.minY - 4))
        line.addLine(to: CGPoint(x: pageRect.width - margin, y: rect.minY - 4))
        line.lineWidth = 0.5
        line.stroke()
        text.draw(in: rect)

        let pageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: inkFaint
        ]
        let pageText = NSAttributedString(string: "Page \(pageNumber)", attributes: pageAttrs)
        let size = pageText.size()
        pageText.draw(at: CGPoint(x: pageRect.width - margin - size.width,
                                  y: pageRect.height - margin + 2))
    }

    // MARK: Text helpers

    @discardableResult
    private func drawText(_ string: String,
                          font: UIFont,
                          color: UIColor,
                          spacingAfter: CGFloat = 4) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]
        let text = NSAttributedString(string: string, attributes: attrs)
        let bounds = text.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        )
        let height = ceil(bounds.height)
        ensureSpace(height + spacingAfter)
        text.draw(in: CGRect(x: margin, y: cursorY, width: contentWidth, height: height))
        cursorY += height + spacingAfter
        return height
    }

    private func drawRule(spacing: CGFloat = 8) {
        ensureSpace(spacing + 1)
        rule.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: cursorY))
        path.addLine(to: CGPoint(x: pageRect.width - margin, y: cursorY))
        path.lineWidth = 0.5
        path.stroke()
        cursorY += spacing
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }

    // MARK: Header

    private func drawHeader() {
        drawText("Trough — Bloodwork & Protocol Summary",
                 font: .systemFont(ofSize: 20, weight: .bold), color: ink, spacingAfter: 4)
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
        let generated = Date.now.formatted(date: .long, time: .shortened)
        drawText("Generated \(generated)  ·  Trough v\(version)  ·  Data entered by the user on-device",
                 font: .systemFont(ofSize: 9), color: inkSecondary, spacingAfter: 10)
        drawRule(spacing: 12)
    }

    // MARK: Protocol section

    private func drawProtocolSection() {
        drawText("Active Protocol", font: .systemFont(ofSize: 13, weight: .semibold),
                 color: ink, spacingAfter: 6)
        if activeProtocols.isEmpty {
            drawText("No active protocol recorded.", font: .systemFont(ofSize: 10),
                     color: inkSecondary, spacingAfter: 10)
        } else {
            for p in activeProtocols {
                let frequency = p.frequencyDays == 1
                    ? "daily"
                    : "every \(p.frequencyDays) days"
                var line = "\(p.compoundName) — \(fmt(p.doseAmountMg)) mg \(frequency)"
                if p.concentrationMgPerMl > 0 {
                    line += "  (\(fmt(p.concentrationMgPerMl)) mg/mL)"
                }
                if !p.isPrimary { line += "  [secondary]" }
                drawText("•  \(line)", font: .systemFont(ofSize: 10), color: ink, spacingAfter: 3)
                drawText("    Started \(p.startDate.formatted(date: .abbreviated, time: .omitted))",
                         font: .systemFont(ofSize: 8.5), color: inkSecondary, spacingAfter: 6)
            }
        }
        drawRule(spacing: 12)
    }

    // MARK: Bloodwork sessions

    private struct Column {
        let title: String
        let x: CGFloat
        let width: CGFloat
        let alignment: NSTextAlignment
    }

    private var columns: [Column] {
        [
            Column(title: "Marker",    x: 0,   width: 190, alignment: .left),
            Column(title: "Value",     x: 195, width: 65,  alignment: .right),
            Column(title: "Unit",      x: 268, width: 62,  alignment: .left),
            Column(title: "Ref. Range", x: 335, width: 110, alignment: .left),
            Column(title: "Flag",      x: 455, width: 49,  alignment: .center),
        ]
    }

    private func drawTableCell(_ string: String, column: Column, y: CGFloat,
                               font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = column.alignment
        style.lineBreakMode = .byTruncatingTail
        let text = NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ])
        text.draw(in: CGRect(x: margin + column.x, y: y, width: column.width, height: 14))
    }

    private func drawTableHeader() {
        ensureSpace(18)
        for col in columns {
            drawTableCell(col.title, column: col, y: cursorY,
                          font: .systemFont(ofSize: 8.5, weight: .semibold),
                          color: inkSecondary)
        }
        cursorY += 14
        rule.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: cursorY))
        path.addLine(to: CGPoint(x: pageRect.width - margin, y: cursorY))
        path.lineWidth = 0.5
        path.stroke()
        cursorY += 4
    }

    private func orderedMarkers(_ session: SDBloodwork) -> [SDBloodworkMarker] {
        session.markers.sorted { a, b in
            let ia = markerOrder.firstIndex(of: a.markerName) ?? Int.max
            let ib = markerOrder.firstIndex(of: b.markerName) ?? Int.max
            return ia == ib ? a.markerName < b.markerName : ia < ib
        }
    }

    private func drawSessions() {
        drawText("Bloodwork Results (newest first)",
                 font: .systemFont(ofSize: 13, weight: .semibold), color: ink, spacingAfter: 8)

        for session in sessions {
            // Session header + table header kept together
            ensureSpace(52)
            var title = session.drawnAt.formatted(date: .long, time: .omitted)
            if let lab = session.labName, !lab.isEmpty { title += "  ·  \(lab)" }
            drawText(title, font: .systemFont(ofSize: 11, weight: .semibold),
                     color: ink, spacingAfter: 5)
            drawTableHeader()

            for marker in orderedMarkers(session) {
                let rowHeight: CGFloat = 15
                if cursorY + rowHeight > contentBottom {
                    beginPage()
                    drawTableHeader()
                }
                let low = marker.referenceRangeLow
                let high = marker.referenceRangeHigh
                var flag = ""
                if let low, marker.value < low { flag = "LOW" }
                if let high, marker.value > high { flag = "HIGH" }
                let rangeText: String
                switch (low, high) {
                case let (l?, h?): rangeText = "\(fmt(l)) – \(fmt(h))"
                case let (l?, nil): rangeText = "≥ \(fmt(l))"
                case let (nil, h?): rangeText = "≤ \(fmt(h))"
                default: rangeText = "—"
                }
                let valueColor = flag.isEmpty ? ink : outOfRange
                let cells = [marker.markerName, fmt(marker.value), marker.unit, rangeText, flag]
                for (i, col) in columns.enumerated() {
                    let isValue = i == 1 || i == 4
                    drawTableCell(cells[i], column: col, y: cursorY,
                                  font: .systemFont(ofSize: 9, weight: isValue && !flag.isEmpty ? .semibold : .regular),
                                  color: i == 0 ? ink : (isValue ? valueColor : inkSecondary))
                }
                cursorY += rowHeight
            }
            cursorY += 4

            if let doctorNotes = session.doctorNotes, !doctorNotes.isEmpty {
                drawText("Notes for doctor:", font: .systemFont(ofSize: 9, weight: .semibold),
                         color: inkSecondary, spacingAfter: 2)
                drawText(doctorNotes, font: .systemFont(ofSize: 9.5), color: ink, spacingAfter: 6)
            }
            drawRule(spacing: 10)
        }
    }

    // MARK: Trend charts

    private func drawTrendSection() {
        // Marker → (date, value) points across sessions, oldest → newest
        var series: [String: [(Date, Double)]] = [:]
        for session in sessions {
            for marker in session.markers {
                series[marker.markerName, default: []].append((session.drawnAt, marker.value))
            }
        }
        let trendable = series
            .mapValues { $0.sorted { $0.0 < $1.0 } }
            .filter { $0.value.count >= 3 }
        guard !trendable.isEmpty else { return }

        let names = markerOrder.filter { trendable.keys.contains($0) }
            + trendable.keys.filter { !markerOrder.contains($0) }.sorted()

        ensureSpace(40)
        drawText("Trends", font: .systemFont(ofSize: 13, weight: .semibold),
                 color: ink, spacingAfter: 2)
        drawText("Values over time as entered. No interpretation is provided.",
                 font: .systemFont(ofSize: 8.5), color: inkSecondary, spacingAfter: 8)

        for name in names {
            guard let points = trendable[name] else { continue }
            let unit = sessions.flatMap(\.markers).first { $0.markerName == name }?.unit ?? ""
            drawTrendChart(name: name, unit: unit, points: points)
        }
    }

    private func drawTrendChart(name: String, unit: String, points: [(Date, Double)]) {
        let chartHeight: CGFloat = 96
        let labelHeight: CGFloat = 14
        let axisPadLeft: CGFloat = 46
        let axisPadBottom: CGFloat = 14
        let total = labelHeight + chartHeight + axisPadBottom + 12
        ensureSpace(total)

        // Title
        let titleText = unit.isEmpty ? name : "\(name) (\(unit))"
        let title = NSAttributedString(string: titleText, attributes: [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold), .foregroundColor: ink
        ])
        title.draw(at: CGPoint(x: margin, y: cursorY))
        let chartTop = cursorY + labelHeight

        let plot = CGRect(x: margin + axisPadLeft, y: chartTop,
                          width: contentWidth - axisPadLeft, height: chartHeight)

        let values = points.map(\.1)
        var lowV = values.min() ?? 0
        var highV = values.max() ?? 1
        if highV == lowV { lowV -= 1; highV += 1 }
        let pad = (highV - lowV) * 0.12
        lowV -= pad; highV += pad

        let t0 = points.first!.0.timeIntervalSinceReferenceDate
        let t1 = points.last!.0.timeIntervalSinceReferenceDate
        let tSpan = max(t1 - t0, 1)

        func pt(_ p: (Date, Double)) -> CGPoint {
            let fx = (p.0.timeIntervalSinceReferenceDate - t0) / tSpan
            let fy = (p.1 - lowV) / (highV - lowV)
            return CGPoint(x: plot.minX + CGFloat(fx) * plot.width,
                           y: plot.maxY - CGFloat(fy) * plot.height)
        }

        // Axes
        inkFaint.setStroke()
        let axes = UIBezierPath()
        axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
        axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        axes.lineWidth = 0.75
        axes.stroke()

        // Y-axis min/max labels
        let axisAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: inkFaint
        ]
        let maxLabel = NSAttributedString(string: fmt(highV), attributes: axisAttrs)
        let minLabel = NSAttributedString(string: fmt(lowV), attributes: axisAttrs)
        maxLabel.draw(at: CGPoint(x: plot.minX - maxLabel.size().width - 4, y: plot.minY - 3))
        minLabel.draw(at: CGPoint(x: plot.minX - minLabel.size().width - 4, y: plot.maxY - 8))

        // X-axis first/last date labels
        let firstDate = NSAttributedString(
            string: points.first!.0.formatted(date: .abbreviated, time: .omitted),
            attributes: axisAttrs)
        let lastDate = NSAttributedString(
            string: points.last!.0.formatted(date: .abbreviated, time: .omitted),
            attributes: axisAttrs)
        firstDate.draw(at: CGPoint(x: plot.minX, y: plot.maxY + 3))
        lastDate.draw(at: CGPoint(x: plot.maxX - lastDate.size().width, y: plot.maxY + 3))

        // Line
        ink.setStroke()
        let line = UIBezierPath()
        line.lineWidth = 1.2
        line.lineJoinStyle = .round
        for (i, p) in points.enumerated() {
            let cp = pt(p)
            if i == 0 { line.move(to: cp) } else { line.addLine(to: cp) }
        }
        line.stroke()

        // Points
        ink.setFill()
        for p in points {
            let cp = pt(p)
            UIBezierPath(ovalIn: CGRect(x: cp.x - 2, y: cp.y - 2, width: 4, height: 4)).fill()
        }

        cursorY = plot.maxY + axisPadBottom + 12
    }
}
