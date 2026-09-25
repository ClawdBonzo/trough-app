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
    /// Non-nil for today's daily challenge.
    var challenge: DailyChallengeKind? = nil
}

struct BadgeDisplayModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let isUnlocked: Bool
    let unlockedDate: Date?
}

/// Rich 1.4 badge state: catalog definition + read-time progress.
/// For locked secrets, show a mystery card (don't reveal `def.title/howTo`).
struct BadgeProgressModel: Identifiable {
    let def: BadgeDef
    let current: Int
    let target: Int
    let unlockedDate: Date?
    var id: String { def.id }
    var isUnlocked: Bool { unlockedDate != nil }
    var fraction: Double { target > 0 ? min(1, Double(current) / Double(target)) : 0 }
    var isHiddenSecret: Bool { def.isSecret && !isUnlocked }
}

struct StreakDisplayModel {
    let currentCount: Int
    let bestCount: Int
    let streakType: String
    let flameLevel: Int // 0-5
    /// "injection" streaks count on-schedule WEEKS; everything else counts days.
    var isWeekly: Bool { streakType == "injection" }
}

/// Pre-1.4 celebration payload, still consumed by LevelUpCelebrationView.
enum CelebrationEvent {
    case levelUp(level: Int, levelName: String, totalXP: Int)
    case badgeUnlock(name: String, emoji: String)
    case streakMilestone(days: Int, type: String, xpGained: Int)
    case questCompleted(name: String, xpGained: Int)
}

// MARK: - GamificationViewModel

@MainActor
final class GamificationViewModel: ObservableObject {

    /// The live instance (set in `setup`) so services/VMs without a view-injected
    /// reference (BadgeService, PeptidesViewModel) can route events here.
    static weak var active: GamificationViewModel?

    // MARK: Published UI state
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var levelName: String = GamificationCatalog.levelName(1)
    @Published var levelProgressPercent: Double = 0.0 // 0-1 for progress bar
    @Published var xpUntilNextLevel: Int = 0
    @Published var activeQuests: [QuestDisplayModel] = []
    @Published var unlockedBadges: [BadgeDisplayModel] = []
    @Published var allBadges: [BadgeDisplayModel] = []
    @Published var streakStates: [String: StreakDisplayModel] = [:]

    // 1.4 state
    @Published private(set) var badgeProgress: [BadgeProgressModel] = []
    @Published private(set) var persona: Persona?
    @Published private(set) var checkinStreakDays: Int = 0
    /// On-schedule injection weeks (current run).
    @Published private(set) var injectionStreakWeeks: Int = 0
    @Published private(set) var dailyChallenge: QuestDisplayModel?
    @Published private(set) var facts = GamificationFacts()

    // MARK: Celebration queue

    /// The full-screen celebration on screen now (head of the FIFO queue).
    @Published private(set) var currentCelebration: Celebration?
    /// Toast-level event (quest / daily challenge completed).
    @Published private(set) var pendingToast: Celebration?

    /// Drives `.fullScreenCover(isPresented:)`. Setting it to `false` from the
    /// view (legacy ContentView closure) dismisses the current celebration and
    /// advances the queue — same as `dismissCurrentCelebration()`.
    @Published var showCelebration: Bool = false {
        didSet {
            if oldValue, !showCelebration, !isUpdatingPresentation, currentCelebration != nil {
                dismissCurrentCelebration()
            }
        }
    }

    /// Legacy mirror of `currentCelebration` for LevelUpCelebrationView.
    /// Setting nil is ignored — the queue advances via `showCelebration=false`
    /// / `dismissCurrentCelebration()`, so a follow-up event isn't clobbered.
    var pendingCelebration: CelebrationEvent? {
        get { currentCelebration?.legacyEvent }
        set { /* read-only in 1.4; see doc comment */ }
    }

    /// Pending full-screen celebrations after `currentCelebration`.
    private(set) var celebrationQueue: [Celebration] = []
    private var toastQueue: [Celebration] = []
    private var isUpdatingPresentation = false

    /// Gap between back-to-back full-screen covers so SwiftUI can finish the
    /// dismissal before presenting the next one. 0 = synchronous (tests).
    var interCelebrationDelay: TimeInterval = 0.45
    /// Mirror quest toasts into ToastManager (the overlay already installed in
    /// ContentView). Set false once a dedicated `pendingToast` UI exists.
    var mirrorsToastsToToastManager = true
    /// Plan local engagement notifications (off in unit tests).
    var plansNotifications = true

