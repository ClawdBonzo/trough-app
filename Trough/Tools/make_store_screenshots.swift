// Trough: App Store marketing frames (ported from Places I've Visited's compositor).
//
// Seven slides composed as ONE panorama (a night-lab sky fading to a coral/tangerine horizon, stars, a
// faint dot grid, horizon blooms and a dashed PK wave that runs across every join, with a white-hot dot
// at each trough and syringe / droplet glyphs in the gutters), then cut into frames. Each slide: a big
// two-line SF Pro Rounded Heavy headline with *accent* words in a gold → tangerine → coral gradient, a
// subline, a programmatic iPhone (titanium band, Dynamic Island) around the raw capture, and crisp
// floating assets rendered by the app itself (-TRExportAssets) that break out of the phone.
//
// Usage (normally via Tools/make_store_screenshots.sh):
//   swiftc -O -o compose Tools/make_store_screenshots.swift
//   ./compose --metadata fastlane/metadata --raw <rawDir> --assets <assetsDir> --out fastlane/screenshots \
//             --locale en-US [--language en] [--icon AppIcon-1024.png] [--contact <contact.png>]
//   rawDir    : 01-home.png 02-checkin.png 03-pk.png 04-injections.png 05-achievements.png 06-bloodwork.png 07-privacy.png
//   assetsDir : Documents/StoreAssets from the app (rank-card, streak-card, pk-card, next-injection, stamp-<n>,
//               badge-<n>, marker-card, xp-chip, card-*-story, …)
//   out       : <out>/<locale>/<n>_iphone69.png (1…7, the names `deliver` uploads). Old *_iphone69.png there are
//               replaced. The contact sheet goes to --contact (never into the deliver folder: deliver uploads
//               every PNG it finds there).
// Canvas: iPhone 6.9" 1320 × 2868. PNG, RGB, no alpha.
// Copy: <metadata>/<locale>/screenshot_headlines.json, {"1": {"headline": "…*accent*…", "sub": "…", "chips": […]}, …}.
// At most 2 lines each; one type size for the whole set; shrinks to fit without splitting a word (CJK aware).

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import NaturalLanguage
import UniformTypeIdentifiers

// MARK: Arguments

var options: [String: String] = [:]
do {
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let key = iterator.next() {
        guard key.hasPrefix("--"), let value = iterator.next() else { print("bad argument \(key)"); exit(1) }
        options[String(key.dropFirst(2))] = value
    }
}
guard let metadataPath = options["metadata"], let rawPath = options["raw"], let assetsPath = options["assets"], let outPath = options["out"] else {
    print("usage: make_store_screenshots --metadata <dir> --raw <dir> --assets <dir> --out <dir> [--locale en-US] [--language en] [--icon AppIcon.png] [--contact contact.png]")
    exit(1)
}
let storeLocale = options["locale"] ?? "en-US"
/// The language the headline is set in (font and line breaking).
let language: String = options["language"] ?? {
    let map = ["en-US": "en", "en-GB": "en", "en-CA": "en", "en-AU": "en", "es-ES": "es", "es-MX": "es", "pt-BR": "pt", "fr-FR": "fr", "fr-CA": "fr",
               "de-DE": "de", "it": "it", "nl-NL": "nl", "ja": "ja", "ko": "ko", "zh-Hant": "zh-Hant", "zh-Hans": "zh-Hans", "pl": "pl", "sv": "sv", "he": "he", "ar-SA": "ar"]
    return map[storeLocale] ?? String(storeLocale.prefix(2))
}()
let rawDirectory = URL(fileURLWithPath: rawPath)
let assetsDirectory = URL(fileURLWithPath: assetsPath)

let W: CGFloat = 1320
let H: CGFloat = 2868
let slideCount = 7
let PW = W * CGFloat(slideCount)
/// Layout unit (1 on iPhone 6.9").
let u: CGFloat = 1
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Trough palette (Docs/DESIGN_SPEC_1.4.md)
let abyss: UInt32 = 0x0B0C1E, background: UInt32 = 0x1A1A2E, surface: UInt32 = 0x16213E, surfaceRaised: UInt32 = 0x1E2B52
let deepBlue: UInt32 = 0x0F3460, plum: UInt32 = 0x5B2A6E
let coral: UInt32 = 0xE94560, coralLight: UInt32 = 0xFF7A6B, tangerine: UInt32 = 0xFF9A4D, gold: UInt32 = 0xFFB547
let teal: UInt32 = 0x2EC4B6, sky: UInt32 = 0x5AA9FF, lilac: UInt32 = 0x9B8CFF, mint: UInt32 = 0x34D399
let paper: UInt32 = 0xF4F5FB, cream: UInt32 = 0xFBF4E4

// MARK: Line breaking (from PlacesKit/Tools/make_store_screenshots.swift, via Places I've Visited)

let wordJoiner = "\u{2060}"
let languageKey = NSAttributedString.Key("wlLanguage")
let rtlLanguages: Set<String> = ["ar", "he"]
let openingMarks: Set<Character> = ["「", "『", "（", "(", "［", "[", "〈", "《", "【", "〔", "“", "‘", "«"]
let chineseParticles: Set<String> = ["的", "了", "吗", "嗎", "呢", "吧", "着", "著", "过", "過", "地", "得", "们", "們", "里", "裡"]
let unitCharacters: Set<Character> = ["万", "萬", "億", "亿", "兆", "千", "百", "円", "元", "塊", "块", "圓", "ウ", "ォ", "ン"]
let japaneseParticles: Set<String> = [
    "は", "が", "を", "に", "で", "と", "も", "の", "へ", "や", "か", "ね", "よ", "な", "ば", "て", "た", "だ", "から", "まで", "より", "だけ", "など",
    "って", "ので", "のに", "けど", "です", "ます", "ない", "たい", "する", "した", "して", "いる", "ある", "れる", "られる", "として", "ながら",
    "でも", "には", "では", "とは", "への", "での", "にも", "っ", "ん"
]

