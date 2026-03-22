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
    let label: String
    let isRequired: Bool
    let appliesToCheckins: Bool
    let appliesToBloodwork: Bool
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

        SyncEngine.shared.triggerSync()
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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CSVImportViewModel
    @State private var showFilePicker = false
    private var onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        let id = UUID(uuidString: UserDefaults.standard.string(forKey: "userIDString") ?? "") ?? UUID()
        _vm = StateObject(wrappedValue: CSVImportViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Schema(TroughSchemaV1.models))),
            userID: id
        ))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                stepContent
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if vm.step != .report {
                        Button("Cancel") { dismiss() }
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
        case .filePicker:    return "Import CSV"
        case .typePicker:    return "What to Import"
        case .preview:       return "Preview"
        case .columnMapping: return "Map Columns"
        case .importing:     return "Importing…"
        case .report:        return "Import Complete"
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
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accent)
        case .preview:
            Button("Next") { vm.step = .columnMapping }
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accent)
        case .columnMapping:
            Button("Import") {
                Task { await vm.runImport() }
            }
            .fontWeight(.semibold)
            .foregroundColor(vm.hasDateMapped ? AppColors.accent : .secondary)
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
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accent.opacity(0.7))

            VStack(spacing: 8) {
                Text("Select a CSV File")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Supports .csv, .tsv, and .txt with comma, tab, or semicolon delimiters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(CSVImportType.allCases) { type in
                    TypeOptionRow(
                        type: type,
                        isSelected: vm.importType == type,
                        onTap: { vm.importType = type }
                    )
                }
            }
            .padding(.horizontal, 16)

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
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.accent : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .secondary)
                    Text(typeDescription(type))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(16)
            .background(isSelected ? AppColors.accent.opacity(0.12) : AppColors.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func typeDescription(_ t: CSVImportType) -> String {
        switch t {
        case .checkins:  return "Energy, mood, libido, sleep, clarity, body weight"
        case .bloodwork: return "Testosterone, E2, hematocrit, lipids, and more"
        case .both:      return "Map check-in and bloodwork columns from one file"
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
                                .foregroundColor(AppColors.accent)
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(AppColors.card)
                        }
                    }
                    Divider().background(Color.white.opacity(0.1))

                    // First 5 data rows
                    ForEach(Array(parse.rows.prefix(5).enumerated()), id: \.offset) { (rowIdx, row) in
                        HStack(spacing: 0) {
                            ForEach(row.indices, id: \.self) { colIdx in
                                let cell = colIdx < row.count ? row[colIdx] : ""
                                Text(cell.isEmpty ? "—" : cell)
                                    .font(.caption)
                                    .foregroundColor(cell.isEmpty ? .secondary : .white)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(rowIdx % 2 == 0 ? AppColors.card.opacity(0.5) : Color.clear)
                            }
                        }
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
        }

        if let parse = vm.parseResult {
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(parse.rows.count) rows · \(parse.headers.count) columns · delimiter: \(delimiterLabel(parse.delimiter))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func delimiterLabel(_ d: Character) -> String {
        switch d {
        case ",":  return "comma"
        case "\t": return "tab"
        case ";":  return "semicolon"
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
                    .padding(.horizontal, 16)
                }

                // Date not mapped warning
                if !vm.hasDateMapped {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("Map the Date column to proceed.")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
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
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(AppColors.card)
                .cornerRadius(12)
                .padding(.horizontal, 16)

                Text("Green = auto-detected  ·  Yellow = not mapped")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if def.isRequired {
                        Text("required")
                            .font(.caption2)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                if isMapped, selectedIndex < headers.count {
                    Text(headers[selectedIndex])
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .tint(isMapped ? AppColors.accent : .secondary)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 10)
    }

    private var dotColor: Color {
        if isMapped { return .green }
        if def.isRequired { return AppColors.accent }
        return .yellow
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
                    .foregroundColor(.yellow)
                Text("Ambiguous date format")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
            }
            Text("Both day-first and month-first formats matched. Confirm which is correct:")
                .font(.caption)
                .foregroundColor(.secondary)

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
                                .foregroundColor(selected == fmt ? .white : .secondary)
                            if !parsed.isEmpty {
                                Text(parsed)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == fmt ? AppColors.accent.opacity(0.2) : Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected == fmt ? AppColors.accent : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.yellow.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
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
                ProgressView(value: progress)
                    .tint(AppColors.accent)
                    .scaleEffect(x: 1, y: 2)
                    .padding(.horizontal, 32)

                Text(progress >= 1.0 ? "Finishing up…" : "Importing records…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                    Image(systemName: allErrors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(allErrors.isEmpty ? .green : .yellow)

                    Text(allErrors.isEmpty ? "Import Complete" : "Imported with Issues")
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text("Imported \(vm.totalImported) record\(vm.totalImported == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(AppColors.accent)

                    if !vm.dateRangeString.isEmpty {
                        Text(vm.dateRangeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(AppColors.card)
                .cornerRadius(16)

                // ── Per-type breakdown ───────────────────────────────────────
                if let cr = vm.checkinsResult {
                    ResultBreakdownRow(
                        icon: "checkmark.circle",
                        label: "Check-ins",
                        imported: cr.importedCount,
                        skipped: cr.skippedCount
                    )
                }
                if let br = vm.bloodworkResult {
                    ResultBreakdownRow(
                        icon: "drop.fill",
                        label: "Bloodwork",
                        imported: br.importedCount,
                        skipped: br.skippedCount
                    )
                }

                // ── Warnings (collapsible) ───────────────────────────────────
                if !allWarnings.isEmpty {
                    IssueSection(
                        title: "\(allWarnings.count) Warning\(allWarnings.count == 1 ? "" : "s")",
                        icon: "exclamationmark.triangle",
                        color: .yellow,
                        issues: allWarnings,
                        isExpanded: $showWarnings
                    )
                }

                // ── Errors (collapsible) ─────────────────────────────────────
                if !allErrors.isEmpty {
                    IssueSection(
                        title: "\(allErrors.count) Row\(allErrors.count == 1 ? "" : "s") Skipped",
                        icon: "xmark.circle",
                        color: AppColors.accent,
                        issues: allErrors,
                        isExpanded: $showErrors
                    )
                }

                // ── Done button ──────────────────────────────────────────────
                Button("Done") { onDone() }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent)
                    .cornerRadius(14)
                    .padding(.top, 8)
            }
            .padding(16)
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
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 22)

            Text(label)
                .foregroundColor(.white)
                .font(.subheadline)

            Spacer()

            Text("\(imported) imported")
                .font(.caption)
                .foregroundColor(.green)

            if skipped > 0 {
                Text("\(skipped) skipped")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(AppColors.card)
        .cornerRadius(12)
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
                        .foregroundColor(color)
                        .font(.caption)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.white.opacity(0.07))
                VStack(spacing: 0) {
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Text("Row \(issue.row):")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .frame(width: 52, alignment: .leading)
                            Text(issue.message)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        if issue.id != issues.last?.id {
                            Divider().background(Color.white.opacity(0.04))
                                .padding(.leading, 74)
                        }
                    }
                }
            }
        }
        .background(AppColors.card)
        .cornerRadius(12)
    }
}
