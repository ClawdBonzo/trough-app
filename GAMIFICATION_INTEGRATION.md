# Trough Gamification Layer — Integration Instructions

## Implementation Status

✅ **Completed:**
- Phase 1: SwiftData models (SDGamificationState, SDQuest, SDBadge, SDStreakState, SDLevelUpEvent)
- Phase 2: HapticManager utility with 6 distinct haptic patterns
- Phase 3: GamificationViewModel with XP/level logic, quest management, badge unlocking
- Phase 4: GamificationHomeView (dashboard preview), QuestListView, BadgeCollectionView
- Phase 5: LevelUpCelebrationView with particle effects and animations

## Phase 6: Integration into Existing ViewModels

### In `DailyCheckinViewModel.swift` — After saving check-in

Add to the `save()` method, after `try? ctx.save()`:

```swift
// Award XP for daily check-in completion
if let gamificationVM = gamificationViewModel {
    gamificationVM.awardXP(20, reason: "daily_checkin")
    gamificationVM.updateStreak(type: "checkin")
    gamificationVM.completeQuest("log_checkin_daily")
}
```

Also add property:
```swift
@EnvironmentObject var gamificationViewModel: GamificationViewModel?
```

### In `BloodworkViewModel.swift` — After saving bloodwork

Add to the `save()` method:

```swift
// Award XP for bloodwork completion
if let gamificationVM = gamificationViewModel {
    gamificationVM.awardXP(30, reason: "bloodwork_logged")
    gamificationVM.completeQuest("complete_bloodwork_weekly")
}
```

### In `InjectionsViewModel.swift` — After saving injection

Add to the injection save method:

```swift
// Update streak and award XP for on-time injection
if let gamificationVM = gamificationViewModel {
    gamificationVM.updateStreak(type: "injection")
    gamificationVM.completeQuest("inject_on_schedule")
}
```

## Phase 7: UI Integration

### In `ContentView.swift` — Add 5th tab

```swift
TabView(selection: $selectedTab) {
    // ... existing tabs ...
    
    // New Achievements tab
    NavigationStack {
        GamificationHomeView(viewModel: gamificationViewModel)
            .navigationTitle("Achievements")
    }
    .tabItem {
        Label("Achievements", systemImage: "star.fill")
    }
    .tag(4)
}
```

### In `DashboardView.swift` — Add gamification card

Add this section after the protocol score hero:

```swift
Section("🎮 Your Progress") {
    GamificationHomeView(viewModel: gamificationViewModel)
        .environmentObject(gamificationViewModel)
}
```

### In `MoreView.swift` — Add link to Achievements

Add this navigation link:

```swift
NavigationLink {
    GamificationHomeView(viewModel: gamificationViewModel)
        .navigationTitle("Achievements")
} label: {
    Label("Achievements", systemImage: "star.fill")
}
```

### In `TroughApp.swift` — Initialize GamificationViewModel

Add to the main view initialization:

```swift
@StateObject private var gamificationViewModel = GamificationViewModel()

// In the view body, add as environment object:
.environmentObject(gamificationViewModel)

// In onAppear or similar setup:
gamificationViewModel.setup(
    context: container.mainContext,
    userID: userID,
    hapticManager: .shared
)
```

## Quest Initialization

Add to `DailyCheckinViewModel.setup()` or similar initialization:

```swift
private func initializeQuests() {
    guard let ctx = modelContext, let uid = userID else { return }
    
    let dailyQuests: [(String, String, String, Int)] = [
        ("log_checkin_daily", "Log Today's Check-in", "Complete your daily wellness check-in", 10),
        ("sync_data_daily", "Sync Your Data", "Sync your data with cloud backup", 5),
        ("check_healthkit_daily", "Check HealthKit", "View your HealthKit integration status", 5),
        ("log_weight_daily", "Log Body Weight", "Update your body weight tracking", 10),
    ]
    
    let today = Date().startOfDay
    
    for (questID, title, description, xpReward) in dailyQuests {
        // Check if quest already exists for today
        let pred = #Predicate<SDQuest> {
            $0.questID == questID && $0.userID == uid && $0.dueDate >= today
        }
        var desc = FetchDescriptor<SDQuest>(predicate: pred)
        
        if (try? ctx.fetch(desc).first) == nil {
            // Create new daily quest
            let quest = SDQuest(
                userID: uid,
                questID: questID,
                questType: questID,
                frequency: "daily",
                title: title,
                description: description,
                xpReward: xpReward,
                dueDate: today.endOfDay
            )
            ctx.insert(quest)
        }
    }
    
    try? ctx.save()
}
```

