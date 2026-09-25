import SwiftUI
import SwiftData

#if DEBUG
/// App Store screenshot / demo launch arguments (DEBUG builds only — Release never reads them).
/// Driven by `Trough/Tools/make_store_screenshots.sh`.
///
/// - `-TRSeedDemo`        the app runs on an IN-MEMORY ModelContainer (the real store is never
///                        opened) seeded with a realistic, non-sample history: ~120 days of
///                        check-ins, a Test Cyp E7D + hCG Mon/Thu protocol with site rotation,
///                        4 bloodwork panels, 2 peptides, supplements, and gamification state
///                        consistent with that data (Level 8 "Advanced" · Gold cover, ~25/42
///                        badges, 112-day check-in streak, 16 on-schedule weeks, today's quests
///                        done). Also pretends Pro (see `SubscriptionManager.refresh`).
/// - `-TRSkipOnboarding`  marks onboarding complete.
/// - `-TRFixedDate yyyy-MM-dd`  anchors the seeded history to that day instead of today. The app
///                        still reads the real clock, so only pass the current date (or a date
///                        the simulator clock is set to); it exists to make a run reproducible.
///
/// UserDefaults isolation: the first demo launch snapshots the app's persistent defaults domain
/// to Library/TroughDemoDefaultsBackup.plist before writing demo keys (userID, XP ledger,
/// celebrated badges, banner flags); the next non-demo DEBUG launch restores it. A developer
/// who runs the demo on their own device gets their real defaults back.
enum DemoMode {

    // MARK: Launch arguments

    static let arguments = ProcessInfo.processInfo.arguments

    static func flag(_ name: String) -> Bool { arguments.contains(name) }

    /// The argument following `name` (`-TRShowcase home` → "home").
    static func value(of name: String) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        let value = arguments[index + 1]
        return value.hasPrefix("-TR") ? nil : value
    }

    static var seedsDemo: Bool { flag("-TRSeedDemo") }
    static var skipsOnboarding: Bool { flag("-TRSkipOnboarding") || seedsDemo }
    static var isScreenshotMode: Bool { flag("-TRScreenshotMode") }
    /// Pro features unlocked without RevenueCat (demo data only).
    static var pretendsPro: Bool { seedsDemo }
    static var touchesDefaults: Bool { seedsDemo || skipsOnboarding }

    static let fixedDate: Date? = {
        guard let raw = value(of: "-TRFixedDate") else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }()

    /// "Today" for the seeded history.
    static var anchor: Date { (fixedDate ?? .now).startOfDay }

    /// Stable demo identity (so re-launches line up with the XP ledger keys).
    static let userID = UUID(uuidString: "7A0E5C1D-1B4E-4C2A-9D3F-0000000000D0")!

    // MARK: Entry points (TroughApp.init)

    /// Call first thing in `TroughApp.init()`. Restores the user's defaults after a demo run, or
    /// snapshots them and writes the onboarding / demo keys for this run.
    static func prepareDefaults() {
        guard touchesDefaults else {
            restoreDefaultsIfNeeded()
            return
        }
        backupDefaultsIfNeeded()
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "onboardingCompleted")
        defaults.set(true, forKey: "hkPermissionRequested")
        guard seedsDemo else { return }
        defaults.set(userID.uuidString, forKey: "userIDString")
        defaults.set("trt", forKey: "userType")
        defaults.set(true, forKey: "trackBodyWeight")
        defaults.set(true, forKey: "hasShownSupplementBanner")
        defaults.set(true, forKey: "hasShownTrialEndedScreen")
        defaults.set(true, forKey: "dismissedInsightsReEngage")
        defaults.set(true, forKey: "reminderEnabled")
        defaults.set(true, forKey: "injectionReminderEnabled")
        // Fresh gamification bookkeeping; `seed` fills it to match the data.
        defaults.removeObject(forKey: XPLedger.awardedKeysKey)
        defaults.removeObject(forKey: XPLedger.dailyTotalsKey)
        defaults.removeObject(forKey: "gamification.celebratedBadges")
    }

    /// The in-memory, seeded container for `-TRSeedDemo`.
    @MainActor
    static func makeContainer(schema: Schema) -> ModelContainer {
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration("TroughDemo", schema: schema, isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        DemoSeeder(context: context, userID: userID, today: anchor).seed()
        try? context.save()
        return container
    }

    // MARK: Defaults snapshot

    private static var backupURL: URL {
        URL.libraryDirectory.appending(path: "TroughDemoDefaultsBackup.plist")
    }

    private static var domainName: String { Bundle.main.bundleIdentifier ?? "app.trough.ios" }

    private static func backupDefaultsIfNeeded() {
        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        let domain = UserDefaults.standard.persistentDomain(forName: domainName) ?? [:]
        if let data = try? PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0) {
            try? data.write(to: backupURL, options: .atomic)
        }
    }

    private static func restoreDefaultsIfNeeded() {
        guard let data = try? Data(contentsOf: backupURL) else { return }
        if let domain = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            UserDefaults.standard.setPersistentDomain(domain, forName: domainName)
        }
        try? FileManager.default.removeItem(at: backupURL)
    }
}

