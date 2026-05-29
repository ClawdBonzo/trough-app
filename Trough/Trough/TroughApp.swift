import SwiftUI
import SwiftData

// RevenueCat API key loaded from Secrets.
// TestFlight = sandbox environment = MUST use production key (NOT test key).
// RevenueCat production keys work in BOTH sandbox and production.
// The test_ key is ONLY for StoreKit Testing in Xcode (local simulator).
//
// The previous crash was RevenueCat's internal assertion
// (checkForSimulatedStoreAPIKeyInRelease) which fires when using a
// test_ key in a Release build. Using the production key fixes this.
private var rcAPIKey: String {
    #if DEBUG
    // Debug builds: use test key for Xcode StoreKit Testing
    return Secrets.revenueCatTestKey
    #else
    // Release builds (TestFlight + App Store): ALWAYS production key
    return Secrets.revenueCatAPIKey
    #endif
}

@main
struct TroughApp: App {
    let container: ModelContainer
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var toastManager = ToastManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Attempt to create the ModelContainer. If schema/migration fails,
        // fall back to a fresh store (delete corrupted DB) rather than crashing.
        let schema = Schema(TroughSchemaV1.models)
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: TroughMigrationPlan.self
            )
        } catch {
            // Log the error for diagnostics
            print("[TroughApp] ModelContainer failed: \(error). Recreating store.")
            // Attempt without migration as a recovery path
            do {
                container = try ModelContainer(for: schema)
            } catch {
                // Last resort: in-memory only so the app doesn't crash
                print("[TroughApp] Recovery failed: \(error). Using in-memory store.")
                container = try! ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            }
        }

        let isTF = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        if isTF {
            print("[TroughApp] Running in TestFlight sandbox — production key + DangerousSettings enabled")
        }
        RevenueCatService.configure(apiKey: rcAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(subscriptionManager)
                .environmentObject(toastManager)
                .preferredColorScheme(.dark)
                .task { await subscriptionManager.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await subscriptionManager.refresh() }
            }
        }
    }
}
