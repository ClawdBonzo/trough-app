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

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @StateObject private var gamificationVM = GamificationViewModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            DailyCheckinView()
                .tabItem {
                    Label("Log", systemImage: "checkmark.circle.fill")
                }

            InjectionsView()
                .tabItem {
                    Label("Injections", systemImage: "syringe.fill")
                }

            NavigationStack {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    GamificationHomeView(viewModel: gamificationVM)
                }
                .navigationTitle("Achievements")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Achievements", systemImage: "star.fill")
            }

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
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
                            .navigationTitle("Achievements")
                        ) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Achievements")
                                    Text("Level \(gamificationVM.currentLevel) · \(gamificationVM.levelName)")
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
                            Label("Bloodwork", systemImage: "drop.fill")
                        }
                        NavigationLink(destination: PeptidesView()) {
                            Label("Adjuncts & Peptides", systemImage: "pills.fill")
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Bloodwork", systemImage: "drop.fill")
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
                                    Label("Adjuncts & Peptides", systemImage: "pills.fill")
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("Track GLP-1, BPC-157 & more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("More")
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    ContentView()
}