/// Marks where a line may NOT break, so wrapped text never splits a word.
func keepingWordsWhole(_ marked: String, language: String) -> String {
    if language == "th" { return marked }
    let plain = Array(marked.filter { $0 != "*" })
    guard plain.count > 1 else { return marked }
    let unspaced = ["ja", "zh-Hans", "zh-Hant"].contains(language)
    var mayBreakBefore = [Bool](repeating: false, count: plain.count)
    if unspaced {
        let text = String(plain)
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(language == "ja" ? .japanese : language == "zh-Hans" ? .simplifiedChinese : .traditionalChinese)
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            guard start > 0 else { return true }
            let word = String(text[range]), previous = plain[start - 1]
            let afterPunctuation = previous.isPunctuation || previous.isWhitespace
            let loneKana = language == "ja" && word.count == 1 && word.unicodeScalars.allSatisfy { (0x3040...0x309F).contains($0.value) }
            let particle = loneKana || (language == "ja" ? japaneseParticles.contains(word) : chineseParticles.contains(word))
            let beforeWord = plain[..<start].last { !$0.isWhitespace } ?? " "
            let afterNumber = beforeWord.isNumber || (unitCharacters.contains(beforeWord) && word.allSatisfy(unitCharacters.contains))
            mayBreakBefore[start] = (afterPunctuation || !particle) && !afterNumber && !openingMarks.contains(previous)
            return true
        }
        for index in 1..<plain.count where openingMarks.contains(plain[index]) { mayBreakBefore[index] = true }
        var offset = 0, accentStart: Int?
        for character in marked {
            if character == "*" {
                if let start = accentStart {
                    if offset - start <= 8 { for index in (start + 1)..<max(start + 1, offset) { mayBreakBefore[index] = false } }
                    accentStart = nil
                } else { accentStart = offset }
            } else { offset += 1 }
        }
    } else {
        for index in 1..<plain.count { mayBreakBefore[index] = plain[index - 1].isWhitespace || plain[index].isWhitespace }
    }
    var result = "", offset = 0
    for character in marked {
        if character == "*" { result.append(character); continue }
        if offset > 0 && !mayBreakBefore[offset] && !character.isWhitespace && !plain[offset - 1].isWhitespace {
            let betweenLetters = plain[offset - 1].isLetter && character.isLetter
            if language == "ko" || unspaced || !betweenLetters { result += wordJoiner }
        }
        result.append(character)
        offset += 1
    }
    return result
}

enum Weight { case headline, sub, chip }

/// SF Pro Rounded for spaced scripts; the system UI face for the language elsewhere (CJK, Arabic, Hebrew, Thai).
func font(_ weight: Weight, size: CGFloat, language: String) -> CTFont {
    let native = ["ja", "ko", "zh-Hans", "zh-Hant", "ar", "he", "th"].contains(language)
    if native {
        let base = CTFontCreateUIFontForLanguage(weight == .sub ? .system : .emphasizedSystem, size, language as CFString)
        return base ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }
    let nsWeight: NSFont.Weight = weight == .headline ? .heavy : weight == .chip ? .bold : .semibold
    var nsFont = NSFont.systemFont(ofSize: size, weight: nsWeight)
    if let rounded = nsFont.fontDescriptor.withDesign(.rounded) { nsFont = NSFont(descriptor: rounded, size: size) ?? nsFont }
    return nsFont as CTFont
}

func attributed(_ marked: String, size: CGFloat, weight: Weight = .headline, base: CGColor, highlight: CGColor, alignment: NSTextAlignment = .center) -> NSAttributedString {
    let ctFont = font(weight, size: size, language: language)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineHeightMultiple = weight == .headline ? 0.98 : 1.14
    if rtlLanguages.contains(language) { paragraph.baseWritingDirection = .rightToLeft }
    let result = NSMutableAttributedString()
    for (index, part) in keepingWordsWhole(marked, language: language).components(separatedBy: "*").enumerated() where !part.isEmpty {
        var attributes: [NSAttributedString.Key: Any] = [
            languageKey: language, .font: ctFont,
            .foregroundColor: NSColor(cgColor: index % 2 == 1 ? highlight : base) ?? .white, .paragraphStyle: paragraph,
        ]
        if weight == .headline, !["ja", "ko", "zh-Hans", "zh-Hant", "ar", "he", "th"].contains(language) { attributes[.kern] = -size * 0.014 }
        result.append(NSAttributedString(string: part, attributes: attributes))
    }
    return result
}

func measure(_ text: NSAttributedString, width: CGFloat) -> CGSize {
    CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString(text), CFRange(location: 0, length: 0), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)
}

func lines(of text: NSAttributedString, width: CGFloat) -> [CTLine] {
    let setter = CTFramesetterCreateWithAttributedString(text)
    let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 20_000), transform: nil)
    return CTFrameGetLines(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)) as? [CTLine] ?? []
}

func fits(_ text: NSAttributedString, width: CGFloat, maxLines: Int) -> Bool {
    let set = lines(of: text, width: width)
    guard set.count <= maxLines else { return false }
    let string = text.string as NSString
    let breaksOnlyAtSpaces = !["ja", "zh-Hans", "zh-Hant", "th"].contains(language)
    for line in set.dropLast() {
        let range = CTLineGetStringRange(line)
        let next = range.location + range.length
        guard next > 0, next < string.length else { continue }
        if string.character(at: next) == 0x2060 || string.character(at: next - 1) == 0x2060 { return false }
        if breaksOnlyAtSpaces, let scalar = Unicode.Scalar(string.character(at: next - 1)), !CharacterSet.whitespacesAndNewlines.contains(scalar) { return false }
    }
    for line in set where CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line) > Double(width) + 0.5 { return false }
    return true
}

func balancedWidth(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
    let count = lines(of: text, width: width).count
    guard count > 1 else { return width }
    var low = width / CGFloat(count) * 0.8, high = width
    while high - low > 6 {
        let middle = (low + high) / 2
        if fits(text, width: middle, maxLines: count) { high = middle } else { low = middle }
    }
    return min(width, ceil(high) + 2)
}

func clausePerLine(_ marked: String) -> String {
    let characters = Array(marked)
    let visible = characters.filter { $0 != "*" }.count
    var best: (index: Int, distance: Int)?
    var seen = 0
    for (index, character) in characters.enumerated() where character != "*" {
        seen += 1
        let fullWidth = character == "，" || character == "、"
        let spaced = [",", "،", ";", ":", "—", "–"].contains(character) && index + 1 < characters.count && characters[index + 1].isWhitespace
        guard fullWidth || spaced, seen * 10 >= visible * 3, seen * 10 <= visible * 7 else { continue }
        let distance = abs(seen * 2 - visible)
        if best == nil || distance < best!.distance { best = (index, distance) }
    }
    guard let cut = best?.index else { return marked }
    var tail = Array(characters[(cut + 1)...])
    var markers = ""
    while let first = tail.first, first == "*" || first.isWhitespace { if first == "*" { markers.append(first) }; tail.removeFirst() }
    return String(characters[...cut]) + markers + "\n" + String(tail)
}

