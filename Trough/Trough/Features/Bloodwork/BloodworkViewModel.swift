import SwiftUI
import SwiftData

// MARK: - Supporting types

struct MarkerDef {
    let name: String
    let unit: String
    let rangeLow: Double
    let rangeHigh: Double
}

struct MarkerSection {
    let title: String
    let defs: [MarkerDef]
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - BloodworkViewModel

@MainActor
final class BloodworkViewModel: ObservableObject {

    // MARK: List state
    @Published var results: [SDBloodwork] = []
    @Published var showingEntrySheet = false
    @Published var editingResult: SDBloodwork? = nil
    @Published var errorMessage: String?

    // MARK: Trend panel
    enum TrendPanel: String, CaseIterable, Identifiable {
        case primary    = "T / Free T"
        case e2         = "E2"
        case hematocrit = "Hematocrit"
        case shbg       = "SHBG"
        case lipids     = "Lipids"
        case fertility  = "Fertility"
        var id: String { rawValue }
    }
    @Published var selectedPanel: TrendPanel = .primary
    @Published var showFertilityTimeline = false

    /// Panels to display — includes Fertility only when hCG injections exist.
    var availablePanels: [TrendPanel] {
        let hasHCG = results.flatMap(\.markers).contains { $0.markerName == "LH" || $0.markerName == "FSH" }
        if hasHCG { return TrendPanel.allCases }
        return TrendPanel.allCases.filter { $0 != .fertility }
    }

    // MARK: Form state
    @Published var formDrawnAt: Date = .now
    @Published var formLabName: String = ""
    @Published var formNotes: String = ""
    @Published var formDoctorNotes: String = ""
    @Published var formMarkers: [MarkerEntry] = []
    @Published var pendingPhotoData: Data? = nil

    struct MarkerEntry: Identifiable {
        let id = UUID()
        var sectionTitle: String
        var name: String
        var value: String = ""
        let unit: String
        let defaultRangeLow: Double      // original MarkerDef range
        let defaultRangeHigh: Double
        var customRangeLow: String = ""   // user-editable text fields
        var customRangeHigh: String = ""

        /// Effective range — uses custom if set, else default
        var rangeLow: Double {
            Double(customRangeLow) ?? defaultRangeLow
        }
        var rangeHigh: Double {
            Double(customRangeHigh) ?? defaultRangeHigh
        }
        var hasCustomRange: Bool {
            Double(customRangeLow) != nil || Double(customRangeHigh) != nil
        }

        var valueDouble: Double? { Double(value) }
        var isInRange: Bool? {
            guard let v = valueDouble else { return nil }
            return v >= rangeLow && v <= rangeHigh
        }
    }

    // MARK: Marker definitions

    /// Returns true if the device locale uses SI/metric lab units (UK, AU, CA, NZ, etc.)
    private static var usesMetricLabs: Bool {
        let region = Locale.current.region?.identifier ?? "US"
        return ["GB", "AU", "CA", "NZ", "IE", "ZA", "IN"].contains(region)
    }

