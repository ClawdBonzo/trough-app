import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Step enum

enum CSVImportStep: Equatable {
    case filePicker
    case typePicker
    case preview
    case columnMapping
    case importing
    case report
}

// MARK: - Import type

enum CSVImportType: String, CaseIterable, Identifiable {
    case checkins  = "Daily Check-ins"
    case bloodwork = "Bloodwork"
    case both      = "Both"
    var id: String { rawValue }

    /// Localized display name (rawValue stays the stable id).
    var label: String {
        switch self {
        case .checkins:  return NSLocalizedString("import.dailyCheckins", value: "Daily Check-ins", comment: "")
        case .bloodwork: return NSLocalizedString("import.bloodwork", value: "Bloodwork", comment: "")
        case .both:      return NSLocalizedString("import.both", value: "Both", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .checkins:  return "checkmark.circle"
        case .bloodwork: return "drop.fill"
        case .both:      return "square.stack.3d.up"
        }
    }
}

// MARK: - Field definition (used by mapping UI)

struct FieldDef: Identifiable {
    let id: String            // matches ColumnMapping key
    let englishLabel: String
    let isRequired: Bool
    let appliesToCheckins: Bool
    let appliesToBloodwork: Bool

    init(id: String, label: String, isRequired: Bool, appliesToCheckins: Bool, appliesToBloodwork: Bool) {
        self.id = id
        self.englishLabel = label
        self.isRequired = isRequired
        self.appliesToCheckins = appliesToCheckins
        self.appliesToBloodwork = appliesToBloodwork
    }

