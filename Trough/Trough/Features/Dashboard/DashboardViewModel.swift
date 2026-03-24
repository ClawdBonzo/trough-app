import SwiftUI
import SwiftData
import StoreKit

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

    // MARK: GLP-1 weight correlation
    @Published var hasGLP1Data: Bool = false
    @Published var glp1WeeklyWeightChange: Double? = nil   // lbs/week
    @Published var glp1EnergyStable: Bool = false

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

    // MARK: Active compounds (from onboarding)
    @Published var activeCompounds: [SDSupplementConfig] = []

    // MARK: User type
    @Published var userType: String = "trt"

    // MARK: Greeting & Insight
    @Published var greetingText: String = ""
    @Published var cycleDay: Int? = nil
    @Published var smartInsight: String? = nil

    // MARK: Injection compliance
    @Published var injectionsMadeThisMonth: Int = 0
    @Published var injectionsExpectedThisMonth: Int = 0

    // MARK: Supplement compliance
    @Published var supplementCompliancePct: Double = 0

    // MARK: Weight trend
    @Published var weightTrendDelta: Double? = nil  // lbs change over 30d
    @Published var latestWeightLbs: Double? = nil

    // MARK: Personal best
    @Published var isPersonalBest: Bool = false
    @Published var personalBestScore: Double = 0

    // MARK: Forecast
    @Published var forecastText: String? = nil

    // MARK: Weekly comparison (current vs prior 7-day)
    @Published var energyDelta: Double = 0
    @Published var moodDelta: Double = 0
    @Published var libidoDelta: Double = 0
    @Published var sleepDelta: Double = 0
    @Published var clarityDelta: Double = 0

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
        loadActiveCompounds()
        loadTrendChart()
        loadQuickStats()
        loadGLP1Correlation()
        loadGreeting()
        loadInjectionCompliance()
        loadSupplementCompliance()
        loadWeightTrend()
        loadPersonalBest()
        loadForecast()
        loadWeeklyComparison()
        if userType == "natural" { loadBodyComposition() }
        isSyncing = SyncEngine.shared.isSyncing
        isLoading = false
    }

    // MARK: Active Compounds

    private func loadActiveCompounds() {
        guard let modelContext else { return }
        let pred = #Predicate<SDSupplementConfig> { $0.isActive }
        let desc = FetchDescriptor<SDSupplementConfig>(predicate: pred, sortBy: [SortDescriptor(\.supplementName)])
        activeCompounds = (try? modelContext.fetch(desc)) ?? []
    }

    // MARK: Check-ins

    private func loadCheckins() {
        guard let modelContext else { return }
        // Try real data first; fall back to sample data for demo screenshots
        let realPred = #Predicate<SDCheckin> { !$0.isSampleData }
        let realDesc = FetchDescriptor<SDCheckin>(
            predicate: realPred,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var all = (try? modelContext.fetch(realDesc)) ?? []
        if all.isEmpty {
            let samplePred = #Predicate<SDCheckin> { $0.isSampleData }
            let sampleDesc = FetchDescriptor<SDCheckin>(
                predicate: samplePred,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            all = (try? modelContext.fetch(sampleDesc)) ?? []
        }
        recentCheckins = Array(all.prefix(42))

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

        // Try real data first; fall back to sample data so screenshots look real
        let realPred = #Predicate<SDProtocol> { $0.isActive && !$0.isSampleData }
        let realProtos = (try? modelContext.fetch(FetchDescriptor<SDProtocol>(predicate: realPred))) ?? []

        let allProtos: [SDProtocol]
        let usingSampleData: Bool
        if realProtos.isEmpty {
            let samplePred = #Predicate<SDProtocol> { $0.isActive && $0.isSampleData }
            allProtos = (try? modelContext.fetch(FetchDescriptor<SDProtocol>(predicate: samplePred))) ?? []
            usingSampleData = true
        } else {
            allProtos = realProtos
            usingSampleData = false
        }

        guard !allProtos.isEmpty else { return }

        // Primary = first isPrimary, else first protocol
        let primary = allProtos.first(where: \.isPrimary) ?? allProtos[0]
        activeProtocol = primary

        // Build ALL active protocols for multi-ester PK curve
        pkProtocols = allProtos.map { proto in
            PKProtocolInput(
                compoundName: proto.compoundName,
                doseAmountMg: proto.doseAmountMg,
                frequencyDays: proto.frequencyDays,
                colorHex: PKCurveEngine.compoundColors(for: proto.compoundName),
                customHalfLife: nil,
                route: proto.compoundName.lowercased().contains("propionate") ? "subcutaneous" : "intramuscular"
            )
        }

        // Load injections — last 5 half-lives of the longest half-life compound
        let maxHL = allProtos.map { PKCurveEngine.shared.effectiveHalfLife(compound: $0.compoundName) }.max() ?? 8.0
        let cutoff = Calendar.current.date(byAdding: .day, value: -Int(maxHL * 5), to: .now) ?? .now

        let injs: [SDInjection]
        if usingSampleData {
            let injPred = #Predicate<SDInjection> { $0.injectedAt > cutoff && $0.isSampleData }
            injs = (try? modelContext.fetch(FetchDescriptor<SDInjection>(predicate: injPred, sortBy: [SortDescriptor(\SDInjection.injectedAt)]))) ?? []
        } else {
            let injPred = #Predicate<SDInjection> { $0.injectedAt > cutoff && !$0.isSampleData }
            injs = (try? modelContext.fetch(FetchDescriptor<SDInjection>(predicate: injPred, sortBy: [SortDescriptor(\SDInjection.injectedAt)]))) ?? []
        }

        pkInjections = injs.map {
            PKInjectionInput(
                compoundName: $0.compoundName,
                doseAmountMg: $0.doseAmountMg,
                injectedAt: $0.injectedAt,
                route: $0.injectionSite?.lowercased().contains("sub") == true ? "subcutaneous" : "intramuscular"
            )
        }

        // Overdue check (based on primary protocol)
        let primaryInjs = injs.filter { $0.compoundName == primary.compoundName }
        if let lastInj = primaryInjs.last {
            daysSinceLastInjection = Date.now.daysSince(lastInj.injectedAt)
            let overdue = daysSinceLastInjection - primary.frequencyDays
            injectionOverdueDays = max(0, overdue)
        }

        // hCG fertility detection
        if let hcg = allProtos.first(where: { $0.compoundName == "HCG" }) {
            hcgProtocol = hcg
            hcgStartDate = hcg.startDate
            let result = InjectionCycleService.fertilityRecoveryEstimate(
                hcgStartDate: hcg.startDate,
                trtStartDate: primary.startDate
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

        // supplementAdherence7d removed — use supplementCompliancePct instead (computed in loadSupplementCompliance)
    }

    // MARK: GLP-1 weight correlation

    private func loadGLP1Correlation() {
        guard let modelContext else { return }

        // Check for GLP-1 peptide logs in last 14 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let glp1Names = PeptidesViewModel.glp1Compounds
        let pred = #Predicate<SDPeptideLog> { $0.administeredAt > cutoff && !$0.isSampleData }
        let allRecent = (try? modelContext.fetch(FetchDescriptor<SDPeptideLog>(predicate: pred))) ?? []
        var glp1Logs = allRecent.filter { glp1Names.contains($0.peptideName) }

        // Also check sample data if no real data
        if glp1Logs.isEmpty {
            let samplePred = #Predicate<SDPeptideLog> { $0.administeredAt > cutoff && $0.isSampleData }
            let sampleLogs = (try? modelContext.fetch(FetchDescriptor<SDPeptideLog>(predicate: samplePred))) ?? []
            glp1Logs = sampleLogs.filter { glp1Names.contains($0.peptideName) }
        }

        guard !glp1Logs.isEmpty else {
            hasGLP1Data = false
            return
        }

        hasGLP1Data = true

        // Calculate weekly weight change from checkins
        let last14 = Array(recentCheckins.prefix(14))
        let weights = last14.compactMap(\.bodyWeightKg)
        if weights.count >= 7 {
            let firstWeekAvg = weights.suffix(7).reduce(0, +) / Double(min(7, weights.suffix(7).count))
            let lastWeekAvg = weights.prefix(7).reduce(0, +) / Double(min(7, weights.prefix(7).count))
            let changeLbs = (lastWeekAvg - firstWeekAvg) / 0.453592
            glp1WeeklyWeightChange = changeLbs
        }

        let avgEnergy = last14.isEmpty ? 0 : last14.map(\.energyScore).reduce(0, +) / Double(last14.count)
        glp1EnergyStable = avgEnergy >= 3.0
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

        if weightSeries30d.count >= 2, let last = weightSeries30d.last, let first = weightSeries30d.first {
            weightDelta30d = last.weightKg - first.weightKg
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

    // MARK: Greeting

    private func loadGreeting() {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let prefix: String
        switch hour {
        case 0..<12:  prefix = "Good morning"
        case 12..<17: prefix = "Good afternoon"
        default:      prefix = "Good evening"
        }
        greetingText = name.isEmpty ? prefix : "\(prefix), \(name)"

        // Cycle day (days since last injection)
        if daysSinceLastInjection > 0, let proto = activeProtocol {
            cycleDay = (daysSinceLastInjection % proto.frequencyDays) + 1
        }

        // Smart insight from InsightEngine (wrapped for safety)
        if let checkin = todayCheckin ?? recentCheckins.first {
            let ctx = InsightContext(
                recentCheckins: Array(recentCheckins.prefix(30)),
                recentInjections: [],
                activeProtocol: activeProtocol,
                streak: streak
            )
            // Catch any unexpected issues in InsightEngine
            let result = InsightEngine.shared.generateInsight(
                for: checkin,
                userType: userType,
                context: ctx
            )
            if !result.message.isEmpty {
                smartInsight = result.message
            }
        }
    }

    // MARK: Injection Compliance

    private func loadInjectionCompliance() {
        guard let modelContext, let proto = activeProtocol else { return }
        let cal = Calendar.current
        let now = Date.now
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now

        let pred = #Predicate<SDInjection> { $0.injectedAt >= startOfMonth && !$0.isSampleData }
        let injs = (try? modelContext.fetch(FetchDescriptor<SDInjection>(predicate: pred))) ?? []
        injectionsMadeThisMonth = injs.count

        let dayOfMonth = cal.component(.day, from: now)
        injectionsExpectedThisMonth = max(1, dayOfMonth / max(1, proto.frequencyDays))
    }

    // MARK: Supplement Compliance

    private func loadSupplementCompliance() {
        let last7 = Array(recentCheckins.prefix(7))
        guard !last7.isEmpty else { supplementCompliancePct = 0; return }
        let taken = last7.filter { $0.supplementsTaken != nil && !($0.supplementsTaken ?? "").isEmpty }
        supplementCompliancePct = Double(taken.count) / Double(last7.count) * 100
    }

    // MARK: Weight Trend

    private func loadWeightTrend() {
        let last30 = Array(recentCheckins.prefix(30))
        let weights = last30.compactMap(\.bodyWeightKg)
        if let latest = weights.first {
            latestWeightLbs = latest / 0.453592
        }
        if weights.count >= 7 {
            let recent = weights.prefix(7).reduce(0, +) / Double(weights.prefix(7).count)
            let older = weights.suffix(7).reduce(0, +) / Double(weights.suffix(7).count)
            weightTrendDelta = (recent - older) / 0.453592  // convert kg delta to lbs
        }
    }

    // MARK: Personal Best

    private func loadPersonalBest() {
        guard let modelContext else { return }
        // Fetch ALL check-ins to find true all-time best, not just the 42-day window
        let allDesc = FetchDescriptor<SDCheckin>(sortBy: [SortDescriptor(\.protocolScore, order: .reverse)])
        let allCheckins = (try? modelContext.fetch(allDesc)) ?? []
        guard !allCheckins.isEmpty else { return }
        let maxEver = allCheckins.first?.protocolScore ?? 0
        personalBestScore = maxEver
        // Current score equals or exceeds all-time high (need at least 3 check-ins to be meaningful)
        isPersonalBest = protocolScore > 0 && protocolScore >= maxEver && allCheckins.count >= 3
    }

    // MARK: Forecast

    private func loadForecast() {
        guard let proto = activeProtocol else { forecastText = nil; return }
        let nextCycleDay = ((daysSinceLastInjection + 1) % max(1, proto.frequencyDays)) + 1
        let daysUntilInjection = max(0, proto.frequencyDays - daysSinceLastInjection)

        if daysUntilInjection == 0 {
            forecastText = "Injection day today — energy should peak in 24–48 hours."
        } else if daysUntilInjection == 1 {
            forecastText = "Injection due tomorrow. You're at the trough — some fatigue is normal."
        } else if nextCycleDay >= 5 && nextCycleDay <= 6 {
            forecastText = "Day \(nextCycleDay) tomorrow — energy typically dips. Stay ahead of it."
        } else if nextCycleDay <= 3 {
            forecastText = "Day \(nextCycleDay) tomorrow — levels should be strong post-injection."
        } else {
            forecastText = "Next injection in \(daysUntilInjection) days. Levels are tapering gradually."
        }
    }

    // MARK: Weekly Comparison

    private func loadWeeklyComparison() {
        let last7 = Array(recentCheckins.prefix(7))
        let prior7 = Array(recentCheckins.dropFirst(7).prefix(7))
        guard !last7.isEmpty, !prior7.isEmpty else { return }

        func avg(_ checkins: [SDCheckin], _ kp: KeyPath<SDCheckin, Double>) -> Double {
            checkins.map { $0[keyPath: kp] }.reduce(0, +) / Double(checkins.count)
        }

        energyDelta  = avg(last7, \.energyScore) - avg(prior7, \.energyScore)
        moodDelta    = avg(last7, \.moodScore) - avg(prior7, \.moodScore)
        libidoDelta  = avg(last7, \.libidoScore) - avg(prior7, \.libidoScore)
        sleepDelta   = avg(last7, \.sleepQualityScore) - avg(prior7, \.sleepQualityScore)
        clarityDelta = avg(last7, \.mentalClarityScore) - avg(prior7, \.mentalClarityScore)
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
        case 91...:   return Color(hex: "#FFD700")     // gold
        case 76..<91: return .green
        case 61..<76: return Color(hex: "#F1C40F")     // yellow
        case 41..<61: return Color(hex: "#F39C12")     // orange
        default:      return AppColors.accent           // red
        }
    }

    private static func milestone(for streak: Int) -> String? {
        switch streak {
        case 7:   return "🔥 One week! Top 30% of TRT trackers"
        case 14:  return "🔥🔥 Two weeks! Top 15% of TRT trackers"
        case 30:  return "🔥🔥🔥 One month! Top 5% of TRT trackers"
        case 60:  return "🔥🔥🔥🔥 Two months! Top 2% — you're elite"
        case 90:  return "🔥🔥🔥🔥🔥 Three months! Top 1% — legend"
        default:  return nil
        }
    }

    // MARK: - Review Prompt

    /// Call this after check-in or milestone to potentially prompt for App Store review.
    func checkReviewPrompt() {
        let hasPrompted = UserDefaults.standard.bool(forKey: "hasPromptedReview")
        guard !hasPrompted else { return }

        // Trigger at positive moments: score ≥ 75, streak at 14+, or score improving
        let shouldPrompt: Bool
        if streak >= 14 {
            shouldPrompt = true
        } else if protocolScore >= 75 {
            shouldPrompt = true
        } else {
            shouldPrompt = false
        }

        if shouldPrompt {
            UserDefaults.standard.set(true, forKey: "hasPromptedReview")
            requestAppReview()
        }
    }

    private func requestAppReview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
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
