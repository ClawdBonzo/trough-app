import SwiftUI

/// Full-screen celebration for a badge unlock, a new rank, a streak milestone (or, via the
/// legacy wrapper, a quest). Layered: screen background + tinted glow, rotating halo ring,
/// sunburst rays, the art, kicker, title, witty line, a gold "+XP" chip that pops a beat later,
/// "+N more badges", confetti, Share + "Carry on". Tap anywhere to dismiss.
///
/// Reduce Motion: fades only — no spin, no rays rotation, no confetti, no pop.
struct CelebrationView: View {
    let celebration: Celebration
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var chipShown = false
    @State private var spin = false
    @State private var burst = 0
    @State private var shareKind: ShareCardKind?
    @State private var didFinish = false

    var body: some View {
        ZStack {
            // Tap-anywhere dismiss layer.
            ZStack {
                TRBackground(glow: tint, glowOpacity: 0.3)
                GlowBackdrop(colors: glowColors, intensity: 0.42)
                    .opacity(appeared ? 1 : 0)
            }

            VStack(spacing: 14) {
                Spacer(minLength: 12)
                TRKicker(Text(verbatim: eyebrow), color: tint)
                    .tracking(2.4)
                    .opacity(appeared ? 1 : 0)
                art
                    .frame(height: 280)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .allowsHitTesting(false)
                VStack(spacing: 8) {
                    Text(verbatim: title)
                        .font(TR.Font.display(.largeTitle, weight: .black))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    Text(verbatim: line)
                        .font(.title3)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 18)

                HStack(spacing: 8) {
                    if let reward = rewardText {
                        rewardChip(reward)
                            .scaleEffect(chipShown || reduceMotion ? 1 : 0.3)
                            .opacity(chipShown ? 1 : 0)
                    }
                    if alsoEarned > 0 {
                        TRPill(Text(verbatim: String(format: gLoc("ach.celebrate.moreBadges", "+%d more badges"), alsoEarned)),
                               systemImage: "rosette", tint: TR.Palette.lilac)
                            .opacity(chipShown ? 1 : 0)
                    }
                }
                .padding(.top, 4)
                .allowsHitTesting(false)

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    if let kind = shareCardKind {
                        Button {
                            shareKind = kind
                        } label: {
                            Label(gLoc("ach.share", "Share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.trPrimary)
                        .accessibilityIdentifier("celebration-share")
                    }
                    Button { finish() } label: {
                        Text(gLoc("ach.celebrate.carryOn", "Carry on"))
                            .frame(maxWidth: .infinity, minHeight: TR.Metrics.minTap)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
                    .accessibilityIdentifier("celebration-done")
                }
                .frame(maxWidth: 380)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)

            ConfettiBurst(trigger: burst, origin: UnitPoint(x: 0.5, y: 0.34), palette: confettiPalette)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() } // tap anywhere; buttons still win
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.success, trigger: burst)
        .onAppear(perform: start)
        .sheet(item: $shareKind) { kind in
            ShareCardSheet(kind: kind, data: .current)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { finish() }
        .accessibilityIdentifier("celebration")
    }

    // MARK: Lifecycle

    private func start() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.62)) {
            appeared = true
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2).delay(0.2) : TR.Motion.pop.delay(0.45)) {
            chipShown = true
        }
        burst += 1 // also drives the success haptic
        if !reduceMotion {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { spin = true }
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onDone()
    }

    // MARK: Content

    private var eyebrow: String {
        switch celebration {
        case .badge: return gLoc("ach.celebrate.kicker.badge", "BADGE UNLOCKED")
        case .levelUp: return gLoc("ach.celebrate.kicker.rank", "NEW RANK")
        case .streak: return gLoc("ach.celebrate.kicker.streak", "STREAK")
        case .questCompleted: return gLoc("ach.celebrate.kicker.quest", "QUEST COMPLETE")
        }
    }

    private var title: String {
        switch celebration {
        case .badge(let def, _, _): return def.title
        case .levelUp(_, let name, _): return name
        case .streak(let days, _): return String(format: gLoc("ach.celebrate.streak.title", "%d days straight"), days)
        case .questCompleted(let title, _): return title
        }
    }

    private var line: String {
        switch celebration {
        case .badge(let def, _, _):
            return def.unlockedLine
        case .levelUp(let level, _, _):
            let cover = TR.RankCover.forLevel(level)
            return String(format: gLoc("ach.celebrate.rank.line", "Level %d · %@ cover. It's on every card you share."), level, cover.displayName)
        case .streak(let days, _):
            switch days {
            case ..<14: return gLoc("ach.celebrate.streak.line.week", "A full week of check-ins. The habit is forming.")
            case ..<60: return gLoc("ach.celebrate.streak.line.month", "A month without missing a day. That's a routine.")
            case ..<200: return gLoc("ach.celebrate.streak.line.hundred", "Triple digits. Consistency, on the record.")
            default: return gLoc("ach.celebrate.streak.line.year", "A year of daily check-ins. Legendary.")
            }
        case .questCompleted:
            return gLoc("ach.celebrate.quest.line", "Nicely done. Another one for the log.")
        }
    }

