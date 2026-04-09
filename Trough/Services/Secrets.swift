import Foundation

// MARK: - Secrets
// Reads API keys from Info.plist (populated by Secrets.xcconfig at build time).
// Falls back to compiled defaults if xcconfig is not wired.
//
// NOTE: Supabase anon key and RevenueCat public key are CLIENT-SIDE public keys
// by design (see Supabase docs + RevenueCat docs). They are NOT secrets.
// Security comes from Supabase RLS policies, not key secrecy.

enum Secrets {
    // Fallback values used when xcconfig is not wired to the Xcode project.
    // These are public API keys safe for client-side use.
    private static let fallbackSupabaseURL = "https://bwvbmfukxjdteqegcmth.supabase.co"
    private static let fallbackSupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3dmJtZnVreGpkdGVxZWdjbXRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxMjAwNDIsImV4cCI6MjA4OTY5NjA0Mn0.G-0UD4UwfxIrBX_5HDYOLX_XTK4BcZh7r6ifr3g3nyU"
    // TODO: Before App Store submission — confirm fallbackRCProdKey is your live
    //       appl_... production key from the RevenueCat dashboard (Project → API Keys).
    //       The test_ key below is for Xcode StoreKit Testing ONLY and will trigger
    //       RevenueCat's checkForSimulatedStoreAPIKeyInRelease assertion in Release builds.
    private static let fallbackRCProdKey = "appl_ZMwqfCGdTmCpCuEoWQTSeNmGYae"
    // TODO: Replace with live appl_... key before App Store submission.
    //       This test_ key is ONLY valid for DEBUG / Xcode StoreKit file testing.
    private static let fallbackRCTestKey = "test_krkCfgwjlVogQCiaTwYBUsECELI"

    static var supabaseURL: String {
        let val = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        return val.isEmpty || val.contains("$(" ) ? fallbackSupabaseURL : val
    }

    static var supabaseAnonKey: String {
        let val = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
        return val.isEmpty || val.contains("$(" ) ? fallbackSupabaseKey : val
    }

    static var revenueCatAPIKey: String {
        let val = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String ?? ""
        return val.isEmpty || val.contains("$(" ) ? fallbackRCProdKey : val
    }

    static var revenueCatTestKey: String {
        let val = Bundle.main.infoDictionary?["REVENUECAT_TEST_KEY"] as? String ?? ""
        return val.isEmpty || val.contains("$(" ) ? fallbackRCTestKey : val
    }
}
