import SwiftUI

// MARK: - Tier

/// Metal tier for a badge medallion. Picks the ring (metallic angular sweep), disc gradient
/// and glow colour. Tiers reward consistency/logging only.
enum BadgeTier: String, CaseIterable, Identifiable, Comparable {
    case bronze, silver, gold, platinum

    var id: String { rawValue }

    private var order: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .platinum: return 3
        }
    }

    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool { lhs.order < rhs.order }

    /// Stops for the metallic ring (angular, highlight → shade → highlight).
    var ringColors: [Color] {
        switch self {
        case .bronze:   return [Color(trHex: 0xF6C99A), Color(trHex: 0xB8773F), Color(trHex: 0x6E3F1B), Color(trHex: 0xD9955B), Color(trHex: 0xF6C99A)]
        case .silver:   return [Color(trHex: 0xFFFFFF), Color(trHex: 0xB9C2CE), Color(trHex: 0x6F7A8A), Color(trHex: 0xDDE3EA), Color(trHex: 0xFFFFFF)]
        case .gold:     return [Color(trHex: 0xFFE7A8), Color(trHex: 0xFFB547), Color(trHex: 0xB87414), Color(trHex: 0xFFD27A), Color(trHex: 0xFFE7A8)]
        case .platinum: return [Color(trHex: 0xE9FBFF), Color(trHex: 0x7CF3FF), Color(trHex: 0x9B8CFF), Color(trHex: 0xC9F1FF), Color(trHex: 0xE9FBFF)]
        }
    }

    /// Disc fill, top-leading → bottom-trailing.
    var discColors: [Color] {
        switch self {
        case .bronze:   return [Color(trHex: 0xD9955B), Color(trHex: 0x7A4A22)]
        case .silver:   return [Color(trHex: 0xB9C2CE), Color(trHex: 0x5C6778)]
        case .gold:     return [Color(trHex: 0xFFC75A), Color(trHex: 0xC2791A)]
        case .platinum: return [Color(trHex: 0x8FDDF5), Color(trHex: 0x5B5FC7)]
        }
    }

    var ringGradient: AngularGradient {
        AngularGradient(colors: ringColors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }

    var discGradient: LinearGradient {
        LinearGradient(colors: discColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Glow behind unlocked medallions.
    var glowColor: Color {
        switch self {
        case .bronze: return Color(trHex: 0xD9955B)
        case .silver: return Color(trHex: 0xDDE3EA)
        case .gold: return TR.Palette.gold
        case .platinum: return Color(trHex: 0x7CF3FF)
        }
    }

    var displayName: String {
        switch self {
        case .bronze:   return NSLocalizedString("badge.tier.bronze", value: "Bronze", comment: "Badge tier")
        case .silver:   return NSLocalizedString("badge.tier.silver", value: "Silver", comment: "Badge tier")
        case .gold:     return NSLocalizedString("badge.tier.gold", value: "Gold", comment: "Badge tier")
        case .platinum: return NSLocalizedString("badge.tier.platinum", value: "Platinum", comment: "Badge tier")
        }
    }
}

// MARK: - Medallion

/// Badge medallion: metallic progress ring around a glossy gradient disc with an SF Symbol.
///
/// - `.unlocked` — full tier ring, gradient disc, white glyph, optional glow.
/// - `.locked` — dashed ring, dim disc and glyph, tier-coloured progress arc, small lock.
/// - `.secret` — dashed ring, dim disc, "?" glyph (progress hidden).
///
/// All dimensions scale from `size`. Decorative: hidden from VoiceOver — label the tile that
/// contains it (e.g. "Night Owl, gold, unlocked" / "3 of 7").
struct BadgeMedallion: View {
    enum Status: Equatable {
        case unlocked, locked, secret
    }

    var systemImage: String
    var tier: BadgeTier
    var status: Status
    /// 0…1. Shown as the ring arc while locked; ignored when unlocked/secret.
    var progress: Double
    var size: CGFloat
    var glow: Bool
    /// Optional per-badge disc colours (overrides the tier disc when unlocked).
    var discColors: [Color]?

    init(
        systemImage: String,
        tier: BadgeTier = .gold,
        status: Status = .unlocked,
        progress: Double = 0,
        size: CGFloat = 72,
        glow: Bool = true,
        discColors: [Color]? = nil
    ) {
        self.systemImage = systemImage
        self.tier = tier
        self.status = status
        self.progress = progress
        self.size = size
        self.glow = glow
        self.discColors = discColors
    }

    /// Convenience for boolean call sites.
    init(systemImage: String, tier: BadgeTier = .gold, isUnlocked: Bool, isSecret: Bool = false, progress: Double = 0, size: CGFloat = 72, glow: Bool = true) {
        self.init(
            systemImage: systemImage,
            tier: tier,
            status: isUnlocked ? .unlocked : (isSecret ? .secret : .locked),
            progress: progress,
            size: size,
            glow: glow
        )
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringWidth: CGFloat { max(2.5, size * 0.075) }
    private var gap: CGFloat { max(1.5, size * 0.035) }
    private var discInset: CGFloat { ringWidth + gap }
    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            switch status {
            case .unlocked: unlocked
            case .locked: locked
            case .secret: secret
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : TR.Motion.pop, value: status)
        .accessibilityHidden(true)
    }

    // MARK: Unlocked

    @ViewBuilder
    private var unlocked: some View {
        // Metallic ring.
        Circle()
            .strokeBorder(tier.ringGradient, lineWidth: ringWidth)
            .shadow(color: glow ? tier.glowColor.opacity(0.6) : .clear, radius: size * 0.16)
        // Fine bevel on the ring.
        Circle()
            .strokeBorder(.white.opacity(0.45), lineWidth: max(0.5, size * 0.008))
        // Disc.
        Circle()
            .fill(LinearGradient(colors: discColors ?? tier.discColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .padding(discInset)
            .shadow(color: .black.opacity(0.35), radius: size * 0.03, y: size * 0.02)
        // Inner bevel: light top-left, dark bottom-right.
        Circle()
            .strokeBorder(
                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05), .black.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: max(1, size * 0.02)
            )
            .padding(discInset)
        // Gloss dome.
        Ellipse()
            .fill(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.56, height: size * 0.3)
            .offset(y: -size * 0.17)
            .blendMode(.plusLighter)
        glyph(systemImage)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: size * 0.025, y: size * 0.02)
    }

    // MARK: Locked

    @ViewBuilder
    private var locked: some View {
        dashedShell
        // Progress arc.
        if clamped > 0 {
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tier.ringGradient, style: StrokeStyle(lineWidth: ringWidth * 0.8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(ringWidth * 0.4)
                .opacity(0.9)
        }
        glyph(systemImage)
            .foregroundStyle(TR.Palette.textTertiary)
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.14, weight: .bold))
            .foregroundStyle(TR.Palette.textSecondary)
            .padding(size * 0.055)
            .background(TR.Palette.surface, in: Circle())
            .overlay(Circle().strokeBorder(TR.Palette.hairline))
            .offset(x: size * 0.33, y: size * 0.33)
    }

    // MARK: Secret

    @ViewBuilder
    private var secret: some View {
        dashedShell
        Text(verbatim: "?")
            .font(.system(size: size * 0.42, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [TR.Palette.lilac, TR.Palette.coral], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: TR.Palette.lilac.opacity(glow ? 0.5 : 0), radius: size * 0.08)
    }

    // MARK: Parts

    @ViewBuilder
    private var dashedShell: some View {
        Circle()
            .fill(TR.Palette.surfaceRaised.opacity(0.6))
        Circle()
            .strokeBorder(
                TR.Palette.textSecondary.opacity(0.35),
                style: StrokeStyle(lineWidth: max(1, size * 0.025), dash: [size * 0.07, size * 0.05])
            )
        Circle()
            .fill(
                RadialGradient(colors: [TR.Palette.surfaceRaised, TR.Palette.surface], center: .topLeading, startRadius: 0, endRadius: size)
            )
            .padding(discInset)
            .overlay(Circle().strokeBorder(TR.Palette.hairline).padding(discInset))
    }

    private func glyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.36, weight: .bold))
            .symbolRenderingMode(.hierarchical)
    }
}

#if DEBUG
#Preview("Badge medallions") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ForEach(BadgeTier.allCases) { tier in
                    BadgeMedallion(systemImage: "flame.fill", tier: tier, size: 72)
                }
            }
            HStack(spacing: 16) {
                BadgeMedallion(systemImage: "syringe.fill", tier: .gold, status: .locked, progress: 0.6, size: 72)
                BadgeMedallion(systemImage: "moon.stars.fill", tier: .silver, status: .locked, progress: 0, size: 72)
                BadgeMedallion(systemImage: "sparkles", tier: .platinum, status: .secret, size: 72)
                BadgeMedallion(systemImage: "calendar", tier: .bronze, status: .unlocked, size: 72, discColors: [TR.Palette.teal, TR.Palette.deepBlue])
            }
            HStack(alignment: .bottom, spacing: 16) {
                BadgeMedallion(systemImage: "crown.fill", tier: .gold, size: 120)
                BadgeMedallion(systemImage: "crown.fill", tier: .gold, size: 44)
                BadgeMedallion(systemImage: "crown.fill", tier: .gold, size: 28, glow: false)
            }
        }
        .padding(TR.Metrics.gutter)
    }
    .background(TRBackground())
    .preferredColorScheme(.dark)
}
#endif
