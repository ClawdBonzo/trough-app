import SwiftUI
import UniformTypeIdentifiers

// Share cards for Trough 1.4: rank ("passport"), check-in streak and badge.
//
// HEALTH SAFETY — cards show ONLY counts, ranks, streak lengths and badge names. Never doses,
// compounds, lab values, symptom ratings or scores tied to health outcomes. `ShareCardData` is
// the whitelist: if a value isn't in it, it can't end up on a card.

// MARK: - Data (whitelist)

struct ShareCardData: Equatable {
    var level: Int
    var levelName: String
    var checkinStreak: Int
    var bestCheckinStreak: Int
    var injectionWeeks: Int
    var badgesUnlocked: Int
    var badgesTotal: Int
    /// Up to six unlocked badge ids, most prestigious first (shown as a medallion row).
    var showcaseBadgeIDs: [String]

    var cover: TR.RankCover { .forLevel(level) }

    @MainActor
    static func from(_ vm: GamificationViewModel) -> ShareCardData {
        let unlocked = vm.badgeProgress.filter(\.isUnlocked)
        let checkin = vm.streakStates["checkin"]
        return ShareCardData(
            level: vm.currentLevel,
            levelName: vm.levelName,
            checkinStreak: vm.checkinStreakDays,
            bestCheckinStreak: max(checkin?.bestCount ?? 0, vm.facts.longestCheckinStreak, vm.checkinStreakDays),
            injectionWeeks: vm.injectionStreakWeeks,
            badgesUnlocked: unlocked.count,
            badgesTotal: GamificationCatalog.badges.count,
            showcaseBadgeIDs: unlocked.map(\.def).sorted { $0.prestige > $1.prestige }.prefix(6).map(\.id)
        )
    }

    /// Live data from the running gamification VM (falls back to a neutral card).
    @MainActor
    static var current: ShareCardData {
        if let vm = GamificationViewModel.active { return from(vm) }
        #if DEBUG
        return .sample
        #else
        return ShareCardData(level: 1, levelName: GamificationCatalog.levelName(1), checkinStreak: 0, bestCheckinStreak: 0,
                             injectionWeeks: 0, badgesUnlocked: 0, badgesTotal: GamificationCatalog.badges.count, showcaseBadgeIDs: [])
        #endif
    }

    /// Showcase values for previews, screenshots and asset export.
    static let sample = ShareCardData(
        level: 7,
        levelName: GamificationCatalog.levelName(7),
        checkinStreak: 112,
        bestCheckinStreak: 112,
        injectionWeeks: 16,
        badgesUnlocked: 24,
        badgesTotal: GamificationCatalog.badges.count,
        showcaseBadgeIDs: ["checkin_streak_100", "consistency_king", "checkins_100", "on_schedule_weeks_12", "injections_52", "bloodwork_5"]
    )
}

// MARK: - Kind

enum ShareCardKind: Identifiable, Equatable {
    case rank
    case streak
    case badge(BadgeDef)

    var id: String {
        switch self {
        case .rank: return "rank"
        case .streak: return "streak"
        case .badge(let def): return "badge.\(def.id)"
        }
    }

    var fileStem: String {
        switch self {
        case .rank: return "trough-rank"
        case .streak: return "trough-streak"
        case .badge(let def): return "trough-badge-\(def.id)"
        }
    }

    var title: String {
        switch self {
        case .rank: return gLoc("ach.share.title.rank", "Share your rank")
        case .streak: return gLoc("ach.share.title.streak", "Share your streak")
        case .badge: return gLoc("ach.share.title.badge", "Share this badge")
        }
    }
}

// MARK: - Badge art helpers

extension BadgeDef {
    /// Per-badge disc gradient from the catalog tint.
    var discColors: [Color] { tint.map { Color(hex: $0) } }
    var accentColor: Color { discColors.first ?? tier.glowColor }
}

// MARK: - Flame tiers

enum FlameTier {
    /// Disc colours for a flame level 0…5 (0 = no streak, 5 = white-hot).
    static func colors(_ level: Int) -> [Color] {
        switch level {
        case ..<1: return [TR.Palette.textTertiary, TR.Palette.surfaceRaised]
        case 1:    return [TR.Palette.gold, TR.Palette.tangerine]
        case 2:    return [TR.Palette.tangerine, Color(trHex: 0xFF5E3A)]
        case 3:    return [TR.Palette.coralLight, TR.Palette.coral]
        case 4:    return [Color(trHex: 0xFF7AC6), TR.Palette.coralDeep]
        default:   return [TR.Palette.lilac, TR.Palette.coral, TR.Palette.gold, Color(trHex: 0xFFF1C1)]
        }
    }

