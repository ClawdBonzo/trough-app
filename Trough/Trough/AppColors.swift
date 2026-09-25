import SwiftUI

/// Legacy colour names. Forwards to the 1.4 design tokens in `TR.Palette`
/// (DesignSystem/TroughTheme.swift). Prefer `TR.Palette` in new code.
enum AppColors {
    /// #1A1A2E
    static let background    = TR.Palette.background
    /// #E94560
    static let accent        = TR.Palette.coral
    /// #16213E
    static let card          = TR.Palette.surface
    /// #0F3460
    static let secondary     = TR.Palette.deepBlue
    /// #F4F5FB — use for primary body text when `.primary` doesn't apply in dark context
    static let textPrimary   = TR.Palette.textPrimary
    /// #A0A0C0 — use for secondary / muted text
    static let textSecondary = TR.Palette.textSecondary
    /// #2E86AB — calm teal-blue for soft trial CTAs (replaces aggressive pink "Unlock")
    static let softCTA       = Color(hex: "#2E86AB")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
