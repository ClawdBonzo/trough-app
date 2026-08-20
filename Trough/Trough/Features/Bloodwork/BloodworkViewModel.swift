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

    static let sections: [MarkerSection] = [
        MarkerSection(title: "Core", defs: [
            MarkerDef(name: "Total Testosterone",  unit: "ng/dL",  rangeLow: 300,  rangeHigh: 1000),
            MarkerDef(name: "Free Testosterone",   unit: "pg/mL",  rangeLow: 8.7,  rangeHigh: 25.1),
            MarkerDef(name: "Estradiol (E2)",       unit: "pg/mL",  rangeLow: 7.6,  rangeHigh: 42.6),
            MarkerDef(name: "SHBG",                unit: "nmol/L", rangeLow: 16.5, rangeHigh: 55.9),
            MarkerDef(name: "Hematocrit",          unit: "%",      rangeLow: 38.3, rangeHigh: 50.9),
            MarkerDef(name: "Hemoglobin",          unit: "g/dL",   rangeLow: 13.2, rangeHigh: 17.1),
            MarkerDef(name: "PSA",                 unit: "ng/mL",  rangeLow: 0.0,  rangeHigh: 4.0),
        ]),
        MarkerSection(title: "Hormones", defs: [
            MarkerDef(name: "LH",           unit: "IU/L",   rangeLow: 1.7,  rangeHigh: 8.6),
            MarkerDef(name: "FSH",          unit: "IU/L",   rangeLow: 1.5,  rangeHigh: 12.4),
            MarkerDef(name: "Prolactin",    unit: "ng/mL",  rangeLow: 2.0,  rangeHigh: 18.0),
            MarkerDef(name: "DHEA-S",       unit: "μg/dL",  rangeLow: 88.0, rangeHigh: 483.0),
            MarkerDef(name: "Cortisol (AM)",unit: "μg/dL",  rangeLow: 6.2,  rangeHigh: 19.4),
            MarkerDef(name: "TSH",          unit: "mIU/L",  rangeLow: 0.4,  rangeHigh: 4.0),
        ]),
        MarkerSection(title: "Lipids", defs: [
            MarkerDef(name: "Total Cholesterol", unit: "mg/dL", rangeLow: 0.0,  rangeHigh: 200.0),
            MarkerDef(name: "LDL",               unit: "mg/dL", rangeLow: 0.0,  rangeHigh: 100.0),
            MarkerDef(name: "HDL",               unit: "mg/dL", rangeLow: 40.0, rangeHigh: 120.0),
            MarkerDef(name: "Triglycerides",     unit: "mg/dL", rangeLow: 0.0,  rangeHigh: 150.0),
        ]),
        MarkerSection(title: "Liver", defs: [
            MarkerDef(name: "ALT", unit: "U/L", rangeLow: 7.0,  rangeHigh: 56.0),
            MarkerDef(name: "AST", unit: "U/L", rangeLow: 10.0, rangeHigh: 40.0),
        ]),
    ]

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

    /// Injected by the parent view — used to award XP and complete quests on bloodwork save.
    weak var gamificationVM: GamificationViewModel?

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
        healLegacyPhotoPaths()
    }

    /// One-time self-heal: records saved before v1.1.4 stored absolute file
    /// paths, which break whenever the app container UUID changes. Rewrites
    /// them to filename-only once the file is confirmed present.
    private func healLegacyPhotoPaths() {
        var healed = false
        for bw in results {
            guard let stored = bw.photoURL, stored.contains("/") else { continue }
            if let url = Self.photoFileURL(stored),
               FileManager.default.fileExists(atPath: url.path) {
                bw.photoURL = url.lastPathComponent
                healed = true
            }
        }
        if healed { try? modelContext.save() }
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

        let isNewResult = editingResult == nil
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

        // Persist photo locally (on-device only — nothing is uploaded).
        if let data = pendingPhotoData {
            if let saved = Self.savePhoto(data, for: bw.id) {
                bw.photoURL = saved
            }
        } else if editingResult != nil {
            // Editing an existing panel with no photo present — the user removed it.
            Self.deletePhoto(bw.photoURL)
            bw.photoURL = nil
        }

        do {
            try modelContext.save()
            showingEntrySheet = false
            load()

            // Gamification: only award XP for new bloodwork results (not edits)
            if isNewResult {
                BadgeService.checkBloodworkMasterBadge(context: modelContext, userID: userID)
                if let gvm = gamificationVM {
                    gvm.awardXP(30, reason: "bloodwork_logged")
                    gvm.completeQuest(QuestService.weeklyBloodworkQuestID())
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Delete

    func delete(_ bw: SDBloodwork) {
        Self.deletePhoto(bw.photoURL)
        modelContext.delete(bw)
        try? modelContext.save()
        load()
    }

    // MARK: Local photo storage (on-device only)

    /// Directory holding bloodwork photos inside the app's Documents container.
    private static var photoDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("BloodworkPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Writes JPEG data to the photos directory keyed by bloodwork id.
    /// Returns the FILENAME to store in `SDBloodwork.photoURL` — never an
    /// absolute path, because the app container UUID changes on every update
    /// and stored absolute paths go stale.
    static func savePhoto(_ data: Data, for id: UUID) -> String? {
        let filename = "\(id.uuidString).jpg"
        let url = photoDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    /// Resolves a stored `photoURL` value against the CURRENT photo directory.
    /// Handles both the new filename-only format and legacy absolute
    /// path/URL strings (whose container prefix is stale after app updates).
    static func photoFileURL(_ stored: String?) -> URL? {
        guard let stored, !stored.isEmpty else { return nil }
        let filename = stored.contains("/")
            ? (URL(string: stored)?.lastPathComponent ?? (stored as NSString).lastPathComponent)
            : stored
        guard !filename.isEmpty else { return nil }
        return photoDirectory.appendingPathComponent(filename)
    }

    /// Loads photo data for a stored `photoURL` value, if the file exists.
    static func loadPhoto(_ stored: String?) -> Data? {
        guard let url = photoFileURL(stored) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Removes the photo file for a stored `photoURL` value, if present.
    static func deletePhoto(_ stored: String?) {
        guard let url = photoFileURL(stored) else { return }
        try? FileManager.default.removeItem(at: url)
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
