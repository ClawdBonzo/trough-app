import SwiftUI
import Charts

// Trough 1.4 dashboard building blocks. Everything here is presentational: the
// dashboard view passes in derived values (never stores computed state).

/// Localized string with an English fallback (keys live in the
/// "// MARK: 1.4 dashboard" section of en.lproj/Localizable.strings).
func dashL(_ key: String, _ english: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: english, comment: "")
}

enum DashboardScreenshotMode {
    /// `-TRScreenshotMode` launch argument: hide transient banners and tips.
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-TRScreenshotMode") }
}

// MARK: - Card header

/// Icon tile + kicker (+ optional trailing view) used at the top of every dashboard card.
struct DashCardHeader<Trailing: View>: View {
    let icon: String
    let title: String
    var tint: Color = TR.Palette.coral
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            TRKicker(Text(title), color: TR.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 6)
            trailing()
        }
    }
}

extension DashCardHeader where Trailing == EmptyView {
    init(icon: String, title: String, tint: Color = TR.Palette.coral) {
        self.init(icon: icon, title: title, tint: tint) { EmptyView() }
    }
}

// MARK: - Delta pill

/// "+4 vs last week" style pill. Green-ish teal up, coral down.
struct DashDeltaPill: View {
    let delta: Double
    var format: String = "%+.0f"
    var suffix: String? = nil

    var body: some View {
        let up = delta >= 0
        let tint = up ? TR.Palette.teal : TR.Palette.coral
        HStack(spacing: 4) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.heavy))
            Text(String(format: format, delta) + (suffix.map { " \($0)" } ?? ""))
                .font(.caption.weight(.heavy))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Trough wave (brand motif)

/// A soft PK-style wave with a white-hot dot at the trough. Decorative.
struct TroughWaveMotif: View {
    var color: Color
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let path = Path { p in
                let steps = 60
                for i in 0...steps {
                    let x = w * CGFloat(i) / CGFloat(steps)
                    let t = Double(i) / Double(steps) * 2 * .pi * 1.5
                    // Fast rise, slow decay — a stylised injection cycle.
                    let phase = t.truncatingRemainder(dividingBy: 2 * .pi) / (2 * .pi)
                    let v = phase < 0.18 ? phase / 0.18 : exp(-(phase - 0.18) * 2.4)
                    let y = h * 0.85 - CGFloat(v) * h * 0.65
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            path.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 1. Protocol Card (rank hero)

struct DashboardProtocolCard: View {
    let level: Int
    let levelName: String
    let progress: Double
    let xpToNext: Int
    let totalXP: Int
    let checkinStreakDays: Int
    let injectionStreakWeeks: Int
    let showsInjectionStreak: Bool
    let badgesUnlocked: Int
    let badgesTotal: Int

    private var cover: TR.RankCover { TR.RankCover.forLevel(level) }
    private var isMax: Bool { level >= 11 }

    var body: some View {
        let ink = cover.ink
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    TRKicker(Text(String(format: dashL("dash.hero.rankKicker", "Rank · %@"), cover.displayName)),
                             color: ink.opacity(0.7))
                    Text(levelName)
                        .font(TR.Font.display(34, weight: .black))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                levelSeal(ink: ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                TRProgressBar(value: isMax ? 1 : progress, height: 10,
                              colors: [ink.opacity(0.75), ink],
                              trackColor: ink.opacity(0.14), glow: false)
                HStack {
                    Text(isMax
                         ? dashL("dash.hero.maxRank", "Top rank reached")
                         : String(format: dashL("dash.hero.xpToNext", "%1$d XP to %2$@"),
                                  xpToNext, GamificationCatalog.levelName(level + 1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ink.opacity(0.8))
                    Spacer()
                    Text(String(format: dashL("dash.hero.totalXP", "%d XP"), totalXP))
                        .font(.caption.weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(ink.opacity(0.65))
                }
            }

            HStack(spacing: 8) {
                chip(icon: "flame.fill",
                     text: String(format: dashL("dash.hero.streakDays", "%d-day streak"), checkinStreakDays),
                     ink: ink)
                if showsInjectionStreak {
                    chip(icon: "syringe.fill",
                         text: String(format: dashL("dash.hero.onScheduleWeeks", "%d wk on time"), injectionStreakWeeks),
                         ink: ink)
                }
                chip(icon: "medal.fill", text: "\(badgesUnlocked)/\(badgesTotal)", ink: ink)
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background {
            ZStack {
                shape.fill(cover.gradient)
                TroughWaveMotif(color: ink.opacity(0.07), lineWidth: 10)
                    .padding(.top, 40)
                    .clipShape(shape)
                shape.fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                    .blendMode(.softLight)
            }
            .shadow(color: (cover.colors.last ?? TR.Palette.gold).opacity(0.35), radius: 22, y: 10)
        }
        .overlay(shape.strokeBorder(.white.opacity(0.45), lineWidth: 1).blendMode(.overlay))
        .holoSheen(cornerRadius: 26, period: 5.5, intensity: 0.32)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: dashL("dash.hero.a11y", "Level %1$d, %2$@. %3$d XP to next level. %4$d-day check-in streak. %5$d of %6$d badges."),
            level, levelName, xpToNext, checkinStreakDays, badgesUnlocked, badgesTotal)))
        .accessibilityHint(Text(dashL("dash.hero.a11yHint", "Opens achievements")))
        .accessibilityAddTraits(.isButton)
    }

    private func levelSeal(ink: Color) -> some View {
        VStack(spacing: -2) {
            Text(dashL("dash.hero.lv", "LV"))
                .font(.caption2.weight(.heavy))
                .tracking(1)
                .foregroundStyle(ink.opacity(0.65))
            Text("\(level)")
                .font(TR.Font.number(28))
                .foregroundStyle(ink)
        }
        .frame(width: 60, height: 60)
        .background(Circle().fill(.white.opacity(0.28)))
        .overlay(Circle().strokeBorder(ink.opacity(0.25), lineWidth: 1.5))
    }

    private func chip(icon: String, text: String, ink: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2.weight(.heavy))
            Text(text).font(.caption.weight(.heavy)).monospacedDigit().lineLimit(1)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.3)))
        .overlay(Capsule().strokeBorder(ink.opacity(0.15), lineWidth: 1))
        .fixedSize()
    }
}