    static func name(_ level: Int) -> String {
        switch level {
        case ..<1: return gLoc("ach.flame.0", "Unlit")
        case 1:    return gLoc("ach.flame.1", "Spark")
        case 2:    return gLoc("ach.flame.2", "Kindled")
        case 3:    return gLoc("ach.flame.3", "Blazing")
        case 4:    return gLoc("ach.flame.4", "Inferno")
        default:   return gLoc("ach.flame.5", "White-hot")
        }
    }
}

// MARK: - Streak flame emblem

/// Glossy flame disc with a gold ring. Tier colours come from `FlameTier`.
struct StreakFlameEmblem: View {
    var level: Int
    var size: CGFloat = 120
    var glow: Bool = true
    var symbol: String = "flame.fill"

    var body: some View {
        let colors = FlameTier.colors(level)
        let lit = level > 0
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(colors: lit ? BadgeTier.gold.ringColors : BadgeTier.silver.ringColors.map { $0.opacity(0.5) },
                                    center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                    lineWidth: size * 0.075
                )
                .shadow(color: glow && lit ? (colors.last ?? TR.Palette.coral).opacity(0.7) : .clear, radius: size * 0.18)
            Circle()
                .fill(RadialGradient(colors: colors.reversed(), center: UnitPoint(x: 0.5, y: 0.75), startRadius: 0, endRadius: size * 0.55))
                .padding(size * 0.11)
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05), .black.opacity(0.25)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: max(1, size * 0.02))
                .padding(size * 0.11)
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.54, height: size * 0.28)
                .offset(y: -size * 0.18)
                .blendMode(.plusLighter)
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: size * 0.03, y: size * 0.02)
                .offset(y: size * 0.01)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Trough wave (brand motif)

/// The brand curve: a wave dipping to a trough, with a white-hot dot at the low point.
struct TroughWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.18))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.92),
                   control1: CGPoint(x: rect.minX + w * 0.2, y: rect.minY + h * 0.05),
                   control2: CGPoint(x: rect.minX + w * 0.32, y: rect.minY + h * 0.92))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.08),
                   control1: CGPoint(x: rect.minX + w * 0.7, y: rect.minY + h * 0.92),
                   control2: CGPoint(x: rect.minX + w * 0.8, y: rect.minY))
        return p
    }
}

// MARK: - Rank emblem

/// The rank "passport" cover: rank gradient booklet with the trough wave, level and rank name.
struct RankEmblem: View {
    var level: Int
    /// Width; height is 1.38×.
    var width: CGFloat = 130
    var shadow: Bool = true

