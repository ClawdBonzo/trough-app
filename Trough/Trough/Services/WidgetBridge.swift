import Foundation
import WidgetKit

/// Writes the small snapshot the home-screen widget renders into the shared App
/// Group, then asks WidgetKit to refresh. Called whenever the underlying data
/// (level/XP, streak, today's check-in, injection timing) changes.
enum WidgetBridge {

    /// True while the app runs on the seeded demo store (`-TRSeedDemo`, DEBUG only):
    /// demo data must never overwrite the real home-screen widget snapshot.
    static var isSuppressed: Bool {
        #if DEBUG
        return DemoMode.seedsDemo
        #else
        return false
        #endif
    }

    static func updateGamification(streak: Int, level: Int, levelName: String,
                                   progress: Double, xpToNext: Int) {
        guard !isSuppressed else { return }
        guard let d = TroughShared.defaults else { return }
        d.set(streak,    forKey: TroughShared.Key.streak)
        d.set(level,     forKey: TroughShared.Key.level)
        d.set(levelName, forKey: TroughShared.Key.levelName)
        d.set(progress,  forKey: TroughShared.Key.levelProgress)
        d.set(xpToNext,  forKey: TroughShared.Key.xpToNext)
        // Additive v1.4: rank cover for the widget's colour strip (derived from level).
        d.set(TR.RankCover.forLevel(level).rawValue, forKey: TroughShared.Key.rankCover)
        d.set(Date(),    forKey: TroughShared.Key.updatedAt)
        reload()
    }

    /// - Parameters:
    ///   - checkedInToday: whether today's check-in exists right now.
    ///   - daysUntilInjection: whole days until the next dose (nil == no active
    ///     protocol). Still written for back-compat with older widget builds.
    ///   - nextInjectionDate: exact due date, if the caller has it. When nil it
    ///     is derived from `daysUntilInjection` (start of today + N days) so the
    ///     widget can count down between app launches either way.
    static func updateDashboard(checkedInToday: Bool, daysUntilInjection: Int?,
                                nextInjectionDate: Date? = nil) {
        guard !isSuppressed else { return }
        guard let d = TroughShared.defaults else { return }
        d.set(checkedInToday, forKey: TroughShared.Key.checkedInToday)
        d.set(daysUntilInjection ?? Int.min, forKey: TroughShared.Key.daysUntilInjection)

        // Additive v1.2 fields (see WidgetSharedData.Key). Date-stamp the
        // check-in so the widget can scope it to the calendar day it was made.
        if checkedInToday {
            d.set(Date(), forKey: TroughShared.Key.checkedInDate)
        } else {
            d.removeObject(forKey: TroughShared.Key.checkedInDate)
        }
        let cal = Calendar.current
        let dueDate = nextInjectionDate ?? daysUntilInjection.flatMap {
            cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: Date()))
        }
        if let dueDate {
            d.set(dueDate, forKey: TroughShared.Key.nextInjectionDate)
        } else {
            d.removeObject(forKey: TroughShared.Key.nextInjectionDate)
        }

        d.set(Date(), forKey: TroughShared.Key.updatedAt)
        reload()
    }

    /// Additive v1.4: the badge the user is closest to, for the "Next badge"
    /// widget. Pass `name: nil` when every (non-secret) badge is earned — the
    /// widget then shows its "every badge earned" state. Titles only: never pass
    /// doses, compounds or lab values.
    /// - Parameters:
    ///   - name: localized badge title.
    ///   - symbol: SF Symbol name (`BadgeDef.symbol`).
    ///   - current: progress toward the target (already clamped to `target`).
    ///   - target: units needed to earn it.
    static func updateNextBadge(name: String?, symbol: String?, current: Int, target: Int) {
        guard !isSuppressed else { return }
        guard let d = TroughShared.defaults else { return }
        if let name, target > 0 {
            let clamped = min(max(current, 0), target)
            d.set(name, forKey: TroughShared.Key.nextBadgeName)
            d.set(symbol ?? "rosette", forKey: TroughShared.Key.nextBadgeSymbol)
            d.set(clamped, forKey: TroughShared.Key.nextBadgeCurrent)
            d.set(target, forKey: TroughShared.Key.nextBadgeTarget)
            d.set(target - clamped, forKey: TroughShared.Key.nextBadgeRemaining)
            d.set(Double(clamped) / Double(target), forKey: TroughShared.Key.nextBadgeProgress)
        } else {
            // Empty name == "every badge earned" (absent == not written yet).
            d.set("", forKey: TroughShared.Key.nextBadgeName)
            for key in [TroughShared.Key.nextBadgeSymbol,
                        TroughShared.Key.nextBadgeCurrent, TroughShared.Key.nextBadgeTarget,
                        TroughShared.Key.nextBadgeRemaining, TroughShared.Key.nextBadgeProgress] {
                d.removeObject(forKey: key)
            }
        }
        d.set(Date(), forKey: TroughShared.Key.updatedAt)
        reload()
    }

    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
