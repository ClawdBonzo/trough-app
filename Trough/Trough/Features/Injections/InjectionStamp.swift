import SwiftUI
import UIKit

// Trough 1.4 — Injection Stamps.
// Every logged injection becomes a procedural rubber-stamp "sticker", seeded by its id: shape,
// ink, tilt and ink-wear are deterministic, so an injection always gets "its" stamp.
// Health-safety: a stamp shows compound short name, site and date ONLY — never dose, levels,
// or anything outcome-related — and stays inside the app.

// MARK: - Style

struct InjectionStampStyle: Equatable {
    enum Shape: Int, CaseIterable { case circle, roundedRect, hexagon, doubleRing }

    /// Curated Trough inks: `paper` reads on the cream sticker, `glow` on the dark UI.
    struct Ink: Equatable {
        let paper: Color
        let glow: Color
    }

    static let inks: [Ink] = [
        Ink(paper: TR.Palette.coralDeep,       glow: TR.Palette.coral),
        Ink(paper: TR.Palette.deepBlue,        glow: TR.Palette.sky),
        Ink(paper: Color(trHex: 0x14867C),     glow: TR.Palette.teal),
        Ink(paper: Color(trHex: 0x5B4BD1),     glow: TR.Palette.lilac),
        Ink(paper: Color(trHex: 0xC8621A),     glow: TR.Palette.tangerine),
        Ink(paper: Color(trHex: 0x5B2A6E),     glow: Color(trHex: 0xC77DFF)),
    ]

    let seed: UInt64
    let shape: Shape
    let ink: Ink
    /// Degrees, −10…+10.
    let tilt: Double

    init(id: UUID) {
        // FNV-1a over the UUID bytes → stable across launches (unlike `hashValue`).
        var hash: UInt64 = 1_469_598_103_934_665_603
        withUnsafeBytes(of: id.uuid) { bytes in
            for b in bytes { hash = (hash ^ UInt64(b)) &* 1_099_511_628_211 }
        }
        var rng = SplitMix64(seed: hash)
        seed = hash
        shape = Shape(rawValue: Int(rng.next() % UInt64(Shape.allCases.count))) ?? .circle
        ink = Self.inks[Int(rng.next() % UInt64(Self.inks.count))]
        tilt = Double(rng.next() % 2001) / 100 - 10
    }
}

// MARK: - Text helpers

enum InjectionStampText {
    /// "Testosterone Cypionate" → "TEST CYP", "HCG" → "HCG", "Nandrolone Decanoate" → "NAND DEC".
    static func compoundShortName(_ name: String) -> String {
        let words = name
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { String($0) }
        guard let first = words.first else { return "—" }
        if words.count == 1 { return String(first.prefix(9)).uppercased() }
        let a = first.count <= 5 ? first : String(first.prefix(4))
        let b = String(words[1].prefix(3))
        return "\(a) \(b)".uppercased()
    }

    /// "Glute Left" → "L · GLUTE", "SubQ Abdomen Right" → "R · SUBQ ABDOMEN".
    static func siteShort(_ site: String?) -> String? {
        guard let site, !site.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var parts = site.split(separator: " ").map(String.init)
        var side: String?
        if let last = parts.last?.lowercased(), last == "left" || last == "right" {
            side = last == "left"
                ? NSLocalizedString("inj14.side.left", value: "L", comment: "Left side, stamp abbreviation")
                : NSLocalizedString("inj14.side.right", value: "R", comment: "Right side, stamp abbreviation")
            parts.removeLast()
        }
        let region = InjectionSite.localizedRegion(parts.joined(separator: " ")).uppercased()
        return side.map { "\($0) · \(region)" } ?? region
    }
}

// MARK: - Shapes

struct TRStampHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 2
            let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Stamp ink

/// The rubber-stamp impression itself (transparent background). Put it on paper with
/// `InjectionStampSticker`, or use it alone.
struct InjectionStampView: View {
    let id: UUID
    let compound: String
    let site: String?
    let date: Date
    var size: CGFloat = 110
    var onDark = false

    private var style: InjectionStampStyle { InjectionStampStyle(id: id) }

