import SwiftUI
import SwiftData
import AppTrackingTransparency

// RevenueCat API key.
// Debug builds: test key (simulator test store, no real StoreKit).
// Release builds (TestFlight / App Store): set REVENUECAT_API_KEY in the
//   scheme environment or replace the empty string with your production key.
//   Using a test_ key in a Release build triggers a fatalError inside the SDK.
#if DEBUG
private let rcAPIKey = "test_krkCfgwjlVogQCiaTwYBUsECELI"
#else
private let rcAPIKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? ""
#endif

@main
struct TroughApp: App {
    let container: ModelContainer
    @StateObject private var syncEngine = SyncEngine.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var toastManager = ToastManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("attRequested") private var attRequested = false

    init() {
        do {
            container = try ModelContainer(
                for: Schema(TroughSchemaV1.models),
                migrationPlan: TroughMigrationPlan.self
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        RevenueCatService.configure(apiKey: rcAPIKey)
        AnalyticsService.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(syncEngine)
                .environmentObject(subscriptionManager)
                .environmentObject(toastManager)
                .preferredColorScheme(.dark)
                .task { await subscriptionManager.refresh() }
                .task { await requestATTIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await subscriptionManager.refresh() }
            }
        }
    }

    private func requestATTIfNeeded() async {
        guard !attRequested else { return }
        // Brief delay so the UI is fully presented before the system prompt
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        let status = await ATTrackingManager.requestTrackingAuthorization()
        attRequested = true
        if status == .authorized {
            // PostHog already initialized; no additional action needed
        }
    }
}
