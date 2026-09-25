import SwiftUI

/// Pre-1.4 API, kept compiling for any remaining call sites: maps the legacy
/// `CelebrationEvent` onto the 1.4 `Celebration` and shows `CelebrationView`.
/// (The review prompt now fires from `GamificationViewModel.dismissCurrentCelebration()`.)
struct LevelUpCelebrationView: View {
    let event: CelebrationEvent
    let onDismiss: () -> Void

    var body: some View {
        CelebrationView(celebration: Self.celebration(for: event), onDone: onDismiss)
    }

    static func celebration(for event: CelebrationEvent) -> Celebration {
        switch event {
        case .levelUp(let level, let name, let totalXP):
            return .levelUp(level: level, name: name, totalXP: totalXP)
        case .badgeUnlock(let name, _):
            if let def = GamificationCatalog.badges.first(where: { $0.title == name }) {
                return .badge(def, alsoEarned: 0, xp: GamificationCatalog.badgeUnlockXP)
            }
            return .questCompleted(title: name, xp: 0)
        case .streakMilestone(let days, _, let xp):
            return .streak(days: days, xp: xp)
        case .questCompleted(let name, let xp):
            return .questCompleted(title: name, xp: xp)
        }
    }
}

#if DEBUG
#Preview {
    LevelUpCelebrationView(event: .levelUp(level: 5, levelName: "Driven", totalXP: 360)) {}
}
#endif
