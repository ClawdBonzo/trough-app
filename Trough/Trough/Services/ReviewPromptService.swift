import Foundation
import StoreKit
import UIKit

// MARK: - ReviewPromptService

/// Central throttle for App Store review prompts.
///
/// All review-prompt triggers in the app route through
/// `requestIfAppropriate(trigger:)`, which enforces:
/// - at most one prompt per 30 days,
/// - each trigger id fires at most once per install,
/// - at least 3 lifetime check-ins before any prompt,
/// - at most 3 prompts in any rolling 365-day window.
///
/// Everything is stored in UserDefaults — fully on-device, no tracking.
@MainActor
final class ReviewPromptService {
    static let shared = ReviewPromptService()

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

    private let minDaysBetweenPrompts: TimeInterval = 30 * 24 * 60 * 60
    private let rollingWindow: TimeInterval = 365 * 24 * 60 * 60
    private let maxPromptsPerWindow = 3
    private let minLifetimeCheckins = 3
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

    /// Requests an App Store review if all throttle conditions pass.
    /// Each distinct `trigger` id fires at most once per install.
    func requestIfAppropriate(trigger: String) {
        let now = Date()

        // Never re-fire a consumed trigger.
        var consumed = defaults.stringArray(forKey: Keys.consumedTriggers) ?? []
        guard !consumed.contains(trigger) else { return }

        // Require a minimum of engagement before ever asking.
        guard lifetimeCheckinCount >= minLifetimeCheckins else { return }

        // At most one prompt per 30 days.
        if let last = defaults.object(forKey: Keys.lastPromptDate) as? Date,
           now.timeIntervalSince(last) < minDaysBetweenPrompts {
            return
        }

        // At most 3 prompts per rolling 365 days.
        var timestamps = (defaults.array(forKey: Keys.promptTimestamps) as? [Date]) ?? []
        timestamps = timestamps.filter { now.timeIntervalSince($0) < rollingWindow }
        guard timestamps.count < maxPromptsPerWindow else {
            defaults.set(timestamps, forKey: Keys.promptTimestamps)
            return
        }

        // Record the prompt before firing — SKStore may or may not actually
        // show the sheet (Apple decides), and we must not spam the API.
        consumed.append(trigger)
        timestamps.append(now)
        defaults.set(consumed, forKey: Keys.consumedTriggers)
        defaults.set(now, forKey: Keys.lastPromptDate)
        defaults.set(timestamps, forKey: Keys.promptTimestamps)

        Task { @MainActor [promptDelayNanoseconds] in
            try? await Task.sleep(nanoseconds: promptDelayNanoseconds)
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
