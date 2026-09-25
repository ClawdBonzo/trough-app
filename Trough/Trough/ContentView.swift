import SwiftUI
import UIKit

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
        .trToastOverlay()
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

/// Screens pushed inside the More tab.
enum MoreRoute: Hashable {
    case achievements
    case bloodwork
    case peptides
    case settings
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @StateObject private var gamificationVM = GamificationViewModel()
    @State private var selectedTab: AppTab = .home
    @State private var morePath: [MoreRoute] = []
    #if DEBUG
    @State private var debugCelebration: Celebration?
    #endif

    init() {
        Self.configureTabBarAppearance()
    }

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
                AchievementsScreen(viewModel: gamificationVM)
            }
            .tabItem {
                Label(NSLocalizedString("tab.achievements", comment: ""), systemImage: "trophy.fill")
            }
            .tag(AppTab.achievements)

            MoreView(path: $morePath)
                .tabItem {
                    Label(NSLocalizedString("tab.more", comment: ""), systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.more)
        }
        .onOpenURL { url in
            // Deep links from the widgets (trough://checkin, trough://badges)
            // and the Live Activity (trough://injections). Unknown hosts are ignored.
            switch url.host?.lowercased() {
            case "checkin":    selectedTab = .checkin
            case "injections": selectedTab = .injections
            case "badges":     selectedTab = .achievements
            default:           break
            }
        }
        .tint(TR.Palette.coral)
        .background(TR.Palette.background)
        .environmentObject(gamificationVM)
        .overlay(alignment: .top) { gamificationToast }
        .animation(TR.Motion.snappy, value: gamificationVM.pendingToast?.id)
        .task {
            // Run gamification setup off the initial render pass so it doesn't
            // block the first frame. Task is automatically cancelled on disappear.
            // Quest toasts render from `pendingToast` below — don't mirror them.
            gamificationVM.mirrorsToastsToToastManager = false
            let uid = UUID(uuidString: userIDString) ?? UUID()
            gamificationVM.setup(context: modelContext, userID: uid)
            QuestService.seedIfNeeded(context: modelContext, userID: uid)
            BadgeService.seedIfNeeded(context: modelContext, userID: uid)
            #if DEBUG
            applyLaunchHooks()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { gamificationVM.refresh() }
        }
        .fullScreenCover(isPresented: $gamificationVM.showCelebration) {
            if let c = gamificationVM.currentCelebration {
                CelebrationView(celebration: c) { gamificationVM.dismissCurrentCelebration() }
                    .id(c.id) // fresh view state when the next celebration swaps in
                    .environmentObject(gamificationVM)
            }
        }
        #if DEBUG
        .background {
            Color.clear
                .fullScreenCover(item: $debugCelebration) { c in
                    CelebrationView(celebration: c) { debugCelebration = nil }
                        .environmentObject(gamificationVM)
                }
        }
        #endif
    }

    // MARK: Toast (quest complete / daily challenge)

    @ViewBuilder
    private var gamificationToast: some View {
        if let toast = gamificationVM.pendingToast, case .questCompleted(let title, let xp) = toast {
            TRToastCapsule(
                message: Text(verbatim: String(format: gLoc("ach.toast.quest", "%@ · +%d XP"), title, xp)),
                systemImage: "checkmark.seal.fill",
                tint: TR.Palette.gold
            )
            .padding(.horizontal, TR.Metrics.gutter)
            .padding(.top, 8)
            .onTapGesture { gamificationVM.dismissToast() }
            .transition(.move(edge: .top).combined(with: .opacity))
            .id(toast.id)
            .task(id: toast.id) {
                UIAccessibility.post(notification: .announcement, argument: "\(title), +\(xp) XP")
                try? await Task.sleep(for: .seconds(3))
                withAnimation(TR.Motion.snappy) { gamificationVM.dismissToast() }
            }
            .accessibilityIdentifier("quest-toast")
        }
    }

    // MARK: Tab bar

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(TR.Palette.abyss).withAlphaComponent(0.78)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
        let normal = UIColor(TR.Palette.textTertiary)
        let selected = UIColor(TR.Palette.coral)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: DEBUG launch hooks (screenshots / exports)

    #if DEBUG
    /// `-TRShowcase <home|checkin|injections|achievements|more|bloodwork|peptides>` selects a
    /// tab (bloodwork/peptides push inside More). `-TRCelebrate badge:<id>[:<more>] | levelup[:<level>]
    /// | streak:<days>` presents a CelebrationView on launch.
    private func applyLaunchHooks() {
        // `-TRExportShareAssets <dir>`: write share cards + medallions as PNGs (live data if any).
        if let dir = LaunchHooks.value(after: "-TRExportShareAssets") {
            let data = gamificationVM.badgeProgress.contains(where: \.isUnlocked) ? ShareCardData.from(gamificationVM) : .sample
            let urls = ShareRenderer.exportAssets(to: URL(fileURLWithPath: dir), data: data)
            print("[TRExportShareAssets] wrote \(urls.count) files to \(dir)")
        }
        if let target = LaunchHooks.value(after: "-TRShowcase")?.lowercased() {
            switch target {
            case "home": selectedTab = .home
            case "checkin", "log": selectedTab = .checkin
            case "injections": selectedTab = .injections
            case "achievements": selectedTab = .achievements
            case "more": selectedTab = .more
            case "bloodwork": showcaseMore(.bloodwork)
            case "peptides": showcaseMore(.peptides)
            case "settings": showcaseMore(.settings)
            default: break
            }
        }
        if let spec = LaunchHooks.value(after: "-TRCelebrate"),
           let celebration = LaunchHooks.celebration(from: spec, level: gamificationVM.currentLevel, totalXP: gamificationVM.currentXP) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                debugCelebration = celebration
            }
        }
    }

    /// The More tab's NavigationStack is built lazily on first selection, and a
    /// path set in the same pass is dropped — push after the stack exists.
    private func showcaseMore(_ route: MoreRoute) {
        selectedTab = .more
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            morePath = [route]
        }
    }
    #endif
}

