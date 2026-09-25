import SwiftUI

// MARK: - Screen (tab root)

/// Achievements as a full screen: scrolls, TRBackground, share in the toolbar.
/// Use this as a tab root / navigation destination. `GamificationHomeView` alone is the
/// non-scrolling content (for embedding inside an existing ScrollView).
struct AchievementsScreen: View {
    @ObservedObject var viewModel: GamificationViewModel
    @State private var shareKind: ShareCardKind?

    var body: some View {
        ScrollView {
            GamificationHomeView(viewModel: viewModel)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(TRBackground(glow: TR.RankCover.forLevel(viewModel.currentLevel).colors.first ?? TR.Palette.coral, glowOpacity: 0.16))
        .navigationTitle(Text(verbatim: NSLocalizedString("tab.achievements", comment: "")))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { shareKind = .rank } label: {
                    Label(gLoc("ach.share", "Share"), systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("achievements-share")
            }
        }
        .sheet(item: $shareKind) { kind in
            ShareCardSheet(kind: kind, data: .from(viewModel))
        }
        .refreshable { viewModel.refresh() }
    }
}

// MARK: - Content

/// Achievements content: passport, persona, streaks, daily challenge, quests, badge wall.
/// Not scrollable on purpose — wrap in a ScrollView (see `AchievementsScreen`).
struct GamificationHomeView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @State private var shareKind: ShareCardKind?

    var body: some View {
        VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing) {
            PassportCard(viewModel: viewModel) { shareKind = .rank }
                .trRevealOnAppear()
            PersonaCard(persona: viewModel.persona, checkins: viewModel.facts.checkins)
                .trRevealOnAppear(delay: 0.05)
            streaks
                .trRevealOnAppear(delay: 0.1)
            if let challenge = viewModel.dailyChallenge {
                DailyChallengeCard(quest: challenge)
                    .trRevealOnAppear(delay: 0.15)
            }
            QuestSection(viewModel: viewModel)
                .trRevealOnAppear(delay: 0.18)
            BadgeWallGrid(viewModel: viewModel)
        }
        .padding(TR.Metrics.gutter)
        .padding(.bottom, 24)
        .sheet(item: $shareKind) { kind in
            ShareCardSheet(kind: kind, data: .from(viewModel))
        }
    }

    // MARK: Streaks

    private var streaks: some View {
        let checkin = viewModel.streakStates["checkin"]
        let injection = viewModel.streakStates["injection"]
        let days = viewModel.checkinStreakDays
        let weeks = viewModel.injectionStreakWeeks
        return VStack(alignment: .leading, spacing: 12) {
            TRSectionHeader(Text(verbatim: gLoc("ach.streaks.title", "Streaks")))
            HStack(alignment: .top, spacing: 12) {
                StreakCard(
                    title: gLoc("ach.streaks.checkin", "Check-in streak"),
                    count: days,
                    unit: days == 1 ? gLoc("ach.unit.day", "day") : gLoc("ach.unit.days", "days"),
                    best: max(checkin?.bestCount ?? 0, viewModel.facts.longestCheckinStreak, days),
                    flame: GamificationViewModel.flameLevel(forDays: days),
                    symbol: "flame.fill",
                    onShare: days > 0 ? { shareKind = .streak } : nil
                )
                StreakCard(
                    title: gLoc("ach.streaks.injection", "On-time injections"),
                    count: weeks,
                    unit: weeks == 1 ? gLoc("ach.unit.week", "week") : gLoc("ach.unit.weeks", "weeks"),
                    best: max(injection?.bestCount ?? 0, viewModel.facts.longestOnScheduleWeeks, weeks),
                    flame: GamificationViewModel.flameLevel(forWeeks: weeks),
                    symbol: "calendar.badge.checkmark",
                    onShare: nil
                )
            }
        }
    }
}

// MARK: - Passport card

struct PassportCard: View {
    @ObservedObject var viewModel: GamificationViewModel
    var onShare: () -> Void

