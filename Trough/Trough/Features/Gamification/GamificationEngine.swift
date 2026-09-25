import Foundation
import SwiftData

// MARK: - Celebration

/// One moment worth celebrating. `.questCompleted` is toast-level (surfaced via
/// `GamificationViewModel.pendingToast`); everything else is full-screen and
/// flows through the FIFO celebration queue (`currentCelebration`).
enum Celebration: Equatable, Identifiable {
    /// The most prestigious badge unlocked by one save, plus how many others
    /// unlocked alongside it ("+N more").
    case badge(BadgeDef, alsoEarned: Int, xp: Int)
    case levelUp(level: Int, name: String, totalXP: Int)
    case streak(days: Int, xp: Int)
    case questCompleted(title: String, xp: Int)

    var id: String {
        switch self {
        case .badge(let def, let n, _):      return "badge.\(def.id).\(n)"
        case .levelUp(let level, _, _):      return "level.\(level)"
        case .streak(let days, _):           return "streak.\(days)"
        case .questCompleted(let title, _):  return "quest.\(title)"
        }
    }

    /// XP granted by the event this celebrates (for level-ups: 0 — show totalXP).
    var xpReward: Int {
        switch self {
        case .badge(_, _, let xp), .streak(_, let xp), .questCompleted(_, let xp): return xp
        case .levelUp: return 0
        }
    }

    var isFullScreen: Bool {
        if case .questCompleted = self { return false }
        return true
    }

    /// Bridge to the pre-1.4 `LevelUpCelebrationView(event:)` API.
    var legacyEvent: CelebrationEvent {
        switch self {
        case .badge(let def, _, _):
            return .badgeUnlock(name: def.title, emoji: def.legacyEmoji)
        case .levelUp(let level, let name, let totalXP):
            return .levelUp(level: level, levelName: name, totalXP: totalXP)
        case .streak(let days, let xp):
            return .streakMilestone(days: days, type: "checkin", xpGained: xp)
        case .questCompleted(let title, let xp):
            return .questCompleted(name: title, xpGained: xp)
        }
    }

    /// Orders one save's worth of events: the most prestigious new badge
    /// (with "+N"), then a level-up, then a streak milestone.
    static func sequence(
        newBadges: [BadgeDef],
        badgeXP: Int = GamificationCatalog.badgeUnlockXP,
        levelUp: (level: Int, totalXP: Int)?,
        streak: (days: Int, xp: Int)?
    ) -> [Celebration] {
        var out: [Celebration] = []
        if let top = GamificationCatalog.mostPrestigious(newBadges) {
            out.append(.badge(top, alsoEarned: newBadges.count - 1, xp: badgeXP))
        }
        if let levelUp {
            out.append(.levelUp(level: levelUp.level,
                                name: GamificationCatalog.levelName(levelUp.level),
                                totalXP: levelUp.totalXP))
        }
        if let streak {
            out.append(.streak(days: streak.days, xp: streak.xp))
        }
        return out
    }
}

// MARK: - Streak milestones

enum StreakMilestones {
    /// Check-in streak lengths that get a full-screen celebration.
    static let celebrated: Set<Int> = [7, 30, 100, 365]
    /// Bonus XP per check-in streak length (paid once per streak run).
    static let xp: [Int: Int] = [3: 15, 7: 25, 14: 50, 30: 100, 60: 150, 100: 250, 365: 500]
}

// MARK: - XP ledger (idempotent awards)

/// Keyed, idempotent XP awards. Every award carries a stable key
/// ("checkin:2026-09-24", "injection:<uuid>", "bloodwork:<uuid>",
/// "peptide:<uuid>", "badge:<id>", "quest:<questID>", "streak:checkin:7:<start>")
/// so edits, re-saves and imports can never double-pay. Optional per-day caps
/// per category. Stored in UserDefaults — on-device only.
struct XPLedger {
    static let awardedKeysKey = "xp.awarded.keys"
    static let dailyTotalsKey = "xp.daily.totals"

    struct DailyCap: Equatable {
        let category: String
        let limit: Int
        static let checkin = DailyCap(category: "checkin", limit: 20)
        static let peptide = DailyCap(category: "peptide", limit: 15)
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func hasAwarded(_ key: String) -> Bool {
        Set(defaults.stringArray(forKey: Self.awardedKeysKey) ?? []).contains(key)
    }

    /// Marks keys as paid without granting XP (migration / backfill).
    func markAwarded(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        var set = Set(defaults.stringArray(forKey: Self.awardedKeysKey) ?? [])
        set.formUnion(keys)
        defaults.set(Array(set), forKey: Self.awardedKeysKey)
    }

