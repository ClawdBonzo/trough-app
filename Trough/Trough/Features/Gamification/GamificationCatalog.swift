import Foundation
import SwiftData

// MARK: - Localization helper

/// Looks up a 1.4 gamification string. The English copy doubles as the
/// fallback `value`, so a key missing from a not-yet-translated locale shows
/// English instead of the raw key. en.lproj carries the same strings
/// (see "// MARK: 1.4 gamification" in Localizable.strings).
func gLoc(_ key: String, _ english: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: english, comment: "")
}

// MARK: - Badge tiers

// The type itself lives in DesignSystem/BadgeMedallion.swift; the ladder logic lives here.
extension BadgeTier {
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    private static func at(_ rank: Int) -> BadgeTier { allCases[min(max(rank, 0), allCases.count - 1)] }

    /// Tier from a rung's position on a ladder of `count` rungs. Short ladders
    /// (≤3 rungs) climb bronze → silver → gold; longer ones spread evenly
    /// bronze → platinum (first rung bronze, last rung platinum).
    static func forLadderPosition(_ index: Int, of count: Int) -> BadgeTier {
        guard count > 1 else { return .bronze }
        if count <= 3 { return at(min(index, 2)) }
        let scaled = (Double(index) * 3.0 / Double(count - 1)).rounded(.toNearestOrAwayFromZero)
        return at(Int(scaled))
    }

    var nameKey: String { "badge.tier.\(self)" }
    var name: String {
        switch self {
        case .bronze:   return gLoc(nameKey, "Bronze")
        case .silver:   return gLoc(nameKey, "Silver")
        case .gold:     return gLoc(nameKey, "Gold")
        case .platinum: return gLoc(nameKey, "Platinum")
        }
    }
}

// MARK: - Badge metrics

/// What a badge measures. Every metric is about LOGGING, CONSISTENCY or
/// ADHERENCE — never lab values, hormone levels or symptom outcomes
/// (DESIGN_SPEC_1.4 "Gamification rules (health-app safe)").
enum BadgeMetric: String, CaseIterable {
    case checkins
    case checkinStreak          // longest run of consecutive check-in days
    case injections
    case onScheduleWeeks        // longest run of on-schedule injection weeks
    case bloodworkPanels
    case healthSyncedCheckins
    case adjunctLogs
    case level
    case notedLogs
    // Specials (value 0/1 unless noted)
    case goodDayCheckin         // self-rated Protocol Score ≥ 80 (legacy "testosterone_peak")
    case perfectWeek
    case supplementDays30       // compliant days in trailing 30 (target 27)
    case injectionPrecision
    case nightOwl
    case newYear
    case daysSinceFirstCheckin

    /// Higher = more prestigious when two badges share a tier.
    var prestigeWeight: Int {
        switch self {
        case .level:                  return 9
        case .checkinStreak:          return 8
        case .onScheduleWeeks:        return 7
        case .checkins:               return 6
        case .injections:             return 5
        case .daysSinceFirstCheckin, .nightOwl, .newYear: return 4
        case .injectionPrecision, .perfectWeek, .supplementDays30: return 4
        case .bloodworkPanels:        return 3
        case .healthSyncedCheckins:   return 2
        case .goodDayCheckin:         return 2
        case .notedLogs, .adjunctLogs: return 1
        }
    }

    func value(in f: GamificationFacts) -> Int {
        switch self {
        case .checkins:              return f.checkins
        case .checkinStreak:         return f.longestCheckinStreak
        case .injections:            return f.injections
        case .onScheduleWeeks:       return f.longestOnScheduleWeeks
        case .bloodworkPanels:       return f.bloodworkPanels
        case .healthSyncedCheckins:  return f.healthSyncedCheckins
        case .adjunctLogs:           return f.adjunctLogs
        case .level:                 return f.level
        case .notedLogs:             return f.notedLogs
        case .goodDayCheckin:        return f.hasGoodDayCheckin ? 1 : 0
        case .perfectWeek:           return f.hasPerfectWeek ? 1 : 0
        case .supplementDays30:      return f.supplementCompliantDays30
        case .injectionPrecision:    return f.injectionPrecision ? 1 : 0
        case .nightOwl:              return f.nightOwl ? 1 : 0
        case .newYear:               return f.newYear ? 1 : 0
        case .daysSinceFirstCheckin: return f.daysSinceFirstCheckin
        }
    }
}