    // MARK: Private

    private var modelContext: ModelContext?
    private var userID: UUID?
    private var hapticManager: HapticManager?
    private let defaults: UserDefaults
    private var ledger: XPLedger { XPLedger(defaults: defaults) }

    private let xpPerLevel = SDGamificationState.xpThresholds

    private enum Keys {
        static let celebratedBadges = "gamification.celebratedBadges"
    }

    // Batch state — everything that happens during one user action is
    // collected, then flushed as one ordered celebration sequence.
    private var batchDepth = 0
    private var batchStartLevel = 1
    private var batchStreakMilestone: (days: Int, xp: Int)?
    private var batchXPGained = 0
    private var isCommitting = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func setup(context: ModelContext, userID: UUID, hapticManager: HapticManager = .shared) {
        self.modelContext = context
        self.userID = userID
        self.hapticManager = hapticManager
        Self.active = self
        ReviewPromptService.shared.unlockedBadgeCountProvider = { [weak self] in
            self?.unlockedBadgeCount() ?? 0
        }

        QuestService.seedIfNeeded(context: context, userID: userID)
        BadgeService.seedIfNeeded(context: context, userID: userID)

        loadState()
        migrateCelebratedBadgesIfNeeded()

        performBatch {
            // Daily-login quest: completes on the launch-time load (app open).
            completeQuest(QuestService.dailyLoginQuestID())
            recomputeInjectionStreakRow()
        }
        replanNotifications()
    }

    // MARK: - Public hooks (call after the save succeeded)

    /// Re-evaluates badges, challenge and derived state (app foreground,
    /// Apple Health autofill, silent unlocks).
    func refresh() {
        // Re-seed first so an app left resident across midnight gets today's
        // quests and daily challenge (idempotent).
        if let ctx = modelContext, let uid = userID {
            QuestService.seedIfNeeded(context: ctx, userID: uid)
        }
        performBatch {}
        replanNotifications()
    }

    func didSaveCheckin(_ checkin: SDCheckin, isNew: Bool) {
        performBatch {
            if isNew {
                grantXP(key: "checkin:\(XPLedger.dayKey(checkin.date))", amount: 20, cap: .checkin)
            }
            updateStreak(type: "checkin")
            completeQuest(QuestService.dailyCheckinQuestID())
        }
        replanNotifications()
    }

    func didSaveInjection(_ injection: SDInjection, isNew: Bool, onSchedule: Bool) {
        performBatch {
            if isNew {
                grantXP(key: "injection:\(injection.id.uuidString)", amount: 15)
            }
            updateStreak(type: "injection")
            if onSchedule {
                completeQuest(QuestService.weeklyInjectionQuestID())
            }
        }
        replanNotifications()
    }

    func didSaveBloodwork(_ bloodwork: SDBloodwork, isNew: Bool) {
        performBatch {
            if isNew {
                grantXP(key: "bloodwork:\(bloodwork.id.uuidString)", amount: 30)
                completeQuest(QuestService.weeklyBloodworkQuestID())
            }
        }
    }

    func didSavePeptideLog(_ log: SDPeptideLog, isNew: Bool) {
        performBatch {
            if isNew {
                grantXP(key: "peptide:\(log.id.uuidString)", amount: 5, cap: .peptide)
            }
        }
    }

    /// Groups several hooks into one celebration sequence. Nested calls are
    /// fine — celebrations flush when the outermost batch ends.
    func performBatch(_ body: () -> Void) {
        let isOuter = batchDepth == 0 && !isCommitting
        if isOuter {
            batchStartLevel = SDGamificationState.level(forXP: currentXP)
            batchStreakMilestone = nil
            batchXPGained = 0
        }
        batchDepth += 1
        body()
        batchDepth -= 1
        if isOuter { commitBatch() }
    }

    // MARK: - Celebration queue API