    /// Localized label for the mapping UI.
    var label: String {
        let scale = gLoc("csv.field.scale", "%@ (1–5)")
        switch id {
        case "date":        return NSLocalizedString("import.date", value: "Date", comment: "")
        case "energy":      return String(format: scale, gLoc("checkin.energy", "Energy"))
        case "mood":        return String(format: scale, gLoc("checkin.mood", "Mood"))
        case "libido":      return String(format: scale, gLoc("checkin.libido", "Libido"))
        case "sleep":       return String(format: scale, gLoc("checkin.sleepQuality", "Sleep Quality"))
        case "clarity":     return String(format: scale, gLoc("checkin.mentalClarity", "Mental Clarity"))
        case "morningwood": return gLoc("dashboard.quickStats.morningWood", "Morning Wood")
        case "workout":     return gLoc("csv.field.workout", "Worked Out")
        case "bodyweight":  return gLoc("onboarding.hkWeight", "Body Weight")
        case "bodyfat":     return gLoc("dashboard.bodyComposition.bodyFatPct", "Body Fat %")
        case "labname":     return NSLocalizedString("import.labName", value: "Lab Name", comment: "")
        default:            return MarkerFormat.displayName(englishLabel)
        }
    }
}

private let allFieldDefs: [FieldDef] = [
    // Required
    FieldDef(id: "date",         label: "Date",              isRequired: true,  appliesToCheckins: true,  appliesToBloodwork: true),
    // Check-in metrics
    FieldDef(id: "energy",       label: "Energy (1–5)",      isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    FieldDef(id: "mood",         label: "Mood (1–5)",        isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    FieldDef(id: "libido",       label: "Libido (1–5)",      isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    FieldDef(id: "sleep",        label: "Sleep Quality (1–5)",isRequired: false, appliesToCheckins: true, appliesToBloodwork: false),
    FieldDef(id: "clarity",      label: "Mental Clarity (1–5)",isRequired: false, appliesToCheckins: true,appliesToBloodwork: false),
    FieldDef(id: "morningwood",  label: "Morning Wood",      isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    FieldDef(id: "workout",      label: "Worked Out",        isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    FieldDef(id: "bodyweight",   label: "Body Weight",       isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    FieldDef(id: "bodyfat",      label: "Body Fat %",        isRequired: false, appliesToCheckins: true,  appliesToBloodwork: false),
    // Bloodwork
    FieldDef(id: "labname",      label: "Lab Name",          isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "totalt",       label: "Total Testosterone",isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "freet",        label: "Free Testosterone", isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "e2",           label: "Estradiol (E2)",    isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "shbg",         label: "SHBG",              isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "hematocrit",   label: "Hematocrit",        isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "hemoglobin",   label: "Hemoglobin",        isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "psa",          label: "PSA",               isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "lh",           label: "LH",                isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "fsh",          label: "FSH",               isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "prolactin",    label: "Prolactin",         isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "totalchol",    label: "Total Cholesterol", isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "ldl",          label: "LDL",               isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "hdl",          label: "HDL",               isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "triglycerides",label: "Triglycerides",     isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "alt",          label: "ALT",               isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
    FieldDef(id: "ast",          label: "AST",               isRequired: false, appliesToCheckins: false, appliesToBloodwork: true),
]

// MARK: - ViewModel

@MainActor
final class CSVImportViewModel: ObservableObject {
    @Published var step: CSVImportStep = .filePicker
    @Published var importType: CSVImportType = .checkins
    @Published var parseResult: CSVParseResult? = nil
    @Published var dateFormatResult: DateFormatResult = .unknown
    @Published var resolvedDateFormat: String = "yyyy-MM-dd"
    @Published var isAmbiguousDate = false
    @Published var mapping: ColumnMapping = ColumnMapping()
    @Published var progress: Double = 0
    @Published var checkinsResult: ImportResult? = nil
    @Published var bloodworkResult: ImportResult? = nil
    @Published var errorMessage: String? = nil

    private let modelContext: ModelContext
    private let userID: UUID

    init(modelContext: ModelContext, userID: UUID) {
        self.modelContext = modelContext
        self.userID = userID
    }

    // MARK: Load file

    func loadFile(_ url: URL) {
        do {
            let result = try CSVImportService.parseCSV(url: url)
            parseResult = result

            // Detect date column first (quick pass), then sample it for format detection
            let dateColIdx = quickFindDateColumn(headers: result.headers)
            let dateSamples = result.rows.prefix(10).map { row in
                dateColIdx < row.count ? row[dateColIdx] : ""
            }.filter { !$0.isEmpty }

            dateFormatResult = CSVImportService.detectDateFormat(samples: dateSamples)
            switch dateFormatResult {
            case .detected(let fmt):
                resolvedDateFormat = fmt
                isAmbiguousDate = false
            case .ambiguous(let primary, _):
                resolvedDateFormat = primary
                isAmbiguousDate = true
            case .unknown:
                resolvedDateFormat = "yyyy-MM-dd"
                isAmbiguousDate = false
            }

            mapping = CSVImportService.detectColumns(headers: result.headers)
            errorMessage = nil
            step = .typePicker
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Quick scan for a date-like column before full detection
    private func quickFindDateColumn(headers: [String]) -> Int {
        let dateWords = ["date", "day", "timestamp", "datetime", "recorded"]
        for (i, h) in headers.enumerated() {
            let norm = CSVImportService.normalize(h)
            if dateWords.contains(norm) || CSVImportService.levenshtein(norm, "date") <= 1 {
                return i
            }
        }
        return 0
    }

    // MARK: Run import

    func runImport() async {
        guard let data = parseResult else { return }
        step = .importing
        progress = 0

        switch importType {
        case .checkins:
            progress = 0.1
            let r = await CSVImportService.importCheckins(
                data: data, mapping: mapping, dateFormat: resolvedDateFormat,
                userID: userID, context: modelContext)
            checkinsResult = r
            progress = 1.0

        case .bloodwork:
            progress = 0.1
            let r = await CSVImportService.importBloodwork(
                data: data, mapping: mapping, dateFormat: resolvedDateFormat,
                userID: userID, context: modelContext)
            bloodworkResult = r
            progress = 1.0

        case .both:
            progress = 0.1
            let cr = await CSVImportService.importCheckins(
                data: data, mapping: mapping, dateFormat: resolvedDateFormat,
                userID: userID, context: modelContext)
            checkinsResult = cr
            progress = 0.55
            let br = await CSVImportService.importBloodwork(
                data: data, mapping: mapping, dateFormat: resolvedDateFormat,
                userID: userID, context: modelContext)
            bloodworkResult = br
            progress = 1.0
        }

        step = .report
    }

    // MARK: Computed helpers

    var hasDateMapped: Bool { mapping["date"] != nil }

    var totalImported: Int {
        (checkinsResult?.importedCount ?? 0) + (bloodworkResult?.importedCount ?? 0)
    }

    var dateRangeString: String {
        let firsts = [checkinsResult?.firstDate, bloodworkResult?.firstDate].compactMap { $0 }
        let lasts  = [checkinsResult?.lastDate,  bloodworkResult?.lastDate ].compactMap { $0 }
        guard let first = firsts.min(), let last = lasts.max() else { return "" }
        if Calendar.current.isDate(first, inSameDayAs: last) { return first.mediumString }
        return "\(first.mediumString) – \(last.mediumString)"
    }

    var allIssues: [ImportRowIssue] {
        let results = [checkinsResult, bloodworkResult].compactMap { $0 }
        return results.flatMap { $0.errors } + results.flatMap { $0.warnings }
    }

    func fieldDefs(for type: CSVImportType) -> [FieldDef] {
        allFieldDefs.filter { def in
            switch type {
            case .checkins:  return def.appliesToCheckins
            case .bloodwork: return def.appliesToBloodwork
            case .both:      return def.appliesToCheckins || def.appliesToBloodwork
            }
        }
    }
}

// MARK: - Main View

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    private var onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    var body: some View {
        // The ViewModel needs the environment's modelContext (the app's real
        // container — never a freshly built one), so it's constructed here in
        // body and handed to the inner view, whose @StateObject keeps the
        // first instance for the lifetime of the flow.
        CSVImportFlowView(
            modelContext: modelContext,
            userID: UUID(uuidString: userIDString) ?? UUID(),
            onComplete: onComplete
        )
    }
}

private struct CSVImportFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CSVImportViewModel
    @State private var showFilePicker = false
    private var onComplete: (() -> Void)?

    init(modelContext: ModelContext, userID: UUID, onComplete: (() -> Void)?) {
        _vm = StateObject(wrappedValue: CSVImportViewModel(
            modelContext: modelContext,
            userID: userID
        ))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground(glow: TR.Palette.mint)
                stepContent
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if vm.step != .report {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    confirmButton
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let didStart = url.startAccessingSecurityScopedResource()
                    defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                    vm.loadFile(url)
                case .failure(let err):
                    vm.errorMessage = err.localizedDescription
                }
            }
        }
    }

    // MARK: Nav title

    private var navTitle: String {
        switch vm.step {
        case .filePicker:    return gLoc("csv.title.import", "Import CSV")
        case .typePicker:    return gLoc("csv.title.whatToImport", "What to Import")
        case .preview:       return gLoc("csv.title.preview", "Preview")
        case .columnMapping: return gLoc("csv.title.mapColumns", "Map Columns")
        case .importing:     return gLoc("csv.title.importing", "Importing…")
        case .report:        return gLoc("csv.title.complete", "Import Complete")
        }
    }

    // MARK: Confirm / next button

    @ViewBuilder
    private var confirmButton: some View {
        switch vm.step {
        case .filePicker:
            EmptyView()
        case .typePicker:
            Button("Next") { vm.step = .preview }
                .fontWeight(.bold)
                .foregroundStyle(TR.Palette.coral)
        case .preview:
            Button("Next") { vm.step = .columnMapping }
                .fontWeight(.bold)
                .foregroundStyle(TR.Palette.coral)
        case .columnMapping:
            Button("Import") {
                Task { await vm.runImport() }
            }
            .fontWeight(.bold)
            .foregroundStyle(vm.hasDateMapped ? TR.Palette.coral : TR.Palette.textTertiary)
            .disabled(!vm.hasDateMapped)
        case .importing, .report:
            EmptyView()
        }
    }

    // MARK: Step content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .filePicker:
            FilePickerStep(showFilePicker: $showFilePicker, errorMessage: vm.errorMessage)
        case .typePicker:
            ImportTypeStep(vm: vm)
        case .preview:
            PreviewStep(vm: vm)
        case .columnMapping:
            ColumnMappingStep(vm: vm)
        case .importing:
            ImportingStep(progress: vm.progress)
        case .report:
            ImportReportView(vm: vm, onDone: {
                if let onComplete { onComplete() } else { dismiss() }
            })
        }
    }
}

// MARK: - Step 1: File Picker

private struct FilePickerStep: View {
    @Binding var showFilePicker: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            GlassEmptyState(
                systemImage: "tablecells",
                title: NSLocalizedString("Select a CSV File", comment: ""),
                message: NSLocalizedString("Supports .csv, .tsv, and .txt with comma, tab, or semicolon delimiters.", comment: ""),
                buttonTitle: NSLocalizedString("Choose File", comment: ""),
                tint: TR.Palette.coral,
                action: { showFilePicker = true }
            )

            if let err = errorMessage {
                Label(err, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .trCard(padding: 12)
                    .padding(.horizontal, TR.Metrics.gutter)
            }

            Spacer()
        }
        .onAppear { showFilePicker = true }
    }
}

// MARK: - Step 2: Import Type

private struct ImportTypeStep: View {
    @ObservedObject var vm: CSVImportViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("What does your spreadsheet contain?")
                .font(TR.Font.display(.title3))
                .foregroundStyle(TR.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            VStack(spacing: 12) {
                ForEach(CSVImportType.allCases) { type in
                    TypeOptionRow(
                        type: type,
                        isSelected: vm.importType == type,
                        onTap: { vm.importType = type }
                    )
                }
            }
            .padding(.horizontal, TR.Metrics.gutter)

            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct TypeOptionRow: View {
    let type: CSVImportType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                GlassIconTile(systemImage: type.icon, tint: isSelected ? TR.Palette.coral : TR.Palette.textSecondary,
                              size: 40, filled: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.label)
                        .font(TR.Font.display(.headline, weight: .bold))
                        .foregroundStyle(isSelected ? TR.Palette.textPrimary : TR.Palette.textSecondary)
                    Text(typeDescription(type))
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? TR.Palette.coral : TR.Palette.textTertiary)
            }
            .trCard(tint: isSelected ? TR.Palette.coral : nil)
            .overlay(
                RoundedRectangle(cornerRadius: TR.Metrics.cardRadius, style: .continuous)
                    .strokeBorder(isSelected ? TR.Palette.coral.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.trPressable)
    }

    private func typeDescription(_ t: CSVImportType) -> String {
        switch t {
        case .checkins:  return gLoc("csv.typeDesc.checkins", "Energy, mood, libido, sleep, clarity, body weight")
        case .bloodwork: return gLoc("csv.typeDesc.bloodwork", "Testosterone, E2, hematocrit, lipids, and more")
        case .both:      return gLoc("csv.typeDesc.both", "Map check-in and bloodwork columns from one file")
        }
    }
}

// MARK: - Step 3: Preview

private struct PreviewStep: View {
    @ObservedObject var vm: CSVImportViewModel

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let parse = vm.parseResult {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(parse.headers, id: \.self) { header in
                            Text(header)
                                .font(.caption.bold())
                                .foregroundStyle(TR.Palette.coralLight)
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(TR.Palette.surfaceRaised)
                        }
                    }
                    Divider().background(TR.Palette.hairline)

                    // First 5 data rows
                    ForEach(Array(parse.rows.prefix(5).enumerated()), id: \.offset) { (rowIdx, row) in
                        HStack(spacing: 0) {
                            ForEach(row.indices, id: \.self) { colIdx in
                                let cell = colIdx < row.count ? row[colIdx] : ""
                                Text(cell.isEmpty ? "—" : cell)
                                    .font(.caption)
                                    .foregroundStyle(cell.isEmpty ? TR.Palette.textTertiary : TR.Palette.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(rowIdx % 2 == 0 ? TR.Palette.surface : TR.Palette.surface.opacity(0.4))
                            }
                        }
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous).strokeBorder(TR.Palette.hairline, lineWidth: 1))
                .padding(TR.Metrics.gutter)
            }
        }

        if let parse = vm.parseResult {
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textTertiary)
                Text(verbatim: String(format: gLoc("csv.parseSummary", "%d rows · %d columns · delimiter: %@"),
                                     parse.rows.count, parse.headers.count, delimiterLabel(parse.delimiter)))
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func delimiterLabel(_ d: Character) -> String {
        switch d {
        case ",":  return gLoc("csv.delimiter.comma", "comma")
        case "\t": return gLoc("csv.delimiter.tab", "tab")
        case ";":  return gLoc("csv.delimiter.semicolon", "semicolon")
        default:   return String(d)
        }
    }
}

// MARK: - Step 4: Column Mapping

private struct ColumnMappingStep: View {
    @ObservedObject var vm: CSVImportViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date format disambiguation banner
                if vm.isAmbiguousDate, case .ambiguous(let primary, let alternate) = vm.dateFormatResult {
                    DateAmbiguityBanner(
                        primary: primary,
                        alternate: alternate,
                        selected: $vm.resolvedDateFormat,
                        sample: sampleDateString()
                    )
                    .padding(.horizontal, TR.Metrics.gutter)
                }

