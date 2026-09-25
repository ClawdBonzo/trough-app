import Foundation
import StoreKit
import UIKit

// MARK: - ReviewPromptService

/// Central throttle for App Store review prompts (1.4 rules).
///
/// The ONLY organic moment we ask is right after the user dismisses a
/// full-screen celebration and the celebration queue is empty
/// (`celebrationSequenceDidFinish(unlockedBadgeCount:)`). A first data export
/// (`requestIfAppropriate(trigger: "firstExport")`) also qualifies. Gates:
/// - ≥3 badges unlocked and ≥3 lifetime check-ins,
/// - at most 3 prompts in any rolling 365 days,
/// - after the first prompt, at least 120 days between prompts,
/// - never in a session where the paywall was shown,
/// - never with the `-TRScreenshotMode` launch argument.
/// Settings → "Rate Trough" uses `writeReviewURL` and is unaffected.
///
/// Everything is stored in UserDefaults — fully on-device, no tracking.
@MainActor
final class ReviewPromptService {
    static let shared = ReviewPromptService()

    /// Set by PaywallView when it appears; suppresses prompts for the rest of
    /// the session (in-memory only — resets on relaunch).
    static var paywallShownThisSession = false

    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-TRScreenshotMode")
    }

    /// Deep link to the App Store "Write a Review" sheet for Trough.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id6760955550?action=write-review")!
    }

    // MARK: Keys

    private enum Keys {
        static let lastPromptDate     = "reviewPrompt.lastPromptDate"
        static let consumedTriggers   = "reviewPrompt.consumedTriggers"
        static let promptTimestamps   = "reviewPrompt.promptTimestamps"
        static let checkinCount       = "reviewPrompt.lifetimeCheckinCount"
        /// Legacy one-shot flag from the pre-1.3.0 prompt logic.
        static let legacyHasPrompted  = "hasPromptedReview"
    }

    // MARK: Tuning

    static let minDaysBetweenPrompts: TimeInterval = 120 * 24 * 60 * 60
    static let rollingWindow: TimeInterval = 365 * 24 * 60 * 60
    static let maxPromptsPerWindow = 3
    static let minLifetimeCheckins = 3
    static let minUnlockedBadges = 3
    /// Legacy triggers that still qualify (once per install each).
    static let legacyQualifyingTriggers: Set<String> = ["firstExport"]
    /// Delay so the prompt appears after celebratory UI has settled.
    private let promptDelayNanoseconds: UInt64 = 1_500_000_000

    private let defaults = UserDefaults.standard

    private init() {
        migrateLegacyFlagIfNeeded()
    }

    /// Users who were already prompted by the old one-shot logic get
    /// `lastPromptDate` seeded to now so they aren't immediately re-prompted.
    private func migrateLegacyFlagIfNeeded() {
        guard defaults.bool(forKey: Keys.legacyHasPrompted) else { return }
        if defaults.object(forKey: Keys.lastPromptDate) == nil {
            defaults.set(Date(), forKey: Keys.lastPromptDate)
            defaults.set([Date()], forKey: Keys.promptTimestamps)
        }
        defaults.removeObject(forKey: Keys.legacyHasPrompted)
    }

    // MARK: - Lifetime check-in counter

    /// True until the counter has been seeded (existing users get it seeded
    /// from a SwiftData fetch count on their next check-in save).
    var needsCheckinCountSeed: Bool {
        defaults.object(forKey: Keys.checkinCount) == nil
    }

    var lifetimeCheckinCount: Int {
        defaults.integer(forKey: Keys.checkinCount)
    }

    /// Seeds the counter with an absolute count (e.g. a SwiftData fetch count),
    /// so long-time users aren't treated as brand-new installs.
    func seedLifetimeCheckinCount(_ count: Int) {
        defaults.set(max(0, count), forKey: Keys.checkinCount)
    }

    /// Call once per newly created (not re-saved) check-in.
    func incrementLifetimeCheckinCount() {
        defaults.set(lifetimeCheckinCount + 1, forKey: Keys.checkinCount)
    }

    // MARK: - Prompting

    /// Pure gate (unit-tested).
    static func shouldPrompt(
        now: Date,
        previousPrompts: [Date],
        unlockedBadgeCount: Int,
        lifetimeCheckins: Int,
        paywallShown: Bool,
        screenshotMode: Bool
    ) -> Bool {
        guard !screenshotMode, !paywallShown else { return false }
        guard unlockedBadgeCount >= minUnlockedBadges, lifetimeCheckins >= minLifetimeCheckins else { return false }
        let recent = previousPrompts.filter { now.timeIntervalSince($0) < rollingWindow }
        guard recent.count < maxPromptsPerWindow else { return false }
        if let last = previousPrompts.max(), now.timeIntervalSince(last) < minDaysBetweenPrompts { return false }
        return true
    }

    private var promptHistory: [Date] {
        var dates = (defaults.array(forKey: Keys.promptTimestamps) as? [Date]) ?? []
        if let last = defaults.object(forKey: Keys.lastPromptDate) as? Date, !dates.contains(last) {
            dates.append(last)
        }
        return dates
    }

    /// The 1.4 hook: call when a full-screen celebration was dismissed and the
    /// celebration queue is now empty. GamificationViewModel does this itself.
    func celebrationSequenceDidFinish(unlockedBadgeCount: Int) {
        requestIfEligible(unlockedBadgeCount: unlockedBadgeCount)
    }

    /// Legacy trigger API. Only "firstExport" still qualifies (once per
    /// install); "levelup", "highScore" and "streakN" are ignored — those
    /// moments now reach the prompt via the celebration-dismissed hook.
    func requestIfAppropriate(trigger: String) {
        guard Self.legacyQualifyingTriggers.contains(trigger) else { return }
        var consumed = defaults.stringArray(forKey: Keys.consumedTriggers) ?? []
        guard !consumed.contains(trigger) else { return }
        let badges = unlockedBadgeCountProvider?() ?? 0
        guard requestIfEligible(unlockedBadgeCount: badges) else { return }
        consumed.append(trigger)
        defaults.set(consumed, forKey: Keys.consumedTriggers)
    }

    /// Supplies the unlocked-badge count for legacy triggers (set by
    /// GamificationViewModel.setup).
    var unlockedBadgeCountProvider: (() -> Int)?

    @discardableResult
    private func requestIfEligible(unlockedBadgeCount: Int) -> Bool {
        let now = Date()
        guard Self.shouldPrompt(
            now: now,
            previousPrompts: promptHistory,
            unlockedBadgeCount: unlockedBadgeCount,
            lifetimeCheckins: lifetimeCheckinCount,
            paywallShown: Self.paywallShownThisSession,
            screenshotMode: Self.isScreenshotMode
        ) else { return false }

        // Record the prompt before firing — SKStore may or may not actually
        // show the sheet (Apple decides), and we must not spam the API.
        let timestamps = promptHistory.filter { now.timeIntervalSince($0) < Self.rollingWindow } + [now]
        defaults.set(now, forKey: Keys.lastPromptDate)
        defaults.set(timestamps, forKey: Keys.promptTimestamps)

        Task { @MainActor [promptDelayNanoseconds] in
            try? await Task.sleep(nanoseconds: promptDelayNanoseconds)
            guard !Self.paywallShownThisSession,
                  let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            AppStore.requestReview(in: scene)
        }
        return true
    }
}
