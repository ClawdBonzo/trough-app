import SwiftUI

// Backgrounds, cards and decorative light. Everything decorative here is hidden from
// VoiceOver, ignores hits, and holds still with Reduce Motion.

// MARK: - Screen background

/// App-wide screen background: abyss → background gradient, a faint radial coral glow at the
/// top, and a barely-there dot grid. Use behind scroll views:
/// `ZStack { TRBackground(); content }` or `.trScreenBackground()`.
struct TRBackground: View {
    /// Colour of the glow at the top of the screen.
    var glow: Color = TR.Palette.coral
    var glowOpacity: Double = 0.18
    var showsDotGrid: Bool = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TR.Gradients.screen
                RadialGradient(
                    colors: [glow.opacity(glowOpacity), glow.opacity(glowOpacity * 0.3), .clear],
                    center: UnitPoint(x: 0.5, y: -0.05),
                    startRadius: 0,
                    endRadius: max(proxy.size.width, 1) * 0.95
                )
                if showsDotGrid {
                    TRDotGrid()
                        .mask(
                            LinearGradient(colors: [.white, .white.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts `TRBackground` behind this view (full-bleed).
    func trScreenBackground(glow: Color = TR.Palette.coral) -> some View {
        background { TRBackground(glow: glow) }
    }
}

// MARK: - Dot grid texture

/// A lab-notebook dot grid. Very low alpha; purely texture.
struct TRDotGrid: View {
    var spacing: CGFloat = 18
    var dotSize: CGFloat = 1.4
    var color: Color = .white
    var opacity: Double = 0.045

    var body: some View {
        Canvas { context, size in
            let r = dotSize / 2
            var path = Path()
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x - r, y: y - r, width: dotSize, height: dotSize))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(color.opacity(opacity)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

/// Surface card: continuous radius 22, hairline stroke, soft radial tint glow in the
/// top-leading corner, and a drop shadow for depth.
struct TRCardModifier: ViewModifier {
    var tint: Color?
    var padding: CGFloat = TR.Metrics.cardPadding
    var cornerRadius: CGFloat = TR.Metrics.cardRadius
    var fill: Color = TR.Palette.surface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(fill)
                    if let tint {
                        shape.fill(
                            RadialGradient(
                                colors: [tint.opacity(0.22), tint.opacity(0.06), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 260
                            )
                        )
                    }
                    // Top-edge sheen for a glossy lip.
                    shape.fill(
                        LinearGradient(colors: [.white.opacity(0.04), .clear], startPoint: .top, endPoint: .center)
                    )
                }
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.12), TR.Palette.hairline, .white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
    }
}

extension View {
    /// Trough card. `tint` adds a radial glow in the top-leading corner; `padding` defaults
    /// to 16 (pass 0 to manage your own).
    func trCard(tint: Color? = nil, padding: CGFloat = TR.Metrics.cardPadding, fill: Color = TR.Palette.surface) -> some View {
        modifier(TRCardModifier(tint: tint, padding: padding, fill: fill))
    }
}

// MARK: - Glow backdrop

/// Slow-drifting pools of brand light behind hero screens (level up, onboarding, badge unlock).
/// Radial gradients, no blur: cheap to draw. Still with Reduce Motion.
struct GlowBackdrop: View {
    var colors: [Color] = [TR.Palette.coral, TR.Palette.lilac, TR.Palette.tangerine]
    var intensity: Double = 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height)
            let palette = colors.isEmpty ? [TR.Palette.coral] : colors
            ZStack {
                blob(palette[0], side: side)
                    .offset(x: -proxy.size.width * (drift ? 0.30 : 0.18), y: -proxy.size.height * (drift ? 0.30 : 0.22))
                blob(palette[1 % palette.count], side: side)
                    .offset(x: proxy.size.width * (drift ? 0.32 : 0.22), y: proxy.size.height * (drift ? 0.05 : 0.16))
                blob(palette[2 % palette.count], side: side * 0.8)
                    .offset(x: proxy.size.width * (drift ? -0.12 : 0.05), y: proxy.size.height * (drift ? 0.42 : 0.34))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private func blob(_ color: Color, side: CGFloat) -> some View {
        RadialGradient(
            colors: [color.opacity(intensity), color.opacity(intensity * 0.35), .clear],
            center: .center,
            startRadius: 0,
            endRadius: side * 0.45
        )
        .frame(width: side, height: side)
    }
}

// MARK: - Holo sheen

/// A band of light that sweeps across a card now and then, like a foil trading card.
/// Nothing with Reduce Motion.
struct HoloSheen: ViewModifier {
    var cornerRadius: CGFloat = TR.Metrics.cardRadius
    var period: Double = 4.5
    var intensity: Double = 0.28

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(intensity), .white.opacity(intensity * 0.18), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.45)
                        .rotationEffect(.degrees(18))
                        .offset(x: sweep ? proxy.size.width * 3.2 : -proxy.size.width * 0.8)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .onAppear {
                        // Most of each lap is off the card: a glint every few seconds, not a strobe.
                        withAnimation(.linear(duration: period).delay(0.8).repeatForever(autoreverses: false)) {
                            sweep = true
                        }
                    }
                }
            }
    }
}

extension View {
    /// A foil-card sweep of light across this view (see `HoloSheen`).
    func holoSheen(cornerRadius: CGFloat = TR.Metrics.cardRadius, period: Double = 4.5, intensity: Double = 0.28) -> some View {
        modifier(HoloSheen(cornerRadius: cornerRadius, period: period, intensity: intensity))
    }

    /// Soft coloured glow behind a view (rings, medallions, hero numbers).
    func trGlow(_ color: Color, radius: CGFloat = 16, opacity: Double = 0.55) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

#if DEBUG
#Preview("Surfaces") {
    ZStack {
        TRBackground()
        VStack(spacing: 16) {
            Text("Plain card").font(.headline).foregroundStyle(TR.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .trCard()
            Text("Teal tint card").font(.headline).foregroundStyle(TR.Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .trCard(tint: TR.Palette.teal)
            Text("Holo rank card").font(TR.Font.display(22)).foregroundStyle(TR.RankCover.gold.ink)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(TR.RankCover.gold.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .holoSheen()
        }
        .padding(TR.Metrics.gutter)
    }
    .preferredColorScheme(.dark)
}

#Preview("Glow backdrop") {
    ZStack {
        TR.Palette.abyss.ignoresSafeArea()
        GlowBackdrop()
    }
}
#endif
