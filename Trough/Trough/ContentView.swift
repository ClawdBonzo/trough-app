import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some View {
        Group {
            if !onboardingCompleted {
                // Onboarding includes: protocol setup → compounds → first check-in → HealthKit → trial prompt
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .toastOverlay()
    }
}

// MARK: - Main Tab View

/// Tabs in MainTabView, in display order. Used as TabView selection tags and
/// as deep-link targets for the `trough://` URL scheme (widget + Live Activity).
enum AppTab: Hashable {
    case home
    case checkin
    case injections
    case achievements
    case more
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @StateObject private var gamificationVM = GamificationViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill")
                }
                .tag(AppTab.home)

            DailyCheckinView()
                .tabItem {
                    Label(NSLocalizedString("tab.log", comment: ""), systemImage: "checkmark.circle.fill")
                }
                .tag(AppTab.checkin)

            InjectionsView()
                .tabItem {
                    Label(NSLocalizedString("tab.injections", comment: ""), systemImage: "syringe.fill")
                }
                .tag(AppTab.injections)

            NavigationStack {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    GamificationHomeView(viewModel: gamificationVM)
                }
                .navigationTitle(NSLocalizedString("tab.achievements", comment: ""))
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label(NSLocalizedString("tab.achievements", comment: ""), systemImage: "star.fill")
            }
            .tag(AppTab.achievements)

            MoreView()
                .tabItem {
                    Label(NSLocalizedString("tab.more", comment: ""), systemImage: "ellipsis.circle.fill")
                }
                .tag(AppTab.more)
        }
        .onOpenURL { url in
            // Deep links from the widget (trough://checkin) and the Live
            // Activity (trough://injections). Unknown hosts are ignored.
            switch url.host?.lowercased() {
            case "checkin":    selectedTab = .checkin
            case "injections": selectedTab = .injections
            default:           break
            }
        }
        .tint(AppColors.accent)
        .background(AppColors.background)
        .environmentObject(gamificationVM)
        .task {
            // Run gamification setup off the initial render pass so it doesn't
            // block the first frame. Task is automatically cancelled on disappear.
            let uid = UUID(uuidString: userIDString) ?? UUID()
            gamificationVM.setup(context: modelContext, userID: uid)
            QuestService.seedIfNeeded(context: modelContext, userID: uid)
            BadgeService.seedIfNeeded(context: modelContext, userID: uid)
        }
        .fullScreenCover(isPresented: $gamificationVM.showCelebration) {
            if let event = gamificationVM.pendingCelebration {
                LevelUpCelebrationView(event: event) {
                    gamificationVM.showCelebration = false
                    gamificationVM.pendingCelebration = nil
                }
            }
        }
    }
}

// MARK: - More View

struct MoreView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var gamificationVM: GamificationViewModel
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                List {
                    // Achievements (always accessible)
                    Section {
                        NavigationLink(destination:
                            ZStack {
                                AppColors.background.ignoresSafeArea()
                                GamificationHomeView(viewModel: gamificationVM)
                            }
                            .navigationTitle(NSLocalizedString("tab.achievements", comment: ""))
                        ) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("tab.achievements", comment: ""))
                                    Text(String(format: NSLocalizedString("gamification.levelLine", comment: ""), gamificationVM.currentLevel, gamificationVM.levelName))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }

                    if subscriptionManager.isSubscribed {
                        NavigationLink(destination: BloodworkView()) {
                            Label(NSLocalizedString("bloodwork.title", comment: ""), systemImage: "drop.fill")
                        }
                        NavigationLink(destination: PeptidesView()) {
                            Label(NSLocalizedString("peptides.title", comment: ""), systemImage: "pills.fill")
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label(NSLocalizedString("bloodwork.title", comment: ""), systemImage: "drop.fill")
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)

                        Button {
                            showPaywall = true
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Label(NSLocalizedString("peptides.title", comment: ""), systemImage: "pills.fill")
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(NSLocalizedString("more.peptidesTeaser", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label(NSLocalizedString("settings.title", comment: ""), systemImage: "gear")
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle(NSLocalizedString("tab.more", comment: ""))
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    ContentView()
}