func sentencePerLine(_ marked: String) -> String {
    let characters = Array(marked)
    var result = "", index = 0
    while index < characters.count {
        let character = characters[index]
        result.append(character)
        index += 1
        guard [".", "。", "?", "？", "؟", "!", "！", "…"].contains(character) else { continue }
        var ahead = index
        while ahead < characters.count, characters[ahead] == "*" { ahead += 1 }
        let fullWidth = character == "。" || character == "？" || character == "！"
        guard ahead < characters.count, fullWidth || characters[ahead].isWhitespace else { continue }
        result.append(contentsOf: characters[index..<ahead])
        index = ahead
        while index < characters.count, characters[index].isWhitespace { index += 1 }
        if index < characters.count { result.append("\n") }
    }
    return result
}

/// The text as it will be set: sentence or clause per line when that costs little size, else free wrapping.
func arrangement(_ marked: String, size: CGFloat, width: CGFloat, weight: Weight) -> String {
    let white = color(0xFFFFFF)
    if fits(attributed(marked, size: size, weight: weight, base: white, highlight: white), width: width, maxLines: 1) { return marked }
    let sentences = sentencePerLine(marked)
    if sentences != marked { return sentences }
    return clausePerLine(marked)
}

/// Largest size (≤ start) at which `marked` fits in `maxLines`.
func fittedSize(_ marked: String, start: CGFloat, floor: CGFloat, width: CGFloat, maxLines: Int, weight: Weight) -> (text: String, size: CGFloat) {
    let white = color(0xFFFFFF)
    func largest(_ source: String, downTo limit: CGFloat) -> CGFloat? {
        var size = start
        while size >= limit {
            if fits(attributed(source, size: size, weight: weight, base: white, highlight: white), width: width, maxLines: maxLines) { return size }
            size -= 2
        }
        return nil
    }
    if fits(attributed(marked, size: start, weight: weight, base: white, highlight: white), width: width, maxLines: 1) { return (marked, start) }
    let sentences = sentencePerLine(marked)
    if sentences != marked, let size = largest(sentences, downTo: start * 0.8) { return (sentences, size) }
    let clauses = clausePerLine(marked)
    if sentences == marked, clauses != marked, let size = largest(clauses, downTo: start * 0.86) { return (clauses, size) }
    return (marked, largest(marked, downTo: floor) ?? floor)
}

// MARK: Drawing helpers (top-left coordinates on the panorama; CG is y-up underneath)

/// A rect given from the top-left.
func R(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect { CGRect(x: x, y: H - top - height, width: width, height: height) }

func load(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

var missing: [String] = []
func asset(_ name: String) -> CGImage? {
    if let image = load(assetsDirectory.appendingPathComponent(name)) { return image }
    missing.append(name)
    return nil
}
func raw(_ name: String) -> CGImage? {
    if let image = load(rawDirectory.appendingPathComponent(name)) { return image }
    missing.append(name)
    return nil
}

/// Draws text centred in [x, x + width] with its top edge at `top`. Accent spans get the gradient.
@discardableResult
func drawText(_ marked: String, size: CGFloat, weight: Weight, centerX: CGFloat, top: CGFloat, width maximumWidth: CGFloat, base: CGColor, gradient: [UInt32]?, in context: CGContext) -> CGFloat {
    let probe = attributed(marked, size: size, weight: weight, base: base, highlight: base)
    let width = balancedWidth(probe, width: maximumWidth)
    let height = ceil(measure(probe, width: width).height) + 8
    let rect = R(centerX - width / 2, top, width, height)
    func frame(_ text: NSAttributedString, _ target: CGContext, _ rect: CGRect) {
        let setter = CTFramesetterCreateWithAttributedString(text)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil), target)
    }
    guard let gradient, marked.contains("*") else {
        frame(probe, context, rect)
        return top + height
    }
    // Base text without the accents, then the accents as a mask filled with a gradient.
    frame(attributed(marked, size: size, weight: weight, base: base, highlight: color(0, 0)), context, rect)
    let maskWidth = Int(ceil(rect.width)), maskHeight = Int(ceil(rect.height))
    guard let mask = CGContext(data: nil, width: maskWidth, height: maskHeight, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return top + height }
    mask.setFillColor(gray: 0, alpha: 1)
    mask.fill(CGRect(x: 0, y: 0, width: maskWidth, height: maskHeight))
    frame(attributed(marked, size: size, weight: weight, base: CGColor(gray: 0, alpha: 1), highlight: CGColor(gray: 1, alpha: 1)), mask, CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
    guard let maskImage = mask.makeImage() else { return top + height }
    context.saveGState()
    context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: CGFloat(maskWidth), height: CGFloat(maskHeight)), mask: maskImage)
    let fill = CGGradient(colorsSpace: colorSpace, colors: gradient.map { color($0) } as CFArray, locations: nil)!
    context.drawLinearGradient(fill, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    return top + height
}

/// Runs `body` in a coordinate space centred on (cx, cy) (top-left coordinates), rotated clockwise by `degrees`.
func placed(_ context: CGContext, cx: CGFloat, cy: CGFloat, degrees: CGFloat, _ body: () -> Void) {
    context.saveGState()
    context.translateBy(x: cx, y: H - cy)
    context.rotate(by: -degrees * .pi / 180)
    body()
    context.restoreGState()
}

/// A floating asset: centred at (cx, cy), `width` wide, rotated, with a soft shadow.
/// `corner` rounds and strokes an opaque card; nil draws a transparent asset as is.
func float(_ image: CGImage?, cx: CGFloat, cy: CGFloat, width: CGFloat, degrees: CGFloat = 0, corner: CGFloat? = nil, shadow: CGFloat = 1, in context: CGContext) {
    guard let image else { return }
    let height = width * CGFloat(image.height) / CGFloat(image.width)
    let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
    placed(context, cx: cx, cy: cy, degrees: degrees) {
        context.interpolationQuality = .high
        if let corner {
            let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -40 * u * shadow), blur: 90 * u * shadow, color: color(0x000000, 0.55))
            context.addPath(path); context.setFillColor(color(surface)); context.fillPath()
            context.restoreGState()
            context.saveGState()
            context.addPath(path); context.clip()
            context.draw(image, in: rect)
            context.restoreGState()
            context.addPath(path)
            context.setStrokeColor(color(0xFFFFFF, 0.28))
            context.setLineWidth(3 * u)
            context.strokePath()
        } else {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -26 * u * shadow), blur: 60 * u * shadow, color: color(0x000000, 0.55))
            context.draw(image, in: rect)
            context.restoreGState()
        }
    }
}