                // Date not mapped warning
                if !vm.hasDateMapped {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(TR.Palette.gold)
                            .font(.subheadline)
                        Text("Map the Date column to proceed.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TR.Palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .trCard(tint: TR.Palette.gold, padding: 12)
                    .padding(.horizontal, TR.Metrics.gutter)
                }

                // Field rows
                VStack(spacing: 0) {
                    ForEach(vm.fieldDefs(for: vm.importType)) { def in
                        FieldMappingRow(
                            def: def,
                            headers: vm.parseResult?.headers ?? [],
                            selectedIndex: selectedBinding(key: def.id)
                        )
                        if def.id != vm.fieldDefs(for: vm.importType).last?.id {
                            Divider().background(TR.Palette.hairline)
                        }
                    }
                }
                .trCard(padding: 0)
                .padding(.horizontal, TR.Metrics.gutter)

                Text("Green = auto-detected  ·  Yellow = not mapped")
                    .font(.caption2)
                    .foregroundStyle(TR.Palette.textTertiary)
                    .padding(.bottom, 8)
            }
            .padding(.top, 12)
        }
    }

    private func selectedBinding(key: String) -> Binding<Int> {
        Binding<Int>(
            get: { vm.mapping[key] ?? -1 },
            set: { vm.mapping[key] = $0 == -1 ? nil : $0 }
        )
    }

    private func sampleDateString() -> String {
        guard let parse = vm.parseResult,
              let dateIdx = vm.mapping["date"], dateIdx < (parse.rows.first?.count ?? 0),
              let row = parse.rows.first else { return "" }
        return row[dateIdx]
    }
}

