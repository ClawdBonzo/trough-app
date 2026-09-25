import SwiftUI
import UIKit

// MARK: - Format

/// Share card sizes. Designed on a point canvas and rendered at 3×, so exports are exact pixels.
enum TRShareFormat: String, CaseIterable, Identifiable {
    /// 1080 × 1920 — Instagram / TikTok / WhatsApp stories.
    case story
    /// 1080 × 1080 — messages, anywhere.
    case square

    var id: String { rawValue }

    static let renderScale: CGFloat = 3

    var pixelSize: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }

    var canvasSize: CGSize {
        CGSize(width: pixelSize.width / Self.renderScale, height: pixelSize.height / Self.renderScale)
    }

    var title: String {
        switch self {
        case .story: return gLoc("ach.share.format.story", "Story")
        case .square: return gLoc("ach.share.format.square", "Square")
        }
    }
}

// MARK: - Renderer

/// Turns a view into pixels with `ImageRenderer`. Cards are artwork: fixed Dynamic Type
/// (`.large`), dark appearance, and the static-render environment so every `Reveal`/`CountUp`
/// shows its final state (no half-finished animations in an export).
@MainActor
enum ShareRenderer {

    /// Renders a card at the format's canvas size, 3× (opaque).
    static func render<Content: View>(_ content: Content, format: TRShareFormat) -> UIImage? {
        render(content, size: format.canvasSize, opaque: true)
    }

    /// Renders any view at `size` points × 3. `opaque: false` keeps transparency (medallions).
    static func render<Content: View>(_ content: Content, size: CGSize, opaque: Bool) -> UIImage? {
        let view = content
            .frame(width: size.width, height: size.height)
            .environment(\.trStaticRender, true)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = TRShareFormat.renderScale
        renderer.isOpaque = opaque
        guard let cgImage = renderer.cgImage else { return nil }
        return UIImage(cgImage: cgImage, scale: TRShareFormat.renderScale, orientation: .up)
    }

    /// PNG bytes for a share card.
    static func png(kind: ShareCardKind, data: ShareCardData, format: TRShareFormat) -> Data? {
        render(TRShareCardView(kind: kind, data: data, format: format), format: format)?.pngData()
    }

    #if DEBUG
    /// Exports every share card (story + square) plus large badge medallions, a streak flame
    /// emblem and a rank emblem as PNGs into `dir` (created if needed). Cards are opaque;
    /// medallions/emblems are transparent. Returns the written file URLs.
    ///
    /// Files: card-rank-story.png, card-rank-square.png, card-streak-story.png,
    /// card-streak-square.png, card-badge-story.png, card-badge-square.png,
    /// medallion-<badgeID>.png ×3, emblem-streak-flame.png, emblem-rank.png.
    @discardableResult
    static func exportAssets(to dir: URL, data: ShareCardData = .sample) -> [URL] {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var written: [URL] = []

        func write(_ image: UIImage?, _ name: String) {
            guard let png = image?.pngData() else { return }
            let url = dir.appendingPathComponent(name)
            if (try? png.write(to: url, options: .atomic)) != nil { written.append(url) }
        }

        let featured = GamificationCatalog.badge("consistency_king") ?? GamificationCatalog.badges[0]
        let cards: [(ShareCardKind, String)] = [(.rank, "rank"), (.streak, "streak"), (.badge(featured), "badge")]
        for (kind, name) in cards {
            for format in TRShareFormat.allCases {
                write(render(TRShareCardView(kind: kind, data: data, format: format), format: format),
                      "card-\(name)-\(format.rawValue).png")
            }
        }

        // Large medallions (transparent), padded so the glow isn't clipped.
        let medallionIDs = ["consistency_king", "checkin_streak_100", "on_schedule_weeks_12"]
        for id in medallionIDs {
            guard let def = GamificationCatalog.badge(id) else { continue }
            let art = BadgeMedallion(systemImage: def.symbol, tier: def.tier, status: .unlocked, size: 240, discColors: def.discColors)
                .padding(40)
            write(render(art, size: CGSize(width: 320, height: 320), opaque: false), "medallion-\(id).png")
        }

        let flame = StreakFlameEmblem(level: 5, size: 240).padding(40)
        write(render(flame, size: CGSize(width: 320, height: 320), opaque: false), "emblem-streak-flame.png")

        let rank = RankEmblem(level: data.level, width: 220).padding(40)
        write(render(rank, size: CGSize(width: 300, height: 220 * 1.38 + 80), opaque: false), "emblem-rank.png")

        return written
    }
    #endif
}