    /// Dismisses the celebration on screen and advances the FIFO queue. When a
    /// full-screen celebration closes and nothing is left, this is the review
    /// prompt's moment (ReviewPromptService applies its own gates).
    func dismissCurrentCelebration() {
        guard let finished = currentCelebration else { return }
        setPresentation(nil, show: false)
        if celebrationQueue.isEmpty {
            if finished.isFullScreen {
                ReviewPromptService.shared.celebrationSequenceDidFinish(unlockedBadgeCount: unlockedBadgeCount())
            }
            return
        }
        if interCelebrationDelay <= 0 {
            presentNextIfIdle()
        } else {
            let delay = UInt64(interCelebrationDelay * 1_000_000_000)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: delay)
                self?.presentNextIfIdle()
            }
        }
    }

    func dismissToast() {
        pendingToast = toastQueue.isEmpty ? nil : toastQueue.removeFirst()
    }

    private func enqueue(_ items: [Celebration]) {
        for item in items {
            if item.isFullScreen {
                celebrationQueue.append(item)
            } else if pendingToast == nil {
                pendingToast = item
                mirrorToast(item)
            } else {
                toastQueue.append(item)
                mirrorToast(item)
            }
        }
        presentNextIfIdle()
    }

    private func presentNextIfIdle() {
        guard currentCelebration == nil, !celebrationQueue.isEmpty else { return }
        let next = celebrationQueue.removeFirst()
        setPresentation(next, show: true)
        switch next {
        case .badge:   hapticManager?.badgeUnlock()
        case .levelUp: hapticManager?.levelUp()
        case .streak:  hapticManager?.streakMilestone()
        case .questCompleted: break
        }
    }

    private func setPresentation(_ celebration: Celebration?, show: Bool) {
        isUpdatingPresentation = true
        currentCelebration = celebration
        showCelebration = show
        isUpdatingPresentation = false
    }

    private func mirrorToast(_ item: Celebration) {
        guard mirrorsToastsToToastManager, case .questCompleted(let title, let xp) = item else { return }
        ToastManager.shared.show("\(title) · +\(xp) XP", type: .success, autoDismiss: 3)
    }

    // MARK: - XP

    /// Legacy un-keyed award. Prefer the `didSave…` hooks (keyed/idempotent).
    func awardXP(_ amount: Int, reason: String) {
        performBatch { addXP(amount) }
    }

    /// Idempotent award: `key` is paid at most once, ever.
    @discardableResult
    func grantXP(key: String, amount: Int, cap: XPLedger.DailyCap? = nil) -> Int {
        let granted = ledger.claim(key: key, amount: amount, cap: cap)
        if granted > 0 { performBatch { addXP(granted) } }
        return granted
    }

    private func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        currentXP += amount
        batchXPGained += amount
    }

    // MARK: - Quests

    /// Marks a quest completed and awards its XP (once — keyed by questID).
    func completeQuest(_ questID: String) {
        guard let ctx = modelContext, let uid = userID else { return }
        let pred = #Predicate<SDQuest> {
            $0.questID == questID && !$0.isCompleted && $0.userID == uid
        }
        guard let quest = try? ctx.fetch(FetchDescriptor<SDQuest>(predicate: pred)).first else { return }
        finishQuest(quest)
    }

    private func finishQuest(_ quest: SDQuest) {
        guard let ctx = modelContext else { return }
        quest.isCompleted = true
        quest.completedDate = Date()
        quest.updatedAt = Date()
        try? ctx.save()
        performBatch {
            let xp = ledger.claim(key: "quest:\(quest.questID)", amount: quest.xpReward)
            addXP(xp)
            hapticManager?.questComplete()
            // Daily login / insights are routine — no toast for those.
            if quest.frequency == "weekly" || DailyChallengeKind(questType: quest.questType) != nil {
                enqueue([.questCompleted(title: quest.localizedTitle, xp: xp)])
            }
        }
    }

    private func checkDailyChallenge() {
        guard let ctx = modelContext, let uid = userID else { return }
        let questID = QuestService.dailyChallengeQuestID()
        let pred = #Predicate<SDQuest> { $0.questID == questID && !$0.isCompleted && $0.userID == uid }
        guard let quest = try? ctx.fetch(FetchDescriptor<SDQuest>(predicate: pred)).first,
              let kind = DailyChallengeKind(questType: quest.questType),
              DailyChallenge.isMet(kind, context: ctx) else { return }
        finishQuest(quest)
    }

    // MARK: - Streaks

    /// Updates a streak after a successful save. Check-in streaks count days;
    /// injection streaks count on-schedule ISO weeks (derived from SDInjection).
    func updateStreak(type: String) {
        performBatch { updateStreakInBatch(type: type) }
    }

    private func updateStreakInBatch(type: String) {
        guard let ctx = modelContext, let uid = userID else { return }
        if type == "injection" {
            recomputeInjectionStreakRow()
            return
        }

        let streak = fetchOrCreateStreak(type: type, context: ctx, userID: uid)
        let today = Date().startOfDay
        let lastDay = streak.lastCompletedDate?.startOfDay

        if lastDay == today {
            return // Already counted today
        } else if let lastDay, Calendar.current.date(byAdding: .day, value: 1, to: lastDay) == today {
            streak.currentCount += 1
            streak.flameLevel = Self.flameLevel(forDays: streak.currentCount)
            handleStreakMilestone(streak, today: today)
        } else {
            streak.currentCount = 1
            streak.flameLevel = 1
        }

        streak.lastCompletedDate = today
        streak.bestCount = max(streak.bestCount, streak.currentCount)
        streak.updatedAt = Date()
        try? ctx.save()

        if type == "checkin", streak.currentCount >= 7 {
            completeQuest(QuestService.weeklyStreakQuestID())
        }
        loadStreakState()
    }

    private func handleStreakMilestone(_ streak: SDStreakState, today: Date) {
        guard streak.streakType == "checkin" else { return }
        let n = streak.currentCount
        let start = Calendar.current.date(byAdding: .day, value: -(n - 1), to: today) ?? today
        var xp = 0
        if let bonus = StreakMilestones.xp[n] {
            xp = ledger.claim(key: "streak:checkin:\(n):\(XPLedger.dayKey(start))", amount: bonus)
            performBatch { addXP(xp) }
        }
        if StreakMilestones.celebrated.contains(n) {
            batchStreakMilestone = (n, xp)
        }
    }

    /// Injection streak = on-schedule weeks, derived from SDInjection at read
    /// time; the SDStreakState row is refreshed for widget/back-compat.
    private func recomputeInjectionStreakRow() {
        guard let ctx = modelContext, let uid = userID else { return }
        let f = GamificationFacts.compute(context: ctx, level: currentLevel)
        guard f.injections > 0 else { return }
        let row = fetchOrCreateStreak(type: "injection", context: ctx, userID: uid)
        row.currentCount = f.currentOnScheduleWeeks
        row.bestCount = max(row.bestCount, f.longestOnScheduleWeeks, f.currentOnScheduleWeeks)
        row.flameLevel = Self.flameLevel(forWeeks: f.currentOnScheduleWeeks)
        row.lastCompletedDate = Date().startOfDay
        row.updatedAt = Date()
        try? ctx.save()
    }

    static func flameLevel(forDays days: Int) -> Int {
        [(30, 5), (14, 4), (7, 3), (3, 2), (1, 1)].first { days >= $0.0 }?.1 ?? 0
    }

    static func flameLevel(forWeeks weeks: Int) -> Int {
        [(12, 5), (8, 4), (4, 3), (2, 2), (1, 1)].first { weeks >= $0.0 }?.1 ?? 0
    }

    private func fetchOrCreateStreak(type: String, context: ModelContext, userID: UUID) -> SDStreakState {
        let pred = #Predicate<SDStreakState> { $0.streakType == type && $0.userID == userID }
        if let existing = try? context.fetch(FetchDescriptor<SDStreakState>(predicate: pred)).first {
            return existing
        }
        let streak = SDStreakState(userID: userID, streakType: type)
        context.insert(streak)
        return streak
    }

    // MARK: - Commit: badges → level-up → streak

    private func commitBatch() {
        guard let ctx = modelContext, let uid = userID else { return }
        isCommitting = true
        defer { isCommitting = false }

        checkDailyChallenge()

        // Evaluate badges; badge XP can raise the level, which can unlock
        // level badges — iterate to a fixed point (bounded).
        var celebrated = Set(defaults.stringArray(forKey: Keys.celebratedBadges) ?? [])
        var newBadges: [BadgeDef] = []
        let rows = (try? ctx.fetch(FetchDescriptor<SDBadge>(predicate: #Predicate { $0.userID == uid }))) ?? []
        let rowsByID = Dictionary(rows.map { ($0.badgeID, $0) }, uniquingKeysWith: { a, _ in a })
        var latestFacts = facts
        for _ in 0..<4 {
            latestFacts = GamificationFacts.compute(context: ctx, level: SDGamificationState.level(forXP: currentXP))
            var fresh: [BadgeDef] = []
            for def in GamificationCatalog.badges {
                guard let row = rowsByID[def.id] else { continue }
                if row.unlockedDate == nil, def.isEarned(latestFacts) {
                    row.unlockedDate = Date()
                    row.updatedAt = Date()
                }
                // Any unlocked-but-uncelebrated row counts — including unlocks
                // made silently elsewhere (BadgeService.unlockIfNeeded).
                if row.unlockedDate != nil, !celebrated.contains(def.id) {
                    fresh.append(def)
                }
            }
            if fresh.isEmpty { break }
            for def in fresh {
                celebrated.insert(def.id)
                addXP(ledger.claim(key: "badge:\(def.id)", amount: GamificationCatalog.badgeUnlockXP))
            }
            newBadges += fresh
        }
        defaults.set(Array(celebrated), forKey: Keys.celebratedBadges)
        try? ctx.save()

        // Level
        let newLevel = SDGamificationState.level(forXP: currentXP)
        let leveledUp = newLevel > batchStartLevel
        currentLevel = newLevel
        levelName = GamificationCatalog.levelName(newLevel)
        if batchXPGained > 0, !leveledUp, newBadges.isEmpty { hapticManager?.xpEarned() }

        enqueue(Celebration.sequence(
            newBadges: newBadges,
            levelUp: leveledUp ? (level: newLevel, totalXP: currentXP) : nil,
            streak: batchStreakMilestone
        ))
        batchStreakMilestone = nil
        batchXPGained = 0

        facts = latestFacts
        persona = Persona.derive(latestFacts)
        checkinStreakDays = latestFacts.currentCheckinStreak
        injectionStreakWeeks = latestFacts.currentOnScheduleWeeks

        persistState()
        updateProgressBar()
        loadQuests()
        loadBadges(rows: rows)
        loadStreakState()
    }

    /// First 1.4 launch: badges unlocked by older builds are treated as
    /// already celebrated (and already paid) so upgraders don't get a replay.
    private func migrateCelebratedBadgesIfNeeded() {
        guard defaults.object(forKey: Keys.celebratedBadges) == nil,
              let ctx = modelContext, let uid = userID else { return }
        let pred = #Predicate<SDBadge> { $0.userID == uid && $0.unlockedDate != nil }
        let ids = ((try? ctx.fetch(FetchDescriptor<SDBadge>(predicate: pred))) ?? []).map(\.badgeID)
        defaults.set(ids, forKey: Keys.celebratedBadges)
        ledger.markAwarded(ids.map { "badge:\($0)" })
    }

    // MARK: - Level math

    private func updateProgressBar() {
        let currentThreshold = xpPerLevel[min(currentLevel - 1, 10)]
        let nextThreshold = (currentLevel < 11) ? xpPerLevel[currentLevel] : xpPerLevel[10] + 1000
        let progress = Double(currentXP - currentThreshold) / Double(nextThreshold - currentThreshold)
        levelProgressPercent = min(max(progress, 0.0), 1.0)
        xpUntilNextLevel = max(0, nextThreshold - currentXP)
        syncWidget()
    }

    private func syncWidget() {
        WidgetBridge.updateGamification(
            streak: checkinStreakDays,
            level: currentLevel,
            levelName: levelName,
            progress: levelProgressPercent,
            xpToNext: xpUntilNextLevel
        )
    }

    // MARK: - Persistence / loading

    private func loadState() {
        guard let ctx = modelContext, let uid = userID else { return }
        let pred = #Predicate<SDGamificationState> { $0.userID == uid }
        if let state = try? ctx.fetch(FetchDescriptor<SDGamificationState>(predicate: pred)).first {
            currentXP = state.currentXP
            currentLevel = state.derivedLevel // derive from XP; never trust the stored copy
            levelName = GamificationCatalog.levelName(currentLevel)
            updateProgressBar()
        } else {
            ctx.insert(SDGamificationState(userID: uid))
            try? ctx.save()
        }
    }

    private func persistState() {
        guard let ctx = modelContext, let uid = userID else { return }
        let pred = #Predicate<SDGamificationState> { $0.userID == uid }
        if let state = try? ctx.fetch(FetchDescriptor<SDGamificationState>(predicate: pred)).first {
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
    func unlockedBadgeCount() -> Int {
        guard let ctx = modelContext, let uid = userID else { return 0 }
        let pred = #Predicate<SDBadge> { $0.userID == uid && $0.unlockedDate != nil }
        return (try? ctx.fetchCount(FetchDescriptor<SDBadge>(predicate: pred))) ?? 0
    }

    private func loadQuests() {
        guard let ctx = modelContext, let uid = userID else { return }
        let today = Date().startOfDay
        let pred = #Predicate<SDQuest> { $0.userID == uid && $0.dueDate >= today }
        var desc = FetchDescriptor<SDQuest>(predicate: pred)
        desc.sortBy = [SortDescriptor(\SDQuest.frequency)]
        let quests = (try? ctx.fetch(desc)) ?? []
        activeQuests = quests.map { quest in
            QuestDisplayModel(
                id: quest.questID,
                title: quest.localizedTitle,
                description: quest.localizedDescription,
                xpReward: quest.xpReward,
                isCompleted: quest.isCompleted,
                dueDate: quest.dueDate,
                frequency: quest.frequency,
                challenge: DailyChallengeKind(questType: quest.questType)
            )
        }
        dailyChallenge = activeQuests.first { $0.challenge != nil }
    }

    private func loadBadges(rows: [SDBadge]) {
        let rowsByID = Dictionary(rows.map { ($0.badgeID, $0) }, uniquingKeysWith: { a, _ in a })
        badgeProgress = GamificationCatalog.badges.map { def in
            let p = def.progress(facts)
            return BadgeProgressModel(def: def, current: p.current, target: p.target,
                                      unlockedDate: rowsByID[def.id]?.unlockedDate)
        }

        // "Next badge" widget: the nearest non-secret locked badge (highest
        // fraction, then fewest units left, then least prestigious).
        let next = badgeProgress
            .filter { !$0.isUnlocked && !$0.def.isSecret }
            .min { (-$0.fraction, $0.target - $0.current, $0.def.prestige)
                 < (-$1.fraction, $1.target - $1.current, $1.def.prestige) }
        WidgetBridge.updateNextBadge(name: next?.def.title, symbol: next?.def.symbol,
                                     current: next?.current ?? 0, target: next?.target ?? 0)

        // Legacy list: unlocked newest-first, then locked by closest progress
        // (so "next badge to unlock" = the nearest one). Locked secrets are masked.
        let unlocked = badgeProgress.filter(\.isUnlocked)
            .sorted { ($0.unlockedDate ?? .distantPast) > ($1.unlockedDate ?? .distantPast) }
        let locked = badgeProgress.filter { !$0.isUnlocked }
            .sorted { ($0.isHiddenSecret ? 1 : 0, -$0.fraction, $0.def.prestige) < ($1.isHiddenSecret ? 1 : 0, -$1.fraction, $1.def.prestige) }
        allBadges = (unlocked + locked).map { m in
            BadgeDisplayModel(
                id: m.def.id,
                name: m.isHiddenSecret ? gLoc("badge.secret.title", "Secret Badge") : m.def.title,
                description: m.isHiddenSecret ? gLoc("badge.secret.how", "Keep logging to discover it.") : m.def.howTo,
                emoji: m.isHiddenSecret ? "❔" : m.def.legacyEmoji,
                isUnlocked: m.isUnlocked,
                unlockedDate: m.unlockedDate
            )
        }
        unlockedBadges = allBadges.filter(\.isUnlocked)
    }

    private func loadStreakState() {
        guard let ctx = modelContext, let uid = userID else { return }
        let pred = #Predicate<SDStreakState> { $0.userID == uid }
        let streaks = (try? ctx.fetch(FetchDescriptor<SDStreakState>(predicate: pred))) ?? []
        var map: [String: StreakDisplayModel] = [:]
        for s in streaks where map[s.streakType] == nil {
            // Current counts are derived at read time where we can: a stored
            // check-in count goes stale the moment a day is missed.
            let current: Int
            switch s.streakType {
            case "checkin":   current = facts.checkins > 0 ? checkinStreakDays : s.currentCount
            case "injection": current = facts.injections > 0 ? injectionStreakWeeks : s.currentCount
            default:          current = s.currentCount
            }
            map[s.streakType] = StreakDisplayModel(
                currentCount: current,
                bestCount: max(s.bestCount, current),
                streakType: s.streakType,
                flameLevel: s.streakType == "injection"
                    ? Self.flameLevel(forWeeks: current)
                    : Self.flameLevel(forDays: current)
            )
        }
        streakStates = map
        syncWidget()
    }

    private func replanNotifications() {
        guard plansNotifications, let ctx = modelContext else { return }
        Task { @MainActor in await EngagementNotifications.replan(context: ctx) }
    }
}
