import SwiftData
import Foundation

// MARK: - Supporting Types

struct QuestDisplayModel: Identifiable {
    let id: String
    let title: String
    let description: String
    let xpReward: Int
    let isCompleted: Bool
    let dueDate: Date
    let frequency: String // "daily" or "weekly"
}

struct BadgeDisplayModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let isUnlocked: Bool
    let unlockedDate: Date?
}

struct StreakDisplayModel {
    let currentCount: Int
    let bestCount: Int
    let streakType: String
    let flameLevel: Int // 0-5
}

enum CelebrationEvent {
    case levelUp(level: Int, levelName: String, totalXP: Int)
    case badgeUnlock(name: String, emoji: String)
    case streakMilestone(days: Int, type: String, xpGained: Int)
    case questCompleted(name: String, xpGained: Int)
}

// MARK: - GamificationViewModel

@MainActor
final class GamificationViewModel: ObservableObject {
    // Published UI state
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var levelName: String = "Beginner"
    @Published var levelProgressPercent: Double = 0.0 // 0-1 for progress bar
    @Published var xpUntilNextLevel: Int = 0
    @Published var activeQuests: [QuestDisplayModel] = []
    @Published var unlockedBadges: [BadgeDisplayModel] = []
    @Published var pendingCelebration: CelebrationEvent?
    @Published var showCelebration: Bool = false

    // Streak visual state
    @Published var streakStates: [String: StreakDisplayModel] = [:]
    @Published var allBadges: [BadgeDisplayModel] = []

    private var modelContext: ModelContext?
    private var userID: UUID?
    private var hapticManager: HapticManager?

    // XP thresholds for levels (cumulative) — canonical table lives on the model
    // so level is always derivable from XP (CLAUDE.md derive-at-read).
    private let xpPerLevel = SDGamificationState.xpThresholds

    private let levelNames = [
        1: "Beginner",
        2: "Rising",
        3: "Committed",
        4: "Dedicated",
        5: "Driven",
        6: "Focused",
        7: "Disciplined",
        8: "Advanced",
        9: "Expert",
        10: "Master",
        11: "Optimized Alpha"
    ]

    func setup(context: ModelContext, userID: UUID, hapticManager: HapticManager = .shared) {
        self.modelContext = context
        self.userID = userID
        self.hapticManager = hapticManager

        // Ensure today's/this week's quests and badge rows exist before loading.
        // MainTabView also seeds after calling setup — both calls are idempotent,
        // but seeding here first means the daily-login quest below can complete
        // on the first launch of a new day.
        QuestService.seedIfNeeded(context: context, userID: userID)
        BadgeService.seedIfNeeded(context: context, userID: userID)

        loadState()
        loadQuests()
        loadBadges()
        loadStreakState()

        // Daily-login quest: completes on the launch-time load (app open).
        completeQuest(QuestService.dailyLoginQuestID())
    }

    // MARK: - Core Methods: XP & Levels

    /// Award XP for an action (check-in, bloodwork, etc.)
    func awardXP(_ amount: Int, reason: String) {
        guard let ctx = modelContext, let uid = userID else { return }

        let oldLevel = currentLevel
        currentXP += amount
        let newLevel = levelFromXP(currentXP)

        if newLevel > oldLevel {
            currentLevel = newLevel
            levelName = levelNames[newLevel] ?? "Level \(newLevel)"
            triggerLevelUpCelebration(newLevel)
            hapticManager?.levelUp()
        } else {
            hapticManager?.xpEarned()
        }

        updateProgressBar()
        persistState()
    }

    /// Mark a quest as completed and award XP
    func completeQuest(_ questID: String) {
        guard let ctx = modelContext, let uid = userID else { return }

        let pred = #Predicate<SDQuest> {
            $0.questID == questID && !$0.isCompleted && $0.userID == uid
        }
        var desc = FetchDescriptor<SDQuest>(predicate: pred)

        guard let quest = try? ctx.fetch(desc).first else { return }

        quest.isCompleted = true
        quest.completedDate = Date()

        awardXP(quest.xpReward, reason: "quest_\(questID)")
        hapticManager?.questComplete()

