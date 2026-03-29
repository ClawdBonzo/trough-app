import SwiftUI
import SwiftData

@MainActor
final class InjectionsViewModel: ObservableObject {

    @Published var injections: [SDInjection] = []
    @Published var activeProtocols: [SDProtocol] = []
    @Published var showingLogSheet = false
    @Published var errorMessage: String?

    // Calendar state
    @Published var calendarMonth: Date = Date.now.startOfDay

    // Log form state
    @Published var formCompoundName = "Testosterone Cypionate"
    @Published var formDoseMg: String = ""
    @Published var formDate: Date = .now
    @Published var formSite: String = ""
    @Published var formNotes: String = ""
    @Published var editingInjection: SDInjection?

    private var modelContext: ModelContext?
    private(set) var userID: UUID = UUID()

    init() {}

    // MARK: - Setup

    func setup(context: ModelContext, userID: UUID) {
        self.modelContext = context
        self.userID = SupabaseService.resolvedUserUUID ?? userID // FIXED: use real Supabase user ID
        load()
    }

    // MARK: - Load

    func load() {
        guard let modelContext else { return }
        let pred = #Predicate<SDInjection> { !$0.isSampleData }
        let desc = FetchDescriptor<SDInjection>(
            predicate: pred,
            sortBy: [SortDescriptor(\.injectedAt, order: .reverse)]
        )
        injections = (try? modelContext.fetch(desc)) ?? []

        let pp = #Predicate<SDProtocol> { $0.isActive && !$0.isSampleData }
        activeProtocols = (try? modelContext.fetch(FetchDescriptor<SDProtocol>(predicate: pp))) ?? []

        // Pre-fill form from active primary protocol
        if formDoseMg.isEmpty, let primary = activeProtocols.first(where: { $0.isPrimary }) {
            formCompoundName = primary.compoundName
            formDoseMg = String(format: "%.0f", primary.doseAmountMg)
        }
    }

    // MARK: - Calendar helpers

    /// Dictionary mapping start-of-day Date → injections on that day.
    var injectionsByDay: [Date: [SDInjection]] {
        Dictionary(grouping: injections, by: { $0.injectedAt.startOfDay })
    }

    /// Color for a compound name (from protocol colorHex, fallback from PKCurveEngine).
    func color(for compound: String) -> Color {
        if let proto = activeProtocols.first(where: {
            $0.compoundName.lowercased() == compound.lowercased()
        }), !proto.colorHex.isEmpty {
            return Color(hex: proto.colorHex)
        }
        return Color(hex: PKCurveEngine.compoundColors(for: compound))
    }

    // MARK: - Site rotation

    var recentInjectionsForSiteRotation: [SDInjection] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return injections.filter { $0.injectedAt >= cutoff }
    }

    var suggestedSite: String {
        InjectionCycleService.siteRotationSuggestion(
            recentInjections: recentInjectionsForSiteRotation
        ).displayName
    }

    // MARK: - Form

    func prepareLogForm() {
        editingInjection = nil
        formDate = .now
        formSite = suggestedSite
        formNotes = ""
        // Compound + dose already pre-filled in load()
        showingLogSheet = true
    }

    func prepareEditForm(injection: SDInjection) {
        editingInjection = injection
        formCompoundName = injection.compoundName
        formDoseMg = String(format: "%.0f", injection.doseAmountMg)
        formDate = injection.injectedAt
        formSite = injection.injectionSite ?? ""
        formNotes = injection.notes ?? ""
        showingLogSheet = true
    }

    func saveForm() {
        guard let modelContext else { return }
        guard let dose = Double(formDoseMg), dose > 0 else {
            errorMessage = "Please enter a valid dose."
            return
        }
        let conc: Double = activeProtocols.first(where: {
            $0.compoundName.lowercased() == formCompoundName.lowercased()
        })?.concentrationMgPerMl ?? 200
        let vol = dose / conc

        if let existing = editingInjection {
            existing.compoundName  = formCompoundName
            existing.doseAmountMg  = dose
            existing.volumeMl      = vol
            existing.injectedAt    = formDate
            existing.injectionSite = formSite.isBlank ? nil : formSite
            existing.notes         = formNotes.isBlank ? nil : formNotes
            existing.updatedAt     = .now
        } else {
            let inj = SDInjection(
                userID: userID,
                injectedAt: formDate,
                compoundName: formCompoundName,
                doseAmountMg: dose,
                volumeMl: vol,
                injectionSite: formSite.isBlank ? nil : formSite,
                notes: formNotes.isBlank ? nil : formNotes
            )
            modelContext.insert(inj)
        }

        do {
            try modelContext.save()
            showingLogSheet = false
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ injection: SDInjection) {
        guard let modelContext else { return }
        modelContext.delete(injection)
        try? modelContext.save()
        load()
    }
}
