import SwiftUI

// Trough 1.4 design tokens — "Night lab, coral pulse."
// Dark-first. See Docs/DESIGN_SPEC_1.4.md. `AppColors` forwards to these.

// MARK: - Hex init

extension Color {
    /// `Color(trHex: 0xE94560)` — 24-bit RGB, sRGB, with optional opacity.
    init(trHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - TR

enum TR {

    // MARK: Palette

    enum Palette {
        /// #0B0C1E — deepest background (top of the screen gradient).
        static let abyss         = Color(trHex: 0x0B0C1E)
        /// #1A1A2E — app background.
        static let background    = Color(trHex: 0x1A1A2E)
        /// #16213E — card surface.
        static let surface       = Color(trHex: 0x16213E)
        /// #1E2B52 — raised card / pills.
        static let surfaceRaised = Color(trHex: 0x1E2B52)
        /// #0F3460 — deep blue (legacy secondary).
        static let deepBlue      = Color(trHex: 0x0F3460)
        /// White @ 8% — card/pill strokes.
        static let hairline      = Color.white.opacity(0.08)

        /// #E94560 — primary accent.
        static let coral         = Color(trHex: 0xE94560)
        /// #FF7A6B — CTA gradient top stop.
        static let coralLight    = Color(trHex: 0xFF7A6B)
        /// #C2304F
        static let coralDeep     = Color(trHex: 0xC2304F)
        /// #FF9A4D
        static let tangerine     = Color(trHex: 0xFF9A4D)
        /// #FFB547 — XP, streaks, medals, highlight.
        static let gold          = Color(trHex: 0xFFB547)
        /// #2EC4B6 — on-track / healthy logging.
        static let teal          = Color(trHex: 0x2EC4B6)
        /// #5AA9FF
        static let sky           = Color(trHex: 0x5AA9FF)
        /// #9B8CFF
        static let lilac         = Color(trHex: 0x9B8CFF)
        /// #34D399 — success.
        static let mint          = Color(trHex: 0x34D399)

        /// #F4F5FB
        static let textPrimary   = Color(trHex: 0xF4F5FB)
        /// #A0A0C0
        static let textSecondary = Color(trHex: 0xA0A0C0)
        /// #6E739B
        static let textTertiary  = Color(trHex: 0x6E739B)

        /// Confetti / sparkle colours.
        static let celebration: [Color] = [coral, gold, teal, sky, lilac, tangerine, .white]
    }

    // MARK: Gradients

    enum Gradients {
        static let ctaColors: [Color] = [Palette.coralLight, Palette.coral]
        static let sunsetColors: [Color] = [Palette.deepBlue, Color(trHex: 0x5B2A6E), Palette.coral, Palette.tangerine]
        static let screenColors: [Color] = [Palette.abyss, Palette.background]
        static let xpColors: [Color] = [Palette.gold, Palette.tangerine]

        /// coralLight → coral, top → bottom.
        static let cta = LinearGradient(colors: ctaColors, startPoint: .top, endPoint: .bottom)
        /// Hero / share backdrop: deep blue → plum → coral → tangerine.
        static let sunset = LinearGradient(colors: sunsetColors, startPoint: .top, endPoint: .bottom)
        /// App-wide background: abyss → background.
        static let screen = LinearGradient(colors: screenColors, startPoint: .top, endPoint: .bottom)
        /// XP bars: gold → tangerine (leading → trailing).
        static let xp = LinearGradient(colors: xpColors, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: Rank covers

    /// Card/cover look for the user's level (11 levels). Celebrates consistency only.
    enum RankCover: String, CaseIterable, Identifiable {
        case paper, bronze, silver, gold, platinum, diamond

        var id: String { rawValue }

        /// L1–2 paper, L3–4 bronze, L5–6 silver, L7–8 gold, L9–10 platinum, L11+ diamond.
        static func forLevel(_ level: Int) -> RankCover {
            switch level {
            case ..<3: return .paper
            case 3...4: return .bronze
            case 5...6: return .silver
            case 7...8: return .gold
            case 9...10: return .platinum
            default: return .diamond
            }
        }

        var colors: [Color] {
            switch self {
            case .paper:    return [Color(trHex: 0xE8E1D3), Color(trHex: 0xCFC6B4)]
            case .bronze:   return [Color(trHex: 0xD9955B), Color(trHex: 0x8C5A2E)]
            case .silver:   return [Color(trHex: 0xE7ECF2), Color(trHex: 0x9AA4B2)]
            case .gold:     return [Color(trHex: 0xFFD27A), Color(trHex: 0xE0A23F)]
            case .platinum: return [Color(trHex: 0xC9F1FF), Color(trHex: 0x7FB6D9)]
            case .diamond:  return [Color(trHex: 0x7CF3FF), Color(trHex: 0x9B8CFF), Color(trHex: 0xFF7AC6)]
            }
        }

        var gradient: LinearGradient {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        /// Text/glyph colour that reads on the cover.
        var ink: Color {
            switch self {
            case .paper:    return Color(trHex: 0x3A3326)
            case .bronze:   return Color(trHex: 0x2B1A0C)
            case .silver:   return Color(trHex: 0x1E2530)
            case .gold:     return Color(trHex: 0x3A2600)
            case .platinum: return Color(trHex: 0x0D2A3A)
            case .diamond:  return Color(trHex: 0x120A2E)
            }
        }

        var displayName: String {
            switch self {
            case .paper:    return NSLocalizedString("rank.cover.paper", value: "Paper", comment: "Rank cover name, levels 1–2")
            case .bronze:   return NSLocalizedString("rank.cover.bronze", value: "Bronze", comment: "Rank cover name, levels 3–4")
            case .silver:   return NSLocalizedString("rank.cover.silver", value: "Silver", comment: "Rank cover name, levels 5–6")
            case .gold:     return NSLocalizedString("rank.cover.gold", value: "Gold", comment: "Rank cover name, levels 7–8")
            case .platinum: return NSLocalizedString("rank.cover.platinum", value: "Platinum", comment: "Rank cover name, levels 9–10")
            case .diamond:  return NSLocalizedString("rank.cover.diamond", value: "Diamond", comment: "Rank cover name, level 11")
            }
        }
    }

    // MARK: Metrics

    enum Metrics {
        static let gutter: CGFloat = 16
        static let cardRadius: CGFloat = 22
        static let controlRadius: CGFloat = 14
        static let sectionSpacing: CGFloat = 24
        static let minTap: CGFloat = 44
        static let buttonHeight: CGFloat = 54
        static let cardPadding: CGFloat = 16
    }

    // MARK: Motion

    enum Motion {
        /// Celebratory pop (badge unlock, level up).
        static let pop = Animation.spring(response: 0.42, dampingFraction: 0.52)
        /// Button press feedback.
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
        static let snappy = Animation.snappy(duration: 0.28)
        static let gentle = Animation.easeInOut(duration: 0.35)

        /// `animation`, or a short cross-fade when Reduce Motion is on.
        static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
            reduceMotion ? .easeInOut(duration: 0.2) : animation
        }
    }

    // MARK: Type

    enum Font {
        /// Display headline: SF Pro Rounded, heavy.
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .heavy) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        /// Display headline scaling with Dynamic Type from a text style.
        static func display(_ style: SwiftUI.Font.TextStyle, weight: SwiftUI.Font.Weight = .heavy) -> SwiftUI.Font {
            .system(style, design: .rounded).weight(weight)
        }

        /// Numbers: rounded, black, monospaced digits.
        static func number(_ size: CGFloat, weight: SwiftUI.Font.Weight = .black) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded).monospacedDigit()
        }

        /// Numbers scaling with Dynamic Type from a text style.
        static func number(_ style: SwiftUI.Font.TextStyle, weight: SwiftUI.Font.Weight = .black) -> SwiftUI.Font {
            .system(style, design: .rounded).weight(weight).monospacedDigit()
        }

        /// Kicker: caption, heavy (apply `.textCase(.uppercase)` + `.tracking(1.2)` or use `TRKicker`).
        static let kicker: SwiftUI.Font = .caption.weight(.heavy)
    }
}
