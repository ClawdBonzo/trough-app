import WidgetKit
import SwiftUI

@main
struct TroughWidgetBundle: WidgetBundle {
    var body: some Widget {
        TroughStreakWidget()
        InjectionLiveActivity()
    }
}

// MARK: - Widget-local palette (mirrors AppColors; the app's AppColors is not a
// member of this target, so we keep a small local copy).

enum WColors {
    static let background = Color(wHex: "#1A1A2E")
    static let accent     = Color(wHex: "#E94560")
    static let card       = Color(wHex: "#16213E")
    static let secondary  = Color(wHex: "#0F3460")
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
