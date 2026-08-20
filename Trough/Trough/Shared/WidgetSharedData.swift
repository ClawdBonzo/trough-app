import Foundation
import ActivityKit

// MARK: - Shared between the Trough app and the TroughWidget extension
// This file is a member of BOTH targets, so each compiles its own copy — no
// cross-module access is needed. Data is exchanged at runtime via an App Group.

enum TroughShared {
    /// App Group container shared by the app and the widget extension.
    static let appGroupID = "group.app.trough.shared"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    enum Key {
        static let streak             = "w_streak"
        static let level              = "w_level"
        static let levelName          = "w_levelName"
        static let levelProgress      = "w_levelProgress"
        static let xpToNext           = "w_xpToNext"
        static let checkedInToday     = "w_checkedInToday"
        static let daysUntilInjection = "w_daysUntilInjection"  // Int.min == none
        static let updatedAt          = "w_updatedAt"
        // Additive v1.2 keys. Never delete or rename existing keys — older
        // widget builds may still read them from the shared store.
        static let checkedInDate      = "w_checkedInDate"       // Date the check-in flag was written
        static let nextInjectionDate  = "w_nextInjectionDate"   // Date the next injection is due
    }
}

/// Plain snapshot the widget renders. Read/written through the App Group.
struct WidgetSnapshot {
    var streak: Int = 0
    var level: Int = 1
    var levelName: String = "Beginner"
    var levelProgress: Double = 0      // 0...1
    var xpToNext: Int = 0
    var checkedInToday: Bool = false
    var daysUntilInjection: Int? = nil // nil == no active protocol
    // Additive (v1.2): raw timestamps so date-sensitive fields can be resolved
    // at render time instead of trusting stored booleans/ints forever.
    var checkedInDate: Date? = nil     // when the check-in flag was written
    var nextInjectionDate: Date? = nil // when the next injection is due
    var updatedAt: Date? = nil         // last write of any snapshot field

    /// Stored values with the date-sensitive fields resolved for "now".
    /// Most callers want this.
    static func load() -> WidgetSnapshot {
        loadRaw().resolved(at: Date())
    }

    /// Reads the App Group store verbatim, with no date scoping applied.
    static func loadRaw() -> WidgetSnapshot {
        guard let d = TroughShared.defaults else { return WidgetSnapshot() }
        var s = WidgetSnapshot()
        s.streak            = d.integer(forKey: TroughShared.Key.streak)
        s.level             = max(1, d.integer(forKey: TroughShared.Key.level))
        s.levelName         = d.string(forKey: TroughShared.Key.levelName) ?? "Beginner"
        s.levelProgress     = d.double(forKey: TroughShared.Key.levelProgress)
        s.xpToNext          = d.integer(forKey: TroughShared.Key.xpToNext)
        s.checkedInToday    = d.bool(forKey: TroughShared.Key.checkedInToday)
        let days = d.object(forKey: TroughShared.Key.daysUntilInjection) as? Int
        s.daysUntilInjection = (days == nil || days == Int.min) ? nil : days
        s.checkedInDate     = d.object(forKey: TroughShared.Key.checkedInDate) as? Date
        s.nextInjectionDate = d.object(forKey: TroughShared.Key.nextInjectionDate) as? Date
        s.updatedAt         = d.object(forKey: TroughShared.Key.updatedAt) as? Date
        return s
    }

    /// Resolves the date-sensitive fields as of `date`:
    /// - `checkedInToday` counts only when the check-in was written on the same
    ///   calendar day (falls back to `updatedAt` for snapshots stored by
    ///   pre-1.2 app builds, which had no `checkedInDate`), so the checkmark
    ///   clears after midnight.
    /// - `daysUntilInjection` is derived from `nextInjectionDate` when present,
    ///   so the countdown ticks down between app launches. The stored Int is
    ///   kept as a fallback for snapshots written by older app builds.
    func resolved(at date: Date) -> WidgetSnapshot {
        var s = self
        let cal = Calendar.current
        if s.checkedInToday {
            let stamp = checkedInDate ?? updatedAt
            s.checkedInToday = stamp.map { cal.isDate($0, inSameDayAs: date) } ?? false
        }
        if let next = nextInjectionDate {
            let days = cal.dateComponents([.day],
                                          from: cal.startOfDay(for: date),
                                          to: cal.startOfDay(for: next)).day ?? 0
            s.daysUntilInjection = max(0, days)
        }
        return s
    }
}

// MARK: - Live Activity attributes (injection countdown)

struct InjectionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the next injection is due. Used for a live countdown.
        var nextInjectionDate: Date
        /// Short status line, e.g. "Due today" or "Right leg next".
        var statusLine: String
    }

    /// Compound being tracked, e.g. "Testosterone Cypionate".
    var compoundName: String
}
