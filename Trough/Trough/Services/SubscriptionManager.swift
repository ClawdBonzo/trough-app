import SwiftUI

// MARK: - SubscriptionManager

/// App-wide subscription state. Inject as @EnvironmentObject.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = true

    // MARK: Refresh

    func refresh() async {
        isLoading = true
        isSubscribed = await RevenueCatService.shared.isSubscribed()
        isLoading = false
    }
}
