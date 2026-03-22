import SwiftUI
import SwiftData

// MARK: - ActiveCompound

struct ActiveCompound: Identifiable {
    var id: String { name }
    let name: String
    let lastAdministered: Date
    let doseCount: Int
    let lastDose: Double
    let lastDoseUnit: String
}

// MARK: - PeptidesViewModel

@MainActor
final class PeptidesViewModel: ObservableObject {
    @Published var logs: [SDPeptideLog] = []
    @Published var activeCompounds: [ActiveCompound] = []
    @Published var showingLogSheet = false
    @Published var errorMessage: String?

    // Form state
    @Published var formCompoundSelection = "BPC-157"
    @Published var formCustomName = ""
    @Published var formDoseAmount: String = ""
    @Published var formDoseUnit = "mcg"
    @Published var formRoute = "subcutaneous"
    @Published var formSite: String = ""
    @Published var formBatch: String = ""
    @Published var formNotes: String = ""
    @Published var formDate: Date = .now
    @Published var editingLog: SDPeptideLog?

    static let presetCompounds = [
        "BPC-157", "TB-500", "Ipamorelin", "CJC-1295",
        "Semaglutide", "Tirzepatide", "MK-677", "Sermorelin",
        "GHRP-2", "PT-141", "Epithalon", "Custom"
    ]
    static let routes = ["subcutaneous", "intramuscular", "intranasal", "oral"]
    static let doseUnits = ["mcg", "mg", "units"]

    private static let defaultUnits: [String: String] = [
        "BPC-157": "mcg", "TB-500": "mcg", "Ipamorelin": "mcg",
        "CJC-1295": "mcg", "Sermorelin": "mcg", "GHRP-2": "mcg",
        "PT-141": "mcg", "Epithalon": "mcg",
        "Semaglutide": "mg", "Tirzepatide": "mg", "MK-677": "mg"
    ]

    var effectiveCompoundName: String {
        formCompoundSelection == "Custom" ? formCustomName : formCompoundSelection
    }

    private let modelContext: ModelContext
    private let syncEngine = SyncEngine.shared
    let userID: UUID

    init(modelContext: ModelContext, userID: UUID) {
        self.modelContext = modelContext
        self.userID = userID
    }

    // MARK: - Load

    func load() {
        let predicate = #Predicate<SDPeptideLog> { !$0.isSampleData }
        let descriptor = FetchDescriptor<SDPeptideLog>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.administeredAt, order: .reverse)]
        )
        logs = (try? modelContext.fetch(descriptor)) ?? []
        buildActiveCompounds()
    }

    func logsGroupedByDate() -> [(Date, [SDPeptideLog])] {
        let grouped = Dictionary(grouping: logs) { $0.administeredAt.startOfDay }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }

    // MARK: - Form

    func prepareAddForm(compound: String? = nil) {
        editingLog = nil
        let name = compound ?? "BPC-157"
        let isPreset = Self.presetCompounds.contains(name)
        formCompoundSelection = isPreset ? name : "Custom"
        formCustomName = isPreset ? "" : name
        formDoseAmount = ""
        formDoseUnit = Self.defaultUnits[formCompoundSelection] ?? "mcg"
        formRoute = "subcutaneous"
        formSite = ""
        formBatch = ""
        formNotes = ""
        formDate = .now
        showingLogSheet = true
    }

    func prepareEditForm(log: SDPeptideLog) {
        editingLog = log
        let isPreset = Self.presetCompounds.contains(log.peptideName)
        formCompoundSelection = isPreset ? log.peptideName : "Custom"
        formCustomName = isPreset ? "" : log.peptideName
        let dose = log.doseMcg
        formDoseAmount = dose.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", dose)
            : String(format: "%.2f", dose)
        formDoseUnit = log.doseUnit ?? "mcg"
        formRoute = log.routeOfAdministration
        formSite = log.injectionSite ?? ""
        formBatch = log.batchLotNumber ?? ""
        formNotes = log.notes ?? ""
        formDate = log.administeredAt
        showingLogSheet = true
    }

    func onCompoundChanged() {
        if formCompoundSelection != "Custom" {
            formDoseUnit = Self.defaultUnits[formCompoundSelection] ?? "mcg"
        }
    }

    func saveForm() {
        guard let dose = Double(formDoseAmount), dose > 0 else {
            errorMessage = "Please enter a valid dose."
            return
        }
        let name = effectiveCompoundName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = "Please enter a compound name."
            return
        }

        if let existing = editingLog {
            existing.peptideName           = name
            existing.doseMcg               = dose
            existing.doseUnit              = formDoseUnit
            existing.routeOfAdministration = formRoute
            existing.injectionSite         = formSite.isBlank ? nil : formSite
            existing.batchLotNumber        = formBatch.isBlank ? nil : formBatch
            existing.notes                 = formNotes.isBlank ? nil : formNotes
            existing.administeredAt        = formDate
            existing.updatedAt             = .now
        } else {
            let log = SDPeptideLog(
                userID: userID,
                administeredAt: formDate,
                peptideName: name,
                doseMcg: dose,
                doseUnit: formDoseUnit,
                routeOfAdministration: formRoute,
                injectionSite: formSite.isBlank ? nil : formSite,
                batchLotNumber: formBatch.isBlank ? nil : formBatch,
                notes: formNotes.isBlank ? nil : formNotes
            )
            modelContext.insert(log)
        }

        do {
            try modelContext.save()
            showingLogSheet = false
            load()
            syncEngine.triggerSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ log: SDPeptideLog) {
        modelContext.delete(log)
        try? modelContext.save()
        load()
    }

    // MARK: - Private

    private func buildActiveCompounds() {
        let grouped = Dictionary(grouping: logs) { $0.peptideName }
        activeCompounds = grouped.map { name, entries in
            let sorted = entries.sorted { $0.administeredAt > $1.administeredAt }
            let last = sorted[0]
            return ActiveCompound(
                name: name,
                lastAdministered: last.administeredAt,
                doseCount: sorted.count,
                lastDose: last.doseMcg,
                lastDoseUnit: last.doseUnit ?? "mcg"
            )
        }.sorted { $0.lastAdministered > $1.lastAdministered }
    }
}