// MARK: - Badge definition

struct BadgeDef: Identifiable, Hashable {
    let id: String
    let metric: BadgeMetric
    let target: Int
    let tier: BadgeTier
    /// SF Symbol shown for the badge (iconEmoji on SDBadge is legacy only).
    let symbol: String
    /// Two-stop gradient tint (hex, "#RRGGBB").
    let tint: [String]
    let isSecret: Bool
    /// Emoji written to SDBadge.iconEmoji for legacy views/back-compat.
    let legacyEmoji: String
    /// Position inside its ladder (0-based) — tie-breaker for prestige.
    let ladderIndex: Int

    fileprivate let enTitle: String
    fileprivate let enHowTo: String
    fileprivate let enUnlockedLine: String

    var titleKey: String { "badge.\(id).title" }
    var howToKey: String { "badge.\(id).how" }
    var unlockedLineKey: String { "badge.\(id).line" }

    var title: String { gLoc(titleKey, enTitle) }
    /// How to earn it (shown on the locked card; hide for locked secrets).
    var howTo: String { gLoc(howToKey, enHowTo) }
    /// Witty, tasteful line shown on unlock. No health claims.
    var unlockedLine: String { gLoc(unlockedLineKey, enUnlockedLine) }

    /// Higher = more prestigious. Tier dominates, then metric weight, then rung.
    var prestige: Int { tier.rank * 1000 + metric.prestigeWeight * 10 + ladderIndex }

    /// (current, target) derived at read time from facts. `current` is clamped
    /// to `target` so progress bars never overflow.
    func progress(_ facts: GamificationFacts) -> (current: Int, target: Int) {
        (min(metric.value(in: facts), target), target)
    }

    func isEarned(_ facts: GamificationFacts) -> Bool {
        metric.value(in: facts) >= target
    }

    static func == (lhs: BadgeDef, rhs: BadgeDef) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// English strings for the localization parity test.
    var englishStrings: [(key: String, value: String)] {
        [(titleKey, enTitle), (howToKey, enHowTo), (unlockedLineKey, enUnlockedLine)]
    }
}

// MARK: - Catalog

enum GamificationCatalog {

    static let badgeUnlockXP = 25

    /// One rung of a ladder: target, optional legacy id override, symbol,
    /// title, how-to, unlocked line.
    private typealias Rung = (target: Int, id: String?, symbol: String, title: String, how: String, line: String)

    private static func ladder(
        metric: BadgeMetric,
        idPrefix: String,
        tint: [String],
        emoji: String,
        tiers rungs: [Rung]
    ) -> [BadgeDef] {
        rungs.enumerated().map { index, rung in
            BadgeDef(
                id: rung.id ?? "\(idPrefix)_\(rung.target)",
                metric: metric,
                target: rung.target,
                tier: .forLadderPosition(index, of: rungs.count),
                symbol: rung.symbol,
                tint: tint,
                isSecret: false,
                legacyEmoji: emoji,
                ladderIndex: index,
                enTitle: rung.title,
                enHowTo: rung.how,
                enUnlockedLine: rung.line
            )
        }
    }

    private static func special(
        _ id: String, metric: BadgeMetric, target: Int = 1, tier: BadgeTier,
        symbol: String, tint: [String], secret: Bool = false, emoji: String,
        title: String, how: String, line: String
    ) -> BadgeDef {
        BadgeDef(id: id, metric: metric, target: target, tier: tier, symbol: symbol,
                 tint: tint, isSecret: secret, legacyEmoji: emoji, ladderIndex: 0,
                 enTitle: title, enHowTo: how, enUnlockedLine: line)
    }