/// An SF Symbol as a CGImage (AppKit), tinted.
func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .bold, tint: NSColor = .white) -> CGImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else { return nil }
    let size = image.size
    let scale: CGFloat = 2
    guard let bitmap = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    bitmap.scaleBy(x: scale, y: scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
    image.draw(in: CGRect(origin: .zero, size: size))
    tint.set()
    CGRect(origin: .zero, size: size).fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.makeImage()
}

func drawSymbol(_ name: String, cx: CGFloat, cy: CGFloat, height: CGFloat, degrees: CGFloat = 0, tint: NSColor = .white, weight: NSFont.Weight = .bold, in context: CGContext) {
    guard let image = symbol(name, pointSize: height, weight: weight, tint: tint) else { return }
    let aspect = CGFloat(image.width) / CGFloat(image.height)
    let h = height, w = h * aspect
    placed(context, cx: cx, cy: cy, degrees: degrees) {
        context.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
    }
}

func radialGlow(_ context: CGContext, cx: CGFloat, cy: CGFloat, radius: CGFloat, hex: UInt32, alpha: CGFloat) {
    let center = CGPoint(x: cx, y: H - cy)
    let glow = CGGradient(colorsSpace: colorSpace, colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// MARK: Device frame

/// A modern iPhone drawn from scratch around a raw capture: titanium band, black bezel, Dynamic Island,
/// side buttons. `width` is the device body width. Returns the screen rect (top-left coords).
@discardableResult
func drawDevice(_ capture: CGImage?, cx: CGFloat, top: CGFloat, width: CGFloat, in context: CGContext) -> CGRect {
    let aspect = capture.map { CGFloat($0.width) / CGFloat($0.height) } ?? (1320.0 / 2868.0)
    let band = width * 0.022        // titanium band
    let bezel = width * 0.024       // black glass border
    let screenWidth = width - 2 * (band + bezel)
    let screenHeight = screenWidth / aspect
    let height = screenHeight + 2 * (band + bezel)
    let s = screenWidth / 440       // points of a 440-pt-wide iPhone 17 Pro Max screen
    let screenRadius = 64 * s
    let body = R(cx - width / 2, top, width, height)
    let bodyRadius = screenRadius + band + bezel

    // Side buttons (behind the body).
    context.setFillColor(color(0x3A3F48))
    for (y, h) in [(0.17, 0.032), (0.235, 0.062), (0.31, 0.062)] as [(CGFloat, CGFloat)] {
        context.addPath(CGPath(roundedRect: R(body.minX - 7 * u, top + height * y, 12 * u, height * h), cornerWidth: 5 * u, cornerHeight: 5 * u, transform: nil))
    }
    context.addPath(CGPath(roundedRect: R(body.maxX - 5 * u, top + height * 0.25, 12 * u, height * 0.1), cornerWidth: 5 * u, cornerHeight: 5 * u, transform: nil))
    context.addPath(CGPath(roundedRect: R(body.maxX - 5 * u, top + height * 0.47, 10 * u, height * 0.055), cornerWidth: 4 * u, cornerHeight: 4 * u, transform: nil))
    context.fillPath()

    let bodyPath = CGPath(roundedRect: body, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)
    // Shadows: a deep drop shadow and a warm coral glow.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -60 * u), blur: 140 * u, color: color(0x000000, 0.62))
    context.addPath(bodyPath); context.setFillColor(color(0x15181D)); context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.setShadow(offset: .zero, blur: 130 * u, color: color(coral, 0.30))
    context.addPath(bodyPath); context.setFillColor(color(0x15181D)); context.fillPath()
    context.restoreGState()
    // Titanium band: a brushed gradient with highlights on both edges.
    context.saveGState()
    context.addPath(bodyPath); context.clip()
    let metal = CGGradient(colorsSpace: colorSpace, colors: [color(0x8C929C), color(0x4A4F58), color(0x2B2F36), color(0x5D636D), color(0x9AA0A9)] as CFArray, locations: [0, 0.18, 0.5, 0.82, 1])!
    context.drawLinearGradient(metal, start: CGPoint(x: body.minX, y: body.midY), end: CGPoint(x: body.maxX, y: body.midY), options: [])
    context.restoreGState()
    // Bezel.
    let glass = body.insetBy(dx: band, dy: band)
    let glassPath = CGPath(roundedRect: glass, cornerWidth: bodyRadius - band, cornerHeight: bodyRadius - band, transform: nil)
    context.addPath(glassPath); context.setFillColor(color(0x050608)); context.fillPath()
    context.addPath(glassPath); context.setStrokeColor(color(0xFFFFFF, 0.10)); context.setLineWidth(2 * u); context.strokePath()
    // Screen.
    let screen = glass.insetBy(dx: bezel, dy: bezel)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: screenRadius, cornerHeight: screenRadius, transform: nil)
    context.saveGState()
    context.addPath(screenPath); context.clip()
    if let capture {
        context.interpolationQuality = .high
        context.draw(capture, in: screen)
    } else {
        context.setFillColor(color(background)); context.fill(screen)
    }
    context.restoreGState()
    // Dynamic Island.
    let islandWidth = 126 * s, islandHeight = 37 * s
    let island = CGRect(x: screen.midX - islandWidth / 2, y: screen.maxY - 11 * s - islandHeight, width: islandWidth, height: islandHeight)
    context.addPath(CGPath(roundedRect: island, cornerWidth: islandHeight / 2, cornerHeight: islandHeight / 2, transform: nil))
    context.setFillColor(color(0x000000)); context.fillPath()
    let lens = islandHeight * 0.36
    context.addEllipse(in: CGRect(x: island.maxX - islandHeight * 0.5 - lens / 2, y: island.midY - lens / 2, width: lens, height: lens))
    context.setFillColor(color(0x10131A)); context.fillPath()
    // A faint glass reflection.
    context.saveGState()
    context.addPath(screenPath); context.clip()
    let sheen = CGGradient(colorsSpace: colorSpace, colors: [color(0xFFFFFF, 0.06), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(sheen, start: CGPoint(x: screen.minX, y: screen.maxY), end: CGPoint(x: screen.midX, y: screen.midY), options: [])
    context.restoreGState()
    return CGRect(x: screen.minX, y: H - screen.maxY, width: screen.width, height: screen.height)
}

/// Height of the device drawn at `width` for a capture.
func deviceHeight(_ capture: CGImage?, width: CGFloat) -> CGFloat {
    let aspect = capture.map { CGFloat($0.width) / CGFloat($0.height) } ?? (1320.0 / 2868.0)
    let frame = width * (0.022 + 0.024) * 2
    return (width - frame) / aspect + frame
}

// MARK: Panorama background

struct SplitMix { var state: UInt64
    mutating func next() -> UInt64 { state &+= 0x9E3779B97F4A7C15; var z = state; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
    mutating func unit() -> CGFloat { CGFloat(next() % 1_000_000) / 1_000_000 }
}

/// Dose positions along the panorama (in slide widths): in the gutters, a little off the joins, so each
/// dose shows on one slide. The wave between them is a Bateman-style rise and decay (the PK motif).
let doses: [CGFloat] = [-0.9, 0.045, 0.955, 2.045, 2.955, 4.045, 4.955, 6.045, 6.955]
let waveTop = H * 0.205, waveAmplitude = H * 0.062

func bateman(_ t: CGFloat) -> CGFloat {
    guard t > 0 else { return 0 }
    let ka: CGFloat = 9, ke: CGFloat = 1.05
    return (exp(-ke * t) - exp(-ka * t)) * ka / (ka - ke)
}

let waveRange: (low: CGFloat, high: CGFloat) = {
    var low = CGFloat.greatestFiniteMagnitude, high = -CGFloat.greatestFiniteMagnitude
    var x: CGFloat = 0
    while x <= PW { let c = rawConcentration(x); low = min(low, c); high = max(high, c); x += 6 }
    return (low, high)
}()

func rawConcentration(_ x: CGFloat) -> CGFloat {
    doses.reduce(0) { $0 + bateman((x / W - $1) * 1.25) }
}

/// Top-left y of the PK wave at panorama x (peaks up, troughs down).
func waveY(_ x: CGFloat) -> CGFloat {
    let c = (rawConcentration(x) - waveRange.low) / max(0.0001, waveRange.high - waveRange.low)
    return waveTop + waveAmplitude * (1 - c)
}

func drawBackground(_ context: CGContext) {
    // Sky: night lab at the top, sunset at the horizon (the app's `sunset` gradient, stretched).
    let skyFill = CGGradient(colorsSpace: colorSpace, colors: [color(abyss), color(0x12132E), color(background), color(deepBlue), color(0x3B2C6B), color(plum), color(coral), color(tangerine)] as CFArray,
                             locations: [0, 0.16, 0.3, 0.5, 0.66, 0.78, 0.92, 1])!
    context.drawLinearGradient(skyFill, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
    // Horizon blooms that straddle the joins, so neighbouring slides share a glow.
    let blooms: [(CGFloat, CGFloat, UInt32, CGFloat)] = [
        (0.15, 0.98, coral, 0.55), (1.0, 0.9, gold, 0.38), (1.9, 1.0, plum, 0.6), (2.95, 0.92, tangerine, 0.42),
        (4.0, 0.96, lilac, 0.40), (5.0, 0.9, coral, 0.5), (6.0, 0.96, teal, 0.30), (6.85, 1.0, gold, 0.42),
    ]
    for (x, y, hex, alpha) in blooms { radialGlow(context, cx: x * W, cy: y * H, radius: W * 0.95, hex: hex, alpha: alpha) }
    // High, cool glows behind the headlines, and a coral pulse at the top (the app's screen glow).
    for (x, hex, alpha) in [(0.5, sky, 0.14), (1.6, coral, 0.12), (2.5, lilac, 0.15), (3.6, teal, 0.10), (4.6, sky, 0.13), (5.6, coral, 0.12), (6.5, lilac, 0.14)] as [(CGFloat, UInt32, CGFloat)] {
        radialGlow(context, cx: x * W, cy: H * 0.11, radius: W * 0.85, hex: hex, alpha: alpha)
    }
    // Stars in the upper sky.
    var random = SplitMix(state: 41)
    for _ in 0..<(slideCount * 150) {
        let x = random.unit() * PW, y = pow(random.unit(), 1.6) * H * 0.55
        let r = (0.8 + random.unit() * 2.2) * u
        let alpha = (0.12 + random.unit() * 0.5) * (1 - y / (H * 0.6))
        context.setFillColor(color(0xFFFFFF, alpha))
        context.fillEllipse(in: CGRect(x: x - r, y: H - y - r, width: 2 * r, height: 2 * r))
    }
    // Dot grid ("night lab" graph paper): quiet behind the copy, fuller behind the phones, and lit up
    // coral/gold in a band under the PK wave, like a chart's fill.
    let spacing = 24 * u
    var y = spacing / 2
    while y < H {
        let t = Double(y / H)
        let fade = t < 0.1 ? 0.25 : t < 0.26 ? 0.25 + (t - 0.1) / 0.16 * 0.75 : min(1, max(0.35, 1.25 - t))
        var x = spacing / 2
        while x < PW {
            let wave = waveY(x)
            let below = y > wave && y < wave + H * 0.09
            let r = (below ? 3.4 : 2.6) * u
            if below {
                let strength = 1 - (y - wave) / (H * 0.09)
                context.setFillColor(color(coralLight, 0.38 * strength))
            } else {
                context.setFillColor(color(0xFFFFFF, 0.075 * fade))
            }
            context.fillEllipse(in: CGRect(x: x - r, y: H - y - r, width: 2 * r, height: 2 * r))
            x += spacing
        }
        y += spacing
    }
    // The PK wave, dashed, glowing faintly.
    let path = CGMutablePath()
    path.move(to: CGPoint(x: -20, y: H - waveY(-20)))
    var x: CGFloat = 0
    while x <= PW + 20 { path.addLine(to: CGPoint(x: x, y: H - waveY(x))); x += 8 }
    context.saveGState()
    context.addPath(path)
    context.setShadow(offset: .zero, blur: 18 * u, color: color(coral, 0.9))
    context.setStrokeColor(color(0xFFD7C9, 0.55))
    context.setLineWidth(5 * u)
    context.setLineCap(.round)
    context.setLineDash(phase: 0, lengths: [2 * u, 17 * u])
    context.strokePath()
    context.restoreGState()
}

/// The white-hot dot at a trough (just before a dose) and a syringe / droplet glyph above it.
func drawDose(atSlideX slideX: CGFloat, glyph: String, in context: CGContext) {
    let x = slideX * W
    // The trough sits right at the dose; its y is the wave's minimum there.
    let trough = waveY(x - 1)
    radialGlow(context, cx: x, cy: trough, radius: 70 * u, hex: 0xFFFFFF, alpha: 0.55)
    radialGlow(context, cx: x, cy: trough, radius: 120 * u, hex: coral, alpha: 0.45)
    context.setFillColor(color(0xFFFFFF))
    context.fillEllipse(in: CGRect(x: x - 11 * u, y: H - trough - 11 * u, width: 22 * u, height: 22 * u))
    // Glyph in a small frosted disc above the wave.
    let cy = trough + 92 * u
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 22 * u, color: color(0x000000, 0.45))
    context.setFillColor(color(surfaceRaised, 0.92))
    context.fillEllipse(in: CGRect(x: x - 42 * u, y: H - cy - 42 * u, width: 84 * u, height: 84 * u))
    context.restoreGState()
    context.setStrokeColor(color(0xFFFFFF, 0.25)); context.setLineWidth(2 * u)
    context.strokeEllipse(in: CGRect(x: x - 42 * u, y: H - cy - 42 * u, width: 84 * u, height: 84 * u))
    drawSymbol(glyph, cx: x, cy: cy, height: 40 * u, degrees: glyph == "syringe.fill" ? -35 : 0, tint: NSColor(cgColor: color(coralLight))!, in: context)
}

// MARK: Pieces

func confetti(in context: CGContext, around center: CGPoint, spread: CGSize, count: Int, seed: UInt64, avoiding: CGRect = .null) {
    var random = SplitMix(state: seed)
    let palette: [UInt32] = [gold, coral, teal, sky, lilac, 0xFFFFFF, tangerine]
    for _ in 0..<count {
        let x = center.x + (random.unit() - 0.5) * spread.width
        let y = center.y + (random.unit() - 0.5) * spread.height
        let w = (14 + random.unit() * 16) * u, h = (7 + random.unit() * 8) * u
        let hex = palette[Int(random.next() % UInt64(palette.count))]
        let angle = random.unit() * 180
        if avoiding.contains(CGPoint(x: x, y: y)) { continue }
        placed(context, cx: x, cy: y, degrees: angle) {
            context.setFillColor(color(hex, 0.95))
            if random.next() % 3 == 0 {
                context.fillEllipse(in: CGRect(x: -h / 2, y: -h / 2, width: h, height: h))
            } else {
                context.addPath(CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerWidth: 2 * u, cornerHeight: 2 * u, transform: nil))
                context.fillPath()
            }
        }
    }
}

/// A frosted pill with an SF Symbol and a label ("No account").
func chip(_ text: String, symbolName: String, cx: CGFloat? = nil, left: CGFloat? = nil, cy: CGFloat, degrees: CGFloat = 0, tint: UInt32 = teal, in context: CGContext) {
    let size = 40 * u
    let label = attributed(text, size: size, weight: .chip, base: color(0x14163A), highlight: color(0x14163A), alignment: .left)
    let textSize = measure(label, width: 2000)
    let iconBox = 64 * u
    let padding = 22 * u
    let width = padding + iconBox + 18 * u + ceil(textSize.width) + padding * 1.3
    let height = 104 * u
    let cx = cx ?? ((left ?? 0) + width / 2)
    placed(context, cx: cx, cy: cy, degrees: degrees) {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -20 * u), blur: 50 * u, color: color(0x000000, 0.45))
        context.addPath(path); context.setFillColor(color(paper)); context.fillPath()
        context.restoreGState()
        let icon = CGRect(x: rect.minX + padding * 0.55, y: -iconBox / 2, width: iconBox, height: iconBox)
        context.setFillColor(color(tint))
        context.fillEllipse(in: icon)
        if let image = symbol(symbolName, pointSize: 30 * u, weight: .heavy) {
            let h = 32 * u, w = h * CGFloat(image.width) / CGFloat(image.height)
            context.draw(image, in: CGRect(x: icon.midX - w / 2, y: icon.midY - h / 2, width: w, height: h))
        }
        let setter = CTFramesetterCreateWithAttributedString(label)
        let textRect = CGRect(x: icon.maxX + 18 * u, y: -textSize.height / 2 - 2 * u, width: ceil(textSize.width) + 4, height: ceil(textSize.height) + 2)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: textRect, transform: nil), nil), context)
    }
}