    var body: some View {
        let level = viewModel.currentLevel
        let cover = TR.RankCover.forLevel(level)
        let ink = cover.ink
        let isMax = level >= 11
        let badges = viewModel.badgeProgress.filter(\.isUnlocked).count
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "\(gLoc("ach.passport.kicker", "Protocol passport")) · \(cover.displayName)".uppercased())
                        .font(.caption.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(ink.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(verbatim: viewModel.levelName)
                        .font(TR.Font.display(.largeTitle, weight: .black))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(verbatim: String(format: gLoc("ach.levelN", "Level %d"), level))
                        .font(TR.Font.display(.subheadline, weight: .bold))
                        .foregroundStyle(ink.opacity(0.8))
                }
                Spacer(minLength: 0)
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ink)
                        .frame(width: TR.Metrics.minTap, height: TR.Metrics.minTap)
                        .background(ink.opacity(0.12), in: Circle())
                        .overlay(Circle().strokeBorder(ink.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.trPressable)
                .accessibilityLabel(Text(verbatim: gLoc("ach.share.title.rank", "Share your rank")))
                .accessibilityIdentifier("passport-share")
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ink.opacity(0.15))
                        Capsule()
                            .fill(ink.opacity(0.85))
                            .frame(width: max(8, proxy.size.width * (isMax ? 1 : viewModel.levelProgressPercent)))
                    }
                }
                .frame(height: 8)
                HStack {
                    Text(verbatim: String(format: gLoc("ach.xpTotal", "%@ XP"), viewModel.currentXP.formatted()))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Spacer()
                    Text(verbatim: isMax
                         ? gLoc("ach.passport.topRank", "Top rank")
                         : String(format: gLoc("ach.passport.toNext", "%d XP to %@"), viewModel.xpUntilNextLevel, GamificationCatalog.levelName(level + 1)))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(ink)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips(ink: ink, badges: badges) }
                VStack(alignment: .leading, spacing: 8) { chips(ink: ink, badges: badges) }
            }
        }
        .padding(20)
        .background {
            ZStack {
                shape.fill(cover.gradient)
                // Faint trough wave watermark.
                TroughWaveShape()
                    .stroke(ink.opacity(0.1), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 110)
                    .offset(x: 110, y: 10)
                shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear, .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .clipShape(shape)
        }
        .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .holoSheen(cornerRadius: 24)
        .shadow(color: (cover.colors.last ?? .clear).opacity(0.4), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("passport-card")
    }

    @ViewBuilder
    private func chips(ink: Color, badges: Int) -> some View {
        if viewModel.checkinStreakDays > 0 {
            chip(String(format: gLoc("ach.chip.streak", "%d-day streak"), viewModel.checkinStreakDays), "flame.fill", ink: ink)
        }
        chip(String(format: gLoc("ach.chip.badges", "%d/%d badges"), badges, GamificationCatalog.badges.count), "rosette", ink: ink)
        if viewModel.injectionStreakWeeks > 0 {
            chip(String(format: gLoc("ach.chip.weeks", "%d wks on time"), viewModel.injectionStreakWeeks), "syringe.fill", ink: ink)
        }
    }

    private func chip(_ text: String, _ symbol: String, ink: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).imageScale(.small)
            Text(verbatim: text).lineLimit(1).fixedSize()
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ink.opacity(0.14), in: Capsule())
    }
}

// MARK: - Persona

struct PersonaCard: View {
    let persona: Persona?
    let checkins: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TRKicker(Text(verbatim: gLoc("ach.persona.kicker", "Your protocol persona")))
            if let persona {
                Label {
                    Text(verbatim: persona.title)
                        .font(TR.Font.display(.title2, weight: .heavy))
                } icon: {
                    Image(systemName: persona.symbol)
                        .foregroundStyle(TR.Palette.teal)
                }
                .foregroundStyle(TR.Palette.textPrimary)
                Text(verbatim: persona.tagline)
                    .font(.body)
                    .foregroundStyle(TR.Palette.textSecondary)
            } else {
                Label {
                    Text(verbatim: gLoc("ach.persona.lockedTitle", "Still taking notes"))
                        .font(TR.Font.display(.title3, weight: .heavy))
                } icon: {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(TR.Palette.textTertiary)
                }
                .foregroundStyle(TR.Palette.textPrimary)
                Text(verbatim: String(format: gLoc("ach.persona.locked", "Your logging style is revealed after %d check-ins (%d so far)."),
                                      Persona.minimumCheckins, min(checkins, Persona.minimumCheckins)))
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textSecondary)
                TRProgressBar(value: Double(checkins) / Double(Persona.minimumCheckins), height: 6,
                              colors: [TR.Palette.teal, TR.Palette.sky])
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: persona == nil ? TR.Palette.deepBlue : TR.Palette.teal)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Streak card

struct StreakCard: View {
    let title: String
    let count: Int
    let unit: String
    let best: Int
    let flame: Int
    let symbol: String
    var onShare: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                StreakFlameEmblem(level: flame, size: 52, symbol: symbol)
                Spacer(minLength: 0)
                if let onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TR.Palette.textSecondary)
                            .frame(width: TR.Metrics.minTap, height: TR.Metrics.minTap)
                    }
                    .accessibilityLabel(Text(verbatim: gLoc("ach.share.title.streak", "Share your streak")))
                    .accessibilityIdentifier("streak-share")
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                CountUp(count)
                    .font(TR.Font.number(36))
                    .foregroundStyle(count > 0 ? AnyShapeStyle(TR.Gradients.xp) : AnyShapeStyle(TR.Palette.textTertiary))
                Text(verbatim: unit)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(verbatim: "\(FlameTier.name(flame)) · \(String(format: gLoc("ach.streaks.best", "best %d"), best))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TR.Palette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: flame > 0 ? FlameTier.colors(flame).last : nil, padding: 14)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AchievementsScreen(viewModel: GamificationViewModel())
    }
    .preferredColorScheme(.dark)
}
#endif
