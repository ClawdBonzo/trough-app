import SwiftUI
import SwiftData

// MARK: - Supporting types

struct MetricDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MetricSeries: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let color: Color
    var dataPoints: [MetricDataPoint]
    var isVisible: Bool = true
}

struct WeightDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

// MARK: - DashboardViewModel

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: Protocol Score
    @Published var protocolScore: Double = 0
    @Published var interpretation: String = ""
    @Published var scoreColor: Color = .secondary
    @Published var sevenDayAvg: Double = 0
    @Published var priorSevenDayAvg: Double = 0    // days 8–14
    @Published var trend: Double = 0               // positive = improving

    // MARK: Check-in state
    @Published var todayCheckin: SDCheckin? = nil
    @Published var recentCheckins: [SDCheckin] = []

    // MARK: Streak
    @Published var streak: Int = 0
    @Published var hasWeeklyReport: Bool = false
    @Published var milestoneText: String? = nil

    // MARK: PK Curve inputs (computed from DB, passed to PKCurveEngine in view)
    @Published var pkProtocols: [PKProtocolInput] = []
    @Published var pkInjections: [PKInjectionInput] = []
    @Published var activeProtocol: SDProtocol? = nil
    @Published var daysSinceLastInjection: Int = 0
    @Published var injectionOverdueDays: Int = 0   // > 0 if overdue

    // MARK: Fertility (hCG)
    @Published var hcgProtocol: SDProtocol? = nil
    @Published var hcgStartDate: Date? = nil
    @Published var fertilityEstimate: String? = nil

    // MARK: Trend chart
    @Published var metricSeries: [MetricSeries] = []

    // MARK: Quick stats
    @Published var avgEnergy7d: Double = 0
    @Published var avgLibido7d: Double = 0
    @Published var morningWoodPct30d: Double = 0
    @Published var supplementAdherence7d: Double = 0   // natural users

    // MARK: Body composition (natural users)
    @Published var weightSeries30d: [WeightDataPoint] = []
    @Published var weightMovingAvg: [WeightDataPoint] = []
    @Published var bodyFatSeries: [WeightDataPoint] = []
    @Published var weightDelta30d: Double? = nil

    // MARK: User type
    @Published var userType: String = "trt"

    // MARK: Loading state
    @Published var isLoading = true

    // MARK: Sync state
    @Published var isSyncing = false

    // MARK: Private
    private var modelContext: ModelContext?

    init() {
        self.userType = UserDefaults.standard.string(forKey: "userType") ?? "trt"
    }

    /// Inject the shared environment ModelContext (called from onAppear).
    func setModelContext(_ ctx: ModelContext) {
        if modelContext == nil {
            modelContext = ctx
        }
    }

    // MARK: - Load

    func load() {
        guard modelContext != nil else { return }
        isLoading = true
        loadCheckins()
        loadStreak()
        loadProtocolAndInjections()
        loadTrendChart()
        loadQuickStats()
        if userType == "natural" { loadBodyComposition() }
        isSyncing = SyncEngine.shared.isSyncing
        isLoading = false
    }

    // MARK: Check-ins

    private func loadCheckins() {
        guard let modelContext else { return }
        let pred = #Predicate<SDCheckin> { !$0.isSampleData }
        let desc = FetchDescriptor<SDCheckin>(
            predicate: pred,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = (try? modelContext.fetch(desc)) ?? []
        recentCheckins = Array(all.prefix(30))

        let today = Date.now.startOfDay
        todayCheckin = all.first { $0.date == today }

        // 7-day average (new formula weights)
        let last7 = Array(all.prefix(7))
        if !last7.isEmpty {
            sevenDayAvg = last7.map(\.protocolScore).reduce(0, +) / Double(last7.count)
        }

        // Prior 7-day average (days 8–14)
        let prior7 = Array(all.dropFirst(7).prefix(7))
        if !prior7.isEmpty {
            priorSevenDayAvg = prior7.map(\.protocolScore).reduce(0, +) / Double(prior7.count)
        }

        trend = sevenDayAvg - priorSevenDayAvg

        // Use today's score if checked in, else 7d avg
        let displayScore = todayCheckin?.protocolScore ?? sevenDayAvg
        protocolScore = displayScore
        interpretation = Self.interpret(displayScore)
        scoreColor = Self.color(for: displayScore)
    }

    // MARK: Streak

    private func loadStreak() {
        let dates = Set(recentCheckins.map(\.date))
        var count = 0
        var d = Date.now.startOfDay

        // Allow today-or-yesterday as starting point
        if !dates.contains(d) {
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }
        while dates.contains(d) {
            count += 1
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }
        streak = count
        hasWeeklyReport = count >= 7
        milestoneText = Self.milestone(for: count)
    }

    // MARK: Protocol + injections for PK curve

    private func loadProtocolAndInjections() {
        guard let modelContext else { return }
        let protoPred = #Predicate<SDProtocol> { $0.isActive && !$0.isSampleData }
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: protoPred)
        protoDesc.fetchLimit = 1
        guard let proto = try? modelContext.fetch(protoDesc).first else { return }
        activeProtocol = proto

        pkProtocols = [PKProtocolInput(
            compoundName: proto.compoundName,
            doseAmountMg: proto.doseAmountMg,
            frequencyDays: proto.frequencyDays,
            colorHex: PKCurveEngine.compoundColors(for: proto.compoundName),
            customHalfLife: nil,
            route: "intramuscular"
        )]

        // Last 5 half-lives of injections
        let halfLife = PKCurveEngine.shared.effectiveHalfLife(compound: proto.compoundName)
        let cutoff   = Calendar.current.date(byAdding: .day, value: -Int(halfLife * 5), to: .now) ?? .now
        let injPred  = #Predicate<SDInjection> { $0.injectedAt > cutoff && !$0.isSampleData }
        let injDesc  = FetchDescriptor<SDInjection>(predicate: injPred, sortBy: [SortDescriptor(\SDInjection.injectedAt)])
        let injs     = (try? modelContext.fetch(injDesc)) ?? []

        pkInjections = injs.map {
            PKInjectionInput(
                compoundName: $0.compoundName,
                doseAmountMg: $0.doseAmountMg,
                injectedAt: $0.injectedAt,
                route: $0.injectionSite?.lowercased().contains("sub") == true ? "subcutaneous" : "intramuscular"
            )
        }

        // Overdue check
        if let lastInj = injs.last {
            daysSinceLastInjection = Date.now.daysSince(lastInj.injectedAt)
            let overdue = daysSinceLastInjection - proto.frequencyDays
            injectionOverdueDays = max(0, overdue)
        }

        // hCG fertility detection — look for active HCG protocol (secondary compound)
        let hcgPred = #Predicate<SDProtocol> {
            $0.isActive && !$0.isSampleData && $0.compoundName == "HCG"
        }
        var hcgDesc = FetchDescriptor<SDProtocol>(predicate: hcgPred)
        hcgDesc.fetchLimit = 1
        if let hcg = try? modelContext.fetch(hcgDesc).first {
            hcgProtocol = hcg
            hcgStartDate = hcg.startDate
            let result = InjectionCycleService.fertilityRecoveryEstimate(
                hcgStartDate: hcg.startDate,
                trtStartDate: proto.startDate
            )
            fertilityEstimate = result?.estimate
        } else {
            hcgProtocol = nil
            hcgStartDate = nil
            fertilityEstimate = nil
        }
    }

    // MARK: Trend chart

    private func loadTrendChart() {
        let checkins = Array(recentCheckins.prefix(14)).reversed()  // oldest first for chart

        let specs: [(id: String, label: String, emoji: String, color: Color, kp: KeyPath<SDCheckin, Double>)] = [
            ("energy",  "Energy",        "⚡️", .yellow,        \.energyScore),
            ("mood",    "Mood",          "😌", .cyan,           \.moodScore),
            ("libido",  "Libido",        "🔥", AppColors.accent, \.libidoScore),
            ("sleep",   "Sleep",         "🌙", .indigo,         \.sleepQualityScore),
            ("clarity", "Mental Clarity","🧠", .mint,           \.mentalClarityScore),
        ]

        metricSeries = specs.map { spec in
            let pts = checkins.map { MetricDataPoint(date: $0.date, value: $0[keyPath: spec.kp]) }
            return MetricSeries(id: spec.id, label: spec.label, emoji: spec.emoji, color: spec.color, dataPoints: pts)
        }
    }

    // MARK: Quick stats

    private func loadQuickStats() {
        let last7 = Array(recentCheckins.prefix(7))
        let last30 = Array(recentCheckins.prefix(30))

        avgEnergy7d  = last7.isEmpty ? 0 : last7.map(\.energyScore).reduce(0, +) / Double(last7.count)
        avgLibido7d  = last7.isEmpty ? 0 : last7.map(\.libidoScore).reduce(0, +) / Double(last7.count)

        let mwCheckins = last30.filter { $0.morningWood != nil }
        morningWoodPct30d = mwCheckins.isEmpty ? 0
            : Double(mwCheckins.filter { $0.morningWood == true }.count) / Double(mwCheckins.count) * 100

        let suppCheckins = last7.filter { $0.supplementsTaken != nil && !(($0.supplementsTaken ?? "").isEmpty) }
        supplementAdherence7d = last7.isEmpty ? 0 : Double(suppCheckins.count) / Double(last7.count) * 100
    }

    // MARK: Body composition (natural users)

    private func loadBodyComposition() {
        let sorted = recentCheckins.prefix(30).reversed()

        weightSeries30d = sorted.compactMap { c in
            c.bodyWeightKg.map { WeightDataPoint(date: c.date, weightKg: $0) }
        }

        // 7-day moving average
        weightMovingAvg = weightSeries30d.enumerated().map { (i, pt) in
            let window = weightSeries30d[max(0, i - 3)...min(weightSeries30d.count - 1, i + 3)]
            let avg = window.map(\.weightKg).reduce(0, +) / Double(window.count)
            return WeightDataPoint(date: pt.date, weightKg: avg)
        }

        bodyFatSeries = sorted.compactMap { c in
            c.bodyFatPercent.map { WeightDataPoint(date: c.date, weightKg: $0) }
        }

        if weightSeries30d.count >= 2 {
            weightDelta30d = weightSeries30d.last!.weightKg - weightSeries30d.first!.weightKg
        } else {
            weightDelta30d = nil
        }
    }

    // MARK: Toggle metric visibility

    func toggleMetric(id: String) {
        guard let i = metricSeries.firstIndex(where: { $0.id == id }) else { return }
        metricSeries[i].isVisible.toggle()
    }

    // MARK: Sync

    func triggerSync() {
        SyncEngine.shared.triggerSync()
    }

    // MARK: - Static helpers

    static func interpret(_ score: Double) -> String {
        switch score {
        case 80...:    return "Dialed in"
        case 60..<80:  return "Steady"
        case 40..<60:  return "Trending down"
        default:       return "Off baseline"
        }
    }

    static func color(for score: Double) -> Color {
        switch score {
        case 70...:   return .green
        case 40..<70: return Color(hex: "#F39C12")   // amber
        default:      return AppColors.accent          // red
        }
    }

    private static func milestone(for streak: Int) -> String? {
        switch streak {
        case 7:   return "🔥 One week!"
        case 14:  return "🔥 Two weeks!"
        case 30:  return "🔥 One month!"
        case 60:  return "🔥 Two months!"
        case 90:  return "🔥 Three months!"
        default:  return nil
        }
    }
}

// MARK: - Extension on PKCurveEngine for color lookup

extension PKCurveEngine {
    static func compoundColors(for compound: String) -> String {
        let map: [String: String] = [
            "Testosterone Cypionate":   "#4A90D9",
            "Testosterone Enanthate":   "#27AE60",
            "Testosterone Propionate":  "#F39C12",
            "Testosterone Undecanoate": "#9B59B6",
            "HCG":                      "#E74C3C",
            "Nandrolone Decanoate":     "#1ABC9C",
        ]
        return map[compound] ?? "#E94560"
    }
}
