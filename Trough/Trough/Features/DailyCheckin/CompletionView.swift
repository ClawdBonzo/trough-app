import SwiftUI

// MARK: - Screen 3: Completion (the reward moment)
//
// Celebrates LOGGING and CONSISTENCY only: XP for checking in, the check-in streak, today's
// quests. Never celebrates scores, levels or symptom outcomes. No auto-dismiss — the user
// leaves with Done or the close button.

struct CompletionView: View {
    @EnvironmentObject private var vm: DailyCheckinViewModel
    @EnvironmentObject private var gamificationVM: GamificationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heroIn = false
    @State private var xpIn = false
    @State private var confetti = 0
    @State private var displayedStreak = 0
    @State private var ticked = 0
    @State private var visibleItems = 0
    @State private var showInsight = false
    @State private var hkValues: HKSnapshot? = nil
    @State private var didStart = false

    private let healthItems: [(icon: String, tint: Color, label: String, keyPath: KeyPath<HKSnapshot, String>)] = [
        ("waveform.path.ecg", TR.Palette.teal,  NSLocalizedString("checkin.hrv", comment: ""),       \.hrv),
        ("moon.zzz.fill",     TR.Palette.lilac, NSLocalizedString("checkin.sleep", comment: ""),     \.sleep),
        ("figure.walk",       TR.Palette.sky,   NSLocalizedString("checkin.steps", comment: ""),     \.steps),
        ("heart.fill",        TR.Palette.coral, NSLocalizedString("checkin.restingHR", comment: ""), \.hr),
    ]

    private var streakDays: Int { gamificationVM.checkinStreakDays }
    private var bestStreak: Int { max(streakDays, gamificationVM.streakStates["checkin"]?.bestCount ?? 0) }

