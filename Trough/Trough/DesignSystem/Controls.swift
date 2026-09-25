import SwiftUI

// MARK: - Buttons

/// Primary call to action: coral gradient capsule, heavy rounded label, glossy top lip,
/// coral glow, press scale 0.98. Min height 54.
struct TRPrimaryButtonStyle: ButtonStyle {
    var colors: [Color] = TR.Gradients.ctaColors
    var foreground: Color = .white
    var fullWidth: Bool = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TR.Font.display(.headline))
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: TR.Metrics.buttonHeight)
            .padding(.horizontal, 22)
            .background {
                ZStack {
                    Capsule().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                        .padding(1.5)
                    Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: (colors.last ?? TR.Palette.coral).opacity(configuration.isPressed ? 0.25 : 0.45),
                        radius: configuration.isPressed ? 8 : 16, y: configuration.isPressed ? 3 : 8)
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : TR.Motion.press, value: configuration.isPressed)
    }
}

/// Secondary action: quiet raised-surface capsule with hairline.
struct TRSecondaryButtonStyle: ButtonStyle {
    var tint: Color = TR.Palette.textPrimary
    var fullWidth: Bool = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .padding(.horizontal, 20)
            .background(TR.Palette.surfaceRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(TR.Palette.hairline, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : TR.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TRPrimaryButtonStyle {
    /// `.buttonStyle(.trPrimary)`
    static var trPrimary: TRPrimaryButtonStyle { TRPrimaryButtonStyle() }
}

extension ButtonStyle where Self == TRSecondaryButtonStyle {
    /// `.buttonStyle(.trSecondary)`
    static var trSecondary: TRSecondaryButtonStyle { TRSecondaryButtonStyle() }
}

// MARK: - Kicker

/// Small caps kicker line ("DAY 4 OF 7"): caption heavy, uppercase, tracking 1.2.
struct TRKicker: View {
    let text: Text
    var color: Color = TR.Palette.textSecondary

    init(_ text: Text, color: Color = TR.Palette.textSecondary) {
        self.text = text
        self.color = color
    }

    init(_ key: LocalizedStringKey, color: Color = TR.Palette.textSecondary) {
        self.init(Text(key), color: color)
    }

    init(verbatim string: String, color: Color = TR.Palette.textSecondary) {
        self.init(Text(verbatim: string), color: color)
    }

    var body: some View {
        text
            .font(TR.Font.kicker)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

// MARK: - Pill / chip

/// Icon + text capsule on raised surface. With `tint`, the icon takes the tint and the
/// capsule gets a faint tint wash + tinted stroke.
struct TRPill: View {
    let text: Text
    var systemImage: String?
    var tint: Color?

    init(_ text: Text, systemImage: String? = nil, tint: Color? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    init(_ key: LocalizedStringKey, systemImage: String? = nil, tint: Color? = nil) {
        self.init(Text(key), systemImage: systemImage, tint: tint)
    }

    init(verbatim string: String, systemImage: String? = nil, tint: Color? = nil) {
        self.init(Text(verbatim: string), systemImage: systemImage, tint: tint)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint ?? TR.Palette.textSecondary)
                    .accessibilityHidden(true)
            }
            text
                .font(.caption.weight(.bold))
                .foregroundStyle(TR.Palette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            ZStack {
                Capsule().fill(TR.Palette.surfaceRaised)
                if let tint { Capsule().fill(tint.opacity(0.14)) }
            }
        }
        .overlay(Capsule().strokeBorder((tint ?? .white).opacity(tint == nil ? 0.08 : 0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Alias used by the spec (`TRPill`/`TRChip`).
typealias TRChip = TRPill

// MARK: - Section header

/// Rounded title3 header with optional trailing content (e.g. "See all" button or a pill).
struct TRSectionHeader<Trailing: View>: View {
    let title: Text
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: Text, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    init(_ key: LocalizedStringKey, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(Text(key), trailing: trailing)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            title
                .font(TR.Font.display(.title3, weight: .bold))
                .foregroundStyle(TR.Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
        }
    }
}

extension TRSectionHeader where Trailing == EmptyView {
    init(_ title: Text) { self.init(title) { EmptyView() } }
    init(_ key: LocalizedStringKey) { self.init(Text(key)) { EmptyView() } }
}

extension TRSectionHeader where Trailing == Text {
    /// Header with a trailing caption ("3 of 5").
    init(_ title: Text, trailing: Text) { self.init(title) { trailing } }
}

// MARK: - Ring

/// Progress ring with an angular-gradient stroke, soft glow, glossy end cap and a centre slot.
/// Animates changes to `progress` (cross-fade only with Reduce Motion).
struct TRRing<Center: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var colors: [Color] = [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]
    var trackColor: Color = .white.opacity(0.07)
    var glow: Bool = true
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        colors: [Color] = [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold],
        trackColor: Color = .white.opacity(0.07),
        glow: Bool = true,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.colors = colors
        self.trackColor = trackColor
        self.glow = glow
        self.center = center
    }

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        let stops = colors.isEmpty ? [TR.Palette.coral] : colors
        let gradient = AngularGradient(
            colors: stops + [stops[0]],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glow ? (stops.last ?? TR.Palette.coral).opacity(0.55) : .clear, radius: lineWidth * 0.9)
            // Inner gloss.
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: max(1, lineWidth * 0.22), lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(lineWidth * 0.18)
                .blendMode(.plusLighter)
            center()
                .padding(lineWidth)
        }
        .padding(lineWidth / 2)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.9, dampingFraction: 0.85), value: clamped)
    }
}

extension TRRing where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 12, colors: [Color] = [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold], glow: Bool = true) {
        self.init(progress: progress, lineWidth: lineWidth, colors: colors, glow: glow) { EmptyView() }
    }
}

// MARK: - Progress bar

/// Capsule progress bar (0…1) with a gradient fill and glossy highlight. Animated unless
/// Reduce Motion. Decorative by default — give the surrounding view an accessibility value.
struct TRProgressBar: View {
    var value: Double
    var height: CGFloat = 10
    var colors: [Color] = TR.Gradients.xpColors
    var trackColor: Color = .white.opacity(0.07)
    var glow: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(1, max(0, value)) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                            .padding(.horizontal, height * 0.25)
                            .padding(.top, height * 0.12)
                            .padding(.bottom, height * 0.5)
                    )
                    .frame(width: max(height, proxy.size.width * clamped))
                    .opacity(clamped > 0 ? 1 : 0)
                    .shadow(color: glow ? (colors.last ?? TR.Palette.gold).opacity(0.5) : .clear, radius: height * 0.6)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.7, dampingFraction: 0.85), value: clamped)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Controls") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            TRKicker(verbatim: "Day 4 of 7", color: TR.Palette.gold)
            TRSectionHeader(Text(verbatim: "This week"), trailing: Text(verbatim: "3 of 5"))
            HStack {
                TRPill(verbatim: "12-day streak", systemImage: "flame.fill", tint: TR.Palette.gold)
                TRPill(verbatim: "On track", systemImage: "checkmark.circle.fill", tint: TR.Palette.teal)
                TRPill(verbatim: "Plain")
            }
            HStack(spacing: 24) {
                TRRing(progress: 0.72, lineWidth: 14) {
                    VStack(spacing: 0) {
                        Text(verbatim: "72").font(TR.Font.number(34)).foregroundStyle(TR.Palette.textPrimary)
                        TRKicker(verbatim: "Week")
                    }
                }
                .frame(width: 140, height: 140)
                TRRing(progress: 0.4, lineWidth: 8, colors: [TR.Palette.teal, TR.Palette.sky])
                    .frame(width: 80, height: 80)
            }
            TRProgressBar(value: 0.62)
            TRProgressBar(value: 0.3, height: 6, colors: [TR.Palette.teal, TR.Palette.mint])
            Button(String("Log injection")) {}.buttonStyle(.trPrimary)
            Button(String("Maybe later")) {}.buttonStyle(.trSecondary)
            Button(String("Disabled")) {}.buttonStyle(.trPrimary).disabled(true)
        }
        .padding(TR.Metrics.gutter)
    }
    .background(TRBackground())
    .preferredColorScheme(.dark)
}
#endif