    var body: some View {
        let style = style
        let ink = onDark ? style.ink.glow : style.ink.paper
        ZStack {
            outline(style.shape, ink: ink)
            VStack(spacing: size * 0.025) {
                Text(verbatim: "TROUGH")
                    .font(.system(size: size * 0.07, weight: .heavy, design: .rounded))
                    .tracking(size * 0.02)
                    .lineLimit(1)
                Text(verbatim: InjectionStampText.compoundShortName(compound))
                    .font(.system(size: size * 0.15, weight: .black, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let site = InjectionStampText.siteShort(site) {
                    Text(verbatim: site)
                        .font(.system(size: size * 0.075, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(date, format: .dateTime.month(.abbreviated).day(.twoDigits).year())
                    .font(.system(size: size * 0.072, weight: .heavy, design: .monospaced))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, size * 0.035)
                    .padding(.vertical, size * 0.008)
                    .overlay(Rectangle().stroke(ink, lineWidth: size * 0.012))
            }
            .padding(size * (style.shape == .roundedRect ? 0.1 : 0.17))
        }
        .foregroundStyle(ink)
        .frame(width: size, height: style.shape == .roundedRect ? size * 0.8 : size)
        .mask(wear(seed: style.seed))
        .opacity(0.92)
        .rotationEffect(.degrees(style.tilt))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: NSLocalizedString("inj14.stampA11y", value: "Injection stamp: %@", comment: "VoiceOver label; %@ = compound"), compound)))
        .accessibilityValue(Text([site, date.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.joined(separator: ", ")))
    }

    @ViewBuilder
    private func outline(_ shape: InjectionStampStyle.Shape, ink: Color) -> some View {
        let line = size * 0.03
        switch shape {
        case .circle:
            Circle().strokeBorder(ink, lineWidth: line)
                .overlay(Circle().strokeBorder(ink, lineWidth: line * 0.35).padding(line * 1.8))
        case .roundedRect:
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous).strokeBorder(ink, lineWidth: line)
                .overlay(RoundedRectangle(cornerRadius: size * 0.05, style: .continuous).strokeBorder(ink, lineWidth: line * 0.4).padding(line * 1.8))
        case .hexagon:
            TRStampHexagon().stroke(ink, lineWidth: line)
        case .doubleRing:
            Circle().strokeBorder(ink, lineWidth: line)
                .overlay(Circle().strokeBorder(ink, style: StrokeStyle(lineWidth: line * 0.5, dash: [line, line * 0.7])).padding(line * 2.2))
        }
    }

    /// Ink wear: seeded speckles knocked out of the impression so no two look freshly printed.
    private func wear(seed: UInt64) -> some View {
        Canvas { context, canvasSize in
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.black))
            var random = SplitMix64(seed: seed ^ 0xA5A5_5A5A_DEAD_BEEF)
            context.blendMode = .destinationOut
            for _ in 0..<110 {
                let x = Double(random.next() % 1_000) / 1_000 * canvasSize.width
                let y = Double(random.next() % 1_000) / 1_000 * canvasSize.height
                let r = Double(random.next() % 100) / 100 * size * 0.022 + size * 0.004
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.black.opacity(0.85)))
            }
            // A couple of faint dry streaks.
            for _ in 0..<2 {
                let y = Double(random.next() % 1_000) / 1_000 * canvasSize.height
                context.fill(Path(CGRect(x: 0, y: y, width: canvasSize.width, height: size * 0.012)), with: .color(.black.opacity(0.35)))
            }
        }
    }
}

// MARK: - Sticker (stamp on cream paper)

/// A cream paper sticker with the stamp pressed onto it — the tile used in the log grid.
struct InjectionStampSticker: View {
    let injection: SDInjection
    var size: CGFloat = 104

    var body: some View {
        let style = InjectionStampStyle(id: injection.id)
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(trHex: 0xFBF6EA), Color(trHex: 0xEFE6D2)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    // Faint guilloché lines.
                    Canvas { context, s in
                        for row in stride(from: 8.0, through: s.height, by: 10) {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: row))
                            p.addCurve(to: CGPoint(x: s.width, y: row), control1: CGPoint(x: s.width * 0.3, y: row - 4), control2: CGPoint(x: s.width * 0.7, y: row + 4))
                            context.stroke(p, with: .color(Color(trHex: 0xD8CDB3).opacity(0.55)), lineWidth: 0.5)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 2))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
                .shadow(color: style.ink.glow.opacity(0.18), radius: 14)
            InjectionStampView(
                id: injection.id,
                compound: injection.compoundName,
                site: injection.injectionSite,
                date: injection.injectedAt,
                size: size * 0.86
            )
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(style.tilt * 0.2))
    }
}

// MARK: - Calendar marker

/// Glowing "stamped" day marker for the injection calendar.
struct InjectionDayMarker: View {
    let dayNumber: Int
    let injections: [SDInjection]
    let isToday: Bool

