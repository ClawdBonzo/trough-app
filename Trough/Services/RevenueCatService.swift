import Foundation
import RevenueCat

// MARK: - RevenueCatService

@MainActor
final class RevenueCatService {
    static let shared = RevenueCatService()
    private init() {}

    // MARK: Configure

    static func configure(apiKey: String) {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    // MARK: Offerings

    func fetchOfferings() async -> Offerings? {
        try? await Purchases.shared.offerings()
    }

    // MARK: Purchase

    /// Returns updated CustomerInfo. Throws on error; callers should check `.userCancelled`.
    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo
    }

    // MARK: Restore

    func restorePurchases() async throws -> CustomerInfo {
        try await Purchases.shared.restorePurchases()
    }

    // MARK: Subscription status

    /// True if the user has an active "pro" entitlement (covers both monthly and annual).
    func isSubscribed() async -> Bool {
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return info.entitlements["pro"]?.isActive == true
    }
}