    // Tints per family
    private static let tCheckins  = ["#E94560", "#FF8A5B"]
    private static let tStreak    = ["#FF9F1C", "#FF5E3A"]
    private static let tInject    = ["#4ECDC4", "#1A9E95"]
    private static let tWeeks     = ["#7B61FF", "#4B3BC4"]
    private static let tBlood     = ["#5AC8FA", "#2D7FF9"]
    private static let tHealth    = ["#FF6B81", "#E0245E"]
    private static let tAdjunct   = ["#A3E635", "#4D9E1F"]
    private static let tLevel     = ["#FFD86B", "#E0A526"]
    private static let tNotes     = ["#C9B6FF", "#8E7CC3"]
    private static let tSpecial   = ["#F5F5F7", "#9EA7B3"]
    private static let tSecret    = ["#E94560", "#7B2FF7"]

    static let badges: [BadgeDef] = {
        var all: [BadgeDef] = []

        all += ladder(metric: .checkins, idPrefix: "checkins", tint: tCheckins, emoji: "📝", tiers: [
            (1,   nil, "checkmark.circle.fill",   "First Entry",     "Log your first check-in.",  "Day one is on the books."),
            (7,   nil, "calendar.badge.checkmark", "Week Logged",    "Log 7 check-ins.",          "Seven entries. A pattern is forming."),
            (30,  nil, "calendar",                "Month of Data",   "Log 30 check-ins.",         "Thirty entries. Your log has a shape now."),
            (100, nil, "rosette",                 "Centurion",       "Log 100 check-ins.",        "Triple digits. The notebook is getting thick."),
            (365, nil, "crown.fill",              "Year in the Log", "Log 365 check-ins.",        "A full year of entries. Remarkable consistency."),
        ])

        all += ladder(metric: .checkinStreak, idPrefix: "checkin_streak", tint: tStreak, emoji: "🔥", tiers: [
            (3,   nil,                "flame",             "Warming Up",       "Check in 3 days in a row.",   "Three straight days. Momentum unlocked."),
            (7,   "streak_flame_7",   "flame.fill",        "Flame Keeper",     "Check in 7 days in a row.",   "A full week without missing a beat."),
            (14,  nil,                "flame.circle.fill", "Fortnight Focus",  "Check in 14 days in a row.",  "Two weeks straight. Habit territory."),
            (30,  "consistency_king", "bolt.fill",         "Consistency King", "Check in 30 days in a row.",  "Thirty days running. Crown earned."),
            (60,  nil,                "bolt.circle.fill",  "Unbroken",         "Check in 60 days in a row.",  "Sixty days. The streak has its own gravity."),
            (100, nil,                "sparkles",          "The Hundred",      "Check in 100 days in a row.", "One hundred days straight. Legendary."),
        ])

        all += ladder(metric: .injections, idPrefix: "injections", tint: tInject, emoji: "💉", tiers: [
            (1,   nil, "syringe",          "First Shot Logged", "Log your first injection.", "Logged and dated. That's how it starts."),
            (10,  nil, "syringe.fill",     "Ten Logged",        "Log 10 injections.",        "Ten entries. Your schedule has a history."),
            (25,  nil, "cross.vial",       "Quarter Century",   "Log 25 injections.",        "25 logged. The calendar thanks you."),
            (52,  nil, "cross.vial.fill",  "Year of Logs",      "Log 52 injections.",        "52 logged. A year's worth of records."),
            (100, nil, "medal.fill",       "Record Keeper",     "Log 100 injections.",       "100 injections logged. Meticulous."),
        ])

        all += ladder(metric: .onScheduleWeeks, idPrefix: "on_schedule_weeks", tint: tWeeks, emoji: "🗓️", tiers: [
            (4,  nil, "calendar.badge.clock", "On the Clock",     "Log your injection on schedule for 4 weeks in a row.",  "Four on-schedule weeks. Clockwork."),
            (12, nil, "metronome",            "Metronome",        "Log your injection on schedule for 12 weeks in a row.", "Twelve weeks, right on time."),
            (26, nil, "metronome.fill",       "Half-Year Rhythm", "Log your injection on schedule for 26 weeks in a row.", "Six months on schedule. Steady hands."),
            (52, nil, "infinity.circle.fill", "Full Rotation",    "Log your injection on schedule for 52 weeks in a row.", "A full year of on-schedule weeks."),
        ])

        all += ladder(metric: .bloodworkPanels, idPrefix: "bloodwork", tint: tBlood, emoji: "📊", tiers: [
            (1,  nil,                "testtube.2",                "First Panel",      "Log your first bloodwork panel.", "First panel filed. On the record."),
            (3,  nil,                "chart.bar.doc.horizontal",  "Paper Trail",      "Log 3 bloodwork panels.",         "Three panels logged. Handy for your next appointment."),
            (5,  nil,                "doc.text.magnifyingglass",  "Lab Regular",      "Log 5 bloodwork panels.",         "Five panels filed. The archive grows."),
            (10, "bloodwork_master", "books.vertical.fill",       "Bloodwork Master", "Log 10 bloodwork panels.",        "Ten panels on file. Impeccable records."),
        ])

        all += ladder(metric: .healthSyncedCheckins, idPrefix: "health_synced", tint: tHealth, emoji: "❤️", tiers: [
            (7,   nil, "heart.text.square",                    "Synced Up",        "Log 7 check-ins with Apple Health data.",   "Your log and Apple Health are talking."),
            (30,  nil, "heart.text.square.fill",               "Data Stream",      "Log 30 check-ins with Apple Health data.",  "Thirty synced check-ins. Effortless records."),
            (100, nil, "applewatch.radiowaves.left.and.right", "Fully Integrated", "Log 100 check-ins with Apple Health data.", "100 synced check-ins. Automation at its finest."),
        ])

        all += ladder(metric: .adjunctLogs, idPrefix: "adjunct_logs", tint: tAdjunct, emoji: "💊", tiers: [
            (1,  nil, "pills",           "Stack Started",   "Log your first peptide or adjunct dose.", "First adjunct entry logged."),
            (10, nil, "pills.fill",      "Stack Tracker",   "Log 10 peptide or adjunct doses.",        "Ten adjunct logs. Every entry accounted for."),
            (50, nil, "shippingbox.fill","Stack Archivist", "Log 50 peptide or adjunct doses.",        "Fifty adjunct logs. Nothing slips through."),
        ])

        all += ladder(metric: .level, idPrefix: "level", tint: tLevel, emoji: "⭐", tiers: [
            (5,  "level_5",  "star.fill",        "Rising Star",       "Reach Level 5.",  "Level 5. The climb is on."),
            (10, "level_10", "trophy.fill",      "Master Tier",       "Reach Level 10.", "Level 10. Rarefied air."),
            (11, "level_11", "star.circle.fill", "Top of the Ladder", "Reach Level 11.", "Max level. Nowhere to go but consistent."),
        ])

        all += ladder(metric: .notedLogs, idPrefix: "notes", tint: tNotes, emoji: "🗒️", tiers: [
            (10, nil, "note.text",        "Field Notes", "Add notes to 10 logs.", "Ten notes. Context is king."),
            (50, nil, "book.closed.fill", "Chronicler",  "Add notes to 50 logs.", "Fifty notes. Your future self says thanks."),
        ])

        // Specials — the four remaining legacy ids keep their ids.
        all.append(special("testosterone_peak", metric: .goodDayCheckin, tier: .silver,
                           symbol: "sun.max.fill", tint: tSpecial, emoji: "🧬",
                           title: "Good Day Logged",
                           how: "Log a check-in with a self-rated Protocol Score of 80 or higher.",
                           line: "A great day, noted for the record."))
        all.append(special("perfect_week", metric: .perfectWeek, tier: .silver,
                           symbol: "checkmark.seal.fill", tint: tSpecial, emoji: "✅",
                           title: "Perfect Week",
                           how: "Check in every day of a calendar week, Monday to Sunday.",
                           line: "Seven for seven, Monday to Sunday."))
        all.append(special("supplement_adherence", metric: .supplementDays30, target: 27, tier: .gold,
                           symbol: "capsule.fill", tint: tSpecial, emoji: "💊",
                           title: "Supplement Scholar",
                           how: "Log your supplements on 27 of the last 30 days.",
                           line: "Twenty-seven of thirty. Diligent."))
        all.append(special("injection_precision", metric: .injectionPrecision, tier: .gold,
                           symbol: "scope", tint: tSpecial, emoji: "💉",
                           title: "Precision Injector",
                           how: "Log every scheduled injection on time for 30 days.",
                           line: "Thirty days, zero missed entries."))

        // Secrets — hidden until earned.
        all.append(special("secret_night_owl", metric: .nightOwl, tier: .gold,
                           symbol: "moon.stars.fill", tint: tSecret, secret: true, emoji: "🦉",
                           title: "Night Owl",
                           how: "Check in between midnight and 4 a.m.",
                           line: "The log never sleeps. (You should, though.)"))
        all.append(special("secret_new_year", metric: .newYear, tier: .gold,
                           symbol: "party.popper.fill", tint: tSecret, secret: true, emoji: "🎉",
                           title: "Fresh Start",
                           how: "Check in on January 1.",
                           line: "New year, same great logging habit."))
        all.append(special("secret_full_year", metric: .daysSinceFirstCheckin, target: 365, tier: .platinum,
                           symbol: "birthday.cake.fill", tint: tSecret, secret: true, emoji: "🎂",
                           title: "Full Orbit",
                           how: "Reach one year since your first check-in.",
                           line: "One trip around the sun with Trough."))
        return all
    }()

