import Foundation
import WidgetKit

/// Writes the small snapshot the home-screen widget renders into the shared App
/// Group, then asks WidgetKit to refresh. Called whenever the underlying data
/// (level/XP, streak, today's check-in, injection timing) changes.
enum WidgetBridge {

    static func updateGamification(streak: Int, level: Int, levelName: String,
                                   progress: Double, xpToNext: Int) {
        guard let d = TroughShared.defaults else { return }
        d.set(streak,    forKey: TroughShared.Key.streak)
        d.set(level,     forKey: TroughShared.Key.level)
        d.set(levelName, forKey: TroughShared.Key.levelName)
        d.set(progress,  forKey: TroughShared.Key.levelProgress)
        d.set(xpToNext,  forKey: TroughShared.Key.xpToNext)
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

    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
