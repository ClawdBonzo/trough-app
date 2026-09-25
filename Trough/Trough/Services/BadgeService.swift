import SwiftData
import Foundation

/// Seeds one SDBadge row per `GamificationCatalog.badges` definition. Safe to
/// call on every app launch — only inserts badges that don't already exist,
/// never renames/deletes rows (schema + id stability).
///
/// Unlocking is owned by `GamificationViewModel`, which evaluates every
/// definition against `GamificationFacts` after each save and routes ALL new
/// unlocks through the celebration queue (+25 XP each, idempotent). The legacy
/// `check…` entry points below are kept for source compatibility; they simply
/// ask the active GamificationViewModel to re-evaluate.
enum BadgeService {

    /// Seeds all catalog badge definitions for the user if not already present.
    static func seedIfNeeded(context: ModelContext, userID: UUID) {
        let pred = #Predicate<SDBadge> { $0.userID == userID }
        let existing = Set(((try? context.fetch(FetchDescriptor<SDBadge>(predicate: pred))) ?? []).map(\.badgeID))
        var inserted = false
        for def in GamificationCatalog.badges where !existing.contains(def.id) {
            context.insert(SDBadge(
                userID: userID,
                badgeID: def.id,
                name: def.title,
                badgeDescription: def.howTo,
                iconEmoji: def.legacyEmoji,
                xpRequired: def.metric == .level
                    ? SDGamificationState.xpThresholds[min(def.target, 11) - 1]
                    : nil
            ))
            inserted = true
        }
        if inserted { try? context.save() }
    }

    // MARK: - Legacy entry points (route through the celebration queue)

    @MainActor static func checkProtocolScoreBadge(score: Double, context: ModelContext, userID: UUID) {
        requestEvaluation()
    }

    @MainActor static func checkBloodworkMasterBadge(context: ModelContext, userID: UUID) {
        requestEvaluation()
    }

    @MainActor static func checkSupplementAdherenceBadge(context: ModelContext, userID: UUID) {
        requestEvaluation()
    }

    @MainActor static func checkInjectionPrecisionBadge(context: ModelContext, userID: UUID, frequencyDays: Int) {
        requestEvaluation()
    }

    /// Unlocks a badge by ID if not already unlocked, then asks the active
    /// GamificationViewModel to re-evaluate so the unlock is celebrated
    /// (queue + XP) instead of happening silently.
    @MainActor static func unlockIfNeeded(_ badgeID: String, context: ModelContext, userID: UUID) {
        let pred = #Predicate<SDBadge> {
            $0.badgeID == badgeID && $0.userID == userID
        }
        var desc = FetchDescriptor<SDBadge>(predicate: pred)
        desc.fetchLimit = 1

        guard let badge = try? context.fetch(desc).first, badge.unlockedDate == nil else { return }
        badge.unlockedDate = Date()
        badge.updatedAt = Date()
        try? context.save()
        requestEvaluation()
    }

    @MainActor private static func requestEvaluation() {
        GamificationViewModel.active?.refresh()
    }
}
