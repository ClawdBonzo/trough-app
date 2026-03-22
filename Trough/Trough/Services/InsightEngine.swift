import Foundation

// MARK: - InsightResult

enum InsightType {
    case warning   // amber — something worth watching
    case positive  // green — keep it up
    case neutral   // secondary — informational
}

struct InsightResult {
    let message: String
    let type: InsightType
    let ruleID: String
}

// MARK: - InsightContext

/// All historical data the engine needs. Built by the caller (ViewModel) from SwiftData.
struct InsightContext {
    /// Most recent checkins, sorted newest-first. Provide at least 30 days when available.
    var recentCheckins: [SDCheckin]
    /// Most recent injections, sorted newest-first.
    var recentInjections: [SDInjection]
    /// The user's primary active protocol (nil for natural users).
    var activeProtocol: SDProtocol?
    /// Current daily check-in streak.
    var streak: Int
    /// Recent peptide/adjunct logs, sorted newest-first. Used for AI correlation rule.
    var recentPeptideLogs: [SDPeptideLog] = []
}

// MARK: - InsightEngine

final class InsightEngine {
    static let shared = InsightEngine()
    private init() {}

    // MARK: - Public API

    /// Evaluates rules in priority order and returns the first match.
    /// Returns nil only if the checkin lacks the minimum data to run any rule.
    func generateInsight(
        for checkin: SDCheckin,
        userType: String,
        context: InsightContext
    ) -> InsightResult {
        let rules: [(InsightEngine) -> InsightResult?] = [
            { $0.energyDipPattern(checkin: checkin, userType: userType, ctx: context) },
            { $0.sleepMorningWoodCorrelation(checkin: checkin, ctx: context) },
            { $0.hrvBaselineDrop(checkin: checkin, ctx: context) },
            { $0.supplementAdherence(checkin: checkin, userType: userType, ctx: context) },
            { $0.weightTrend(checkin: checkin, userType: userType, ctx: context) },
            { $0.positiveReinforcement(checkin: checkin, ctx: context) },
            // Rule 7 reserved
            { $0.aiCorrelation(checkin: checkin, ctx: context) },
            { $0.glp1Correlation(checkin: checkin, ctx: context) },
        ]
        for rule in rules {
            if let result = rule(self) { return result }
        }
        return InsightResult(
            message: "Keep tracking. Insights emerge after 2+ injection cycles.",
            type: .neutral,
            ruleID: "default"
        )
    }

    // MARK: - Rule 1: Energy dip pattern (TRT users)

    private func energyDipPattern(
        checkin: SDCheckin,
        userType: String,
        ctx: InsightContext
    ) -> InsightResult? {
        guard userType == "trt",
              let proto = ctx.activeProtocol else { return nil }

        let freq = Double(proto.frequencyDays)
        let daysSinceInj = InjectionCycleService.daysSinceLastInjection(
            injections: ctx.recentInjections,
            compound: proto.compoundName
        )

        guard daysSinceInj > freq * 0.6 else { return nil }

        let last14 = Array(ctx.recentCheckins.prefix(14))
        guard last14.count >= 7 else { return nil }

        let avgEnergy = mean(last14.map(\.energyScore))
        guard checkin.energyScore < avgEnergy else { return nil }

        // Count previous cycles that also showed late-phase energy dips
        let matchingInjs = ctx.recentInjections
            .filter { compoundsMatch($0.compoundName, proto.compoundName) }
            .sorted { $0.injectedAt < $1.injectedAt }

        var dipCycles = 0
        var totalCycles = 0

        for i in 0..<(matchingInjs.count - 1) {
            let cycleStart = matchingInjs[i].injectedAt
            let cycleEnd   = matchingInjs[i + 1].injectedAt
            let lateStart  = cycleStart.addingTimeInterval(freq * 0.6 * 86400)

            let lateCheckins = ctx.recentCheckins.filter {
                $0.date >= lateStart && $0.date < cycleEnd
            }
            guard !lateCheckins.isEmpty else { continue }
            totalCycles += 1
            if mean(lateCheckins.map(\.energyScore)) < avgEnergy { dipCycles += 1 }
        }

        guard dipCycles >= 2 else { return nil }

        let dayX = Int(daysSinceInj.rounded())
        return InsightResult(
            message: "Your energy tends to dip around day \(dayX). " +
                     "This has happened in \(dipCycles) of your last \(totalCycles) cycles.",
            type: .warning,
            ruleID: "energy_dip"
        )
    }

