import Foundation
import ActivityKit

/// Manages the injection-countdown Live Activity. Kept conservative for App Review:
/// the activity only runs when an injection is genuinely timely (due within ~a day),
/// and is ended once it is no longer relevant.
enum LiveActivityService {

    private static var existing: Activity<InjectionActivityAttributes>? {
        Activity<InjectionActivityAttributes>.activities.first
    }

    /// Starts or refreshes the injection Live Activity when the next dose is imminent;
    /// ends it otherwise.
    /// - Parameters:
    ///   - compound: e.g. "Testosterone Cypionate"
    ///   - nextDate: when the next injection is due
    ///   - daysUntil: whole days until that dose (<= 0 means due today/overdue)
    static func reconcile(compound: String, nextDate: Date, daysUntil: Int) {
        // Only surface a Live Activity for timely doses.
        guard daysUntil <= 1 else { end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let status = daysUntil <= 0 ? "Due today" : "Due tomorrow"
        let state = InjectionActivityAttributes.ContentState(
            nextInjectionDate: max(nextDate, Date()),
            statusLine: status
        )

        if let activity = existing {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            let attributes = InjectionActivityAttributes(compoundName: compound)
            do {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } catch {
                // Non-fatal: user may have disabled Live Activities.
            }
        }
    }

    static func end() {
        let activities = Activity<InjectionActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
