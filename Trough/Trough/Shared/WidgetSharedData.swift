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

    static func load() -> WidgetSnapshot {
        guard let d = TroughShared.defaults else { return WidgetSnapshot() }
        var s = WidgetSnapshot()
        s.streak         = d.integer(forKey: TroughShared.Key.streak)
        s.level          = max(1, d.integer(forKey: TroughShared.Key.level))
        s.levelName      = d.string(forKey: TroughShared.Key.levelName) ?? "Beginner"
        s.levelProgress  = d.double(forKey: TroughShared.Key.levelProgress)
        s.xpToNext       = d.integer(forKey: TroughShared.Key.xpToNext)
        s.checkedInToday = d.bool(forKey: TroughShared.Key.checkedInToday)
        let days = d.object(forKey: TroughShared.Key.daysUntilInjection) as? Int
        s.daysUntilInjection = (days == nil || days == Int.min) ? nil : days
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