    // MARK: - Rule 2: Sleep / morning wood correlation

    private func sleepMorningWoodCorrelation(
        checkin: SDCheckin,
        ctx: InsightContext
    ) -> InsightResult? {
        guard let sleepHours = checkin.sleepHours,
              sleepHours < 6.5,
              checkin.morningWood == false else { return nil }

        let last30 = Array(ctx.recentCheckins.prefix(30))
        let shortSleepCheckins = last30.filter { ($0.sleepHours ?? 99) < 6.5 && $0.morningWood != nil }
        guard shortSleepCheckins.count >= 5 else { return nil }

        let noMwCount = shortSleepCheckins.filter { $0.morningWood == false }.count
        let pct = Int((Double(noMwCount) / Double(shortSleepCheckins.count)) * 100)
        guard pct > 60 else { return nil }

        return InsightResult(
            message: "Sleep under 6.5 hrs is linked to lower morning wood in your data (\(pct)% of the time).",
            type: .warning,
            ruleID: "sleep_mw_correlation"
        )
    }

    // MARK: - Rule 3: HRV baseline drop

    private func hrvBaselineDrop(
        checkin: SDCheckin,
        ctx: InsightContext
    ) -> InsightResult? {
        guard let todayHRV = checkin.hrv else { return nil }

        let last14HRVs = ctx.recentCheckins.prefix(14).compactMap(\.hrv)
        guard last14HRVs.count >= 5 else { return nil }

        let baseline = mean(last14HRVs)
        guard baseline > 0, todayHRV < baseline * 0.85 else { return nil }

        let dropPct = Int(((baseline - todayHRV) / baseline) * 100)
        return InsightResult(
            message: "Your HRV is \(dropPct)% below your baseline. Recovery may be impacted.",
            type: .warning,
            ruleID: "hrv_drop"
        )
    }

    // MARK: - Rule 4: Supplement adherence (natural users)

    private func supplementAdherence(
        checkin: SDCheckin,
        userType: String,
        ctx: InsightContext
    ) -> InsightResult? {
        guard userType == "natural" else { return nil }

        let last7 = Array(ctx.recentCheckins.prefix(7))
        guard last7.count >= 7 else { return nil }

        let taken = last7.filter {
            let s = $0.supplementsTaken ?? ""
            return !s.isEmpty
        }.count

        guard Double(taken) / Double(last7.count) < 0.5 else { return nil }

        let missed = last7.count - taken
        return InsightResult(
            message: "You've missed supplements \(missed) of 7 days. Consistency matters.",
            type: .warning,
            ruleID: "supplement_adherence"
        )
    }

    // MARK: - Rule 5: Weight trend (natural users)

    private func weightTrend(
        checkin: SDCheckin,
        userType: String,
        ctx: InsightContext
    ) -> InsightResult? {
        guard userType == "natural" else { return nil }

        // Need oldest-first for trend direction
        let trend14 = Array(ctx.recentCheckins.prefix(14).reversed())
        let half = trend14.count / 2
        guard half >= 3 else { return nil }

        let earlyWeights  = trend14.prefix(half).compactMap(\.bodyWeightKg)
        let recentWeights = trend14.dropFirst(half).compactMap(\.bodyWeightKg)
        guard earlyWeights.count >= 2, recentWeights.count >= 2 else { return nil }

        let earlyAvgW  = mean(earlyWeights)
        let recentAvgW = mean(recentWeights)
        guard recentAvgW < earlyAvgW - 0.2 else { return nil }   // at least 200 g drop

        let earlyEnergy  = mean(trend14.prefix(half).map(\.energyScore))
        let recentEnergy = mean(trend14.dropFirst(half).map(\.energyScore))
        guard recentEnergy >= earlyEnergy - 0.2 else { return nil }

        return InsightResult(
            message: "Weight is dropping while energy stays high. Your protocol is working.",
            type: .positive,
            ruleID: "weight_trend"
        )
    }

    // MARK: - Rule 6: Positive reinforcement

