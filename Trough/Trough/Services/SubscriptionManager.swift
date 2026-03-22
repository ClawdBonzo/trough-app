import SwiftUI
import RevenueCat

// MARK: - SubscriptionManager

/// App-wide subscription state. Inject as @EnvironmentObject.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = true
    @Published var isInTrial: Bool = false
    @Published var trialDaysRemaining: Int? = nil  // nil = not in trial

    /// True when trial ends in ≤ 2 days — show gentle banner
    var showTrialExpiryWarning: Bool {
        guard isInTrial, let days = trialDaysRemaining else { return false }
        return days <= 2
    }

    // MARK: Refresh

    func refresh() async {
        isLoading = true
        isSubscribed = await RevenueCatService.shared.isSubscribed()

        // Check trial status
        if let info = try? await Purchases.shared.customerInfo(),
           let entitlement = info.entitlements["pro"],
           entitlement.isActive,
           let expirationDate = entitlement.expirationDate {
            let periodType = entitlement.periodType
            isInTrial = (periodType == .trial)
            if isInTrial {
                trialDaysRemaining = Calendar.current.dateComponents([.day], from: .now, to: expirationDate).day
            } else {
                trialDaysRemaining = nil
            }
        } else {
            isInTrial = false
            trialDaysRemaining = nil
        }

        isLoading = false
    }
}