    static var sections: [MarkerSection] {
        let metric = usesMetricLabs
        return [
            MarkerSection(title: "Core", defs: [
                // UK/AU/CA labs report testosterone in nmol/L; US in ng/dL
                metric
                    ? MarkerDef(name: "Total Testosterone", unit: "nmol/L", rangeLow: 10.4, rangeHigh: 34.7)
                    : MarkerDef(name: "Total Testosterone", unit: "ng/dL",  rangeLow: 300,  rangeHigh: 1000),
                metric
                    ? MarkerDef(name: "Free Testosterone",  unit: "pmol/L", rangeLow: 170,  rangeHigh: 700)
                    : MarkerDef(name: "Free Testosterone",  unit: "pg/mL",  rangeLow: 8.7,  rangeHigh: 25.1),
                metric
                    ? MarkerDef(name: "Estradiol (E2)",     unit: "pmol/L", rangeLow: 28,   rangeHigh: 156)
                    : MarkerDef(name: "Estradiol (E2)",     unit: "pg/mL",  rangeLow: 7.6,  rangeHigh: 42.6),
                MarkerDef(name: "SHBG",                     unit: "nmol/L", rangeLow: 16.5, rangeHigh: 55.9),
                // Hematocrit: UK upper limit slightly stricter per NHS guidelines
                metric
                    ? MarkerDef(name: "Hematocrit",         unit: "%",      rangeLow: 38.0, rangeHigh: 49.0)
                    : MarkerDef(name: "Hematocrit",         unit: "%",      rangeLow: 38.3, rangeHigh: 50.9),
                metric
                    ? MarkerDef(name: "Haemoglobin",        unit: "g/L",    rangeLow: 130,  rangeHigh: 170)
                    : MarkerDef(name: "Hemoglobin",         unit: "g/dL",   rangeLow: 13.2, rangeHigh: 17.1),
                // PSA: UK/AU use same threshold but different spelling context
                MarkerDef(name: "PSA",                      unit: "ng/mL",  rangeLow: 0.0,  rangeHigh: 4.0),
            ]),
            MarkerSection(title: "Hormones", defs: [
                MarkerDef(name: "LH",            unit: "IU/L",   rangeLow: 1.7,  rangeHigh: 8.6),
                MarkerDef(name: "FSH",           unit: "IU/L",   rangeLow: 1.5,  rangeHigh: 12.4),
                MarkerDef(name: "Prolactin",     unit: "mIU/L",  rangeLow: 86,   rangeHigh: 324),
                metric
                    ? MarkerDef(name: "DHEA-S",  unit: "μmol/L", rangeLow: 2.4,  rangeHigh: 13.1)
                    : MarkerDef(name: "DHEA-S",  unit: "μg/dL",  rangeLow: 88.0, rangeHigh: 483.0),
                metric
                    ? MarkerDef(name: "Cortisol (AM)", unit: "nmol/L", rangeLow: 171, rangeHigh: 536)
                    : MarkerDef(name: "Cortisol (AM)", unit: "μg/dL",  rangeLow: 6.2, rangeHigh: 19.4),
                MarkerDef(name: "TSH",           unit: "mIU/L",  rangeLow: 0.4,  rangeHigh: 4.0),
            ]),
            MarkerSection(title: "Lipids", defs: [
                // UK/AU/CA labs report cholesterol in mmol/L
                metric
                    ? MarkerDef(name: "Total Cholesterol", unit: "mmol/L", rangeLow: 0.0, rangeHigh: 5.0)
                    : MarkerDef(name: "Total Cholesterol", unit: "mg/dL",  rangeLow: 0.0, rangeHigh: 200.0),
                metric
                    ? MarkerDef(name: "LDL",               unit: "mmol/L", rangeLow: 0.0, rangeHigh: 3.0)
                    : MarkerDef(name: "LDL",               unit: "mg/dL",  rangeLow: 0.0, rangeHigh: 100.0),
                metric
                    ? MarkerDef(name: "HDL",               unit: "mmol/L", rangeLow: 1.0, rangeHigh: 3.1)
                    : MarkerDef(name: "HDL",               unit: "mg/dL",  rangeLow: 40.0, rangeHigh: 120.0),
                metric
                    ? MarkerDef(name: "Triglycerides",     unit: "mmol/L", rangeLow: 0.0, rangeHigh: 1.7)
                    : MarkerDef(name: "Triglycerides",     unit: "mg/dL",  rangeLow: 0.0, rangeHigh: 150.0),
            ]),
            MarkerSection(title: "Liver", defs: [
                MarkerDef(name: "ALT", unit: "U/L", rangeLow: 7.0,  rangeHigh: 56.0),
                MarkerDef(name: "AST", unit: "U/L", rangeLow: 10.0, rangeHigh: 40.0),
            ]),
        ]
    }

    // MARK: Trend data

    var trendPoints: [String: [TrendPoint]] {
        var dict: [String: [TrendPoint]] = [:]
        for bw in results {
            for m in bw.markers {
                dict[m.markerName, default: []].append(
                    TrendPoint(date: bw.drawnAt, value: m.value)
                )
            }
        }
        return dict.mapValues { $0.sorted { $0.date < $1.date } }
    }

    func def(for name: String) -> MarkerDef? {
        Self.sections.flatMap(\.defs).first { $0.name == name }
    }

    // MARK: Private

    private var modelContext: ModelContext!
    private(set) var userID: UUID = UUID()

    init() {}

    func setup(context: ModelContext, userID: UUID) {
        self.modelContext = context
        self.userID = userID
    }

    // MARK: Load

