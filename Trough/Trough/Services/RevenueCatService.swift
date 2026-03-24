import Foundation
import RevenueCat

// MARK: - RevenueCatService

@MainActor
final class RevenueCatService {
    static let shared = RevenueCatService()
    private init() {}

    static private(set) var isConfiguredFlag = false
    private static var isConfigured: Bool {
        get { isConfiguredFlag }
        set { isConfiguredFlag = newValue }
    }

    // MARK: Configure

    static func configure(apiKey: String) {
        guard !apiKey.isEmpty else {
            print("[RevenueCat] No API key configured — purchases disabled.")
            isConfigured = false
            return
        }
        #if !DEBUG
        // Prevent test keys from crashing in Release builds
        if apiKey.hasPrefix("test_") {
            print("[RevenueCat] Test API key detected in Release build — purchases disabled.")
            isConfigured = false
            return
        }
        #endif
        Purchases.logLevel = .warn
        // StoreKit 2 + DangerousSettings to prevent sandbox receipt
        // validation crash (checkForSimulatedStoreAPIKeyInRelease)
        // on TestFlight builds where production key + sandbox receipts coexist.
        let config = Configuration.Builder(withAPIKey: apiKey)
            .with(storeKitVersion: .storeKit2)
            .with(dangerousSettings: DangerousSettings(autoSyncPurchases: true))
            .build()
        Purchases.configure(with: config)
        isConfigured = true
    }

    // MARK: Offerings

    func fetchOfferings() async -> Offerings? {
        guard RevenueCatService.isConfigured else { return nil }
        do {
            return try await Purchases.shared.offerings()
        } catch {
            print("[RevenueCat] Failed to fetch offerings: \(error)")
            return nil
        }
    }

    // MARK: Purchase

    /// Returns updated CustomerInfo. Throws on error; callers should check `.userCancelled`.
    func purchase(package: Package) async throws -> CustomerInfo {
        guard RevenueCatService.isConfigured else {
            throw NSError(domain: "RevenueCat", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Purchases not configured"])
        }
        print("[RevenueCat] Starting purchase for \(package.storeProduct.productIdentifier)")
        let result = try await Purchases.shared.purchase(package: package)
        print("[RevenueCat] Purchase completed, userCancelled=\(result.userCancelled)")
        return result.customerInfo
    }

    // MARK: Restore

    func restorePurchases() async throws -> CustomerInfo {
        guard RevenueCatService.isConfigured else {
            throw NSError(domain: "RevenueCat", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Purchases not configured"])
        }
        return try await Purchases.shared.restorePurchases()
    }

    // MARK: Subscription status

    /// True if the user has an active "pro" entitlement (covers both monthly and annual).
    func isSubscribed() async -> Bool {
        guard RevenueCatService.isConfigured else { return false }
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return info.entitlements["pro"]?.isActive == true
    }
}
