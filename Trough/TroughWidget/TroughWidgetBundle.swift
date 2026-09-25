import WidgetKit
import SwiftUI

@main
struct TroughWidgetBundle: WidgetBundle {
    var body: some Widget {
        TroughStreakWidget()
        TroughNextBadgeWidget()
        TroughLockScreenWidget()
        TroughInjectionLockWidget()
        InjectionLiveActivity()
    }
}

// MARK: - Widget-local palette
// The app's DesignSystem (`TR`) is not a member of this target, so we keep a
// small local copy of the 1.4 tokens ("Night lab, coral pulse"). Keep in sync
// with Trough/Trough/DesignSystem/TroughTheme.swift.

enum WColors {
    // Legacy names (kept so existing call sites compile).
    static let background = Color(wHex: "#1A1A2E")
    static let accent     = Color(wHex: "#E94560")
    static let card       = Color(wHex: "#16213E")
    static let secondary  = Color(wHex: "#0F3460")

    // 1.4 palette.
    static let abyss         = Color(wHex: "#0B0C1E")
    static let surfaceRaised = Color(wHex: "#1E2B52")
    static let coral         = Color(wHex: "#E94560")
    static let coralLight    = Color(wHex: "#FF7A6B")
    static let tangerine     = Color(wHex: "#FF9A4D")
    static let gold          = Color(wHex: "#FFB547")
    static let teal          = Color(wHex: "#2EC4B6")
    static let textPrimary   = Color(wHex: "#F4F5FB")
    static let textSecondary = Color(wHex: "#A0A0C0")
    static let textTertiary  = Color(wHex: "#6E739B")
    static let hairline      = Color.white.opacity(0.08)

    /// abyss → background (top → bottom), the app's screen gradient.
    static var screen: LinearGradient {
        LinearGradient(colors: [abyss, background], startPoint: .top, endPoint: .bottom)
    }

    /// Screen gradient plus a faint coral glow at the top — widget container background.
    static var widgetBackground: some View {
        ZStack {
            screen
            RadialGradient(colors: [coral.opacity(0.22), coral.opacity(0.05), .clear],
                           center: UnitPoint(x: 0.15, y: -0.1), startRadius: 0, endRadius: 190)
        }
    }

    static let ctaColors: [Color] = [coralLight, coral]
    static let xpColors: [Color] = [gold, tangerine]
    static let flameColors: [Color] = [gold, tangerine, coral]

    /// Rank-cover gradient stops (mirror of TR.RankCover), keyed by raw value.
    static func rankCover(_ key: String) -> [Color] {
        switch key {
        case "bronze":   return [Color(wHex: "#D9955B"), Color(wHex: "#8C5A2E")]
        case "silver":   return [Color(wHex: "#E7ECF2"), Color(wHex: "#9AA4B2")]
        case "gold":     return [Color(wHex: "#FFD27A"), Color(wHex: "#E0A23F")]
        case "platinum": return [Color(wHex: "#C9F1FF"), Color(wHex: "#7FB6D9")]
        case "diamond":  return [Color(wHex: "#7CF3FF"), Color(wHex: "#9B8CFF"), Color(wHex: "#FF7AC6")]
        default:         return [Color(wHex: "#E8E1D3"), Color(wHex: "#CFC6B4")] // paper
        }
    }
}

extension Color {
    init(wHex hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

/// Widget string lookup with an English fallback, so 1.4 keys that a locale
/// hasn't translated yet show English rather than the raw key.
func wLoc(_ key: String, _ english: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: english, comment: "")
}