// MARK: - Seeder

/// Builds the demo history. Deterministic (fixed seeds), relative to `today`.
@MainActor
private struct DemoSeeder {
    let context: ModelContext
    let userID: UUID
    let today: Date
    let cal = Calendar.current

    // Shape of the story.
    let historyDays = 120            // check-ins from 119 days ago through today…
    let missedDaysAgo = 112          // …except this one, so the current streak is 112
    let cypInjections = 16           // weekly, one per ISO week → 16 on-schedule weeks
    let lastCypDaysAgo = 5           // next dose in 2 days: the PK curve sits near the trough
    let demoXP = 1_436               // Level 8 "Advanced" (1,120–1,519) → Gold rank cover

    private func day(_ daysAgo: Int) -> Date { cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today }
    private func at(_ date: Date, _ hour: Int, _ minute: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    func seed() {
        let firstCyp = day(lastCypDaysAgo + 7 * (cypInjections - 1))   // 110 days ago

        // ── Protocols ──────────────────────────────────────────────────────
        let cyp = SDProtocol(
            userID: userID, name: "Test Cyp 150mg E7D", compoundName: "Testosterone Cypionate",
            doseAmountMg: 150, frequencyDays: 7, concentrationMgPerMl: 200,
            isActive: true, isPrimary: true, colorHex: "#E94560",
            startDate: firstCyp, createdAt: at(firstCyp, 8, 30), updatedAt: at(firstCyp, 8, 30)
        )
        let hcg = SDProtocol(
            userID: userID, name: "hCG 500 IU Mon/Thu", compoundName: "HCG",
            doseAmountMg: 500, frequencyDays: 3, concentrationMgPerMl: 5000,
            isActive: true, isPrimary: false, colorHex: "#2EC4B6", weekdaysString: "2,5",
            startDate: firstCyp, createdAt: at(firstCyp, 8, 32), updatedAt: at(firstCyp, 8, 32)
        )
        context.insert(cyp)
        context.insert(hcg)

        for (name, dose, unit) in [("Vitamin D3", 5000.0, "IU"), ("Fish Oil", 2.0, "g"), ("Magnesium Glycinate", 400.0, "mg")] {
            context.insert(SDSupplementConfig(userID: userID, supplementName: name, doseAmount: dose, doseUnit: unit,
                                              frequencyDays: 1, startDate: day(historyDays - 1)))
        }

        // ── Injections: Test Cyp weekly, rotating IM sites ─────────────────
        let imSites = ["Glute Left", "Glute Right", "Ventro-Glute Left", "Ventro-Glute Right", "Quad Left", "Quad Right"]
        var injectionKeys: [String] = []
        var cypDates: [Date] = []
        for i in 0..<cypInjections {
            let daysAgo = lastCypDaysAgo + 7 * (cypInjections - 1 - i)
            let when = at(day(daysAgo), 8, 5 + (i * 7) % 40)
            cypDates.append(when)
            let shot = SDInjection(
                userID: userID, protocolID: cyp.id, injectedAt: when,
                compoundName: "Testosterone Cypionate", doseAmountMg: 150, volumeMl: 0.75,
                injectionSite: imSites[i % imSites.count],
                notes: [3, 9, 14].contains(i) ? ["New vial started", "Switched to 25g needle", "Smooth one"][[3, 9, 14].firstIndex(of: i)!] : nil,
                createdAt: when, updatedAt: when
            )
            context.insert(shot)
            injectionKeys.append("injection:\(shot.id.uuidString)")
        }

        // ── Injections: hCG Mon/Thu, alternating abdomen sides ─────────────
        var hcgCount = 0
        for daysAgo in stride(from: 110, through: 0, by: -1) {
            let date = day(daysAgo)
            let weekday = cal.component(.weekday, from: date)   // 2 = Mon, 5 = Thu
            guard weekday == 2 || weekday == 5 else { continue }
            if daysAgo == 0 && cal.component(.hour, from: .now) < 20 && fixedTodayIsReal { continue }   // tonight's not due yet
            let when = at(date, 20, 10)
            let shot = SDInjection(
                userID: userID, protocolID: hcg.id, injectedAt: when,
                compoundName: "HCG", doseAmountMg: 500, volumeMl: 0.1,
                injectionSite: hcgCount % 2 == 0 ? "SubQ Abdomen Left" : "SubQ Abdomen Right",
                createdAt: when, updatedAt: when
            )
            context.insert(shot)
            injectionKeys.append("injection:\(shot.id.uuidString)")
            hcgCount += 1
        }

        // ── Check-ins ──────────────────────────────────────────────────────
        var checkinKeys: [String] = []
        var checkinDates: [Date] = []
        var syncedDates: [Date] = []
        var notedCount = 0
        let notes: [Int: String] = [
            96: "Baseline week. Writing everything down.",
            71: "Slept great, long walk after work.",
            44: "Travel day, late dinner.",
            23: "Leg day. Felt strong.",
            9: "Busy week at work.",
            2: "Early night, good sleep.",
        ]
        for daysAgo in stride(from: historyDays - 1, through: 0, by: -1) where daysAgo != missedDaysAgo {
            let date = day(daysAgo)
            var rng = SeededRandom(seed: UInt64(daysAgo) &* 7919 &+ 17)

            // Days since the last Test Cyp dose (nil before the protocol started).
            let sinceDose: Int? = cypDates.last(where: { $0.startOfDay <= date })
                .map { cal.dateComponents([.day], from: $0.startOfDay, to: date).day ?? 0 }
            let onProtocol = sinceDose != nil
            // Baseline weeks sit a little lower; days 5–6 after a dose dip slightly.
            var base = onProtocol ? 4.05 : 3.35
            if let s = sinceDose, s >= 5 { base -= 0.35 }
            if let s = sinceDose, s <= 2 { base += 0.15 }
            // A handful of off days.
            if [88, 61, 37, 15].contains(daysAgo) { base -= 1.0 }

            func score(_ bias: Double = 0) -> Double {
                (base + bias + rng.uniform(-0.55, 0.55)).rounded().clamped(to: 1...5)
            }
            let energy = score(0.05), mood = score(), libido = score(-0.1), sleepQ = score(-0.05), clarity = score(0.1)

            let hk = rng.uniform(0, 1) < 0.8 || daysAgo < 14
            let sleepHrs = (7.1 + (sleepQ - 3.5) * 0.35 + rng.uniform(-0.5, 0.5)).clamped(to: 5.2...8.9)
            let progress = Double(historyDays - daysAgo) / Double(historyDays)
            let weightLbs = 201.0 - 4.5 * progress + rng.uniform(-0.9, 0.9)
            let mw = rng.uniform(0, 1) < (onProtocol ? 0.78 : 0.45)
            let workout = rng.uniform(0, 1) < 0.6
            // Evenings for half the log so the persona reads "Metronome", not "Early Riser".
            let created = daysAgo % 2 == 0 ? at(date, 7, 40 + Int(rng.uniform(0, 15))) : at(date, 21, 5 + Int(rng.uniform(0, 30)))
            let note = notes[daysAgo]
            if note != nil { notedCount += 1 }

            context.insert(SDCheckin(
                userID: userID, date: date,
                energyScore: energy, moodScore: mood, libidoScore: libido,
                sleepQualityScore: sleepQ, morningWoodScore: mw ? 5 : 1, mentalClarityScore: clarity,
                morningWood: mw, workoutToday: workout,
                trainingPerformanceScore: workout ? score(0.1) : nil,
                supplementsTaken: daysAgo % 4 == 1 ? nil : "Vitamin D3,Fish Oil,Magnesium Glycinate",
                bodyWeightKg: weightLbs * 0.453592,
                bodyFatPercent: 21.0 - 2.2 * progress + rng.uniform(-0.3, 0.3),
                restingHR: hk ? (58 + rng.uniform(-4, 5)).rounded() : nil,
                sleepHours: hk ? sleepHrs : nil,
                hrv: hk ? (46 + (sleepQ - 3.5) * 4 + rng.uniform(-7, 7)).clamped(to: 28...72) : nil,
                stepCount: hk ? Int(8400 + rng.uniform(-2600, 3600)) : nil,
                notes: note,
                createdAt: created, updatedAt: created
            ))
            checkinKeys.append("checkin:\(XPLedger.dayKey(date))")
            checkinDates.append(date)
            if hk { syncedDates.append(date) }
        }

        // ── Bloodwork: baseline + three follow-ups ~5–6 weeks apart ────────
        let panels: [(daysAgo: Int, label: String, values: [String: Double])] = [
            (116, "Baseline panel", ["Total Testosterone": 318, "Free Testosterone": 7.4, "Estradiol (E2)": 21, "SHBG": 38, "Hematocrit": 44.1, "Hemoglobin": 14.8, "PSA": 0.7, "LH": 4.1, "FSH": 5.2, "Total Cholesterol": 196, "LDL": 121, "HDL": 46, "Triglycerides": 134, "ALT": 24, "AST": 22]),
            (78, "6-week follow-up", ["Total Testosterone": 742, "Free Testosterone": 19.6, "Estradiol (E2)": 34, "SHBG": 31, "Hematocrit": 46.9, "Hemoglobin": 15.7, "PSA": 0.8, "LH": 0.4, "FSH": 0.6, "Total Cholesterol": 189, "LDL": 116, "HDL": 45, "Triglycerides": 118, "ALT": 27, "AST": 24]),
            (41, "12-week follow-up", ["Total Testosterone": 868, "Free Testosterone": 22.9, "Estradiol (E2)": 39, "SHBG": 29, "Hematocrit": 48.6, "Hemoglobin": 16.2, "PSA": 0.9, "LH": 0.3, "FSH": 0.5, "Total Cholesterol": 184, "LDL": 110, "HDL": 47, "Triglycerides": 109, "ALT": 26, "AST": 25]),
            (4, "16-week follow-up", ["Total Testosterone": 815, "Free Testosterone": 21.4, "Estradiol (E2)": 33, "SHBG": 30, "Hematocrit": 48.2, "Hemoglobin": 16.0, "PSA": 0.8, "LH": 0.3, "FSH": 0.4, "Total Cholesterol": 181, "LDL": 106, "HDL": 49, "Triglycerides": 101, "ALT": 25, "AST": 23]),
        ]
        var bloodworkKeys: [String] = []
        var panelDates: [Date] = []
        for panel in panels {
            let drawn = at(day(panel.daysAgo), 7, 45)
            panelDates.append(drawn)
            let bw = SDBloodwork(userID: userID, drawnAt: drawn, labName: panel.label,
                                 notes: panel.daysAgo == 116 ? "Fasted, 7:45 a.m." : "Fasted, trough draw (day 6)",
                                 createdAt: drawn.addingTimeInterval(3 * 86_400), updatedAt: drawn.addingTimeInterval(3 * 86_400))
            context.insert(bw)
            for (name, unit, low, high) in Self.markerDefs {
                guard let value = panel.values[name] else { continue }
                let marker = SDBloodworkMarker(bloodworkID: bw.id, markerName: name, value: value, unit: unit,
                                               referenceRangeLow: low, referenceRangeHigh: high,
                                               createdAt: bw.createdAt, updatedAt: bw.createdAt)
                context.insert(marker)
                bw.markers.append(marker)
            }
            bloodworkKeys.append("bloodwork:\(bw.id.uuidString)")
        }

        // ── Peptides / adjuncts ────────────────────────────────────────────
        var peptideKeys: [String] = []
        var peptideDates: [Date] = []
        // BPC-157 250 mcg, weekdays, a 5-week block ending 10 days ago.
        for daysAgo in stride(from: 45, through: 10, by: -1) {
            let date = day(daysAgo)
            let weekday = cal.component(.weekday, from: date)
            guard (2...6).contains(weekday) else { continue }
            let when = at(date, 7, 30)
            let log = SDPeptideLog(userID: userID, administeredAt: when, peptideName: "BPC-157", doseMcg: 250,
                                   doseUnit: "mcg", routeOfAdministration: "subcutaneous",
                                   injectionSite: weekday % 2 == 0 ? "SubQ Abdomen Left" : "SubQ Abdomen Right",
                                   createdAt: when, updatedAt: when)
            context.insert(log)
            peptideKeys.append("peptide:\(log.id.uuidString)")
            peptideDates.append(when)
        }
        // Ipamorelin 200 mcg, Mon/Wed/Fri nights for the last 4 weeks.
        for daysAgo in stride(from: 27, through: 0, by: -1) {
            let date = day(daysAgo)
            guard [2, 4, 6].contains(cal.component(.weekday, from: date)), daysAgo > 0 else { continue }
            let when = at(date, 22, 15)
            let log = SDPeptideLog(userID: userID, administeredAt: when, peptideName: "Ipamorelin", doseMcg: 200,
                                   doseUnit: "mcg", routeOfAdministration: "subcutaneous", injectionSite: "SubQ Abdomen",
                                   createdAt: when, updatedAt: when)
            context.insert(log)
            peptideKeys.append("peptide:\(log.id.uuidString)")
            peptideDates.append(when)
        }
        try? context.save()

        // ── Gamification ───────────────────────────────────────────────────
        let ledger = XPLedger(defaults: .standard)
        ledger.markAwarded(checkinKeys + injectionKeys + bloodworkKeys + peptideKeys)

        context.insert(SDGamificationState(userID: userID, currentXP: demoXP,
                                           currentLevel: SDGamificationState.level(forXP: demoXP),
                                           createdAt: day(historyDays - 1), updatedAt: .now))

        // Streak rows (the VM derives current counts from rows at read time).
        context.insert(SDStreakState(userID: userID, streakType: "checkin", currentCount: missedDaysAgo,
                                     bestCount: missedDaysAgo, lastCompletedDate: today,
                                     flameLevel: GamificationViewModel.flameLevel(forDays: missedDaysAgo)))
        context.insert(SDStreakState(userID: userID, streakType: "injection", currentCount: cypInjections,
                                     bestCount: cypInjections, lastCompletedDate: cypDates.last,
                                     flameLevel: GamificationViewModel.flameLevel(forWeeks: cypInjections)))

        // Quests: today's dailies and the week's easy ones already done (their XP is in demoXP).
        QuestService.seedIfNeeded(context: context, userID: userID)
        let quests = (try? context.fetch(FetchDescriptor<SDQuest>())) ?? []
        var questKeys: [String] = []
        for quest in quests where quest.userID == userID {
            let done = quest.frequency == "daily"
                || quest.questType == "hit_streak"
                || quest.questType == "inject_on_schedule"
                || quest.questType == "complete_bloodwork"
            guard done else { continue }
            quest.isCompleted = true
            quest.completedDate = at(today, 7, 52)
            quest.updatedAt = quest.completedDate ?? .now
            questKeys.append("quest:\(quest.questID)")
        }
        ledger.markAwarded(questKeys)

        // Badges: unlock exactly what the data earns, with the date each was earned.
        BadgeService.seedIfNeeded(context: context, userID: userID)
        try? context.save()
        let facts = GamificationFacts.compute(context: context, level: SDGamificationState.level(forXP: demoXP), now: .now)
        let rows = (try? context.fetch(FetchDescriptor<SDBadge>())) ?? []
        let rowsByID = Dictionary(rows.map { ($0.badgeID, $0) }, uniquingKeysWith: { a, _ in a })
        let checkinsAsc = checkinDates.sorted()
        let syncedAsc = syncedDates.sorted()
        let injectionsAsc = ((try? context.fetch(FetchDescriptor<SDInjection>())) ?? []).map(\.injectedAt).sorted()
        let peptidesAsc = peptideDates.sorted()
        let streakStart = day(missedDaysAgo - 1)
        func nth(_ dates: [Date], _ n: Int) -> Date? { n >= 1 && n <= dates.count ? dates[n - 1] : dates.last }

        var earned: [String] = []
        for def in GamificationCatalog.badges where def.isEarned(facts) {
            guard let row = rowsByID[def.id] else { continue }
            let date: Date?
            switch def.metric {
            case .checkins:             date = nth(checkinsAsc, def.target)
            case .checkinStreak:        date = cal.date(byAdding: .day, value: def.target - 1, to: streakStart)
            case .injections:           date = nth(injectionsAsc, def.target)
            case .onScheduleWeeks:      date = nth(cypDates, def.target)
            case .bloodworkPanels:      date = nth(panelDates, def.target)
            case .healthSyncedCheckins: date = nth(syncedAsc, def.target)
            case .adjunctLogs:          date = nth(peptidesAsc, def.target)
            case .level:                date = day(58)
            case .notedLogs:            date = day(9)
            case .goodDayCheckin:       date = day(104)
            case .perfectWeek:          date = day(98)
            case .injectionPrecision:   date = cal.date(byAdding: .day, value: 30, to: firstCyp)
            default:                    date = day(20)
            }
            row.unlockedDate = at(date ?? today, 21, 12)
            row.updatedAt = row.unlockedDate ?? .now
            earned.append(def.id)
        }
        UserDefaults.standard.set(earned, forKey: "gamification.celebratedBadges")
        ledger.markAwarded(earned.map { "badge:\($0)" })
        if let state = try? context.fetch(FetchDescriptor<SDGamificationState>()).first {
            state.totalBadgesUnlocked = earned.count
        }
        _ = notedCount
        print("[DemoMode] seeded \(checkinDates.count) check-ins, \(injectionsAsc.count) injections, \(panels.count) panels, \(peptidesAsc.count) peptide logs, \(earned.count)/\(GamificationCatalog.badges.count) badges, XP \(demoXP) (L\(SDGamificationState.level(forXP: demoXP)))")
    }

    /// When the history is anchored on the real today, tonight's hCG isn't logged yet.
    private var fixedTodayIsReal: Bool { cal.isDateInToday(today) }

    /// (name, unit, reference low, reference high) — matches the bloodwork entry form.
    static let markerDefs: [(String, String, Double, Double)] = [
        ("Total Testosterone", "ng/dL", 300, 1000),
        ("Free Testosterone", "pg/mL", 8.7, 25.1),
        ("Estradiol (E2)", "pg/mL", 7.6, 42.6),
        ("SHBG", "nmol/L", 16.5, 55.9),
        ("Hematocrit", "%", 38.3, 50.9),
        ("Hemoglobin", "g/dL", 13.2, 17.1),
        ("PSA", "ng/mL", 0, 4),
        ("LH", "IU/L", 1.7, 8.6),
        ("FSH", "IU/L", 1.5, 12.4),
        ("Total Cholesterol", "mg/dL", 0, 200),
        ("LDL", "mg/dL", 0, 130),
        ("HDL", "mg/dL", 40, 100),
        ("Triglycerides", "mg/dL", 0, 150),
        ("ALT", "U/L", 7, 55),
        ("AST", "U/L", 8, 48),
    ]
}

/// SplitMix64-based uniform doubles (deterministic per seed).
private struct SeededRandom {
    var generator: SplitMix64
    init(seed: UInt64) { generator = SplitMix64(seed: seed) }
    mutating func uniform(_ low: Double, _ high: Double) -> Double {
        low + Double(generator.next() % 1_000_000) / 1_000_000 * (high - low)
    }
}
#endif