    var body: some View {
        let first = injections.first.map { InjectionStampStyle(id: $0.id) }
        ZStack {
            if let style = first {
                Circle()
                    .fill(RadialGradient(colors: [style.ink.glow.opacity(0.55), style.ink.glow.opacity(0.15)], center: .center, startRadius: 1, endRadius: 18))
                Circle()
                    .strokeBorder(style.ink.glow, lineWidth: 2)
                Circle()
                    .strokeBorder(style.ink.glow.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .padding(4)
                    .rotationEffect(.degrees(style.tilt * 3))
            } else if isToday {
                Circle().strokeBorder(TR.Palette.coral, lineWidth: 1.5)
            }
            Text(verbatim: "\(dayNumber)")
                .font(.system(size: 13, weight: first != nil || isToday ? .heavy : .medium, design: .rounded))
                .foregroundStyle(first != nil ? Color.white : (isToday ? TR.Palette.coral : TR.Palette.textPrimary.opacity(0.85)))
            if injections.count > 1 {
                Text(verbatim: "\(injections.count)")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(Color(trHex: 0x3A2600))
                    .frame(width: 13, height: 13)
                    .background(TR.Palette.gold, in: Circle())
                    .offset(x: 13, y: -13)
            }
        }
        .frame(width: 34, height: 34)
        .shadow(color: first.map { $0.ink.glow.opacity(0.6) } ?? .clear, radius: 6)
        .rotationEffect(.degrees(first.map { $0.tilt * 0.6 } ?? 0))
    }
}

// MARK: - Slam overlay

/// The moment a new injection is logged: the stamp SLAMS onto a paper card
/// (scale 2.4 → 1, spring 0.28/0.5) with a heavy haptic and an ink-fleck burst.
/// Reduce Motion: fades in. Tap anywhere to dismiss; auto-dismisses unless `holds`.
struct InjectionStampSlamOverlay: View {
    let injection: SDInjection
    var streakWeeks: Int = 0
    var holds = false
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slammed = false
    @State private var burst = 0
    @State private var captionIn = false

    var body: some View {
        let style = InjectionStampStyle(id: injection.id)
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [Color(trHex: 0xFBF6EA), Color(trHex: 0xEADFC8)], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white, lineWidth: 3))
                        .frame(width: 250, height: 250)
                        .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
                        .shadow(color: style.ink.glow.opacity(slammed ? 0.45 : 0), radius: 30)
                        // Paper jolts when the stamp lands.
                        .scaleEffect(slammed && !reduceMotion ? 1 : 0.97)
                    InjectionStampView(
                        id: injection.id,
                        compound: injection.compoundName,
                        site: injection.injectionSite,
                        date: injection.injectedAt,
                        size: 200
                    )
                    .scaleEffect(slammed || reduceMotion ? 1 : 2.4)
                    .opacity(slammed || reduceMotion ? 1 : 0)
                    ConfettiBurst(
                        trigger: burst,
                        origin: .center,
                        count: 36,
                        duration: 1.1,
                        palette: [style.ink.paper, style.ink.glow, TR.Palette.gold],
                        speeds: 160...420
                    )
                    .frame(width: 320, height: 320)
                }
                VStack(spacing: 10) {
                    Text(NSLocalizedString("inj14.stamped", value: "Stamped!", comment: "Stamp slam headline"))
                        .font(TR.Font.display(32, weight: .black))
                        .foregroundStyle(TR.Palette.textPrimary)
                    HStack(spacing: 8) {
                        TRPill(Text(verbatim: "+15 XP"), systemImage: "sparkles", tint: TR.Palette.gold)
                        if streakWeeks > 0 {
                            TRPill(Text(String(format: NSLocalizedString("inj14.streakWeeksPill", value: "%d-week streak", comment: "Injection on-schedule streak"), streakWeeks)),
                                   systemImage: "flame.fill", tint: TR.Palette.tangerine)
                        }
                    }
                }
                .opacity(captionIn ? 1 : 0)
                .offset(y: captionIn ? 0 : 12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
        .task {
            if reduceMotion {
                captionIn = true
            } else {
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { slammed = true }
                try? await Task.sleep(for: .seconds(0.12))
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
                burst += 1
                withAnimation(TR.Motion.pop.delay(0.1)) { captionIn = true }
            }
            UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("inj14.stamped", value: "Stamped!", comment: ""))
            guard !holds else { return }
            try? await Task.sleep(for: .seconds(2.0))
            onDismiss()
        }
    }
}