/// An injection stamp inked on a cream card, the way the app shows a fresh stamp: reads on any background.
func stampTile(_ image: CGImage?, cx: CGFloat, cy: CGFloat, size: CGFloat, degrees: CGFloat, in context: CGContext) {
    guard let image else { return }
    placed(context, cx: cx, cy: cy, degrees: degrees) {
        let rect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        let path = CGPath(roundedRect: rect, cornerWidth: size * 0.07, cornerHeight: size * 0.07, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -26 * u), blur: 60 * u, color: color(0x000000, 0.5))
        context.addPath(path); context.setFillColor(color(cream)); context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(path); context.clip()
        let paperGrain = CGGradient(colorsSpace: colorSpace, colors: [color(0xFFFBF1), color(0xF1E6CF)] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(paperGrain, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
        // The stamp asset carries 30 pt of padding around a 240 pt stamp: fill most of the card.
        let stampSize = size * 1.02
        let h = stampSize * CGFloat(image.height) / CGFloat(image.width)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: -stampSize / 2, y: -h / 2, width: stampSize, height: h))
        context.restoreGState()
        context.addPath(path); context.setStrokeColor(color(0xFFFFFF, 0.9)); context.setLineWidth(4 * u); context.strokePath()
    }
}

/// The app icon as a floating tile.
func appIcon(_ image: CGImage?, cx: CGFloat, cy: CGFloat, size: CGFloat, degrees: CGFloat = 0, in context: CGContext) {
    float(image, cx: cx, cy: cy, width: size, degrees: degrees, corner: size * 0.225, shadow: 0.8, in: context)
}

