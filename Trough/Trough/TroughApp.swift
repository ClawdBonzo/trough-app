import SwiftUI
import SwiftData

// RevenueCat API key loaded from Secrets.
// TestFlight = sandbox environment = MUST use production key (NOT test key).
// RevenueCat production keys work in BOTH sandbox and production.
// The test_ key is ONLY for StoreKit Testing in Xcode (local simulator).
//
// The previous crash was RevenueCat's internal assertion
// (checkForSimulatedStoreAPIKeyInRelease) which fires when using a
// test_ key in a Release build. Using the production key fixes this.
private var rcAPIKey: String {
    #if DEBUG
    // Debug builds: use test key for Xcode StoreKit Testing
    return Secrets.revenueCatTestKey
    #else
    // Release builds (TestFlight + App Store): ALWAYS production key
    return Secrets.revenueCatAPIKey
    #endif
}

// MARK: - ModelContainer tier

/// Which tier of the three-tier ModelContainer fallback actually succeeded.
enum ModelContainerTier {
    case primary       // normal store with migration plan
    case noMigration   // store opened without the migration plan
    case inMemory      // last resort — nothing persists across launches
}

@main
struct TroughApp: App {
    let container: ModelContainer
    let containerTier: ModelContainerTier
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var toastManager = ToastManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Attempt to create the ModelContainer. If schema/migration fails,
        // fall back to a fresh store (delete corrupted DB) rather than crashing.
        let schema = Schema(TroughSchemaV1.models)
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: TroughMigrationPlan.self
            )
            containerTier = .primary
        } catch {
            // Log the error for diagnostics
            print("[TroughApp] ModelContainer failed: \(error). Recreating store.")
            // Attempt without migration as a recovery path
            do {
                container = try ModelContainer(for: schema)
                containerTier = .noMigration
            } catch {
                // Last resort: in-memory only so the app doesn't crash
                print("[TroughApp] Recovery failed: \(error). Using in-memory store.")
                container = try! ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                containerTier = .inMemory
            }
        }

        // Persist the user identity and adopt data orphaned under random
        // UUIDs (see UserIdentityService). Must run against the real store
        // before any view reads @AppStorage("userIDString"). Skip for the
        // in-memory tier so a transient failure can't stamp a canonical ID
        // derived from an empty store.
        if containerTier != .inMemory {
            UserIdentityService.adoptOrphanedDataIfNeeded(container: container)
        }

        let isTF = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        if isTF {
            print("[TroughApp] Running in TestFlight sandbox — production key + DangerousSettings enabled")
        }
        RevenueCatService.configure(apiKey: rcAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(subscriptionManager)
                .environmentObject(toastManager)
                .preferredColorScheme(.dark)
                .task { await subscriptionManager.refresh() }
                .modifier(StorageFallbackAlert(tier: containerTier))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await subscriptionManager.refresh() }
            }
        }
    }
}

// MARK: - Storage fallback alert

/// Surfaces a user-facing alert on launch when the ModelContainer fell back
/// to a recovery tier instead of the normal persistent store.
private struct StorageFallbackAlert: ViewModifier {
    let tier: ModelContainerTier
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onAppear { isPresented = tier != .primary }
            .alert(title, isPresented: $isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message)
            }
    }

    private var title: String {
        switch tier {
        case .primary:     return ""
        case .noMigration: return "Storage Warning"
        case .inMemory:    return "Data Cannot Be Saved"
        }
    }

    private var message: String {
        switch tier {
        case .primary:
            return ""
        case .noMigration:
            return "Your data was opened in recovery mode. Everything should look normal, but if anything seems missing, please contact support before making changes."
        case .inMemory:
            return "Trough couldn't access its storage, so nothing you enter this session will be saved. Try freeing up storage space and restarting the app. If this keeps happening, please contact support."
        }
    }
}

// MARK: - UserIdentityService

/// Repairs the "userIDString" identity bug: the key was declared via
/// `@AppStorage("userIDString") = UUID().uuidString` in several views but the
/// default was never written to UserDefaults, so every launch/view generated a
/// fresh UUID and gamification rows (state/quests/badges/streaks) accumulated
/// under random userIDs that could never be fetched again.
///
/// This runs a one-time adoption pass: it picks a canonical userID, merges the
/// orphaned rows into it, persists the ID under "userIDString", and is a no-op
/// on every launch after the key exists.
enum UserIdentityService {

    static let userIDKey = "userIDString"

    // XP thresholds and flame levels replicated from GamificationViewModel
    // (`xpPerLevel` / `updateFlameLevel`) — they are private there. Keep in sync.
    private static let xpPerLevel = [0, 50, 120, 220, 360, 550, 800, 1120, 1520, 2000, 2600]
    private static let flameLevels = [(1, 1), (3, 2), (7, 3), (14, 4), (30, 5)]

