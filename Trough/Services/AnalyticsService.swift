import Foundation
import PostHog

// TODO: Replace with your PostHog project API key from us.posthog.com
private let postHogAPIKey = "POSTHOG_API_KEY_PLACEHOLDER"
private let postHogHost   = "https://us.i.posthog.com"

// MARK: - AnalyticsService

enum AnalyticsService {

    static func configure() {
        let config = PostHogConfig(apiKey: postHogAPIKey, host: postHogHost)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false   // manual screen events only
        PostHogSDK.shared.setup(config)
    }

    // MARK: - Events

    /// Fired when user saves a daily check-in.
    /// `dayInCycle`: day within injection cycle (nil for natural users).
    static func checkinCompleted(dayInCycle: Int?) {
        var props: [String: Any] = [:]
        if let day = dayInCycle { props["day_in_cycle"] = day }
        PostHogSDK.shared.capture("checkin_completed", properties: props.isEmpty ? nil : props)
    }

    /// Fired whenever the paywall sheet is presented.
    static func paywallShown() {
        PostHogSDK.shared.capture("paywall_shown")
    }

    /// Fired when a purchase completes successfully.
    static func paywallConverted(productID: String) {
        PostHogSDK.shared.capture("paywall_converted", properties: ["product_id": productID])
    }

    /// Fired when the PK curve card is displayed.
    /// `absorptionDelay`: whether the absorption delay toggle is on.
    static func pkCurveViewed(absorptionDelay: Bool) {
        PostHogSDK.shared.capture("pk_curve_viewed", properties: ["absorption_delay": absorptionDelay])
    }
}
