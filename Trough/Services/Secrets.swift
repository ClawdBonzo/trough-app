import Foundation

// MARK: - Secrets
// Reads API keys from Info.plist (populated by Secrets.xcconfig at build time).
// If xcconfig is not configured, falls back to environment variables or empty strings.
// SECURITY: Never hardcode real API keys in Swift source files.

enum Secrets {
    static var supabaseURL: String {
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    }

    static var supabaseAnonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    static var revenueCatAPIKey: String {
        Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String ?? ""
    }

    static var revenueCatTestKey: String {
        Bundle.main.infoDictionary?["REVENUECAT_TEST_KEY"] as? String ?? ""
    }
}