// MARK: Copy

struct Copy: Decodable { var headline: String; var sub: String?; var chips: [String]? }
let headlinesURL = URL(fileURLWithPath: metadataPath).appendingPathComponent(storeLocale).appendingPathComponent("screenshot_headlines.json")
guard let data = try? Data(contentsOf: headlinesURL),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { print("no \(headlinesURL.path)"); exit(1) }
var copies: [Int: Copy] = [:]
for (key, value) in object {
    guard let number = Int(key), let json = try? JSONSerialization.data(withJSONObject: value), let copy = try? JSONDecoder().decode(Copy.self, from: json) else { continue }
    copies[number] = copy
}

// MARK: Layout

let margin: CGFloat = 80
let textWidth = W - 2 * margin
let headlineStart: CGFloat = 124
let headlineFloor: CGFloat = 60
let subStart: CGFloat = 50
let subFloor: CGFloat = 36
let headlineTop: CGFloat = 176

// One type size for the whole set, so the frames read as one series.
let headlineSize = copies.values.map { fittedSize($0.headline, start: headlineStart, floor: headlineFloor, width: textWidth, maxLines: 2, weight: .headline).size }.min() ?? headlineStart
/// Sublines wrap freely (balanced), shrinking until every one fits in two lines.
func subFits(_ text: String, _ size: CGFloat) -> Bool { fits(attributed(text, size: size, weight: .sub, base: color(0xFFFFFF), highlight: color(0xFFFFFF)), width: textWidth * 0.92, maxLines: 2) }
let subSize: CGFloat = {
    var size = subStart
    while size > subFloor, !copies.values.compactMap({ $0.sub }).allSatisfy({ subFits($0, size) }) { size -= 2 }
    return size
}()
let white = color(0xFFFFFF)
let headlineBand = ceil(measure(attributed("Hg\nHg", size: headlineSize, base: white, highlight: white), width: textWidth).height) + 8
let subBand = ceil(measure(attributed("Hg\nHg", size: subSize, weight: .sub, base: white, highlight: white), width: textWidth).height) + 8
let subTop = headlineTop + headlineBand + 26
/// Where the phones start: below the tallest possible copy.
let deviceTop = subTop + subBand + 64
let bottomMargin: CGFloat = 70

