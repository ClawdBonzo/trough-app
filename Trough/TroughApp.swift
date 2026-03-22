import SwiftUI
import SwiftData
import AppTrackingTransparency

private let rcAPIKey = "test_krkCfgwjlVogQCiaTwYBUsECELI"

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
