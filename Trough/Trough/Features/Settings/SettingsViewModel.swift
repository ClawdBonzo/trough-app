import SwiftUI
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var currentProtocol: SDProtocol?
    @Published var supplements: [SDSupplementConfig] = []       // active only (for check-in)
    @Published var allSupplements: [SDSupplementConfig] = []    // all (for SupplementConfigView)
    @Published var showingAddProtocol = false
    @Published var showingAddSupplement = false
    @Published var syncConflicts: [SDSyncConflict] = []
    @Published var isSyncing = false
    @Published var errorMessage: String?

    // Protocol form
    @Published var formProtoName = ""
    @Published var formCompound = "Testosterone Cypionate"
    @Published var formDoseMg: String = ""
    @Published var formFrequencyDays: String = "7"
    @Published var formConcentration: String = "200"

    // Supplement form
    @Published var formPresetName = "Creatine"       // preset name OR "Custom"
    @Published var formSupplName = ""                // used when formPresetName == "Custom"
    @Published var formSupplDose: String = "5"
    @Published var formSupplUnit = "g"
    @Published var formSupplFreq: String = "1"

    // MARK: - Preset Library

    static let presets: [(name: String, doseAmount: Double, doseUnit: String)] = [
        ("Ashwagandha",       600,  "mg"),
        ("Berberine",         500,  "mg"),
        ("Boron",             6,    "mg"),
        ("CoQ10",             200,  "mg"),
        ("Creatine",          5,    "g"),
        ("DHEA",              25,   "mg"),
        ("DIM",               200,  "mg"),
        ("Fadogia Agrestis",  600,  "mg"),
        ("Fish Oil / Omega-3", 2,   "g"),
        ("Magnesium",         400,  "mg"),
        ("Pregnenolone",      30,   "mg"),
        ("Saw Palmetto",      320,  "mg"),
        ("Tongkat Ali",       400,  "mg"),
        ("Vitamin D3",        5000, "IU"),
        ("Vitamin K2",        100,  "mcg"),
        ("Zinc",              30,   "mg"),
    ]
    static let presetNames: [String] = presets.map(\.name) + ["Custom"]

    private var modelContext: ModelContext!
    private(set) var userID: UUID = UUID()

    init() {}

    func setup(context: ModelContext, userID: UUID) {
        self.modelContext = context
        self.userID = userID
    }

    // MARK: - Load

    func load() {
        let protoPred = #Predicate<SDProtocol> { $0.isActive && !$0.isSampleData }
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: protoPred)
        protoDesc.fetchLimit = 1
        currentProtocol = try? modelContext.fetch(protoDesc).first

        let activeSupplPred = #Predicate<SDSupplementConfig> { $0.isActive && !$0.isSampleData }
        supplements = (try? modelContext.fetch(FetchDescriptor<SDSupplementConfig>(predicate: activeSupplPred))) ?? []

        let allSupplPred = #Predicate<SDSupplementConfig> { !$0.isSampleData }
        let allSupplDesc = FetchDescriptor<SDSupplementConfig>(
            predicate: allSupplPred,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        allSupplements = (try? modelContext.fetch(allSupplDesc)) ?? []

        let conflictDesc = FetchDescriptor<SDSyncConflict>(
            sortBy: [SortDescriptor(\.resolvedAt, order: .reverse)]
        )
        syncConflicts = (try? modelContext.fetch(conflictDesc)) ?? []
    }

    // MARK: - Protocol

    func saveProtocol() {
        guard !formProtoName.isBlank,
              let dose = Double(formDoseMg), dose > 0,
              let freq = Int(formFrequencyDays), freq > 0,
              let conc = Double(formConcentration), conc > 0
        else {
            errorMessage = "Please fill in all protocol fields."
            return
        }

        if let existing = currentProtocol {
            existing.isActive  = false
            existing.endDate   = .now
            existing.updatedAt = .now
        }

        let proto = SDProtocol(
            userID: userID,
            name: formProtoName,
            compoundName: formCompound,
            doseAmountMg: dose,
            frequencyDays: freq,
            concentrationMgPerMl: conc
        )
        modelContext.insert(proto)
        do {
            try modelContext.save()
            showingAddProtocol = false
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Supplements

    func prepareAddSupplementForm() {
        formPresetName = "Creatine"
        applyPreset("Creatine")
        formSupplFreq = "1"
        formSupplName = ""
    }

    func applyPreset(_ name: String) {
        if name == "Custom" {
            formSupplDose = ""
            formSupplUnit = "mg"
        } else if let preset = Self.presets.first(where: { $0.name == name }) {
            formSupplDose = preset.doseAmount.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", preset.doseAmount)
                : String(format: "%.1f", preset.doseAmount)
            formSupplUnit = preset.doseUnit
        }
    }

    func saveSupplement() {
        let name = formPresetName == "Custom" ? formSupplName : formPresetName
        guard !name.isBlank,
              let dose = Double(formSupplDose), dose > 0,
              let freq = Int(formSupplFreq), freq > 0
        else {
            errorMessage = "Please fill in all supplement fields."
            return
        }

        let suppl = SDSupplementConfig(
            userID: userID,
            supplementName: name,
            doseAmount: dose,
            doseUnit: formSupplUnit,
            frequencyDays: freq
        )
        modelContext.insert(suppl)
        do {
            try modelContext.save()
            showingAddSupplement = false
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSupplementActive(_ s: SDSupplementConfig) {
        if s.isActive {
            s.isActive = false
            s.endDate  = .now
        } else {
            s.isActive = true
            s.endDate  = nil
        }
        s.updatedAt = .now
        try? modelContext.save()
        load()
    }

    func deactivateSupplement(_ s: SDSupplementConfig) {
        s.isActive  = false
        s.endDate   = .now
        s.updatedAt = .now
        try? modelContext.save()
        load()
    }

    func deleteSupplement(_ s: SDSupplementConfig) {
        modelContext.delete(s)
        try? modelContext.save()
        load()
    }

    // MARK: - Conflicts

    func markConflictReviewed(_ c: SDSyncConflict) {
        c.isReviewed = true
        try? modelContext.save()
        load()
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await SupabaseService.shared.signOut()
            UserDefaults.standard.set(false, forKey: "isAuthenticated")
            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
            UserDefaults.standard.set(false, forKey: "hkPermissionRequested")
            UserDefaults.standard.removeObject(forKey: "userIDString")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