func deviceWidth(for capture: CGImage?) -> CGFloat {
    // As large as fits between the copy and the bottom margin.
    var width: CGFloat = 1010
    while deviceHeight(capture, width: width) > H - deviceTop - bottomMargin { width -= 4 }
    return width
}

var problems: [String] = []

func drawCopy(_ number: Int, origin: CGFloat, in context: CGContext) {
    guard let copy = copies[number] else { problems.append("no copy for slide \(number)"); return }
    let headline = arrangement(copy.headline, size: headlineSize, width: textWidth, weight: .headline)
    let text = fits(attributed(headline, size: headlineSize, base: white, highlight: white), width: textWidth, maxLines: 2) ? headline : copy.headline
    let probe = attributed(text, size: headlineSize, base: white, highlight: white)
    if !fits(probe, width: textWidth, maxLines: 2) { problems.append("#\(number): headline needs more than 2 lines") }
    let height = ceil(measure(probe, width: balancedWidth(probe, width: textWidth)).height) + 8
    let top = headlineTop + max(0, headlineBand - height)   // bottom-aligned, so the sublines line up
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6 * u), blur: 30 * u, color: color(0x000000, 0.4))
    drawText(text, size: headlineSize, weight: .headline, centerX: origin + W / 2, top: top, width: textWidth, base: color(paper), gradient: [gold, tangerine, coral], in: context)
    context.restoreGState()
    if let sub = copy.sub {
        if !subFits(sub, subSize) { problems.append("#\(number): subline needs more than 2 lines") }
        drawText(sub, size: subSize, weight: .sub, centerX: origin + W / 2, top: subTop, width: textWidth * 0.92, base: color(0xDCE0F5, 0.86), gradient: nil, in: context)
    }
}

// MARK: Assets

let icon = options["icon"].flatMap { load(URL(fileURLWithPath: $0)) }
/// The first existing asset among `names` (so a renamed export still lands).
func firstAsset(_ names: String...) -> CGImage? {
    for name in names { if let image = load(assetsDirectory.appendingPathComponent(name)) { return image } }
    missing.append(names[0])
    return nil
}

// MARK: Compose

guard let context = CGContext(data: nil, width: Int(PW), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { print("no context"); exit(1) }
drawBackground(context)
let s = u   // floating-asset scale

// 1 · Dashboard hero: the rank passport card and the streak emblem break out.
do {
    let o: CGFloat = 0
    drawCopy(1, origin: o, in: context)
    let capture = raw("01-home.png")
    let screen = drawDevice(capture, cx: o + W / 2 + 50 * s, top: deviceTop, width: deviceWidth(for: capture), in: context)
    float(firstAsset("rank-card.png", "emblem-rank.png"), cx: o + 300 * s, cy: screen.maxY - 520 * s, width: 560 * s, degrees: -7, shadow: 1.2, in: context)
    float(firstAsset("streak-card.png", "emblem-streak-flame.png"), cx: o + W - 175 * s, cy: screen.minY + 360 * s, width: 330 * s, degrees: 8, shadow: 1.1, in: context)
}

// 2 · Check-in done: confetti over the completion screen, an XP chip and the streak.
do {
    let o = W
    drawCopy(2, origin: o, in: context)
    let capture = raw("02-checkin.png")
    let screen = drawDevice(capture, cx: o + W / 2, top: deviceTop, width: deviceWidth(for: capture), in: context)
    let island = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: 200 * s)
    confetti(in: context, around: CGPoint(x: o + W / 2, y: screen.minY + 150 * s), spread: CGSize(width: W * 1.05, height: 560 * s), count: 90, seed: 7, avoiding: island)
    float(asset("xp-chip.png"), cx: o + W - 230 * s, cy: screen.minY + 700 * s, width: 400 * s, degrees: 7, shadow: 1.1, in: context)
    float(firstAsset("emblem-streak-flame.png", "streak-card.png"), cx: o + 175 * s, cy: screen.maxY - 520 * s, width: 330 * s, degrees: -9, shadow: 1.1, in: context)
}

// 3 · PK curve (estimated): the curve card breaks out big; the next-injection card above it.
do {
    let o = 2 * W
    drawCopy(3, origin: o, in: context)
    let capture = raw("03-pk.png")
    let screen = drawDevice(capture, cx: o + W / 2 - 50 * s, top: deviceTop, width: deviceWidth(for: capture), in: context)
    float(asset("pk-card.png"), cx: o + W / 2 + 60 * s, cy: screen.maxY - 560 * s, width: 1060 * s, degrees: -3, shadow: 1.4, in: context)
    float(asset("next-injection.png"), cx: o + W - 330 * s, cy: screen.minY + 360 * s, width: 640 * s, degrees: 5, shadow: 1.2, in: context)
}

