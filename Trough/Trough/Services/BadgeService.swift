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
