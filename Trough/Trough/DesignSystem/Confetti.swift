import SwiftUI

// Decorative celebration (level up, badge unlock, streak milestones). Hidden from VoiceOver,
// never intercepts touches, off with Reduce Motion, and drawn only while it plays (no idle
// timeline). Deterministic: the same trigger throws the same burst.

// MARK: - Random

/// SplitMix64: tiny, fast, deterministic RNG for repeatable effects (previews, tests, screenshots).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Particle maths (pure, testable)

/// One confetti particle, relative to where the burst starts.
struct ConfettiParticle: Equatable {
    enum Shape: Int, CaseIterable {
        case strip, dot, star
    }

    var shape: Shape
    /// Index into the burst's palette.
    var colorIndex: Int
    /// Launch velocity, points per second (negative y is up).
    var velocity: CGVector
    /// Spin, radians per second.
    var spin: Double
    /// Edge-on flip rate (paper flutter), radians per second.
    var flip: Double
    var size: CGFloat
    /// Seconds after the burst before this one launches.
    var delay: Double
}

enum ConfettiField {
    /// Downward pull, points per second squared.
    static let gravity: Double = 620
    /// Air drag; higher stops the burst sooner.
    static let drag: Double = 1.9

    static func particles(
        count: Int,
        paletteSize: Int,
        seed: UInt64,
        angles: ClosedRange<Double> = (-.pi * 0.92)...(-.pi * 0.08),
        speeds: ClosedRange<Double> = 380...920,
        sizes: ClosedRange<Double> = 6...12,
        maxDelay: Double = 0.12
    ) -> [ConfettiParticle] {
        guard count > 0, paletteSize > 0 else { return [] }
        var random = SplitMix64(seed: seed)
        let shapes = ConfettiParticle.Shape.allCases
        return (0..<count).map { index in
            let angle = Double.random(in: angles, using: &random)
            let speed = Double.random(in: speeds, using: &random)
            return ConfettiParticle(
                shape: shapes[Int.random(in: 0..<shapes.count, using: &random)],
                colorIndex: index % paletteSize,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                spin: Double.random(in: -9...9, using: &random),
                flip: Double.random(in: 4...11, using: &random),
                size: CGFloat(Double.random(in: sizes, using: &random)),
                delay: Double.random(in: 0...max(0, maxDelay), using: &random)
            )
        }
    }

    /// Where `particle` is `time` seconds after launch, relative to the origin: launched with
    /// drag, then pulled down by gravity.
    static func offset(of particle: ConfettiParticle, at time: Double) -> CGPoint {
        let t = max(0, time)
        let carried = (1 - exp(-drag * t)) / drag
        let x = particle.velocity.dx * carried
        let y = particle.velocity.dy * carried + 0.5 * gravity * t * t * 0.55
        return CGPoint(x: x, y: y)
    }

    /// Fully visible, then fades over the last 35% of the burst.
    static func opacity(at time: Double, duration: Double) -> Double {
        guard duration > 0, time >= 0 else { return 0 }
        let fadeStart = duration * 0.65
        if time <= fadeStart { return 1 }
        return max(0, 1 - (time - fadeStart) / (duration - fadeStart))
    }
}

// MARK: - View

/// A one-shot confetti burst. Changing `trigger` throws another; a positive `trigger` on appear
/// throws one immediately. Overlay it full-screen: `.overlay { ConfettiBurst(trigger: n) }`.
struct ConfettiBurst: View {
    var trigger: Int
    /// Where the burst starts, in the view's unit space.
    var origin: UnitPoint = UnitPoint(x: 0.5, y: 0.42)
    var count: Int = 110
    var duration: Double = 2.8
    var palette: [Color] = TR.Palette.celebration
    var speeds: ClosedRange<Double> = 380...920

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst: Burst?

    private struct Burst: Equatable {
        let started: Date
        let particles: [ConfettiParticle]
    }

    init(
        trigger: Int,
        origin: UnitPoint = UnitPoint(x: 0.5, y: 0.42),
        count: Int = 110,
        duration: Double = 2.8,
        palette: [Color] = TR.Palette.celebration,
        speeds: ClosedRange<Double> = 380...920
    ) {
        self.trigger = trigger
        self.origin = origin
        self.count = count
        self.duration = duration
        self.palette = palette.isEmpty ? TR.Palette.celebration : palette
        self.speeds = speeds
    }

    var body: some View {
        ZStack {
            if let burst, !reduceMotion {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(burst.started)
                    Canvas { context, size in
                        draw(burst.particles, elapsed: elapsed, in: &context, size: size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { if trigger > 0 { fire() } }
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        guard !reduceMotion else { return }
        let started = Date.now
        let particles = ConfettiField.particles(
            count: count,
            paletteSize: palette.count,
            seed: UInt64(truncatingIfNeeded: trigger &* 7919 &+ 17),
            speeds: speeds
        )
        burst = Burst(started: started, particles: particles)
        let lifetime = duration + 0.2
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(lifetime))
            if burst?.started == started { burst = nil }
        }
    }

    private func draw(_ particles: [ConfettiParticle], elapsed: Double, in context: inout GraphicsContext, size: CGSize) {
        let start = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        for particle in particles {
            let t = elapsed - particle.delay
            guard t > 0 else { continue }
            let alpha = ConfettiField.opacity(at: t, duration: duration - particle.delay)
            guard alpha > 0 else { continue }
            let offset = ConfettiField.offset(of: particle, at: t)
            var layer = context
            layer.opacity = alpha
            layer.translateBy(x: start.x + offset.x, y: start.y + offset.y)
            layer.rotate(by: .radians(particle.spin * t))
            // Paper turning edge-on and back.
            layer.scaleBy(x: max(0.15, abs(cos(particle.flip * t))), y: 1)
            let color = palette[particle.colorIndex % palette.count]
            let s = particle.size
            switch particle.shape {
            case .strip:
                layer.fill(Path(roundedRect: CGRect(x: -s / 2, y: -s * 0.3, width: s, height: s * 0.6), cornerRadius: 1.5), with: .color(color))
            case .dot:
                layer.fill(Path(ellipseIn: CGRect(x: -s * 0.4, y: -s * 0.4, width: s * 0.8, height: s * 0.8)), with: .color(color))
            case .star:
                layer.fill(Self.sparkle(size: s * 1.2), with: .color(color))
            }
        }
    }

    /// A four-pointed sparkle path centred on the origin.
    static func sparkle(size: CGFloat) -> Path {
        let r = size / 2
        let waist = r * 0.28
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -r))
        path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: waist, y: -waist))
        path.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: waist, y: waist))
        path.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -waist, y: waist))
        path.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -waist, y: -waist))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Confetti") {
    struct Host: View {
        @State private var trigger = 1
        var body: some View {
            ZStack {
                TRBackground()
                GlowBackdrop(intensity: 0.35)
                Button(String("Celebrate again")) { trigger += 1 }
                    .buttonStyle(.trPrimary)
                    .padding(40)
                ConfettiBurst(trigger: trigger)
            }
        }
    }
    return Host().preferredColorScheme(.dark)
}
#endif
