import Foundation

// MARK: - Secrets
// Reads API keys from Info.plist (populated by Secrets.xcconfig at build time).
// Falls back to compiled defaults if xcconfig is not wired.
//
// NOTE: RevenueCat public key is a CLIENT-SIDE public key by design.
// It is NOT a secret. Security comes from App Store receipt validation.

enum Secrets {
    private static let fallbackRCProdKey = "appl_ZMwqfCGdTmCpCuEoWQTSeNmGYae"
    // Test key: ONLY valid for DEBUG / Xcode StoreKit file testing.
    private static let fallbackRCTestKey = "test_krkCfgwjlVogQCiaTwYBUsECELI"

    static var revenueCatAPIKey: String {
        let val = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String ?? ""
        return val.isEmpty || val.contains("$(" ) ? fallbackRCProdKey : val
    }

    static var revenueCatTestKey: String {
        let val = Bundle.main.infoDictionary?["REVENUECAT_TEST_KEY"] as? String ?? ""
        return val.isEmpty || val.contains("$(" ) ? fallbackRCTestKey : val
    }
}