        try? ctx.save()
        refreshQuests()
        checkBadgeUnlocks()
    }

    /// Update streak after successful check-in/injection/supplement
    func updateStreak(type: String) {
        guard let ctx = modelContext, let uid = userID else { return }

        let pred = #Predicate<SDStreakState> {
            $0.streakType == type && $0.userID == uid
        }
        var desc = FetchDescriptor<SDStreakState>(predicate: pred)
        var streak = (try? ctx.fetch(desc).first) ?? createNewStreak(type: type)

        let today = Date().startOfDay
        let lastDay = streak.lastCompletedDate?.startOfDay

        if lastDay == today {
            return // Already counted today
        } else if let lastDay = lastDay, Calendar.current.date(byAdding: .day, value: 1, to: lastDay) == today {
            // Streak continues
            streak.currentCount += 1
            updateFlameLevel(streak)
            awardStreakMilestoneXP(streak)
        } else {
            // Streak broken, reset
            streak.currentCount = 1
            streak.flameLevel = 1
        }

        streak.lastCompletedDate = today
        if streak.currentCount > streak.bestCount {
            streak.bestCount = streak.currentCount
        }

        try? ctx.save()

        // Weekly quest: check-in streak reached 7+ days.
        if type == "checkin", streak.currentCount >= 7 {
            completeQuest(QuestService.weeklyStreakQuestID())
        }

        loadStreakState()
        checkBadgeUnlocks()
    }

    // MARK: - Private Helpers: Level Calculations

    private func levelFromXP(_ xp: Int) -> Int {
        SDGamificationState.level(forXP: xp)
    }

    private func updateProgressBar() {
        let currentThreshold = xpPerLevel[min(currentLevel - 1, 10)]
        let nextThreshold = (currentLevel < 11) ? xpPerLevel[currentLevel] : xpPerLevel[10] + 1000
        let progress = Double(currentXP - currentThreshold) / Double(nextThreshold - currentThreshold)
        levelProgressPercent = min(max(progress, 0.0), 1.0)
        xpUntilNextLevel = max(0, nextThreshold - currentXP)
        syncWidget()
    }

    /// Pushes level / XP / streak to the home-screen widget.
    private func syncWidget() {
        let streak = streakStates["checkin"]?.currentCount ?? 0
        WidgetBridge.updateGamification(
            streak: streak,
            level: currentLevel,
            levelName: levelName,
            progress: levelProgressPercent,
            xpToNext: xpUntilNextLevel
        )
    }

    private func updateFlameLevel(_ streak: SDStreakState) {
        let flameLevels = [(1, 1), (3, 2), (7, 3), (14, 4), (30, 5)]
        var newFlame = 0
        for (threshold, level) in flameLevels.reversed() {
            if streak.currentCount >= threshold {
                newFlame = level
                break
            }
        }
        streak.flameLevel = newFlame
    }

    private func awardStreakMilestoneXP(_ streak: SDStreakState) {
        let milestones: [Int: Int] = [3: 15, 7: 25, 14: 50, 30: 100]
        if let xp = milestones[streak.currentCount] {
            awardXP(xp, reason: "streak_\(streak.streakType)_\(streak.currentCount)")
            hapticManager?.streakMilestone()
            triggerStreakMilestoneCelebration(streak, xpGained: xp)
        }
    }

    // MARK: - Celebration Triggers

    private func triggerLevelUpCelebration(_ newLevel: Int) {
        pendingCelebration = .levelUp(
            level: newLevel,
            levelName: levelNames[newLevel] ?? "Level \(newLevel)",
            totalXP: currentXP
        )
        showCelebration = true
    }

    private func triggerStreakMilestoneCelebration(_ streak: SDStreakState, xpGained: Int) {
        pendingCelebration = .streakMilestone(
            days: streak.currentCount,
            type: streak.streakType,
            xpGained: xpGained
        )
        showCelebration = true
    }

    // MARK: - Badge Management

    private func checkBadgeUnlocks() {
        guard let ctx = modelContext, let uid = userID else { return }

        // Check level-based badges
        let levelBadges: [(Int, String, String, String)] = [
            (5, "level_5", "Rising Star", "⭐"),
            (10, "level_10", "Master Tier", "🏆")
        ]

        for (levelThreshold, badgeID, name, emoji) in levelBadges {
            if currentLevel >= levelThreshold {
                unlockBadgeIfNotAlready(badgeID, name, emoji, context: ctx, userID: uid)
            }
        }

        // Streak-based badges — consecutive days derived from check-in dates
        // at read time (never trust a stored count).
        let streakDays = consecutiveCheckinDays(context: ctx, userID: uid)

        if streakDays >= 7 {
            unlockBadgeIfNotAlready("streak_flame_7", "Flame Keeper", "🔥", context: ctx, userID: uid)
            unlockBadgeIfNotAlready("perfect_week", "Perfect Week", "✅", context: ctx, userID: uid)
        }
        if streakDays >= 30 {
            unlockBadgeIfNotAlready("consistency_king", "Consistency King", "👑", context: ctx, userID: uid)
        }

        try? ctx.save()
        loadBadges()
        persistState() // refresh stored level/badge-count copies from derived values
    }

    /// Consecutive-day check-in streak ending today (or yesterday, when today's
    /// check-in hasn't happened yet) — derived from SDCheckin dates at read time.
    private func consecutiveCheckinDays(context: ModelContext, userID: UUID) -> Int {
        let pred = #Predicate<SDCheckin> {
            $0.userID == userID && !$0.isSampleData
        }
        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(predicate: pred))) ?? []
        let dates = Set(checkins.map { $0.date.startOfDay })

        var day = Date().startOfDay
        if !dates.contains(day) {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        while dates.contains(day) {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    private func unlockBadgeIfNotAlready(_ badgeID: String, _ name: String, _ emoji: String, context: ModelContext, userID: UUID) {
        let pred = #Predicate<SDBadge> {
            $0.badgeID == badgeID && $0.userID == userID
        }
        var desc = FetchDescriptor<SDBadge>(predicate: pred)

        guard let badge = try? context.fetch(desc).first, badge.unlockedDate == nil else {
            return // Already unlocked or doesn't exist
        }

        badge.unlockedDate = Date()
        badge.updatedAt = Date()

        hapticManager?.badgeUnlock()
        pendingCelebration = .badgeUnlock(name: name, emoji: emoji)
        showCelebration = true
        try? context.save()
    }

    // MARK: - Data Loading

    private func loadState() {
        guard let ctx = modelContext, let uid = userID else { return }

        let pred = #Predicate<SDGamificationState> { $0.userID == uid }
        var desc = FetchDescriptor<SDGamificationState>(predicate: pred)

        if let state = try? ctx.fetch(desc).first {
            currentXP = state.currentXP
            currentLevel = state.derivedLevel // derive from XP; never trust the stored copy
            levelName = levelNames[currentLevel] ?? "Beginner"
            updateProgressBar()
        } else {
            // Create new state for first-time user
            let newState = SDGamificationState(userID: uid)
            ctx.insert(newState)
            try? ctx.save()
        }
    }

    private func persistState() {
        guard let ctx = modelContext, let uid = userID else { return }

        let pred = #Predicate<SDGamificationState> { $0.userID == uid }
        var desc = FetchDescriptor<SDGamificationState>(predicate: pred)

        if let state = try? ctx.fetch(desc).first {
            state.currentXP = currentXP
            // Stored copies kept for widget/back-compat — written ONLY here,
            // always from derived values (CLAUDE.md derive-at-read).
            state.currentLevel = SDGamificationState.level(forXP: currentXP)
            state.totalBadgesUnlocked = unlockedBadgeCount()
            state.updatedAt = Date()
            try? ctx.save()
        }
    }

    /// Unlocked badge count derived from SDBadge rows at read time.
    private func unlockedBadgeCount() -> Int {
        guard let ctx = modelContext, let uid = userID else { return 0 }
        let pred = #Predicate<SDBadge> {
            $0.userID == uid && $0.unlockedDate != nil
        }
        return (try? ctx.fetchCount(FetchDescriptor<SDBadge>(predicate: pred))) ?? 0
    }

    private func loadQuests() {
        guard let ctx = modelContext, let uid = userID else { return }

        let today = Date().startOfDay
        let pred = #Predicate<SDQuest> {
            $0.userID == uid && $0.dueDate >= today
        }
        var desc = FetchDescriptor<SDQuest>(predicate: pred)
        desc.sortBy = [SortDescriptor(\SDQuest.frequency)]

        let quests = (try? ctx.fetch(desc)) ?? []
        activeQuests = quests.map { quest in
            QuestDisplayModel(
                id: quest.questID,
                title: quest.title,
                description: quest.questDescription,
                xpReward: quest.xpReward,
                isCompleted: quest.isCompleted,
                dueDate: quest.dueDate,
                frequency: quest.frequency
            )
        }
    }

    private func loadBadges() {
        guard let ctx = modelContext, let uid = userID else { return }

        let pred = #Predicate<SDBadge> { $0.userID == uid }
        var desc = FetchDescriptor<SDBadge>(predicate: pred)
        desc.sortBy = [SortDescriptor(\.unlockedDate, order: .reverse)]

        let badges = (try? ctx.fetch(desc)) ?? []
        allBadges = badges.map { badge in
            BadgeDisplayModel(
                id: badge.badgeID,
                name: badge.name,
                description: badge.badgeDescription,
                emoji: badge.iconEmoji,
                isUnlocked: badge.unlockedDate != nil,
                unlockedDate: badge.unlockedDate
            )
        }

        unlockedBadges = allBadges.filter { $0.isUnlocked }
    }

    private func loadStreakState() {
        guard let ctx = modelContext, let uid = userID else { return }

        let pred = #Predicate<SDStreakState> { $0.userID == uid }
        var desc = FetchDescriptor<SDStreakState>(predicate: pred)

        let streaks = (try? ctx.fetch(desc)) ?? []
        streakStates = Dictionary(uniqueKeysWithValues: streaks.map { streak in
            (
                streak.streakType,
                StreakDisplayModel(
                    currentCount: streak.currentCount,
                    bestCount: streak.bestCount,
                    streakType: streak.streakType,
                    flameLevel: streak.flameLevel
                )
            )
        })
        syncWidget()
    }

    private func refreshQuests() {
        loadQuests()
    }

    private func createNewStreak(type: String) -> SDStreakState {
        let streak = SDStreakState(userID: userID ?? UUID(), streakType: type)
        modelContext?.insert(streak)
        return streak
    }
}
