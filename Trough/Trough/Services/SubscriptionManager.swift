import SwiftUI
import RevenueCat

// MARK: - SubscriptionManager

/// App-wide subscription state. Inject as @EnvironmentObject.
///
/// Free forever: HealthKit sync, daily check-in, Protocol Score, streak, basic insights, Active Protocol card.
/// Paid (or trial): PK curve, bloodwork, full trends (7d+), weekly report, peptides/GLP-1 analytics,
///                  fertility timeline, body composition charts, PDF export.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = true
    @Published var isInTrial: Bool = false
    @Published var isInGracePeriod: Bool = false   // billing retry — keep access for 3 days
    @Published var trialDaysRemaining: Int? = nil   // nil = not in trial
    @Published var graceDaysRemaining: Int? = nil   // nil = not in grace period

    /// True when trial ends in ≤ 2 days — show gentle banner
    var showTrialExpiryWarning: Bool {
        guard isInTrial, let days = trialDaysRemaining else { return false }
        return days <= 2
    }

    /// True when in billing grace period — show soft warning
    var showGracePeriodWarning: Bool {
        isInGracePeriod
    }

    // MARK: Refresh

    func refresh() async {
        isLoading = true

        // Guard: if RevenueCat isn't configured, skip all checks
        guard RevenueCatService.isConfiguredFlag else {
            isSubscribed = false
            isInTrial = false
            isInGracePeriod = false
            trialDaysRemaining = nil
            graceDaysRemaining = nil
            isLoading = false
            return
        }

        // Check entitlement state from RevenueCat
        // Wrapped in do/catch to prevent sandbox receipt validation crashes
        let info: CustomerInfo?
        do {
            info = try await Purchases.shared.customerInfo()
        } catch {
            print("[SubscriptionManager] customerInfo() failed: \(error)")
            info = nil
        }

        if let info, let entitlement = info.entitlements["pro"] {

            if entitlement.isActive {
                // Active subscription or trial
                isSubscribed = true
                let periodType = entitlement.periodType
                isInTrial = (periodType == .trial)
                isInGracePeriod = false
                graceDaysRemaining = nil

                if isInTrial, let expirationDate = entitlement.expirationDate {
                    trialDaysRemaining = Calendar.current.dateComponents([.day], from: .now, to: expirationDate).day
                } else {
                    trialDaysRemaining = nil
                }
            } else if let expirationDate = entitlement.expirationDate {
                // Expired — check if within 3-day grace period (billing retry)
                let daysSinceExpiry = Calendar.current.dateComponents([.day], from: expirationDate, to: .now).day ?? 999
                if daysSinceExpiry <= 3 {
                    // Grace period: keep access, show warning
                    isSubscribed = true
                    isInGracePeriod = true
                    graceDaysRemaining = 3 - daysSinceExpiry
                    isInTrial = false
                    trialDaysRemaining = nil
                } else {
                    // Fully expired
                    isSubscribed = false
                    isInTrial = false
                    isInGracePeriod = false
                    trialDaysRemaining = nil
                    graceDaysRemaining = nil
                }
            } else {
                isSubscribed = false
                isInTrial = false
                isInGracePeriod = false
                trialDaysRemaining = nil
                graceDaysRemaining = nil
            }
        } else {
            // No entitlement at all
            isSubscribed = await RevenueCatService.shared.isSubscribed()
            isInTrial = false
            isInGracePeriod = false
            trialDaysRemaining = nil
            graceDaysRemaining = nil
        }

        isLoading = false
    }
}
