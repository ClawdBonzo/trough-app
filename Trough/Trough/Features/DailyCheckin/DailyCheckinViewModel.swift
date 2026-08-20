import SwiftUI
import SwiftData

// MARK: - Navigation step enum

enum DailyCheckinStep: Hashable {
    case binaryTaps
    case completion
}

// MARK: - ViewModel

@MainActor
final class DailyCheckinViewModel: ObservableObject {

    // MARK: Navigation
    @Published var navigationPath: [DailyCheckinStep] = []

    // MARK: Screen 1 — Metrics
    @Published var energyScore: Double = 3
    @Published var moodScore: Double = 3
    @Published var libidoScore: Double = 3
    @Published var sleepQualityScore: Double = 3
    @Published var mentalClarityScore: Double = 3
    @Published var bodyWeightInput: String = ""
    @Published var bodyFatInput: String = ""

    // MARK: Screen 2 — Binary taps
    @Published var morningWood: Bool? = nil
    @Published var workoutToday: Bool? = nil
    @Published var trainingPerformanceScore: Double = 3
    @Published var supplementsTaken: Set<String> = []

    // Compound-aware questions
    @Published var hasJointPain: Bool? = nil   // AI users — feeds E2 crash insight
    @Published var hasNausea: Bool? = nil       // GLP-1 users

    // Compound detection flags
    var hasAICompound: Bool {
        availableSupplements.contains { s in
            ["Anastrozole", "Aromasin", "Letrozole"].contains(s.supplementName)
        }
    }
    var hasGLP1Compound: Bool {
        availableSupplements.contains { s in
            ["Semaglutide", "Tirzepatide", "Liraglutide"].contains(s.supplementName)
        }
    }

    // MARK: Supporting data
    @Published var cycleInfo: InjectionCycleService.CycleInfo? = nil
    @Published var availableSupplements: [SDSupplementConfig] = []
    @Published var savedCheckin: SDCheckin? = nil
    @Published var insightResult: InsightResult? = nil

    // MARK: Computed
    var currentScore: Double {
        let w = energyScore * 0.25 + moodScore * 0.20
              + libidoScore * 0.20 + sleepQualityScore * 0.20
              + mentalClarityScore * 0.15
        return Double.protocolScore(from: w)
    }

    var usesMetricWeight: Bool {
        Locale.current.measurementSystem != .us
    }

    // MARK: Private
    private var modelContext: ModelContext?
    private(set) var userID: UUID = UUID()
    private(set) var existingCheckin: SDCheckin? = nil
    /// Always evaluated fresh — a stored value captured at VM creation would
    /// go stale if the app stays resident across midnight, landing a morning
    /// check-in on yesterday's date.
    var date: Date { Date.now.startOfDay }

    /// Injected by the parent view — used to award XP and update streaks on check-in save.
    weak var gamificationVM: GamificationViewModel?

    // MARK: Setup

    func setup(context: ModelContext, userID: UUID) {
        self.modelContext = context
        self.userID = userID
        loadExisting()
        loadCycleInfo()
        loadSupplements()
        prefillYesterdaysWeight()
        Task { await prefillHealthKit() }
    }

    // MARK: Load helpers

    /// Fetches the real (non-sample) check-in for a given day, if any.
    private func fetchCheckin(on targetDate: Date) -> SDCheckin? {
        guard let ctx = modelContext else { return nil }
        let pred = #Predicate<SDCheckin> { $0.date == targetDate && !$0.isSampleData }
        var desc = FetchDescriptor<SDCheckin>(predicate: pred)
        desc.fetchLimit = 1
        return try? ctx.fetch(desc).first
    }

    private func loadExisting() {
        guard let checkin = fetchCheckin(on: date) else { return }
        existingCheckin = checkin
        energyScore           = checkin.energyScore
        moodScore             = checkin.moodScore
        libidoScore           = checkin.libidoScore
        sleepQualityScore     = checkin.sleepQualityScore
        mentalClarityScore    = checkin.mentalClarityScore
        morningWood           = checkin.morningWood
        workoutToday          = checkin.workoutToday
        trainingPerformanceScore = checkin.trainingPerformanceScore ?? 3
        // FIXED: convert stored kg to display units
        bodyWeightInput       = checkin.bodyWeightKg.map { String(format: "%.1f", usesMetricWeight ? $0 : $0 * 2.20462) } ?? ""
        bodyFatInput          = checkin.bodyFatPercent.map { String(format: "%.1f", $0) } ?? ""
        supplementsTaken      = Set(
            (checkin.supplementsTaken ?? "")
                .split(separator: ",")
                .map { String($0).trimmed }
                .filter { !$0.isEmpty }
        )
    }

    private func loadCycleInfo() {
        guard let ctx = modelContext else { return }
        let protoPred = #Predicate<SDProtocol> { $0.isActive && !$0.isSampleData }
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: protoPred)
        protoDesc.fetchLimit = 1
        guard let proto = try? ctx.fetch(protoDesc).first else { return }