    var body: some View {
        let cover = TR.RankCover.forLevel(level)
        let h = width * 1.38
        let shape = RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
        ZStack {
            shape.fill(cover.gradient)
            // Spine shade.
            shape.fill(LinearGradient(colors: [.black.opacity(0.18), .clear], startPoint: .leading, endPoint: UnitPoint(x: 0.12, y: 0.5)))
            // Foil gloss.
            shape.fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .blendMode(.plusLighter)
            shape.inset(by: width * 0.06)
                .strokeBorder(cover.ink.opacity(0.28), lineWidth: max(0.8, width * 0.01))
            VStack(spacing: width * 0.055) {
                Text(verbatim: "TROUGH")
                    .font(.system(size: width * 0.085, weight: .heavy, design: .rounded))
                    .tracking(width * 0.03)
                    .foregroundStyle(cover.ink.opacity(0.75))
                ZStack {
                    Circle()
                        .strokeBorder(cover.ink.opacity(0.55), lineWidth: max(1, width * 0.018))
                    TroughWaveShape()
                        .stroke(cover.ink.opacity(0.85), style: StrokeStyle(lineWidth: max(1.2, width * 0.03), lineCap: .round))
                        .frame(width: width * 0.3, height: width * 0.16)
                    Circle()
                        .fill(cover.ink)
                        .frame(width: width * 0.05, height: width * 0.05)
                        .offset(y: width * 0.065)
                }
                .frame(width: width * 0.44, height: width * 0.44)
                Text(verbatim: "\(level)")
                    .font(.system(size: width * 0.26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(cover.ink)
                    .padding(.vertical, -width * 0.04)
                Text(verbatim: "\(cover.displayName.uppercased()) · \(gLoc("ach.rank.level", "LEVEL"))")
                    .font(.system(size: width * 0.07, weight: .heavy, design: .rounded))
                    .tracking(width * 0.015)
                    .foregroundStyle(cover.ink.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: width, height: h)
        .shadow(color: shadow ? .black.opacity(0.4) : .clear, radius: width * 0.12, y: width * 0.07)
        .accessibilityHidden(true)
    }
}

// MARK: - Card view

/// A share card. Designed on a point canvas (360 wide) and rendered at 3× by `ShareRenderer`.
struct TRShareCardView: View {
    let kind: ShareCardKind
    let data: ShareCardData
    let format: TRShareFormat

    private var isStory: Bool { format == .story }
    private let ink = Color.white
    private let secondaryInk = Color.white.opacity(0.72)

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ShareCardFooter(compact: !isStory)
            }
            .padding(.horizontal, 22)
            .padding(.top, isStory ? 50 : 22)
            .padding(.bottom, isStory ? 30 : 16)
        }
        .foregroundStyle(ink)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Background

    private var glowColor: Color {
        switch kind {
        case .rank: return data.cover.colors.first ?? TR.Palette.gold
        case .streak: return TR.Palette.tangerine
        case .badge(let def): return def.accentColor
        }
    }

    private var background: some View {
        ZStack {
            TR.Gradients.sunset
            RadialGradient(colors: [glowColor.opacity(0.45), glowColor.opacity(0.1), .clear],
                           center: UnitPoint(x: 0.5, y: isStory ? 0.3 : 0.32), startRadius: 0, endRadius: 260)
            TRDotGrid(spacing: 14, dotSize: 1.3, opacity: 0.07)
                .mask(LinearGradient(colors: [.white, .white.opacity(0.1), .clear, .white.opacity(0.4)], startPoint: .top, endPoint: .bottom))
            // Faint trough wave across the lower third.
            TroughWaveShape()
                .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(height: 120)
                .offset(y: isStory ? 150 : 90)
                .padding(.horizontal, -30)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .rank: rankCard
        case .streak: streakCard
        case .badge(let def): badgeCard(def)
        }
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(isStory ? 4 : 3)
            .foregroundStyle(secondaryInk)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var question: some View {
        Text(gLoc("ach.share.cta", "How consistent are you?"))
            .font(.system(size: 21, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: isStory ? 22 : 19, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isStory ? 10 : 8)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    private var badgesStat: some View {
        stat("\(data.badgesUnlocked)/\(data.badgesTotal)", gLoc("ach.share.stat.badges", "badges"))
    }

    private var streakStat: some View {
        stat("\(data.checkinStreak)", gLoc("ach.share.stat.dayStreak", "day streak"))
    }

    private var levelStat: some View {
        stat("\(data.level)", gLoc("ach.share.stat.level", "level"))
    }

    // Rank

    private var rankCard: some View {
        VStack(spacing: isStory ? 16 : 8) {
            kicker(gLoc("ach.share.rank.kicker", "My protocol rank"))
            if isStory {
                RankEmblem(level: data.level, width: 150)
                    .rotationEffect(.degrees(-4))
                    .padding(.vertical, 8)
            } else {
                RankEmblem(level: data.level, width: 84)
                    .rotationEffect(.degrees(-4))
            }
            VStack(spacing: 2) {
                Text(data.levelName)
                    .font(.system(size: isStory ? 42 : 30, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(verbatim: "\(data.cover.displayName) · \(String(format: gLoc("ach.levelN", "Level %d"), data.level))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(TR.Palette.gold)
            }
            HStack(spacing: 10) {
                streakStat
                badgesStat
                stat("\(data.injectionWeeks)", gLoc("ach.share.stat.weeks", "on-time weeks"))
            }
            if isStory {
                medallionRow
                Spacer(minLength: 0)
                question
                Spacer(minLength: 0)
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var medallionRow: some View {
        let defs = data.showcaseBadgeIDs.compactMap(GamificationCatalog.badge)
        if !defs.isEmpty {
            HStack(spacing: 8) {
                ForEach(defs) { def in
                    BadgeMedallion(systemImage: def.symbol, tier: def.tier, status: .unlocked, size: 44, glow: false, discColors: def.discColors)
                }
            }
            .padding(.top, 6)
        }
    }

    // Streak

    private var streakCard: some View {
        let flame = GamificationViewModel.flameLevel(forDays: data.checkinStreak)
        return VStack(spacing: isStory ? 12 : 4) {
            kicker(gLoc("ach.share.streak.kicker", "My check-in streak"))
            StreakFlameEmblem(level: flame, size: isStory ? 150 : 78)
                .padding(.vertical, isStory ? 10 : 2)
            Text(verbatim: "\(data.checkinStreak)")
                .font(.system(size: isStory ? 128 : 72, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(TR.Gradients.xp)
                .shadow(color: TR.Palette.gold.opacity(0.4), radius: 16)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.vertical, isStory ? -12 : -8)
            Text(String(format: gLoc("ach.share.streak.line", "%d-day check-in streak"), data.checkinStreak).uppercased())
                .font(.system(size: isStory ? 17 : 14, weight: .heavy, design: .rounded))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 10) {
                stat("\(data.bestCheckinStreak)", gLoc("ach.share.stat.best", "best streak"))
                badgesStat
                levelStat
            }
            .padding(.top, isStory ? 10 : 4)
            if isStory {
                Spacer(minLength: 0)
                question
                Spacer(minLength: 0)
            }
        }
        .multilineTextAlignment(.center)
    }

    // Badge

    private func badgeCard(_ def: BadgeDef) -> some View {
        VStack(spacing: isStory ? 14 : 6) {
            kicker(gLoc("ach.share.badge.kicker", "Badge unlocked"))
            BadgeMedallion(systemImage: def.symbol, tier: def.tier, status: .unlocked, size: isStory ? 180 : 96, discColors: def.discColors)
                .padding(.vertical, isStory ? 14 : 4)
            Text(def.title)
                .font(.system(size: isStory ? 38 : 28, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(verbatim: "\(def.tier.name) · \(def.unlockedLine)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
            HStack(spacing: 10) {
                levelStat
                badgesStat
                streakStat
            }
            .padding(.top, isStory ? 8 : 2)
            if isStory {
                Spacer(minLength: 0)
                question
                Spacer(minLength: 0)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Footer

/// App mark, name, short line and QR to the App Store: on every card (the download loop).
struct ShareCardFooter: View {
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Image("AppIcon-Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Trough — TRT Tracker")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                Text(gLoc("ach.share.footer", "Private protocol log · App Store"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            TRQRCodeView(size: compact ? 44 : 52)
                .padding(4)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.top, 10)
    }
}

// MARK: - PNG transferable

/// A rendered card as PNG data, for `ShareLink`.
struct SharePNG: Transferable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { $0.fileName }
    }
}

enum ShareText {
    /// Message that travels with the image. Plain App Store link, no tracking.
    static var message: String {
        gLoc("ach.share.message", "How consistent are you? I keep my protocol log private with Trough — TRT Tracker.")
            + "\n" + TroughLinks.appStoreURL.absoluteString
    }
}

// MARK: - Share sheet

/// Preview + format picker + system share. Present with `.sheet(item:)` on a `ShareCardKind`.
struct ShareCardSheet: View {
    let kind: ShareCardKind
    var data: ShareCardData

    @Environment(\.dismiss) private var dismiss
    @State private var format: TRShareFormat = .story
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()
                VStack(spacing: 18) {
                    Picker(gLoc("ach.share.format", "Format"), selection: $format) {
                        ForEach(TRShareFormat.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)

                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12)))
                                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                                .accessibilityLabel(Text(kind.title))
                        } else {
                            ProgressView().tint(TR.Palette.coral)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if let image, let png = image.pngData() {
                        ShareLink(
                            item: SharePNG(data: png, fileName: "\(kind.fileStem)-\(format.rawValue).png"),
                            message: Text(ShareText.message),
                            preview: SharePreview(Text(verbatim: "Trough"), image: Image(uiImage: image))
                        ) {
                            Label(gLoc("ach.share", "Share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.trPrimary)
                        .accessibilityIdentifier("share-card-share")
                    }
                    Text(gLoc("ach.share.privacy", "Cards show ranks, streaks and badges only — never doses or lab values."))
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(TR.Metrics.gutter)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(TR.Palette.coral)
        .task(id: format) {
            image = ShareRenderer.render(TRShareCardView(kind: kind, data: data, format: format), format: format)
        }
    }
}

#if DEBUG
#Preview("Rank story") {
    TRShareCardView(kind: .rank, data: .sample, format: .story)
        .frame(width: 360, height: 640)
}

#Preview("Streak square") {
    TRShareCardView(kind: .streak, data: .sample, format: .square)
        .frame(width: 360, height: 360)
}
#endif