    /// Runs only while the defaults key is absent; idempotent afterwards.
    static func adoptOrphanedDataIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: userIDKey), !existing.isEmpty {
            return // Identity already persisted — nothing to adopt.
        }

        let context = ModelContext(container)
        context.autosaveEnabled = false

        // Canonical user = the gamification state with the most XP,
        // or a brand-new identity if none exist yet.
        let states = (try? context.fetch(FetchDescriptor<SDGamificationState>())) ?? []
        let canonical = states.max { $0.currentXP < $1.currentXP }
        let canonicalID = canonical?.userID ?? UUID()

        if let canonical {
            // Each orphaned state earned its session's XP independently
            // (every launch started from 0), so the true total is the sum.
            let totalXP = states.reduce(0) { $0 + $1.currentXP }
            canonical.currentXP = totalXP
            canonical.currentLevel = levelFromXP(totalXP)
            canonical.updatedAt = .now
            for state in states where state !== canonical {
                context.delete(state)
            }
        }

        let unlockedBadges = mergeBadges(into: canonicalID, context: context)
        canonical?.totalBadgesUnlocked = unlockedBadges
        rebuildStreaks(for: canonicalID, context: context)

        // Quests are per-period; they reseed for the canonical user on next
        // launch via QuestService.seedIfNeeded.
        try? context.delete(model: SDQuest.self)

        try? context.save()
        defaults.set(canonicalID.uuidString, forKey: userIDKey)
    }

    // MARK: Badges

    /// Keeps one row per badgeID (preferring the earliest unlocked one),
    /// reassigns it to the canonical user, and deletes the extras.
    /// Returns the number of unlocked badges kept.
    private static func mergeBadges(into canonicalID: UUID, context: ModelContext) -> Int {
        let badges = (try? context.fetch(FetchDescriptor<SDBadge>())) ?? []
        guard !badges.isEmpty else { return 0 }

        var unlockedCount = 0
        for (_, rows) in Dictionary(grouping: badges, by: \.badgeID) {
            let keeper = rows
                .filter { $0.unlockedDate != nil }
                .min { ($0.unlockedDate ?? .distantFuture) < ($1.unlockedDate ?? .distantFuture) }
                ?? rows[0]
            keeper.userID = canonicalID
            keeper.updatedAt = .now
            if keeper.unlockedDate != nil { unlockedCount += 1 }
            for row in rows where row !== keeper {
                context.delete(row)
            }
        }
        return unlockedCount
    }

    // MARK: Streaks

    /// Keeps one row per streakType under the canonical user. Check-in streaks
    /// are rebuilt from actual SDCheckin dates (each orphan row only ever saw
    /// one launch); injection/other streaks take the max across orphan rows.
    private static func rebuildStreaks(for canonicalID: UUID, context: ModelContext) {
        let streaks = (try? context.fetch(FetchDescriptor<SDStreakState>())) ?? []
        guard !streaks.isEmpty else { return }

        for (type, rows) in Dictionary(grouping: streaks, by: \.streakType) {
            let keeper = rows[0]
            keeper.userID = canonicalID
            for row in rows.dropFirst() {
                context.delete(row)
            }

            if type == "checkin" {
                let (current, best, last) = checkinStreakCounts(context: context)
                keeper.currentCount = current
                keeper.bestCount = best
                keeper.lastCompletedDate = last
            } else {
                keeper.currentCount = rows.map(\.currentCount).max() ?? 0
                keeper.bestCount = rows.map(\.bestCount).max() ?? 0
                keeper.lastCompletedDate = rows.compactMap(\.lastCompletedDate).max()
            }
            keeper.flameLevel = flameLevel(for: keeper.currentCount)
            keeper.updatedAt = .now
        }
    }

    /// Recomputes the check-in streak from real check-in dates:
    /// current = consecutive calendar days ending today or yesterday,
    /// best = longest run overall.
    private static func checkinStreakCounts(context: ModelContext) -> (current: Int, best: Int, last: Date?) {
        let pred = #Predicate<SDCheckin> { !$0.isSampleData }
        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(predicate: pred))) ?? []
        let cal = Calendar.current
        let days = Set(checkins.map { cal.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return (0, 0, nil) }

        var best = 1
        var run = 1
        for i in 1..<days.count {
            if cal.date(byAdding: .day, value: 1, to: days[i - 1]) == days[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }

        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        var current = 0
        if days.last == today || days.last == yesterday {
            current = 1
            var idx = days.count - 1
            while idx > 0, cal.date(byAdding: .day, value: 1, to: days[idx - 1]) == days[idx] {
                current += 1
                idx -= 1
            }
        }
        return (current, best, days.last)
    }

    // MARK: Level / flame helpers

    private static func levelFromXP(_ xp: Int) -> Int {
        var level = 1
        for i in 0..<xpPerLevel.count where xp >= xpPerLevel[i] {
            level = i + 1
        }
        return min(level, 11)
    }

    private static func flameLevel(for streakCount: Int) -> Int {
        var flame = 0
        for (threshold, level) in flameLevels where streakCount >= threshold {
            flame = level
        }
        return flame
    }
}