// MARK: - 2. Protocol Score

struct DashboardScoreCard: View {
    let score: Double
    let interpretation: String
    let trend: Double
    let hasPriorWeek: Bool
    let sevenDayAvg: Double
    /// Oldest → newest, up to 7 (date, score 0–100).
    let week: [(date: Date, score: Double)]
    let hasData: Bool
    var onLogToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashCardHeader(icon: "gauge.with.dots.needle.67percent",
                           title: NSLocalizedString("dashboard.protocolScore", comment: "")) {
                if hasPriorWeek {
                    DashDeltaPill(delta: trend, suffix: dashL("dash.score.vsLastWeek", "vs last wk"))
                }
            }

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [TR.Palette.coral.opacity(0.28), .clear],
                                             center: .center, startRadius: 10, endRadius: 90))
                        .scaleEffect(1.25)
                    TRRing(progress: score / 100, lineWidth: 14,
                           colors: [TR.Palette.coralDeep, TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]) {
                        VStack(spacing: 0) {
                            CountUp(Int(score.rounded()))
                                .font(TR.Font.number(44))
                                .foregroundStyle(TR.Palette.textPrimary)
                            Text(NSLocalizedString("onboarding.outOf100", comment: ""))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(TR.Palette.textTertiary)
                        }
                    }
                }
                .frame(width: 148, height: 148)

                VStack(alignment: .leading, spacing: 10) {
                    Text(hasData ? interpretation : dashL("dash.score.noData", "No check-ins yet"))
                        .font(TR.Font.display(.title3, weight: .heavy))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if hasData {
                        Text(String(format: dashL("dash.score.avg7", "7-day avg %.0f"), sevenDayAvg))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TR.Palette.textSecondary)
                        weekBars
                    } else {
                        Button(action: onLogToday) {
                            Label(NSLocalizedString("dashboard.logToday", comment: ""), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(TR.Palette.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }

            DisclaimerBanner(type: .protocolScore)
        }
        .trCard(tint: TR.Palette.coral)
    }

    private var weekBars: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(week.enumerated()), id: \.offset) { idx, day in
                VStack(spacing: 4) {
                    Capsule()
                        .fill(LinearGradient(colors: [TR.Palette.gold, TR.Palette.coral],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(idx == week.count - 1 ? 1 : 0.55)
                        .frame(width: 10, height: max(6, 38 * day.score / 100))
                    Text(String(SharedFormatters.weekdayShort.string(from: day.date).prefix(1)))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TR.Palette.textTertiary)
                }
            }
        }
        .frame(height: 54, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - 3a. Check-in CTA

struct DashboardCheckinCTA: View {
    let isCheckedIn: Bool
    let xpEarned: Int
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        if isCheckedIn {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(TR.Palette.mint)
                        .trGlow(TR.Palette.mint, radius: 10, opacity: 0.5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dashL("dash.today.checkedIn", "Checked in ✓"))
                            .font(TR.Font.display(.headline))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text(dashL("dash.today.checkedInSub", "Tap to review today's log"))
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                    Spacer()
                    Text(String(format: dashL("dash.today.xpEarned", "+%d XP"), xpEarned))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(TR.Palette.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TR.Palette.gold.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(TR.Palette.gold.opacity(0.35), lineWidth: 1))
                }
                .trCard(tint: TR.Palette.mint)
            }
            .buttonStyle(.trPressable)
        } else {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text(NSLocalizedString("dashboard.dailyCheckin", comment: ""))
                    Spacer(minLength: 4)
                    Text(String(format: dashL("dash.today.xpEarned", "+%d XP"), xpEarned))
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(TRPrimaryButtonStyle())
            .scaleEffect(pulse ? 1.015 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
            }
            .accessibilityHint(Text(NSLocalizedString("dashboard.tapToLog", comment: "")))
        }
    }
}

