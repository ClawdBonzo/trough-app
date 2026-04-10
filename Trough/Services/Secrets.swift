import Foundation

// MARK: - Secrets
// Reads API keys from Info.plist (populated by Secrets.xcconfig at build time).
// Falls back to compiled defaults if xcconfig is not wired.
//
// NOTE: RevenueCat public key is a CLIENT-SIDE public key by design.
// It is NOT a secret. Security comes from App Store receipt validation.

enum Secrets {
    // TODO: Before App Store submission — confirm fallbackRCProdKey is your live
    //       appl_... production key from the RevenueCat dashboard (Project → API Keys).
    //       The test_ key below is for Xcode StoreKit Testing ONLY and will trigger
    //       RevenueCat's checkForSimulatedStoreAPIKeyInRelease assertion in Release builds.
    private static let fallbackRCProdKey = "appl_ZMwqfCGdTmCpCuEoWQTSeNmGYae"
    // TODO: Replace with live appl_... key before App Store submission.
    //       This test_ key is ONLY valid for DEBUG / Xcode StoreKit file testing.
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
