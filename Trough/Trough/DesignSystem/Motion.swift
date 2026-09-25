import SwiftUI

// Appear animations, counting numbers and press feedback. Every animation here shows its end
// state immediately with Reduce Motion, or when rendered to an image (share cards).

// MARK: - Static render flag

private struct TRStaticRenderKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while a view is rendered to an image (share cards via `ImageRenderer`): every
    /// `Reveal`/`CountUp` shows its final state immediately.
    var trStaticRender: Bool {
        get { self[TRStaticRenderKey.self] }
        set { self[TRStaticRenderKey.self] = newValue }
    }
}

// MARK: - Reveal

/// Renders `content(false)` then animates to `content(true)` the first time it appears.
/// With Reduce Motion (or a static render) it shows `content(true)` straight away.
///
///     Reveal(delay: 0.1) { shown in
///         card.opacity(shown ? 1 : 0).offset(y: shown ? 0 : 16)
///     }
struct Reveal<Content: View>: View {
    var delay: Double
    var animation: Animation
    @ViewBuilder let content: (Bool) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.trStaticRender) private var isStatic
    @State private var revealed = false

    init(delay: Double = 0, animation: Animation = .spring(response: 0.9, dampingFraction: 0.82), @ViewBuilder content: @escaping (Bool) -> Content) {
        self.delay = delay
        self.animation = animation
        self.content = content
    }

    var body: some View {
        content(revealed || reduceMotion || isStatic)
            .onAppear {
                guard !revealed, !reduceMotion, !isStatic else { return }
                withAnimation(animation.delay(delay)) { revealed = true }
            }
    }
}

extension View {
    /// Fade + rise in on first appearance (staggers nicely with increasing `delay`).
    func trRevealOnAppear(delay: Double = 0, offset: CGFloat = 14) -> some View {
        Reveal(delay: delay) { shown in
            self.opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : offset)
        }
    }

    /// Scale-pop in on first appearance (badges, medals).
    func trPopOnAppear(delay: Double = 0) -> some View {
        Reveal(delay: delay, animation: TR.Motion.pop) { shown in
            self.opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.6)
        }
    }
}

// MARK: - Counting numbers

/// A number that counts through intermediate values as it animates.
struct CountingNumber: View, @preconcurrency Animatable {
    var value: Double
    var fractionDigits: Int

    init(value: Double, fractionDigits: Int = 0) {
        self.value = value
        self.fractionDigits = fractionDigits
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(value, format: .number.precision(.fractionLength(fractionDigits)))
    }
}

/// Counts up from zero to `value` on first appearance, then animates to new values with a
/// numeric content transition. VoiceOver reads the final value, never the tween. Style it like
/// Text: `CountUp(xp).font(TR.Font.number(40)).foregroundStyle(...)`.
struct CountUp: View {
    let value: Double
    let fractionDigits: Int
    let duration: Double
    /// Start from zero on first appearance (false: start at `value`, only animate changes).
    let fromZero: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.trStaticRender) private var isStatic
    @State private var shown: Double?

    init(_ value: Int, duration: Double = 1.1, fromZero: Bool = true) {
        self.value = Double(value)
        self.fractionDigits = 0
        self.duration = duration
        self.fromZero = fromZero
    }

    init(_ value: Double, fractionDigits: Int = 1, duration: Double = 1.1, fromZero: Bool = true) {
        self.value = value
        self.fractionDigits = fractionDigits
        self.duration = duration
        self.fromZero = fromZero
    }

    private var instant: Bool { reduceMotion || isStatic }

    var body: some View {
        let current = shown ?? ((fromZero && !instant) ? 0 : value)
        CountingNumber(value: current, fractionDigits: fractionDigits)
            .monospacedDigit()
            .contentTransition(.numericText(value: current))
            .onAppear {
                guard shown == nil else { return }
                if instant || !fromZero {
                    shown = value
                } else {
                    shown = 0
                    withAnimation(.easeOut(duration: duration)) { shown = value }
                }
            }
            .onChange(of: value) { _, newValue in
                if instant {
                    shown = newValue
                } else {
                    withAnimation(.easeOut(duration: min(duration, 0.8))) { shown = newValue }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(value, format: .number.precision(.fractionLength(fractionDigits))))
    }
}

// MARK: - Press feedback

/// Plain button style that scales down slightly while pressed (for custom card-like buttons).
/// No scaling with Reduce Motion.
struct TRPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : TR.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TRPressableButtonStyle {
    /// `.buttonStyle(.trPressable)` — scale-on-press for custom tappable cards.
    static var trPressable: TRPressableButtonStyle { TRPressableButtonStyle() }
}

extension View {
    /// Wraps this view in a `Button` with press-scale feedback.
    func trPressable(scale: CGFloat = 0.97, action: @escaping () -> Void) -> some View {
        Button(action: action) { self }
            .buttonStyle(TRPressableButtonStyle(scale: scale))
    }
}

#if DEBUG
#Preview("Motion") {
    struct Host: View {
        @State private var xp = 1240
        var body: some View {
            VStack(spacing: 24) {
                CountUp(xp)
                    .font(TR.Font.number(56))
                    .foregroundStyle(TR.Gradients.xp)
                CountUp(87.5, fractionDigits: 1)
                    .font(TR.Font.number(.title))
                    .foregroundStyle(TR.Palette.textPrimary)
                Text(verbatim: "Tap to add XP")
                    .font(.headline)
                    .foregroundStyle(TR.Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .trCard(tint: TR.Palette.gold)
                    .trPressable { xp += 35 }
                    .trRevealOnAppear(delay: 0.2)
            }
            .padding(TR.Metrics.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TRBackground())
        }
    }
    return Host().preferredColorScheme(.dark)
}
#endif