    /// Returns the XP actually granted: 0 when `key` was already paid or the
    /// category's daily cap is exhausted. The key is consumed either way, so a
    /// capped award is never paid later by a re-save.
    @discardableResult
    func claim(key: String, amount: Int, cap: DailyCap? = nil, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard amount > 0 else { return 0 }
        var keys = Set(defaults.stringArray(forKey: Self.awardedKeysKey) ?? [])
        guard !keys.contains(key) else { return 0 }
        keys.insert(key)
        defaults.set(Array(keys), forKey: Self.awardedKeysKey)

        guard let cap else { return amount }
        let today = Self.dayKey(now, calendar: calendar)
        var totals = (defaults.dictionary(forKey: Self.dailyTotalsKey) as? [String: Int]) ?? [:]
        // Keep only today's buckets — older days can never be capped again.
        totals = totals.filter { $0.key.hasSuffix("|\(today)") }
        let bucket = "\(cap.category)|\(today)"
        let used = totals[bucket] ?? 0
        let granted = max(0, min(amount, cap.limit - used))
        totals[bucket] = used + granted
        defaults.set(totals, forKey: Self.dailyTotalsKey)
        return granted
    }
}

// MARK: - Daily challenge

enum DailyChallengeKind: String, CaseIterable {
    case checkin, injection, note, healthSync

    static let questPrefix = "daily_challenge"
    static let xpReward = 20

    var questType: String { "\(Self.questPrefix).\(rawValue)" }

    init?(questType: String) {
        guard questType.hasPrefix(Self.questPrefix + ".") else { return nil }
        self.init(rawValue: String(questType.dropFirst(Self.questPrefix.count + 1)))
    }

    var titleKey: String { "challenge.\(rawValue).title" }
    var descriptionKey: String { "challenge.\(rawValue).desc" }

    private var en: (title: String, desc: String) {
        switch self {
        case .checkin:    return ("Daily Challenge: Check In", "Log today's check-in.")
        case .injection:  return ("Daily Challenge: On Schedule", "Your injection is due — log it today.")
        case .note:       return ("Daily Challenge: Add a Note", "Add a note to any log today.")
        case .healthSync: return ("Daily Challenge: Sync Apple Health", "Check in so Apple Health can fill in today's data.")
        }
    }

    var title: String { gLoc(titleKey, en.title) }
    var questDescription: String { gLoc(descriptionKey, en.desc) }

    var englishStrings: [(key: String, value: String)] {
        [(titleKey, en.title), (descriptionKey, en.desc)]
    }
}

enum DailyChallenge {

    /// 64-bit FNV-1a over the UTF-8 bytes of `string`.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// Deterministic pick for a day: the same date + feasible set always yields
    /// the same challenge. `feasible` is used in canonical (allCases) order.
    static func pick(dayKey: String, feasible: Set<DailyChallengeKind>) -> DailyChallengeKind {
        let ordered = DailyChallengeKind.allCases.filter { feasible.contains($0) }
        guard !ordered.isEmpty else { return .checkin }
        return ordered[Int(fnv1a(dayKey) % UInt64(ordered.count))]
    }

    /// Which challenges make sense today, derived from the user's data.
    static func feasibleKinds(context: ModelContext, now: Date = .now) -> Set<DailyChallengeKind> {
        var kinds: Set<DailyChallengeKind> = [.checkin]
        let injections = (try? context.fetch(FetchDescriptor<SDInjection>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: #Predicate { $0.isActive && $0.isPrimary && !$0.isSampleData })
        protoDesc.fetchLimit = 1
        if let proto = try? context.fetch(protoDesc).first {
            let due = InjectionCycleService.nextInjectionDate(for: proto, injections: injections)
            if due <= now.endOfDay { kinds.insert(.injection) }
        }
        var pepDesc = FetchDescriptor<SDPeptideLog>(predicate: #Predicate { !$0.isSampleData })
        pepDesc.fetchLimit = 1
        let hasPeptides = ((try? context.fetchCount(pepDesc)) ?? 0) > 0
        if !injections.isEmpty || hasPeptides { kinds.insert(.note) }
        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        if checkins.contains(where: \.hasHealthKitData) { kinds.insert(.healthSync) }
        return kinds
    }

    /// Whether today's challenge of `kind` has been met, derived from rows.
    static func isMet(_ kind: DailyChallengeKind, context: ModelContext, now: Date = .now) -> Bool {
        let start = now.startOfDay
        let end = now.endOfDay
        switch kind {
        case .checkin, .healthSync:
            let pred = #Predicate<SDCheckin> { $0.date >= start && $0.date <= end && !$0.isSampleData }
            let today = (try? context.fetch(FetchDescriptor(predicate: pred))) ?? []
            return kind == .checkin ? !today.isEmpty : today.contains(where: \.hasHealthKitData)
        case .injection:
            let pred = #Predicate<SDInjection> { $0.injectedAt >= start && $0.injectedAt <= end && !$0.isSampleData }
            return ((try? context.fetchCount(FetchDescriptor(predicate: pred))) ?? 0) > 0
        case .note:
            func noted(_ s: String?) -> Bool { !(s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let c = #Predicate<SDCheckin> { $0.updatedAt >= start && !$0.isSampleData }
            let i = #Predicate<SDInjection> { $0.updatedAt >= start && !$0.isSampleData }
            let p = #Predicate<SDPeptideLog> { $0.updatedAt >= start && !$0.isSampleData }
            if ((try? context.fetch(FetchDescriptor(predicate: c))) ?? []).contains(where: { noted($0.notes) }) { return true }
            if ((try? context.fetch(FetchDescriptor(predicate: i))) ?? []).contains(where: { noted($0.notes) }) { return true }
            return ((try? context.fetch(FetchDescriptor(predicate: p))) ?? []).contains(where: { noted($0.notes) })
        }
    }
}
