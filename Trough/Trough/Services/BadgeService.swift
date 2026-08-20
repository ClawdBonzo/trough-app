import SwiftData
import Foundation

/// Initializes the full set of achievement badges for a user. Safe to call on every
/// app launch — only inserts badges that don't already exist.
enum BadgeService {

    private struct BadgeDef {
        let badgeID: String
        let name: String
        let description: String
        let iconEmoji: String
    }

    private static let allBadges: [BadgeDef] = [
        BadgeDef(badgeID: "testosterone_peak",
                 name: "Testosterone Peak",
                 description: "Achieve Protocol Score ≥ 80",
                 iconEmoji: "🧬"),
        BadgeDef(badgeID: "consistency_king",
                 name: "Consistency King",
                 description: "Maintain a 30-day check-in streak",
                 iconEmoji: "👑"),
        BadgeDef(badgeID: "bloodwork_master",
                 name: "Bloodwork Master",
                 description: "Log 10 bloodwork sessions",
                 iconEmoji: "📊"),
        BadgeDef(badgeID: "streak_flame_7",
                 name: "Flame Keeper",
                 description: "Reach a 7-day streak",
                 iconEmoji: "🔥"),
        BadgeDef(badgeID: "level_5",
                 name: "Rising Star",
                 description: "Reach Level 5",
                 iconEmoji: "⭐"),
        BadgeDef(badgeID: "level_10",
                 name: "Master Tier",
                 description: "Reach Level 10",
                 iconEmoji: "🏆"),
        BadgeDef(badgeID: "perfect_week",
                 name: "Perfect Week",
                 description: "Log 7 consecutive daily check-ins",
                 iconEmoji: "✅"),
        BadgeDef(badgeID: "supplement_adherence",
                 name: "Supplement Scholar",
                 description: "90%+ supplement compliance over 30 days",
                 iconEmoji: "💊"),
        BadgeDef(badgeID: "injection_precision",
                 name: "Precision Injector",
                 description: "No missed injections for 30 days",
                 iconEmoji: "💉"),
    ]

    /// Seeds all badge definitions for the user if not already present.
    static func seedIfNeeded(context: ModelContext, userID: UUID) {
        for def in allBadges {
            let defBadgeID = def.badgeID
            let pred = #Predicate<SDBadge> {
                $0.badgeID == defBadgeID && $0.userID == userID
            }
            var desc = FetchDescriptor<SDBadge>(predicate: pred)
            desc.fetchLimit = 1

            if (try? context.fetch(desc).first) == nil {
                let badge = SDBadge(
                    userID: userID,
                    badgeID: def.badgeID,
                    name: def.name,
                    badgeDescription: def.description,
                    iconEmoji: def.iconEmoji
                )
                context.insert(badge)
            }
        }
        try? context.save()
    }

    /// Checks for Protocol Score milestone badge.
    static func checkProtocolScoreBadge(score: Double, context: ModelContext, userID: UUID) {
        guard score >= 80 else { return }
        unlockIfNeeded("testosterone_peak", context: context, userID: userID)
    }

    /// Checks bloodwork count badge.
    static func checkBloodworkMasterBadge(context: ModelContext, userID: UUID) {
        let pred = #Predicate<SDBloodwork> { $0.userID == userID && !$0.isSampleData }
        let count = (try? context.fetch(FetchDescriptor<SDBloodwork>(predicate: pred)).count) ?? 0
        if count >= 10 {
            unlockIfNeeded("bloodwork_master", context: context, userID: userID)
        }
    }

    /// Checks the 30-day supplement adherence badge ("90%+ supplement compliance
    /// over 30 days"). Compliance is derived at read time from check-in rows:
    /// a day is compliant when its check-in logged at least one supplement, and
    /// 90% of 30 days = ≥27 compliant days in the trailing 30-day window.
    static func checkSupplementAdherenceBadge(context: ModelContext, userID: UUID) {
        let todayStart = Date().startOfDay
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: todayStart) else { return }
        let pred = #Predicate<SDCheckin> {
            $0.userID == userID && $0.date >= cutoff && !$0.isSampleData
        }
        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(predicate: pred))) ?? []
        let compliantDays = Set(
            checkins
                .filter { !($0.supplementsTaken ?? "").isEmpty }
                .map { $0.date.startOfDay }
        ).count
        if compliantDays >= 27 {
            unlockIfNeeded("supplement_adherence", context: context, userID: userID)
        }
    }

    /// Checks the injection precision badge ("No missed injections for 30 days").
    /// Derived at read time from injection dates: the user must have been injecting
    /// for ≥30 days, and within the trailing 30-day window no gap between
    /// consecutive injections (including window edges) may exceed the protocol
    /// frequency plus a 24h grace period.
    static func checkInjectionPrecisionBadge(context: ModelContext, userID: UUID, frequencyDays: Int) {
        guard frequencyDays > 0 else { return }
        let now = Date()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return }

        let pred = #Predicate<SDInjection> { $0.userID == userID && !$0.isSampleData }
        let all = (try? context.fetch(FetchDescriptor<SDInjection>(predicate: pred))) ?? []

        // Must have at least 30 days of injection history.
        guard let earliestEver = all.map(\.injectedAt).min(), earliestEver <= cutoff else { return }

        let window = all.map(\.injectedAt).filter { $0 >= cutoff }.sorted()
        guard let first = window.first, let last = window.last else { return }

        let maxGap = TimeInterval(frequencyDays) * 86_400 + 86_400 // frequency + 24h grace
        guard first.timeIntervalSince(cutoff) <= maxGap,
              now.timeIntervalSince(last) <= maxGap else { return }
        for (a, b) in zip(window, window.dropFirst()) where b.timeIntervalSince(a) > maxGap {
            return
        }

        unlockIfNeeded("injection_precision", context: context, userID: userID)
    }

    /// Unlocks a badge by ID if not already unlocked.
    static func unlockIfNeeded(_ badgeID: String, context: ModelContext, userID: UUID) {
        let pred = #Predicate<SDBadge> {
            $0.badgeID == badgeID && $0.userID == userID
        }
        var desc = FetchDescriptor<SDBadge>(predicate: pred)
        desc.fetchLimit = 1

        guard let badge = try? context.fetch(desc).first, badge.unlockedDate == nil else { return }
        badge.unlockedDate = Date()
        badge.updatedAt = Date()
        try? context.save()
    }
}
