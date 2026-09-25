import SwiftUI
import UIKit

/// A 1–5 integer rating slider (Trough 1.4): SF Symbol in a tinted circle, big rounded number,
/// custom gradient track with step ticks, a glowing thumb, and a haptic tick on every step.
/// VoiceOver treats it as one adjustable element (swipe up/down to change).
struct HapticSlider: View {
    let label: String
    @Binding var value: Double
    var systemImage: String?
    var emoji: String?
    var tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false
    @State private var lastHapticValue: Double = 0
    private let generator = UISelectionFeedbackGenerator()

    private let range: ClosedRange<Double> = 1...5

    /// 1.4 style: SF Symbol + tint.
    init(systemImage: String, label: String, tint: Color = TR.Palette.coral, value: Binding<Double>) {
        self.label = label
        self._value = value
        self.systemImage = systemImage
        self.emoji = nil
        self.tint = tint
    }

    /// Legacy call sites (onboarding quiz): emoji in a tinted circle.
    init(emoji: String, label: String, value: Binding<Double>) {
        self.label = label
        self._value = value
        self.systemImage = nil
        self.emoji = emoji
        self.tint = TR.Palette.coral
    }

    private var fraction: Double { (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / (range.upperBound - range.lowerBound) }

    private var descriptor: String {
        switch Int(value.rounded()) {
        case ...1: return NSLocalizedString("checkin14.rating.1", value: "Very low", comment: "1-of-5 self rating")
        case 2:    return NSLocalizedString("checkin14.rating.2", value: "Low", comment: "2-of-5 self rating")
        case 3:    return NSLocalizedString("checkin14.rating.3", value: "Okay", comment: "3-of-5 self rating")
        case 4:    return NSLocalizedString("checkin14.rating.4", value: "Good", comment: "4-of-5 self rating")
        default:   return NSLocalizedString("checkin14.rating.5", value: "Great", comment: "5-of-5 self rating")
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(TR.Font.display(.headline, weight: .bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(descriptor)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 8)
                Text(value, format: .number.precision(.fractionLength(0)))
                    .font(TR.Font.number(34))
                    .foregroundStyle(LinearGradient(colors: [.white, tint], startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText(value: value))
                    .frame(minWidth: 30, alignment: .trailing)
                    .shadow(color: tint.opacity(0.45), radius: 10)
            }
            track
        }
        .animation(reduceMotion ? nil : TR.Motion.snappy, value: value)
        .onAppear {
            generator.prepare()
            lastHapticValue = value
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: "\(Int(value.rounded())) / 5, \(descriptor)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(min(range.upperBound, value + 1))
            case .decrement: set(max(range.lowerBound, value - 1))
            @unknown default: break
            }
        }
    }

    private var icon: some View {
        ZStack {
            Circle().fill(tint.opacity(0.18))
            Circle().strokeBorder(tint.opacity(0.35), lineWidth: 1)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
            } else if let emoji {
                Text(emoji).font(.title3)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    private var track: some View {
        GeometryReader { proxy in
            let thumb: CGFloat = 30
            let usable = max(1, proxy.size.width - thumb)
            let x = usable * fraction
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.07))
                    .frame(height: 12)
                    .overlay(Capsule().strokeBorder(TR.Palette.hairline, lineWidth: 1))
                    .padding(.horizontal, thumb / 2 - 6)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.45), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + 12, height: 12)
                    .padding(.leading, thumb / 2 - 6)
                    .shadow(color: tint.opacity(0.55), radius: 8)
                // Step ticks
                ForEach(0..<5, id: \.self) { i in
                    let on = Double(i) <= fraction * 4 + 0.001
                    Circle()
                        .fill(on ? Color.white.opacity(0.85) : Color.white.opacity(0.22))
                        .frame(width: 4, height: 4)
                        .offset(x: thumb / 2 - 2 + usable * CGFloat(i) / 4)
                }
                // Thumb
                ZStack {
                    Circle().fill(tint.opacity(0.35)).frame(width: thumb + 14, height: thumb + 14).blur(radius: 6)
                    Circle().fill(.white)
                    Circle().fill(RadialGradient(colors: [tint.opacity(0.0), tint.opacity(0.35)], center: .center, startRadius: 2, endRadius: thumb / 2))
                    Circle().strokeBorder(tint, lineWidth: 3)
                }
                .frame(width: thumb, height: thumb)
                .scaleEffect(isDragging && !reduceMotion ? 1.18 : 1)
                .shadow(color: tint.opacity(0.7), radius: isDragging ? 14 : 8)
                .offset(x: x)
            }
            .frame(height: thumb)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !isDragging { withAnimation(reduceMotion ? nil : TR.Motion.press) { isDragging = true } }
                        let f = min(1, max(0, (g.location.x - thumb / 2) / usable))
                        set((range.lowerBound + f * (range.upperBound - range.lowerBound)).rounded())
                    }
                    .onEnded { _ in
                        withAnimation(reduceMotion ? nil : TR.Motion.press) { isDragging = false }
                    }
            )
        }
        .frame(height: 36)
    }

    private func set(_ newValue: Double) {
        guard newValue != value else { return }
        value = newValue
        if newValue != lastHapticValue {
            generator.selectionChanged()
            generator.prepare()
            lastHapticValue = newValue
        }
    }
}

#if DEBUG
#Preview("HapticSlider") {
    struct Host: View {
        @State var a: Double = 3
        @State var b: Double = 5
        var body: some View {
            VStack(spacing: 16) {
                HapticSlider(systemImage: "bolt.fill", label: "Energy", tint: TR.Palette.gold, value: $a).trCard(tint: TR.Palette.gold)
                HapticSlider(emoji: "🌙", label: "Sleep", value: $b).trCard()
            }
            .padding()
            .background(TRBackground())
        }
    }
    return Host().preferredColorScheme(.dark)
}
#endif