// MARK: - 3b. Next injection countdown

struct DashboardNextInjectionTile: View {
    let compound: String
    let daysUntil: Int
    let overdueDays: Int

    var body: some View {
        let overdue = overdueDays > 0
        let tint = overdue ? TR.Palette.coral : TR.Palette.sky
        VStack(alignment: .leading, spacing: 8) {
            DashCardHeader(icon: "syringe.fill", title: dashL("dash.today.nextShot", "Next injection"), tint: tint)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if overdue {
                    Text("\(overdueDays)")
                        .font(TR.Font.number(34))
                        .foregroundStyle(TR.Palette.coral)
                    Text(dashL("dash.today.daysLate", "days late"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.coral)
                } else if daysUntil == 0 {
                    Text(dashL("dash.today.dueToday", "Today"))
                        .font(TR.Font.display(30, weight: .black))
                        .foregroundStyle(TR.Palette.textPrimary)
                } else {
                    Text("\(daysUntil)")
                        .font(TR.Font.number(34))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(daysUntil == 1 ? dashL("dash.today.day", "day") : dashL("dash.today.days", "days"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textSecondary)
                }
            }
            Text(compound)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: tint)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 3c. Daily challenge

struct DashboardDailyChallengeCard: View {
    let challenge: QuestDisplayModel

    private var title: String {
        // Catalog titles read "Daily Challenge: X" — the kicker already says that.
        let t = challenge.title
        if let r = t.range(of: ": ") { return String(t[r.upperBound...]) }
        return t
    }

    var body: some View {
        let done = challenge.isCompleted
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? AnyShapeStyle(TR.Palette.mint.opacity(0.18))
                               : AnyShapeStyle(LinearGradient(colors: TR.Gradients.xpColors, startPoint: .top, endPoint: .bottom)))
                    .frame(width: 48, height: 48)
                Image(systemName: done ? "checkmark" : "bolt.fill")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(done ? TR.Palette.mint : Color(trHex: 0x3A2600))
            }
            .trGlow(done ? TR.Palette.mint : TR.Palette.gold, radius: 12, opacity: done ? 0.25 : 0.45)
            VStack(alignment: .leading, spacing: 3) {
                TRKicker(Text(dashL("dash.challenge.kicker", "Daily challenge")), color: TR.Palette.gold)
                Text(title)
                    .font(TR.Font.display(.headline))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .strikethrough(done, color: TR.Palette.textTertiary)
                Text(done ? dashL("dash.challenge.done", "Complete — see you tomorrow") : challenge.description)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Text(String(format: dashL("dash.today.xpEarned", "+%d XP"), challenge.xpReward))
                .font(.caption.weight(.heavy))
                .foregroundStyle(done ? TR.Palette.textTertiary : TR.Palette.gold)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background((done ? Color.white.opacity(0.06) : TR.Palette.gold.opacity(0.14)), in: Capsule())
        }
        .trCard(tint: done ? TR.Palette.mint : TR.Palette.gold)
        .opacity(done ? 0.85 : 1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 5. Next badge

struct DashboardNextBadgeCard: View {
    let badge: BadgeProgressModel

    var body: some View {
        HStack(spacing: 16) {
            BadgeMedallion(systemImage: badge.def.symbol, tier: badge.def.tier, status: .locked,
                           progress: badge.fraction, size: 64, glow: false)
            VStack(alignment: .leading, spacing: 4) {
                TRKicker(Text(dashL("dash.badge.kicker", "Next badge")), color: TR.Palette.gold)
                Text(badge.def.title)
                    .font(TR.Font.display(.headline))
                    .foregroundStyle(TR.Palette.textPrimary)
                Text(Self.remainingLine(badge))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if badge.target > 1 {
                    TRProgressBar(value: badge.fraction, height: 6)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(TR.Palette.textTertiary)
        }
        .trCard(tint: TR.Palette.gold)
        .accessibilityElement(children: .combine)
    }

    static func remainingLine(_ b: BadgeProgressModel) -> String {
        let n = max(0, b.target - b.current)
        switch b.def.metric {
        case .checkins:
            return String(format: dashL("dash.badge.moreCheckins", "%d more check-ins"), n)
        case .checkinStreak, .daysSinceFirstCheckin, .supplementDays30:
            return String(format: dashL("dash.badge.moreDays", "%d more days"), n)
        case .injections:
            return String(format: dashL("dash.badge.moreInjections", "%d more injections"), n)
        case .onScheduleWeeks:
            return String(format: dashL("dash.badge.moreWeeks", "%d more on-schedule weeks"), n)
        case .bloodworkPanels:
            return String(format: dashL("dash.badge.morePanels", "%d more bloodwork panels"), n)
        case .level:
            return String(format: dashL("dash.badge.reachLevel", "Reach level %d"), b.target)
        default:
            return b.target > 1
                ? String(format: dashL("dash.badge.toGo", "%d to go"), n)
                : b.def.howTo
        }
    }
}

// MARK: - 6. Persona

struct DashboardPersonaCard: View {
    let persona: Persona

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: persona.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(colors: [TR.Palette.lilac, TR.Palette.sky], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .trGlow(TR.Palette.lilac, radius: 12, opacity: 0.45)
            VStack(alignment: .leading, spacing: 3) {
                TRKicker(Text(dashL("dash.persona.kicker", "Your logging style")), color: TR.Palette.lilac)
                Text(persona.title)
                    .font(TR.Font.display(.title3, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
                Text(persona.tagline)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .trCard(tint: TR.Palette.lilac)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Compliance ring tile

struct DashboardRingTile: View {
    let progress: Double
    let valueText: String
    let title: String
    let subtitle: String
    let colors: [Color]
    var showsPlus = false

    var body: some View {
        HStack(spacing: 12) {
            TRRing(progress: progress, lineWidth: 6, colors: colors) {
                if showsPlus {
                    Image(systemName: "plus").font(.subheadline.weight(.bold)).foregroundStyle(TR.Palette.textSecondary)
                } else {
                    Text(valueText)
                        .font(TR.Font.number(13, weight: .heavy))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(padding: 12)
    }
}

// MARK: - Pro lock overlay

struct DashboardProLockOverlay: View {
    let icon: String
    let title: String
    let message: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: TR.Gradients.ctaColors, startPoint: .top, endPoint: .bottom))
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(TR.Palette.coral)
                    .padding(5)
                    .background(Circle().fill(.white))
                    .offset(x: 20, y: 20)
            }
            .trGlow(TR.Palette.coral, radius: 16, opacity: 0.5)
            TRKicker(Text(dashL("dash.pro.kicker", "Trough Pro")), color: TR.Palette.gold)
            Text(title)
                .font(TR.Font.display(.title3, weight: .heavy))
                .foregroundStyle(TR.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(TR.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(NSLocalizedString("dashboard.startFreeTrial", comment: ""))
            }
            .buttonStyle(TRPrimaryButtonStyle(fullWidth: false))
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [TR.Palette.surface.opacity(0.35), TR.Palette.surface.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Banner

/// Slim tinted banner used for trial / grace / tips.
struct DashboardBanner<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            trailing()
        }
        .trCard(tint: tint, padding: 14)
    }
}

// MARK: - Area + line chart helpers

extension LinearGradient {
    static func dashArea(_ color: Color, top: Double = 0.35) -> LinearGradient {
        LinearGradient(colors: [color.opacity(top), color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
    }
}