    static let byID: [String: BadgeDef] = Dictionary(uniqueKeysWithValues: badges.map { ($0.id, $0) })

    static func badge(_ id: String) -> BadgeDef? { byID[id] }

    /// The single most prestigious badge in `defs`.
    static func mostPrestigious(_ defs: [BadgeDef]) -> BadgeDef? {
        defs.max { $0.prestige < $1.prestige }
    }

    // MARK: Levels

    /// English level names (11 levels; thresholds in SDGamificationState.xpThresholds).
    private static let enLevelNames = [
        "Beginner", "Rising", "Committed", "Dedicated", "Driven", "Focused",
        "Disciplined", "Advanced", "Expert", "Master", "Optimized Alpha",
    ]

    static func levelNameKey(_ level: Int) -> String { "level.name.\(level)" }

    static func levelName(_ level: Int) -> String {
        let clamped = min(max(level, 1), enLevelNames.count)
        return gLoc(levelNameKey(clamped), enLevelNames[clamped - 1])
    }

    /// Rank cover index for the design system's `RankCover.forLevel(_:)` —
    /// the cover is keyed by level int (1…11), so this is the clamped level.
    static func rankCoverLevel(_ level: Int) -> Int { min(max(level, 1), 11) }

    // MARK: Localization parity

    /// Every English string this engine resolves through `gLoc` — the tests
    /// assert each one exists in en.lproj/Localizable.strings.
    static var englishStrings: [(key: String, value: String)] {
        var out = badges.flatMap(\.englishStrings)
        out += enLevelNames.enumerated().map { (levelNameKey($0.offset + 1), $0.element) }
        out += Persona.allCases.flatMap(\.englishStrings)
        out += DailyChallengeKind.allCases.flatMap(\.englishStrings)
        return out
    }
}