    private func positiveReinforcement(
        checkin: SDCheckin,
        ctx: InsightContext
    ) -> InsightResult? {
        guard checkin.energyScore >= 4,
              checkin.moodScore >= 4,
              checkin.libidoScore >= 4,
              checkin.sleepQualityScore >= 4,
              checkin.mentalClarityScore >= 4,
              ctx.streak >= 3 else { return nil }

        return InsightResult(
            message: "Strong day. Your \(ctx.streak)-day streak is building solid data.",
            type: .positive,
            ruleID: "positive_reinforcement"
        )
    }

    // MARK: - Rule 8: AI / E2 correlation

    private func aiCorrelation(
        checkin: SDCheckin,
        ctx: InsightContext
    ) -> InsightResult? {
        // Need AI doses in last 14 days
        let cutoff14 = Calendar.current.date(byAdding: .day, value: -14, to: Date.now) ?? Date.now
        let recentAIDoses = ctx.recentPeptideLogs.filter {
            PeptidesViewModel.isAICompound($0.peptideName) && $0.administeredAt >= cutoff14
        }
        guard !recentAIDoses.isEmpty else { return nil }

        let last14 = Array(ctx.recentCheckins.prefix(14))
        guard last14.count >= 5 else { return nil }

        let avgEnergy = mean(last14.map(\.energyScore))
        let avgMood   = mean(last14.map(\.moodScore))
        let avgLibido = mean(last14.map(\.libidoScore))

        let energyDrop = avgEnergy - checkin.energyScore > 1
        let moodDrop   = avgMood   - checkin.moodScore   > 1
        let libidoDrop = avgLibido - checkin.libidoScore  > 1

        let jointPainNoted = (checkin.notes ?? "").localizedCaseInsensitiveContains("joint")
            || last14.prefix(3).contains { ($0.notes ?? "").localizedCaseInsensitiveContains("joint") }

        guard energyDrop || moodDrop || libidoDrop || jointPainNoted else { return nil }

        return InsightResult(
            message: "Recent AI use may be crashing your E2 — check bloodwork.",
            type: .warning,
            ruleID: "ai_e2_correlation"
        )
    }

    // MARK: - Rule 9: GLP-1 / Weight correlation

    private func glp1Correlation(
        checkin: SDCheckin,
        ctx: InsightContext
    ) -> InsightResult? {
        // Need GLP-1 doses in last 14 days
        let cutoff14 = Calendar.current.date(byAdding: .day, value: -14, to: Date.now) ?? Date.now
        let recentGLP1 = ctx.recentPeptideLogs.filter {
            PeptidesViewModel.isGLP1Compound($0.peptideName) && $0.administeredAt >= cutoff14
        }
        guard recentGLP1.count >= 2 else { return nil }

        let last14 = Array(ctx.recentCheckins.prefix(14))
        guard last14.count >= 7 else { return nil }

        // Check weight trend (need bodyWeightKg on checkins)
        let weights = last14.compactMap(\.bodyWeightKg)
        let weightTrendingDown = weights.count >= 4 && weights.first! > weights.last!

        // Check energy is stable (not dropping)
        let avgEnergy = mean(last14.map(\.energyScore))
        let energyStable = avgEnergy >= 3.0

        if weightTrendingDown && energyStable {
            return InsightResult(
                message: "Consistent GLP-1 use + weight trending down + stable energy = protocol working well.",
                type: .positive,
                ruleID: "glp1_weight_correlation"
            )
        }

        // If on GLP-1 but energy is tanking, flag it
        if !energyStable && recentGLP1.count >= 3 {
            return InsightResult(
                message: "Energy dropping while on GLP-1 — check calorie intake and recovery.",
                type: .warning,
                ruleID: "glp1_energy_warning"
            )
        }

        return nil
    }

    // MARK: - Legacy compatibility (DailyCheckinViewModel calls this before context is built)

    func insight(for checkin: SDCheckin) -> String {
        let score = checkin.protocolScore
        switch score {
        case 80...: return "Strong day — all metrics tracking well."
        case 65..<80: return "Good response. Stay consistent with your schedule."
        case 45..<65: return "Average day. Check your sleep and recovery."
        default: return "Rough day. Note any stressors and monitor trends."
        }
    }

    // MARK: - Helpers

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func compoundsMatch(_ a: String, _ b: String) -> Bool {
        let al = a.lowercased(), bl = b.lowercased()
        return al == bl || al.contains(bl) || bl.contains(al)
    }
}