        let injPred = #Predicate<SDInjection> { !$0.isSampleData }
        var injDesc = FetchDescriptor<SDInjection>(
            predicate: injPred,
            sortBy: [SortDescriptor(\.injectedAt, order: .reverse)]
        )
        injDesc.fetchLimit = 1
        guard let lastInj = try? ctx.fetch(injDesc).first else { return }
        cycleInfo = InjectionCycleService.cycleDay(
            lastInjectionDate: lastInj.injectedAt,
            frequencyDays: proto.frequencyDays
        )
    }

    private func loadSupplements() {
        guard let ctx = modelContext else { return }
        let pred = #Predicate<SDSupplementConfig> { $0.isActive && !$0.isSampleData }
        availableSupplements = (try? ctx.fetch(FetchDescriptor<SDSupplementConfig>(predicate: pred))) ?? []
    }

    /// Pre-fills weight from yesterday's check-in for quick logging.
    private func prefillYesterdaysWeight() {
        guard bodyWeightInput.isEmpty, let ctx = modelContext else { return }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let pred = #Predicate<SDCheckin> { $0.date == yesterday && !$0.isSampleData }
        var desc = FetchDescriptor<SDCheckin>(predicate: pred)
        desc.fetchLimit = 1
        if let yesterdayCheckin = try? ctx.fetch(desc).first,
           let kg = yesterdayCheckin.bodyWeightKg {
            // FIXED: convert stored kg to display units
            let displayValue = usesMetricWeight ? kg : kg * 2.20462
            bodyWeightInput = String(format: "%.1f", displayValue)
        }
    }

    private func prefillHealthKit() async {
        guard bodyWeightInput.isEmpty else { return }
        if let kg = try? await HealthKitService.shared.latestBodyWeightKg() {
            // FIXED: convert kg to lbs for US locale display
            let displayValue = usesMetricWeight ? kg : kg * 2.20462
            bodyWeightInput = String(format: "%.1f", displayValue)
        }
    }

    // MARK: Actions

    func toggleSupplement(_ name: String) {
        if supplementsTaken.contains(name) {
            supplementsTaken.remove(name)
        } else {
            supplementsTaken.insert(name)
        }
    }

    /// Called from BinaryTapsView — saves to SwiftData then navigates to completion.
    func save() {
        guard let ctx = modelContext else { return }
        // Pin "today" once for the whole save, and re-resolve the existing
        // check-in in case the app has been resident across midnight since
        // setup() — otherwise a morning save would overwrite yesterday's entry.
        let saveDate = date
        if existingCheckin?.date != saveDate {
            existingCheckin = fetchCheckin(on: saveDate)
        }
        let isNewCheckin = existingCheckin == nil
        // FIXED: convert lbs input to kg for storage if US locale
        let rawWeight = Double(bodyWeightInput)
        let bwKg = rawWeight.map { usesMetricWeight ? $0 : $0 / 2.20462 }
        let bfPct   = Double(bodyFatInput)
        let suppStr = supplementsTaken.sorted().joined(separator: ",")
        let mwScore: Double = morningWood == true ? 5 : morningWood == false ? 1 : 3
        let trainScore: Double? = workoutToday == true ? trainingPerformanceScore : nil

        // Build symptoms string from compound-aware questions
        var symptomTags: [String] = []
        if hasJointPain == true { symptomTags.append("joint_pain") }
        if hasNausea == true { symptomTags.append("nausea") }
        let symptomsStr = symptomTags.isEmpty ? nil : symptomTags.joined(separator: ",")

        if let existing = existingCheckin {
            existing.energyScore             = energyScore
            existing.moodScore               = moodScore
            existing.libidoScore             = libidoScore
            existing.sleepQualityScore       = sleepQualityScore
            existing.mentalClarityScore      = mentalClarityScore
            existing.morningWoodScore        = mwScore
            existing.morningWood             = morningWood
            existing.workoutToday            = workoutToday
            existing.trainingPerformanceScore = trainScore
            existing.supplementsTaken        = suppStr.isEmpty ? nil : suppStr
            existing.bodyWeightKg            = bwKg
            existing.bodyFatPercent          = bfPct
            existing.symptoms               = symptomsStr
            existing.updatedAt               = .now
            savedCheckin = existing
        } else {
            let checkin = SDCheckin(
                userID: userID,
                date: saveDate,
                energyScore: energyScore,
                moodScore: moodScore,
                libidoScore: libidoScore,
                sleepQualityScore: sleepQualityScore,
                morningWoodScore: mwScore,
                mentalClarityScore: mentalClarityScore,
                morningWood: morningWood,
                workoutToday: workoutToday,
                trainingPerformanceScore: trainScore,
                supplementsTaken: suppStr.isEmpty ? nil : suppStr,
                bodyWeightKg: bwKg,
                bodyFatPercent: bfPct,
                symptoms: symptomsStr
            )
            ctx.insert(checkin)
            savedCheckin = checkin
        }
        try? ctx.save()

        // Gamification: streak + quests are idempotent and run on every save,
        // but XP is awarded for NEW check-ins only — re-saving today's entry
        // must not re-award.
        if let gvm = gamificationVM {
            if isNewCheckin {
                gvm.awardXP(20, reason: "daily_checkin")
            }
            gvm.updateStreak(type: "checkin")
            gvm.completeQuest(QuestService.dailyCheckinQuestID())
            completeSupplementQuestIfEarned(gvm)
            // Check Protocol Score badge
            BadgeService.checkProtocolScoreBadge(score: currentScore, context: ctx, userID: userID)
            // 30-day supplement adherence badge (90%+ compliance)
            BadgeService.checkSupplementAdherenceBadge(context: ctx, userID: userID)
        }

        if let kg = bwKg {
            Task { try? await HealthKitService.shared.writeBodyWeight(kg: kg, date: saveDate) }
        }

        if let checkin = savedCheckin {
            let ctx = buildInsightContext(around: checkin)
            insightResult = InsightEngine.shared.generateInsight(
                for: checkin,
                userType: UserDefaults.standard.string(forKey: "userType") ?? "trt",
                context: ctx
            )
            if ctx.streak == 7 {
                let count = ctx.recentCheckins.count
                Task { await WeeklyReportService.scheduleStreakDay7Notification(checkinCount: count) }
            }
            // Schedule (or push forward) the streak-at-risk reminder for tomorrow evening.
            let streakNow = ctx.streak
            Task { await WeeklyReportService.scheduleStreakAtRiskNotification(currentStreak: streakNow) }
        }

        navigationPath = [.binaryTaps, .completion]
    }

    // MARK: - Supplement adherence quest

    /// Weekly quest: "Hit ≥80% supplement compliance this week". SDQuest has no
    /// progress fields, so compliance is derived at read time from check-in rows:
    /// a day counts when its check-in logged at least one supplement, and the
    /// quest completes once 6 of the week's 7 days (⌈80% × 7⌉) are covered.
    private func completeSupplementQuestIfEarned(_ gvm: GamificationViewModel) {
        guard let ctx = modelContext,
              let week = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return }
        let weekStart = week.start
        let weekEnd = week.end
        let pred = #Predicate<SDCheckin> {
            $0.date >= weekStart && $0.date < weekEnd && !$0.isSampleData
        }
        let checkins = (try? ctx.fetch(FetchDescriptor<SDCheckin>(predicate: pred))) ?? []
        let compliantDays = Set(
            checkins
                .filter { !($0.supplementsTaken ?? "").isEmpty }
                .map { $0.date.startOfDay }
        ).count
        if compliantDays >= 6 {
            gvm.completeQuest(QuestService.weeklySupplementQuestID())
        }
    }

    // MARK: - Insight context

    private func buildInsightContext(around checkin: SDCheckin) -> InsightContext {
        guard let ctx = modelContext else {
            return InsightContext(recentCheckins: [], recentInjections: [], activeProtocol: nil, streak: 0)
        }

        let cutoff30 = Calendar.current.date(byAdding: .day, value: -30, to: checkin.date) ?? checkin.date

        // Recent checkins (newest-first, excluding this one to avoid double-counting)
        let checkinPred = #Predicate<SDCheckin> { $0.date >= cutoff30 && !$0.isSampleData }
        let checkinDesc = FetchDescriptor<SDCheckin>(
            predicate: checkinPred,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let recentCheckins = (try? ctx.fetch(checkinDesc)) ?? []

        // Recent injections (newest-first)
        let injPred = #Predicate<SDInjection> { $0.injectedAt >= cutoff30 && !$0.isSampleData }
        let injDesc = FetchDescriptor<SDInjection>(
            predicate: injPred,
            sortBy: [SortDescriptor(\.injectedAt, order: .reverse)]
        )
        let recentInjections = (try? ctx.fetch(injDesc)) ?? []

        // Active primary protocol
        let protoPred = #Predicate<SDProtocol> { $0.isActive && $0.isPrimary && !$0.isSampleData }
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: protoPred)
        protoDesc.fetchLimit = 1
        let activeProtocol = try? ctx.fetch(protoDesc).first

        // Streak: count consecutive days ending today
        let allDates = Set(recentCheckins.map(\.date))
        var streak = 0
        var d = checkin.date
        while allDates.contains(d) {
            streak += 1
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }

        // Recent peptide/adjunct logs for AI correlation insight
        let peptPred = #Predicate<SDPeptideLog> { $0.administeredAt >= cutoff30 && !$0.isSampleData }
        let peptDesc = FetchDescriptor<SDPeptideLog>(
            predicate: peptPred,
            sortBy: [SortDescriptor(\.administeredAt, order: .reverse)]
        )
        let recentPeptideLogs = (try? ctx.fetch(peptDesc)) ?? []

        return InsightContext(
            recentCheckins: recentCheckins,
            recentInjections: recentInjections,
            activeProtocol: activeProtocol,
            streak: streak,
            recentPeptideLogs: recentPeptideLogs
        )
    }
}