    func load() {
        let pred = #Predicate<SDBloodwork> { !$0.isSampleData }
        let desc = FetchDescriptor<SDBloodwork>(
            predicate: pred,
            sortBy: [SortDescriptor(\.drawnAt, order: .reverse)]
        )
        results = (try? modelContext.fetch(desc)) ?? []
    }

    // MARK: Prepare form

    func prepareAddForm() {
        editingResult = nil
        formDrawnAt = .now
        formLabName = ""
        formNotes = ""
        formDoctorNotes = ""
        pendingPhotoData = nil
        formMarkers = Self.sections.flatMap { section in
            section.defs.map { def in
                MarkerEntry(sectionTitle: section.title, name: def.name,
                            value: "", unit: def.unit,
                            defaultRangeLow: def.rangeLow, defaultRangeHigh: def.rangeHigh)
            }
        }
        showingEntrySheet = true
    }

    func prepareEditForm(_ bw: SDBloodwork) {
        editingResult = bw
        formDrawnAt = bw.drawnAt
        formLabName = bw.labName ?? ""
        formNotes = bw.notes ?? ""
        formDoctorNotes = bw.doctorNotes ?? ""
        pendingPhotoData = nil
        formMarkers = Self.sections.flatMap { section in
            section.defs.map { def in
                let existing = bw.markers.first { $0.markerName == def.name }
                // Detect custom ranges: if stored range differs from default, show it
                let customLow = existing.flatMap { m in
                    m.referenceRangeLow.flatMap { $0 != def.rangeLow ? String(format: "%.1f", $0) : nil }
                } ?? ""
                let customHigh = existing.flatMap { m in
                    m.referenceRangeHigh.flatMap { $0 != def.rangeHigh ? String(format: "%.1f", $0) : nil }
                } ?? ""
                return MarkerEntry(
                    sectionTitle: section.title, name: def.name,
                    value: existing.map { String(format: "%.1f", $0.value) } ?? "",
                    unit: def.unit, defaultRangeLow: def.rangeLow, defaultRangeHigh: def.rangeHigh,
                    customRangeLow: customLow, customRangeHigh: customHigh
                )
            }
        }
        showingEntrySheet = true
    }

    // MARK: Save

    func saveForm() {
        let filled = formMarkers.filter { $0.valueDouble != nil }
        guard !filled.isEmpty else { errorMessage = "Enter at least one value."; return }

        let bw: SDBloodwork
        if let existing = editingResult {
            existing.drawnAt      = formDrawnAt
            existing.labName      = formLabName.trimmed.nilIfEmpty
            existing.notes        = formNotes.trimmed.nilIfEmpty
            existing.doctorNotes  = formDoctorNotes.trimmed.nilIfEmpty
            existing.updatedAt    = .now
            // Replace markers
            for m in existing.markers { modelContext.delete(m) }
            existing.markers = []
            bw = existing
        } else {
            bw = SDBloodwork(
                userID: userID,
                drawnAt: formDrawnAt,
                labName: formLabName.trimmed.nilIfEmpty,
                notes: formNotes.trimmed.nilIfEmpty,
                doctorNotes: formDoctorNotes.trimmed.nilIfEmpty
            )
            modelContext.insert(bw)
        }

        for entry in filled {
            let marker = SDBloodworkMarker(
                bloodworkID: bw.id,
                markerName: entry.name,
                value: entry.valueDouble!,
                unit: entry.unit,
                referenceRangeLow: entry.rangeLow,
                referenceRangeHigh: entry.rangeHigh
            )
            modelContext.insert(marker)
            bw.markers.append(marker)
        }

        do {
            try modelContext.save()
            showingEntrySheet = false
            load()

            // Upload photo in background if present
            if let photoData = pendingPhotoData {
                let bwID = bw.id
                Task {
                    if let url = try? await SupabaseService.shared.uploadBloodworkPhoto(photoData, bloodworkID: bwID) {
                        bw.photoURL = url
                        try? modelContext.save()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Delete

    func delete(_ bw: SDBloodwork) {
        modelContext.delete(bw)
        try? modelContext.save()
        load()
    }

    // MARK: Sections for form

    func formSections() -> [(title: String, entries: [MarkerEntry])] {
        let sectionTitles = Self.sections.map(\.title)
        return sectionTitles.map { title in
            (title, formMarkers.filter { $0.sectionTitle == title })
        }
    }
}

// MARK: - String helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