// 4 · Injection stamps: fresh stamps spilling out of the log.
do {
    let o = 3 * W
    drawCopy(4, origin: o, in: context)
    let capture = raw("04-injections.png")
    let screen = drawDevice(capture, cx: o + W / 2 + 30 * s, top: deviceTop, width: deviceWidth(for: capture), in: context)
    stampTile(asset("stamp-1.png"), cx: o + 190 * s, cy: screen.minY + 820 * s, size: 330 * s, degrees: -9, in: context)
    stampTile(asset("stamp-2.png"), cx: o + W - 170 * s, cy: screen.minY + 1330 * s, size: 300 * s, degrees: 10, in: context)
}
// Straddling the 4 | 5 join: a stamp half on each slide.
stampTile(load(assetsDirectory.appendingPathComponent("stamp-3.png")), cx: 4 * W, cy: H - 300 * s, size: 290 * s, degrees: -8, in: context)

// 5 · Achievements: three medals float off the badge wall.
do {
    let o = 4 * W
    drawCopy(5, origin: o, in: context)
    let capture = raw("05-achievements.png")
    let screen = drawDevice(capture, cx: o + W / 2, top: deviceTop, width: deviceWidth(for: capture), in: context)
    float(asset("badge-1.png"), cx: o + W - 190 * s, cy: screen.minY + 470 * s, width: 380 * s, degrees: 8, in: context)
    float(asset("badge-2.png"), cx: o + 185 * s, cy: screen.minY + 1100 * s, width: 360 * s, degrees: -9, in: context)
    float(asset("badge-3.png"), cx: o + W - 200 * s, cy: screen.maxY - 420 * s, width: 350 * s, degrees: 6, in: context)
}

// 6 · Bloodwork: the marker card breaks out.
do {
    let o = 5 * W
    drawCopy(6, origin: o, in: context)
    let capture = raw("06-bloodwork.png")
    let screen = drawDevice(capture, cx: o + W / 2 - 60 * s, top: deviceTop, width: deviceWidth(for: capture), in: context)
    float(asset("marker-card.png"), cx: o + W - 350 * s, cy: screen.maxY - 560 * s, width: 700 * s, degrees: 5, shadow: 1.3, in: context)
}

// 7 · Private by design: privacy chips over the quiet end of the More screen, the app icon to sign off.
//     (No share card here — the slide is about keeping your log to yourself.)
do {
    let o = 6 * W
    drawCopy(7, origin: o, in: context)
    let capture = raw("07-privacy.png")
    let screen = drawDevice(capture, cx: o + W / 2 + 70 * s, top: deviceTop, width: deviceWidth(for: capture), in: context)
    let chips = copies[7]?.chips ?? []
    let symbols = ["person.crop.circle.badge.xmark", "lock.iphone", "nosign"]
    let tints = [coral, teal, lilac]
    for (index, text) in chips.prefix(3).enumerated() {
        chip(text, symbolName: symbols[index], left: o + 40 * s + CGFloat(index % 2) * 34 * s, cy: screen.minY + 1300 * s + CGFloat(index) * 160 * s,
             degrees: index % 2 == 0 ? -3 : 2, tint: tints[index], in: context)
    }
    appIcon(icon, cx: o + W - 165 * s, cy: screen.minY + 170 * s, size: 210 * s, degrees: 8, in: context)
}

// Doses in the gutters: a white-hot trough dot with a syringe / droplet glyph.
for (index, x) in [0.955, 2.045, 2.955, 4.955, 6.045].enumerated() { drawDose(atSlideX: CGFloat(x), glyph: index % 2 == 0 ? "syringe.fill" : "drop.fill", in: context) }

// MARK: Output

guard let panorama = context.makeImage() else { exit(1) }
let outFolder = URL(fileURLWithPath: outPath).appendingPathComponent(storeLocale)
try FileManager.default.createDirectory(at: outFolder, withIntermediateDirectories: true)
for name in (try? FileManager.default.contentsOfDirectory(atPath: outFolder.path)) ?? [] where name.hasSuffix("_iphone69.png") {
    try? FileManager.default.removeItem(at: outFolder.appendingPathComponent(name))
}

func save(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw NSError(domain: "screenshots", code: 1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "screenshots", code: 2) }
}

var slides: [CGImage] = []
for index in 0..<slideCount {
    guard let crop = panorama.cropping(to: CGRect(x: CGFloat(index) * W, y: 0, width: W, height: H)),
          let slide = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
    slide.draw(crop, in: CGRect(x: 0, y: 0, width: W, height: H))
    guard let image = slide.makeImage() else { continue }
    try save(image, to: outFolder.appendingPathComponent("\(index + 1)_iphone69.png"))
    slides.append(image)
}

// Contact sheet: the row as the store shows it (small gaps), for reviewing the panorama at a glance.
let contactURL = URL(fileURLWithPath: options["contact"] ?? outFolder.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("contact-\(storeLocale).png").path)
let thumbHeight: CGFloat = 640
let thumbWidth = (W * thumbHeight / H).rounded()
let gap: CGFloat = 28, pad: CGFloat = 48
if let sheet = CGContext(data: nil, width: Int(pad * 2 + thumbWidth * CGFloat(slides.count) + gap * CGFloat(slides.count - 1)), height: Int(thumbHeight + pad * 2),
                         bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
    sheet.setFillColor(color(0x1C1C1E))
    sheet.fill(CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height))
    sheet.interpolationQuality = .high
    for (index, image) in slides.enumerated() {
        let rect = CGRect(x: pad + CGFloat(index) * (thumbWidth + gap), y: pad, width: thumbWidth, height: thumbHeight)
        sheet.saveGState()
        sheet.addPath(CGPath(roundedRect: rect, cornerWidth: 26, cornerHeight: 26, transform: nil))
        sheet.clip()
        sheet.draw(image, in: rect)
        sheet.restoreGState()
    }
    try FileManager.default.createDirectory(at: contactURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let image = sheet.makeImage() { try save(image, to: contactURL) }
}

for name in Set(missing).sorted() { print("WARNING: missing \(name)") }
for problem in problems { print("WARNING: \(problem)") }
print("composed \(slides.count) slides → \(outFolder.path), contact sheet → \(contactURL.path) (headline \(Int(headlineSize)) pt, sub \(Int(subSize)) pt)")