    private var rewardText: String? {
        let xp = celebration.xpReward
        guard xp > 0 else {
            if case .levelUp(_, _, let total) = celebration {
                return String(format: gLoc("ach.celebrate.totalXP", "%d XP total"), total)
            }
            return nil
        }
        return String(format: gLoc("ach.xpReward", "+%d XP"), xp)
    }

    private var alsoEarned: Int {
        if case .badge(_, let n, _) = celebration { return n }
        return 0
    }

    private var shareCardKind: ShareCardKind? {
        switch celebration {
        case .badge(let def, _, _): return .badge(def)
        case .levelUp: return .rank
        case .streak: return .streak
        case .questCompleted: return nil
        }
    }

    private var tint: Color {
        switch celebration {
        case .badge(let def, _, _): return def.tier == .silver ? def.tier.glowColor : def.accentColor
        case .levelUp(let level, _, _): return TR.RankCover.forLevel(level).colors.first ?? TR.Palette.gold
        case .streak: return TR.Palette.tangerine
        case .questCompleted: return TR.Palette.mint
        }
    }

    private var glowColors: [Color] {
        switch celebration {
        case .badge(let def, _, _): return [def.accentColor, def.tier.glowColor, TR.Palette.coral]
        case .levelUp(let level, _, _):
            let c = TR.RankCover.forLevel(level).colors
            return [c.first ?? TR.Palette.gold, TR.Palette.lilac, c.last ?? TR.Palette.tangerine]
        case .streak: return [TR.Palette.tangerine, TR.Palette.coral, TR.Palette.gold]
        case .questCompleted: return [TR.Palette.mint, TR.Palette.teal, TR.Palette.sky]
        }
    }

    private var confettiPalette: [Color] {
        [tint, TR.Palette.gold, TR.Palette.coral, TR.Palette.teal, TR.Palette.lilac, .white]
    }

    private func rewardChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
            Text(verbatim: text)
                .font(TR.Font.number(.subheadline, weight: .black))
        }
        .foregroundStyle(Color(trHex: 0x3A2600))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(TR.Gradients.xp, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 1))
        .shadow(color: TR.Palette.gold.opacity(0.55), radius: 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Art

    @ViewBuilder
    private var art: some View {
        ZStack {
            SunburstRays(color: tint, rays: 18)
                .frame(width: 420, height: 420)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(0.9)
            // Rotating halo ring.
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [tint.opacity(0), tint, .white.opacity(0.9), tint, tint.opacity(0)],
                                    center: .center),
                    lineWidth: 3
                )
                .frame(width: 236, height: 236)
                .rotationEffect(.degrees(spin ? -360 : 0))
                .shadow(color: tint.opacity(0.8), radius: 10)
            Circle()
                .strokeBorder(tint.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [2, 7]))
                .frame(width: 262, height: 262)
                .rotationEffect(.degrees(spin ? 360 : 0))

            switch celebration {
            case .badge(let def, _, _):
                BadgeMedallion(systemImage: def.symbol, tier: def.tier, status: .unlocked, size: 190, discColors: def.discColors)
            case .levelUp(let level, _, _):
                RankEmblem(level: level, width: 138)
                    .rotationEffect(.degrees(-5))
            case .streak(let days, _):
                ZStack(alignment: .bottom) {
                    StreakFlameEmblem(level: GamificationViewModel.flameLevel(forDays: days), size: 180)
                    Text(verbatim: "\(days)")
                        .font(TR.Font.number(30))
                        .foregroundStyle(Color(trHex: 0x3A2600))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 3)
                        .background(TR.Gradients.xp, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                        .offset(y: 16)
                }
            case .questCompleted:
                BadgeMedallion(systemImage: "checkmark.seal.fill", tier: .gold, status: .unlocked, size: 170,
                               discColors: [TR.Palette.mint, TR.Palette.teal])
            }
        }
    }
}

// MARK: - Sunburst

/// Soft tapered rays drawn in a Canvas (cheap; fades out towards the edge).
struct SunburstRays: View {
    var color: Color
    var rays: Int = 16

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            let step = (2 * Double.pi) / Double(max(rays, 1))
            let half = step * 0.22
            var path = Path()
            for i in 0..<rays {
                let a = Double(i) * step
                path.move(to: c)
                path.addLine(to: CGPoint(x: c.x + cos(a - half) * r, y: c.y + sin(a - half) * r))
                path.addLine(to: CGPoint(x: c.x + cos(a + half) * r, y: c.y + sin(a + half) * r))
                path.closeSubpath()
            }
            context.fill(path, with: .radialGradient(
                Gradient(colors: [color.opacity(0.42), color.opacity(0.12), .clear]),
                center: c, startRadius: r * 0.18, endRadius: r
            ))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Badge") {
    CelebrationView(celebration: .badge(GamificationCatalog.badge("consistency_king")!, alsoEarned: 2, xp: 25)) {}
}

#Preview("Level up") {
    CelebrationView(celebration: .levelUp(level: 7, name: GamificationCatalog.levelName(7), totalXP: 1860)) {}
}

#Preview("Streak") {
    CelebrationView(celebration: .streak(days: 100, xp: 250)) {}
}
#endif
