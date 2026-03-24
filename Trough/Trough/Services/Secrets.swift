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
    private static let fallbackRCProdKey = "appl_ZMwqfCGdTmCpCuEoWQTSeNmGYae"
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