    /// Today's daily quests + the daily challenge (weekly quests live on the Achievements tab).
    private var todaysQuests: [QuestDisplayModel] {
        gamificationVM.activeQuests
            .filter { $0.frequency == "daily" || $0.challenge != nil }
            .sorted { ($0.challenge == nil ? 1 : 0, $0.isCompleted ? 0 : 1) < ($1.challenge == nil ? 1 : 0, $1.isCompleted ? 0 : 1) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            TRBackground(glow: TR.Palette.gold, glowOpacity: 0.22)
            GlowBackdrop(colors: [TR.Palette.coral, TR.Palette.gold, TR.Palette.lilac], intensity: 0.22)

            ScrollView {
                VStack(spacing: 16) {
                    hero
                    rewardRow
                    streakCard
                    if !todaysQuests.isEmpty { questsCard }
                    healthCard
                    if showInsight, let result = vm.insightResult {
                        InsightCard(result: result)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    DisclaimerBanner(type: .standard)
                    Button {
                        finish()
                    } label: {
                        Text(NSLocalizedString("common.done", comment: ""))
                    }
                    .buttonStyle(.trPrimary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.bottom, 28)
            }

            ConfettiBurst(trigger: confetti, origin: UnitPoint(x: 0.5, y: 0.18))
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { finish() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TR.Palette.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(TR.Palette.surfaceRaised, in: Circle())
                        .overlay(Circle().strokeBorder(TR.Palette.hairline))
                }
                .accessibilityLabel(Text(NSLocalizedString("checkin14.close", value: "Close", comment: "Close completion screen")))
            }
        }
        .task { await run() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [TR.Palette.gold.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 90))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(LinearGradient(colors: [TR.Palette.coralLight, TR.Palette.coral, TR.Palette.coralDeep], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)).padding(3))
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                    .frame(width: 96, height: 96)
                    .shadow(color: TR.Palette.coral.opacity(0.6), radius: 20, y: 6)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(height: 150)
            .scaleEffect(heroIn ? 1 : 0.4)
            .opacity(heroIn ? 1 : 0)
            .accessibilityHidden(true)

            Text(NSLocalizedString("checkin14.savedTitle", value: "Check-in logged!", comment: "Completion headline"))
                .font(TR.Font.display(30, weight: .black))
                .foregroundStyle(TR.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(vm.lastSaveWasNew
                 ? NSLocalizedString("checkin14.savedSubtitle", value: "Another day on the record. Nice consistency.", comment: "Completion subtitle, new check-in")
                 : NSLocalizedString("checkin14.updatedSubtitle", value: "Today's check-in is up to date.", comment: "Completion subtitle, edited check-in"))
                .font(.subheadline)
                .foregroundStyle(TR.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let info = vm.cycleInfo {
                TRPill(Text(String(format: NSLocalizedString("checkin.dayOf", comment: ""), info.day, info.totalDays)),
                       systemImage: "drop.circle.fill", tint: TR.Palette.coral)
            }
        }
        .padding(.top, 4)
    }

    // MARK: XP chip

    @ViewBuilder
    private var rewardRow: some View {
        if vm.lastSaveWasNew {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .black))
                Text(verbatim: "+20 XP")
                    .font(TR.Font.number(24))
            }
            .foregroundStyle(Color(trHex: 0x3A2600))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    Capsule().fill(TR.Gradients.xp)
                    Capsule().fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center)).padding(2)
                }
                .shadow(color: TR.Palette.gold.opacity(0.6), radius: 16, y: 4)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .holoSheen(cornerRadius: 30, period: 3.5, intensity: 0.4)
            .scaleEffect(xpIn ? 1 : 0.2)
            .opacity(xpIn ? 1 : 0)
            .rotationEffect(.degrees(xpIn ? -3 : -18))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(NSLocalizedString("checkin14.xpEarnedA11y", value: "20 XP earned", comment: "VoiceOver for the +20 XP chip")))
        } else {
            TRPill(Text(NSLocalizedString("checkin14.updatedPill", value: "Check-in updated", comment: "")), systemImage: "checkmark.circle.fill", tint: TR.Palette.teal)
        }
    }

    // MARK: Streak

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [TR.Palette.gold.opacity(0.4), .clear], center: .center, startRadius: 4, endRadius: 40))
                Image(systemName: "flame.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [TR.Palette.gold, TR.Palette.tangerine, TR.Palette.coral], startPoint: .top, endPoint: .bottom))
                    .shadow(color: TR.Palette.tangerine.opacity(0.7), radius: 12)
                    .symbolEffect(.bounce, value: displayedStreak)
            }
            .frame(width: 70, height: 70)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                TRKicker(Text(NSLocalizedString("checkin14.streakKicker", value: "Check-in streak", comment: "")), color: TR.Palette.gold)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    CountUp(displayedStreak, duration: 0.6, fromZero: false)
                        .font(TR.Font.number(44))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(displayedStreak == 1
                         ? NSLocalizedString("checkin14.day", value: "day", comment: "streak unit, singular")
                         : NSLocalizedString("checkin14.days", value: "days", comment: "streak unit, plural"))
                        .font(TR.Font.display(.title3, weight: .bold))
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                if bestStreak > 0 {
                    Text(String(format: NSLocalizedString("checkin14.bestStreak", value: "Best: %d days", comment: "Longest check-in streak"), bestStreak))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TR.Palette.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .trCard(tint: TR.Palette.gold)
        .accessibilityElement(children: .combine)
    }

    // MARK: Quests

    private var questsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TRSectionHeader(Text(NSLocalizedString("checkin14.todaysQuests", value: "Today's quests", comment: "")))
            ForEach(Array(todaysQuests.enumerated()), id: \.element.id) { index, quest in
                let done = quest.isCompleted && index < ticked
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(done ? Color.clear : TR.Palette.textTertiary, lineWidth: 2)
                        if done {
                            Circle().fill(LinearGradient(colors: [TR.Palette.mint, TR.Palette.teal], startPoint: .top, endPoint: .bottom))
                                .shadow(color: TR.Palette.mint.opacity(0.6), radius: 8)
                                .transition(.scale.combined(with: .opacity))
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.white)
                                .transition(.scale)
                        }
                    }
                    .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(quest.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(done ? TR.Palette.textPrimary : TR.Palette.textSecondary)
                            .lineLimit(2)
                        if quest.challenge != nil {
                            TRKicker(Text(NSLocalizedString("checkin14.dailyChallenge", value: "Daily challenge", comment: "")), color: TR.Palette.lilac)
                        }
                    }
                    Spacer(minLength: 6)
                    Text(verbatim: "+\(quest.xpReward) XP")
                        .font(TR.Font.number(.caption, weight: .heavy))
                        .foregroundStyle(done ? TR.Palette.gold : TR.Palette.textTertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(quest.isCompleted
                                         ? NSLocalizedString("checkin14.questDone", value: "Done", comment: "")
                                         : NSLocalizedString("checkin14.questOpen", value: "Not done yet", comment: "")))
            }
        }
        .trCard(tint: TR.Palette.lilac)
    }

    // MARK: Apple Health

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TRKicker(Text(NSLocalizedString("checkin14.appleHealth", value: "From Apple Health", comment: "")), color: TR.Palette.coral)
                Spacer()
                if hkValues == nil {
                    ProgressView().controlSize(.small).tint(TR.Palette.textSecondary)
                }
            }
            .padding(.bottom, 6)
            ForEach(Array(healthItems.enumerated()), id: \.offset) { index, item in
                if index < visibleItems {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(item.tint)
                            .frame(width: 34, height: 34)
                            .background(item.tint.opacity(0.16), in: Circle())
                        Text(item.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Spacer()
                        if let snap = hkValues {
                            let val = snap[keyPath: item.keyPath]
                            if val == "–" {
                                Text(NSLocalizedString("checkin.noData", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(TR.Palette.textTertiary)
                            } else {
                                Text(val)
                                    .font(TR.Font.number(.subheadline, weight: .bold))
                                    .foregroundStyle(TR.Palette.textPrimary)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TR.Palette.mint)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .trCard(tint: TR.Palette.coral)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: visibleItems)
    }

    // MARK: Sequence

    private func run() async {
        guard !didStart else { return }
        didStart = true
        let newSave = vm.lastSaveWasNew
        displayedStreak = newSave ? max(0, streakDays - 1) : streakDays

        // Apple Health auto-populate runs in parallel with the celebration.
        async let populate: () = {
            if let checkin = vm.savedCheckin {
                await HealthKitService.shared.autoPopulateCheckin(checkin)
                await MainActor.run {
                    // Re-evaluate badges / "Sync Apple Health" challenge now that HK data landed.
                    gamificationVM.refresh()
                    hkValues = HKSnapshot(
                        hrv:   checkin.hrv.map    { String(format: "%.0f ms", $0) } ?? "–",
                        sleep: checkin.sleepHours.map { String(format: "%.1f hrs", $0) } ?? "–",
                        steps: checkin.stepCount.map  { "\($0)" } ?? "–",
                        hr:    checkin.restingHR.map  { String(format: "%.0f bpm", $0) } ?? "–"
                    )
                }
            }
        }()

        if reduceMotion {
            heroIn = true; xpIn = true
            displayedStreak = streakDays
            ticked = todaysQuests.count
            visibleItems = healthItems.count
            _ = await populate
            showInsight = true
            return
        }

        withAnimation(TR.Motion.pop) { heroIn = true }
        confetti += 1
        try? await Task.sleep(for: .seconds(0.35))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { xpIn = true }
        if newSave { HapticManager.shared.xpEarned() }
        try? await Task.sleep(for: .seconds(0.35))
        displayedStreak = streakDays
        for i in 1...max(1, todaysQuests.count) {
            try? await Task.sleep(for: .seconds(0.22))
            withAnimation(TR.Motion.pop) { ticked = i }
        }
        for i in 1...healthItems.count {
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation { visibleItems = i }
        }
        _ = await populate
        withAnimation(TR.Motion.gentle) { showInsight = true }
    }

    private func finish() {
        vm.navigationPath = []
    }
}

// MARK: - HKSnapshot (display values for CompletionView)

struct HKSnapshot {
    let hrv: String
    let sleep: String
    let steps: String
    let hr: String
}

// MARK: - InsightCard

struct InsightCard: View {
    let result: InsightResult

    private var accentColor: Color {
        switch result.type {
        case .warning:  return TR.Palette.tangerine
        case .positive: return TR.Palette.mint
        case .neutral:  return TR.Palette.sky
        }
    }

    private var icon: String {
        switch result.type {
        case .warning:  return "exclamationmark.triangle.fill"
        case .positive: return "checkmark.seal.fill"
        case .neutral:  return "lightbulb.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    TRKicker(Text(NSLocalizedString("checkin14.insightKicker", value: "Today's insight", comment: "")), color: accentColor)
                    Text(result.message)
                        .font(.subheadline)
                        .foregroundStyle(TR.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            DisclaimerBanner(type: .insight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: accentColor)
    }
}
