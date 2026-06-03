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

    static func updateDashboard(checkedInToday: Bool, daysUntilInjection: Int?) {
        guard let d = TroughShared.defaults else { return }
        d.set(checkedInToday, forKey: TroughShared.Key.checkedInToday)
        d.set(daysUntilInjection ?? Int.min, forKey: TroughShared.Key.daysUntilInjection)
        d.set(Date(), forKey: TroughShared.Key.updatedAt)
        reload()
    }

    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