## Badge Initialization

Create all badges on first app launch (add to `TroughApp.swift`):

```swift
private func initializeBadges() {
    let badgeDefinitions: [(String, String, String, String)] = [
        ("testosterone_peak", "Testosterone Peak", "Achieve Protocol Score ≥80", "🧬"),
        ("consistency_king", "Consistency King", "30-day check-in streak", "👑"),
        ("bloodwork_master", "Bloodwork Master", "10 bloodwork sessions logged", "📊"),
        ("streak_flame_7", "Flame Keeper", "7-day streak (any type)", "🔥"),
        ("level_5", "Rising Star", "Reach Level 5", "⭐"),
        ("level_10", "Master Tier", "Reach Level 10", "🏆"),
        ("perfect_week", "Perfect Week", "7 consecutive daily check-ins", "✅"),
        ("supplement_adherence", "Supplement Scholar", "90% supplement compliance (30 days)", "💊"),
        ("injection_precision", "Precision Injector", "No missed injections (30 days)", "💉"),
    ]
    
    let ctx = container.mainContext
    let userID = SupabaseService.resolvedUserUUID ?? UUID()
    
    for (badgeID, name, description, emoji) in badgeDefinitions {
        let pred = #Predicate<SDBadge> {
            $0.badgeID == badgeID && $0.userID == userID
        }
        var desc = FetchDescriptor<SDBadge>(predicate: pred)
        
        if (try? ctx.fetch(desc).first) == nil {
            let badge = SDBadge(
                userID: userID,
                badgeID: badgeID,
                name: name,
                description: description,
                iconEmoji: emoji
            )
            ctx.insert(badge)
        }
    }
    
    try? ctx.save()
}
```

## Celebration Modal Integration

In any view that calls gamification methods, add:

```swift
@ObservedObject var gamificationViewModel: GamificationViewModel

// In the view body:
.fullScreenCover(isPresented: $gamificationViewModel.showCelebration) {
    if let event = gamificationViewModel.pendingCelebration {
        LevelUpCelebrationView(event: event) {
            gamificationViewModel.showCelebration = false
        }
    }
}
```

## Testing Checklist

- [ ] SwiftData models compile and persist
- [ ] GamificationViewModel initializes on app launch
- [ ] Check-in → +20 XP awarded
- [ ] Level-up haptics fire (triple buzz)
- [ ] LevelUpCelebrationView modal shows on level-up
- [ ] Quest completion updates UI
- [ ] Streak tracking persists across app restarts
- [ ] Badge unlocks trigger celebration
- [ ] Flame visual updates at 1/3/7/14/30 day streaks
- [ ] All haptics work on device (silent on simulator)
- [ ] GamificationHomeView renders on Dashboard
- [ ] Achievements 5th tab appears in TabView
- [ ] Colors match dark aesthetic (#1A1A2E, #E94560, #16213E)

## Notes

- All gamification data stays local (SwiftData only)
- No backend sync required
- Haptics gracefully degrade on unsupported devices
- Celebration modals auto-dismiss after 2.5 seconds
- XP thresholds optimized for weekly level-ups (aggressive cadence)
- Quest reset logic should run daily (e.g., in AppDelegate or on first check-in of day)

## Files Created

```
Trough/
├─ Models/Schema/
│  └─ TroughSchemaV1.swift (modified: added 5 models)
├─ Features/Gamification/
│  ├─ GamificationViewModel.swift (240 lines)
│  ├─ GamificationHomeView.swift (250+ lines)
│  ├─ QuestListView.swift (90 lines)
│  ├─ BadgeCollectionView.swift (90 lines)
│  └─ LevelUpCelebrationView.swift (260+ lines)
└─ Utilities/
   └─ HapticManager.swift (190+ lines)
```

**Total new code: ~1100+ lines (lightweight, fully on-device)**