#if DEBUG
enum LaunchHooks {
    static func value(after flag: String, in args: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func celebration(from spec: String, level: Int, totalXP: Int) -> Celebration? {
        let parts = spec.split(separator: ":").map(String.init)
        guard let head = parts.first?.lowercased() else { return nil }
        switch head {
        case "badge":
            let id = parts.count > 1 ? parts[1] : "consistency_king"
            guard let def = GamificationCatalog.badge(id) else { return nil }
            let more = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
            return .badge(def, alsoEarned: more, xp: GamificationCatalog.badgeUnlockXP)
        case "levelup", "level":
            let lv = parts.count > 1 ? Int(parts[1]) ?? max(level, 7) : max(level, 7)
            let xp = SDGamificationState.xpThresholds[min(max(lv, 1), 11) - 1]
            return .levelUp(level: lv, name: GamificationCatalog.levelName(lv), totalXP: max(totalXP, xp))
        case "streak":
            let days = parts.count > 1 ? Int(parts[1]) ?? 30 : 30
            return .streak(days: days, xp: StreakMilestones.xp[days] ?? 25)
        default:
            return nil
        }
    }
}
#endif

// MARK: - More View

struct MoreView: View {
    @Binding var path: [MoreRoute]
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var gamificationVM: GamificationViewModel
    @State private var showPaywall = false

    init(path: Binding<[MoreRoute]> = .constant([])) {
        _path = path
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing) {
                    VStack(spacing: 10) {
                        NavigationLink(value: MoreRoute.achievements) {
                            MoreRow(
                                title: NSLocalizedString("tab.achievements", comment: ""),
                                subtitle: String(format: NSLocalizedString("gamification.levelLine", comment: ""), gamificationVM.currentLevel, gamificationVM.levelName),
                                symbol: "trophy.fill",
                                tint: TR.Palette.gold
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TRKicker(Text(verbatim: gLoc("ach.more.tracking", "Tracking")))
                            .padding(.leading, 4)
                        if subscriptionManager.isSubscribed {
                            NavigationLink(value: MoreRoute.bloodwork) {
                                MoreRow(title: NSLocalizedString("bloodwork.title", comment: ""), symbol: "drop.fill", tint: TR.Palette.coral)
                            }
                            NavigationLink(value: MoreRoute.peptides) {
                                MoreRow(title: NSLocalizedString("peptides.title", comment: ""), symbol: "pills.fill", tint: TR.Palette.teal)
                            }
                        } else {
                            Button { showPaywall = true } label: {
                                MoreRow(title: NSLocalizedString("bloodwork.title", comment: ""), symbol: "drop.fill", tint: TR.Palette.coral, locked: true)
                            }
                            Button { showPaywall = true } label: {
                                MoreRow(title: NSLocalizedString("peptides.title", comment: ""),
                                        subtitle: NSLocalizedString("more.peptidesTeaser", comment: ""),
                                        symbol: "pills.fill", tint: TR.Palette.teal, locked: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TRKicker(Text(verbatim: gLoc("ach.more.app", "App")))
                            .padding(.leading, 4)
                        NavigationLink(value: MoreRoute.settings) {
                            MoreRow(title: NSLocalizedString("settings.title", comment: ""), symbol: "gearshape.fill", tint: TR.Palette.sky)
                        }
                    }
                }
                .buttonStyle(.trPressable)
                .padding(TR.Metrics.gutter)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(TRBackground())
            .navigationTitle(NSLocalizedString("tab.more", comment: ""))
            .navigationDestination(for: MoreRoute.self) { route in
                switch route {
                case .achievements: AchievementsScreen(viewModel: gamificationVM)
                case .bloodwork: BloodworkView()
                case .peptides: PeptidesView()
                case .settings: SettingsView()
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

/// Design-system list row: tinted icon tile, title, optional subtitle, chevron or lock.
private struct MoreRow: View {
    let title: String
    var subtitle: String?
    let symbol: String
    let tint: Color
    var locked: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint.opacity(0.3), lineWidth: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TR.Palette.textPrimary)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(TR.Palette.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: TR.Metrics.minTap, alignment: .leading)
        .trCard(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