// MARK: - Facts (derived at read time)

/// Everything the badge catalog and persona need, derived from SwiftData rows
/// at read time. Sample data is always excluded. Rows are not filtered by
/// userID (single on-device user; older builds could orphan userIDs).
struct GamificationFacts: Equatable {
    var checkins = 0
    var currentCheckinStreak = 0
    var longestCheckinStreak = 0
    var injections = 0
    var currentOnScheduleWeeks = 0
    var longestOnScheduleWeeks = 0
    var bloodworkPanels = 0
    var healthSyncedCheckins = 0
    var adjunctLogs = 0
    var level = 1
    var notedLogs = 0
    var hasGoodDayCheckin = false
    var hasPerfectWeek = false
    var supplementCompliantDays30 = 0
    var injectionPrecision = false
    var nightOwl = false
    var newYear = false
    var daysSinceFirstCheckin = 0
    // Persona inputs
    var checkinsBeforeNine = 0
    var injectionIntervals = 0
    var onScheduleInjectionIntervals = 0
    var activeAdjuncts = 0

    static func compute(context: ModelContext, level: Int, now: Date = .now, calendar: Calendar = .current) -> GamificationFacts {
        var f = GamificationFacts()
        f.level = level

        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        let injections = (try? context.fetch(FetchDescriptor<SDInjection>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        let bloodwork = (try? context.fetchCount(FetchDescriptor<SDBloodwork>(predicate: #Predicate { !$0.isSampleData }))) ?? 0
        let peptides = (try? context.fetch(FetchDescriptor<SDPeptideLog>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: #Predicate { $0.isActive && $0.isPrimary && !$0.isSampleData })
        protoDesc.fetchLimit = 1
        let proto = try? context.fetch(protoDesc).first

        // Check-ins
        let days = Set(checkins.map { calendar.startOfDay(for: $0.date) })
        f.checkins = days.count
        f.currentCheckinStreak = DayStreak.current(days: days, now: now, calendar: calendar)
        f.longestCheckinStreak = DayStreak.longest(days: days, calendar: calendar)
        f.healthSyncedCheckins = checkins.filter(\.hasHealthKitData).count
        f.hasGoodDayCheckin = checkins.contains { $0.protocolScore >= 80 }
        f.hasPerfectWeek = Self.hasPerfectISOWeek(days: days, calendar: calendar)
        f.nightOwl = checkins.contains { calendar.component(.hour, from: $0.createdAt) < 4 && calendar.isDate($0.createdAt, inSameDayAs: $0.date) }
        f.newYear = days.contains { let c = calendar.dateComponents([.month, .day], from: $0); return c.month == 1 && c.day == 1 }
        if let first = days.min() {
            f.daysSinceFirstCheckin = max(0, calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: now)).day ?? 0)
        }
        f.checkinsBeforeNine = checkins.filter { calendar.component(.hour, from: $0.createdAt) < 9 }.count
        if let cutoff = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) {
            f.supplementCompliantDays30 = Set(checkins
                .filter { $0.date >= cutoff && !($0.supplementsTaken ?? "").isEmpty }
                .map { calendar.startOfDay(for: $0.date) }).count
        }

        // Injections
        f.injections = injections.count
        let protocolInjections = Self.injectionsForProtocol(injections, proto: proto)
        let dates = protocolInjections.map(\.injectedAt)
        let cadence = InjectionWeekStreak.cadenceWeeks(frequencyDays: proto?.frequencyDays ?? 7)
        let weeks = InjectionWeekStreak.compute(dates: dates, now: now, cadenceWeeks: cadence)
        f.currentOnScheduleWeeks = weeks.current
        f.longestOnScheduleWeeks = weeks.longest
        if let freq = proto?.frequencyDays, freq > 0 {
            f.injectionPrecision = Self.injectionPrecision(dates: dates, frequencyDays: freq, now: now, calendar: calendar)
            let sorted = dates.sorted()
            for (a, b) in zip(sorted, sorted.dropFirst()) {
                f.injectionIntervals += 1
                let gapDays = b.timeIntervalSince(a) / 86_400
                if abs(gapDays - Double(freq)) <= 1.0 { f.onScheduleInjectionIntervals += 1 }
            }
        }

        // Bloodwork / adjuncts / notes
        f.bloodworkPanels = bloodwork
        f.adjunctLogs = peptides.count
        if let cutoff = calendar.date(byAdding: .day, value: -30, to: now) {
            f.activeAdjuncts = Set(peptides.filter { $0.administeredAt >= cutoff }
                .map { $0.peptideName.trimmingCharacters(in: .whitespaces).lowercased() }).count
        }
        f.notedLogs = checkins.filter { !($0.notes ?? "").isBlankish }.count
            + injections.filter { !($0.notes ?? "").isBlankish }.count
            + peptides.filter { !($0.notes ?? "").isBlankish }.count
        return f
    }

    /// Injections belonging to the active primary protocol (by protocolID or
    /// case-insensitive compound name). Falls back to every injection when no
    /// protocol is active or nothing matches (e.g. the compound was renamed).
    static func injectionsForProtocol(_ all: [SDInjection], proto: SDProtocol?) -> [SDInjection] {
        guard let proto else { return all }
        let name = proto.compoundName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = all.filter {
            $0.protocolID == proto.id
                || $0.compoundName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name
        }
        return matching.isEmpty ? all : matching
    }

    /// True when some ISO week (Mon–Sun) has a check-in on all seven days.
    static func hasPerfectISOWeek(days: Set<Date>, calendar: Calendar) -> Bool {
        let iso = InjectionWeekStreak.isoCalendar(timeZone: calendar.timeZone)
        var perWeek: [Date: Int] = [:]
        for d in days {
            guard let start = iso.dateInterval(of: .weekOfYear, for: d)?.start else { continue }
            perWeek[start, default: 0] += 1
        }
        return perWeek.values.contains { $0 >= 7 }
    }

    /// "No missed injections for 30 days": ≥30 days of history, and within the
    /// trailing 30-day window no gap (incl. window edges) exceeds the protocol
    /// frequency + 24h grace. (Moved from BadgeService, unchanged semantics.)
    static func injectionPrecision(dates: [Date], frequencyDays: Int, now: Date, calendar: Calendar) -> Bool {
        guard frequencyDays > 0,
              let cutoff = calendar.date(byAdding: .day, value: -30, to: now),
              let earliest = dates.min(), earliest <= cutoff else { return false }
        let window = dates.filter { $0 >= cutoff && $0 <= now }.sorted()
        guard let first = window.first, let last = window.last else { return false }
        let maxGap = TimeInterval(frequencyDays) * 86_400 + 86_400
        guard first.timeIntervalSince(cutoff) <= maxGap, now.timeIntervalSince(last) <= maxGap else { return false }
        for (a, b) in zip(window, window.dropFirst()) where b.timeIntervalSince(a) > maxGap { return false }
        return true
    }
}

extension SDCheckin {
    /// True when Apple Health auto-filled at least one field on this check-in.
    var hasHealthKitData: Bool {
        hrv != nil || sleepHours != nil || stepCount != nil || restingHR != nil
    }
}

private extension String {
    var isBlankish: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Day streaks

enum DayStreak {
    /// Consecutive days ending today — or yesterday when today isn't logged yet
    /// (a streak is never "broken" before the day is over).
    static func current(days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while days.contains(day) {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// Longest run of consecutive days anywhere in history.
    static func longest(days: Set<Date>, calendar: Calendar) -> Int {
        let sorted = days.sorted()
        guard var prev = sorted.first else { return 0 }
        var run = 1, best = 1
        for d in sorted.dropFirst() {
            if calendar.date(byAdding: .day, value: 1, to: prev) == d { run += 1 } else { run = 1 }
            best = max(best, run)
            prev = d
        }
        return best
    }
}

// MARK: - Injection week streak

/// On-schedule injection weeks: consecutive ISO weeks (Mon–Sun) with ≥1
/// injection logged. Weekly injectors no longer reset to 1 every time (the old
/// consecutive-DAY logic did). The current week never breaks a streak — until
/// it's over there's nothing to nag about. Protocols longer than a week
/// (e.g. E10D, E14D) may skip up to `cadenceWeeks - 1` weeks between logs;
/// the streak then counts the calendar weeks spanned.
enum InjectionWeekStreak {

    static func isoCalendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = timeZone
        return cal
    }

    static func cadenceWeeks(frequencyDays: Int) -> Int {
        max(1, Int((Double(max(frequencyDays, 1)) / 7.0).rounded(.up)))
    }

    static func compute(
        dates: [Date],
        now: Date,
        cadenceWeeks: Int = 1,
        calendar: Calendar = isoCalendar()
    ) -> (current: Int, longest: Int) {
        func weekStart(_ d: Date) -> Date? { calendar.dateInterval(of: .weekOfYear, for: d)?.start }
        func gap(_ a: Date, _ b: Date) -> Int { calendar.dateComponents([.weekOfYear], from: a, to: b).weekOfYear ?? .max }

        let weeks = Set(dates.filter { $0 <= now }.compactMap(weekStart)).sorted()
        guard let firstWeek = weeks.first, let thisWeek = weekStart(now) else { return (0, 0) }
        let cadence = max(1, cadenceWeeks)

        var longest = 0
        var runStart = firstWeek
        var prev = firstWeek
        for w in weeks.dropFirst() {
            if gap(prev, w) > cadence {
                longest = max(longest, gap(runStart, prev) + 1)
                runStart = w
            }
            prev = w
        }
        longest = max(longest, gap(runStart, prev) + 1)

        // `prev` is the latest logged week, `runStart` the start of its run.
        let current = gap(prev, thisWeek) <= cadence ? gap(runStart, prev) + 1 : 0
        return (current, longest)
    }
}

// MARK: - Persona

/// Logging style, derived at read time from behavior (never stored).
/// Requires ≥10 check-ins; below that `derive` returns nil.
enum Persona: String, CaseIterable {
    case earlyRiser, metronome, dataNerd, stackBuilder, synced, steady

    static let minimumCheckins = 10

    static func derive(_ f: GamificationFacts) -> Persona? {
        guard f.checkins >= minimumCheckins else { return nil }
        let total = Double(f.checkins)
        if Double(f.checkinsBeforeNine) / total >= 0.60 { return .earlyRiser }
        if f.injectionIntervals >= 4,
           Double(f.onScheduleInjectionIntervals) / Double(f.injectionIntervals) >= 0.90 { return .metronome }
        if f.bloodworkPanels >= 3 { return .dataNerd }
        if f.activeAdjuncts >= 2 { return .stackBuilder }
        if Double(f.healthSyncedCheckins) / total >= 0.70 { return .synced }
        return .steady
    }

    var symbol: String {
        switch self {
        case .earlyRiser:   return "sunrise.fill"
        case .metronome:    return "metronome.fill"
        case .dataNerd:     return "chart.bar.doc.horizontal.fill"
        case .stackBuilder: return "square.stack.3d.up.fill"
        case .synced:       return "arrow.triangle.2.circlepath.circle.fill"
        case .steady:       return "figure.walk"
        }
    }

    var titleKey: String { "persona.\(rawValue).title" }
    var taglineKey: String { "persona.\(rawValue).tagline" }

    private var en: (title: String, tagline: String) {
        switch self {
        case .earlyRiser:   return ("Early Riser", "Most of your check-ins land before 9 a.m.")
        case .metronome:    return ("Metronome", "Your injections keep perfect time.")
        case .dataNerd:     return ("Data Nerd", "You keep your bloodwork on file.")
        case .stackBuilder: return ("Stack Builder", "You track more than one adjunct.")
        case .synced:       return ("Synced", "Apple Health fills in the details for you.")
        case .steady:       return ("Steady", "Quietly consistent. The best kind.")
        }
    }

    var title: String { gLoc(titleKey, en.title) }
    var tagline: String { gLoc(taglineKey, en.tagline) }

    var englishStrings: [(key: String, value: String)] {
        [(titleKey, en.title), (taglineKey, en.tagline)]
    }
}