private struct FieldMappingRow: View {
    let def: FieldDef
    let headers: [String]
    @Binding var selectedIndex: Int

    private var isMapped: Bool { selectedIndex >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .padding(.leading, 16)

            // Field label
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(def.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TR.Palette.textPrimary)
                    if def.isRequired {
                        Text("required")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(TR.Palette.coralLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TR.Palette.coral.opacity(0.15), in: Capsule())
                    }
                }
                if isMapped, selectedIndex < headers.count {
                    Text(headers[selectedIndex])
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                }
            }

            Spacer()

            // Column picker
            Picker("", selection: $selectedIndex) {
                Text("— Not mapped —").tag(-1)
                ForEach(headers.indices, id: \.self) { i in
                    Text(headers[i]).tag(i)
                }
            }
            .pickerStyle(.menu)
            .tint(isMapped ? TR.Palette.coral : TR.Palette.textSecondary)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 10)
    }

    private var dotColor: Color {
        if isMapped { return TR.Palette.mint }
        if def.isRequired { return TR.Palette.coral }
        return TR.Palette.gold
    }
}

private struct DateAmbiguityBanner: View {
    let primary: String
    let alternate: String
    @Binding var selected: String
    let sample: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(TR.Palette.gold)
                Text("Ambiguous date format")
                    .font(.caption.bold())
                    .foregroundStyle(TR.Palette.gold)
            }
            Text("Both day-first and month-first formats matched. Confirm which is correct:")
                .font(.caption)
                .foregroundStyle(TR.Palette.textSecondary)

            // Show what the sample parses to under each format
            HStack(spacing: 10) {
                ForEach([primary, alternate], id: \.self) { fmt in
                    let parsed = parseSample(sample, format: fmt)
                    Button {
                        selected = fmt
                    } label: {
                        VStack(spacing: 3) {
                            Text(fmt)
                                .font(.caption2.bold())
                                .foregroundStyle(selected == fmt ? TR.Palette.textPrimary : TR.Palette.textSecondary)
                            if !parsed.isEmpty {
                                Text(parsed)
                                    .font(.caption2)
                                    .foregroundStyle(TR.Palette.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .frame(minHeight: TR.Metrics.minTap)
                        .background(selected == fmt ? TR.Palette.coral.opacity(0.2) : TR.Palette.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                                .strokeBorder(selected == fmt ? TR.Palette.coral : TR.Palette.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .trCard(tint: TR.Palette.gold, padding: 14)
    }

    private func parseSample(_ s: String, format: String) -> String {
        guard !s.isEmpty else { return "" }
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: s) else { return "" }
        return d.formatted(date: .long, time: .omitted)
    }
}

// MARK: - Step 5: Importing

private struct ImportingStep: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                TRRing(progress: progress, lineWidth: 12, colors: [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]) {
                    Text("\(Int((min(max(progress, 0), 1)) * 100))%")
                        .font(TR.Font.number(28))
                        .foregroundStyle(TR.Palette.textPrimary)
                }
                .frame(width: 140, height: 140)

                Text(progress >= 1.0 ? gLoc("csv.finishing", "Finishing up…") : gLoc("csv.importingRecords", "Importing records…"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Step 6: Import Report

struct ImportReportView: View {
    @ObservedObject var vm: CSVImportViewModel
    let onDone: () -> Void

    @State private var showWarnings = false
    @State private var showErrors   = false

    private var allErrors:   [ImportRowIssue] {
        [vm.checkinsResult, vm.bloodworkResult].compactMap { $0 }.flatMap { $0.errors }
    }
    private var allWarnings: [ImportRowIssue] {
        [vm.checkinsResult, vm.bloodworkResult].compactMap { $0 }.flatMap { $0.warnings }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Success banner ───────────────────────────────────────────
                VStack(spacing: 12) {
                    GlassIconTile(systemImage: allErrors.isEmpty ? "checkmark" : "exclamationmark",
                                  tint: allErrors.isEmpty ? TR.Palette.mint : TR.Palette.gold,
                                  size: 64, filled: true)
                        .trGlow(allErrors.isEmpty ? TR.Palette.mint : TR.Palette.gold, radius: 14, opacity: 0.4)

                    Text(allErrors.isEmpty ? gLoc("csv.title.complete", "Import Complete") : gLoc("csv.title.withIssues", "Imported with Issues"))
                        .font(TR.Font.display(.title2))
                        .foregroundStyle(TR.Palette.textPrimary)

                    Text(verbatim: vm.totalImported == 1
                         ? gLoc("csv.importedRecords.one", "Imported 1 record")
                         : String(format: gLoc("csv.importedRecords.other", "Imported %d records"), vm.totalImported))
                        .font(TR.Font.display(.headline, weight: .bold))
                        .foregroundStyle(TR.Palette.coralLight)

                    if !vm.dateRangeString.isEmpty {
                        Text(vm.dateRangeString)
                            .font(.subheadline)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .trCard(tint: allErrors.isEmpty ? TR.Palette.mint : TR.Palette.gold, padding: 20)

                // ── Per-type breakdown ───────────────────────────────────────
                if let cr = vm.checkinsResult {
                    ResultBreakdownRow(
                        icon: "checkmark.circle",
                        label: gLoc("ach.cat.checkins", "Check-ins"),
                        imported: cr.importedCount,
                        skipped: cr.skippedCount
                    )
                }
                if let br = vm.bloodworkResult {
                    ResultBreakdownRow(
                        icon: "drop.fill",
                        label: NSLocalizedString("import.bloodwork", value: "Bloodwork", comment: ""),
                        imported: br.importedCount,
                        skipped: br.skippedCount
                    )
                }

                // ── Warnings (collapsible) ───────────────────────────────────
                if !allWarnings.isEmpty {
                    IssueSection(
                        title: allWarnings.count == 1
                            ? gLoc("csv.warnings.one", "1 Warning")
                            : String(format: gLoc("csv.warnings.other", "%d Warnings"), allWarnings.count),
                        icon: "exclamationmark.triangle",
                        color: TR.Palette.gold,
                        issues: allWarnings,
                        isExpanded: $showWarnings
                    )
                }

                // ── Errors (collapsible) ─────────────────────────────────────
                if !allErrors.isEmpty {
                    IssueSection(
                        title: allErrors.count == 1
                            ? gLoc("csv.rowsSkipped.one", "1 Row Skipped")
                            : String(format: gLoc("csv.rowsSkipped.other", "%d Rows Skipped"), allErrors.count),
                        icon: "xmark.circle",
                        color: TR.Palette.lilac,
                        issues: allErrors,
                        isExpanded: $showErrors
                    )
                }

                // ── Done button ──────────────────────────────────────────────
                Button("Done") { onDone() }
                    .buttonStyle(.trPrimary)
                    .padding(.top, 8)
            }
            .padding(TR.Metrics.gutter)
        }
    }
}

private struct ResultBreakdownRow: View {
    let icon: String
    let label: String
    let imported: Int
    let skipped: Int

    var body: some View {
        HStack(spacing: 14) {
            GlassIconTile(systemImage: icon, tint: TR.Palette.coral)

            Text(label)
                .foregroundStyle(TR.Palette.textPrimary)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(verbatim: String(format: gLoc("csv.importedCount", "%d imported"), imported))
                .font(.caption.weight(.bold))
                .foregroundStyle(TR.Palette.mint)

            if skipped > 0 {
                Text(verbatim: String(format: gLoc("csv.skippedCount", "%d skipped"), skipped))
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
        }
        .trCard(padding: 14)
    }
}

private struct IssueSection: View {
    let title: String
    let icon: String
    let color: Color
    let issues: [ImportRowIssue]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header (tap to expand)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.caption)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TR.Palette.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: TR.Metrics.minTap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(TR.Palette.hairline)
                VStack(spacing: 0) {
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Text(verbatim: String(format: gLoc("csv.rowIssue", "Row %d:"), issue.row))
                                .font(.caption2.bold())
                                .foregroundStyle(TR.Palette.textTertiary)
                                .frame(width: 52, alignment: .leading)
                            Text(issue.message)
                                .font(.caption2)
                                .foregroundStyle(TR.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        if issue.id != issues.last?.id {
                            Divider().background(TR.Palette.hairline)
                                .padding(.leading, 74)
                        }
                    }
                }
            }
        }
        .trCard(padding: 0)
    }
}
