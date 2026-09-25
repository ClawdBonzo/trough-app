// Renders the Trough app icon: a bold pharmacokinetic wave (two peaks, one deep trough)
// with a white-hot dot sitting at the trough — the low point the app is named for.
//
// Usage:  swift Trough/Tools/make_icon.swift <outdir> [pixelWidth]
// Writes:
//   AppIcon-1024.png         default: abyss navy field, coral glow, coral->gold wave, glossy rim, white-hot dot
//   AppIcon-1024-dark.png    dark appearance: near-black field, slightly muted wave, no big glow
//   AppIcon-1024-tinted.png  tinted appearance: grayscale wave on black, dot as the brightest element
//
// All output is sRGB with no alpha channel (App Store requirement).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("usage: swift make_icon.swift <outdir> [pixelWidth]")
    exit(1)
}
let outDir = URL(fileURLWithPath: arguments[1], isDirectory: true)
let pixelWidth = arguments.count > 2 ? (Int(arguments[2]) ?? 1024) : 1024
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { exit(1) }

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(
        colorsSpace: colorSpace,
        colors: stops.map { color($0.0, alpha: $0.1) } as CFArray,
        locations: stops.map { $0.2 }
    )!
}

// MARK: - Geometry (1024 design grid, top-left origin)

let env = ProcessInfo.processInfo.environment
func knob(_ key: String, _ fallback: CGFloat) -> CGFloat { CGFloat(Double(env[key] ?? "") ?? Double(fallback)) }

let strokeWidth: CGFloat = knob("T_STROKE", 120)
let peakRadius: CGFloat = knob("T_PR", 112)
let troughRadius: CGFloat = knob("T_TR", 138)

// The wave is a zig-zag through these corner points, each corner rounded with a generous arc
// (so the inside of every bend stays round even at this stroke weight). It bleeds off both edges
// so it reads as a live signal, not a letterform. Rise legs are steeper than decay legs — the
// pharmacokinetic shape: fast absorption, slow elimination.
let targetPeakY: CGFloat = knob("T_PY", 340)     // centerline y at the top of each peak
let targetTroughY: CGFloat = knob("T_TY", 716)   // centerline y at the bottom of each trough
let troughX: CGFloat = knob("T_TX", 542)
let decayWidth: CGFloat = knob("T_DW", 320)      // peak -> next trough (slow elimination)
let riseWidth: CGFloat = knob("T_RW", 260)       // trough -> next peak (fast absorption)

func unit(_ v: CGPoint) -> CGPoint { let l = hypot(v.x, v.y); return CGPoint(x: v.x / l, y: v.y / l) }

/// Center of the arc that rounds corner `i` of `pts` with radius `r`.
func arcCenter(_ pts: [CGPoint], _ i: Int, _ r: CGFloat) -> CGPoint {
    let v = pts[i]
    let u1 = unit(CGPoint(x: pts[i - 1].x - v.x, y: pts[i - 1].y - v.y))
    let u2 = unit(CGPoint(x: pts[i + 1].x - v.x, y: pts[i + 1].y - v.y))
    let bis = unit(CGPoint(x: u1.x + u2.x, y: u1.y + u2.y))
    let halfAngle = acos(max(-1, min(1, u1.x * u2.x + u1.y * u2.y))) / 2
    let d = r / sin(halfAngle)
    return CGPoint(x: v.x + bis.x * d, y: v.y + bis.y * d)
}

// One and a half periods: (edge trough) rise, PEAK, decay, TROUGH, rise, PEAK, decay, (edge trough) rise.
// Corner heights are solved so the ROUNDED curve hits the target peak/trough heights exactly.
func cornerPoints(peakCornerY: CGFloat, troughCornerY: CGFloat) -> [CGPoint] {
    let p1 = troughX - decayWidth, p2 = troughX + riseWidth
    let t0 = p1 - riseWidth, t2 = p2 + decayWidth
    let slopeUp = (troughCornerY - peakCornerY) / riseWidth
    return [
        CGPoint(x: t0 - 200, y: troughCornerY - slopeUp * 200),
        CGPoint(x: t0, y: troughCornerY),
        CGPoint(x: p1, y: peakCornerY),
        CGPoint(x: troughX, y: troughCornerY),
        CGPoint(x: p2, y: peakCornerY),
        CGPoint(x: t2, y: troughCornerY),
        CGPoint(x: t2 + 200, y: troughCornerY - slopeUp * 200),
    ]
}

let corners: [CGPoint] = {
    var py = targetPeakY, ty = targetTroughY
    for _ in 0..<200 {
        let pts = cornerPoints(peakCornerY: py, troughCornerY: ty)
        let actualPeak = arcCenter(pts, 2, peakRadius).y - peakRadius
        let actualTrough = arcCenter(pts, 3, troughRadius).y + troughRadius
        py += (targetPeakY - actualPeak) * 0.5
        ty += (targetTroughY - actualTrough) * 0.5
    }
    return cornerPoints(peakCornerY: py, troughCornerY: ty)
}()
let radii: [CGFloat] = [troughRadius, peakRadius, troughRadius, peakRadius, troughRadius]

func wavePath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: corners[0])
    for i in 1..<(corners.count - 1) {
        p.addArc(tangent1End: corners[i], tangent2End: corners[i + 1], radius: radii[i - 1])
    }
    p.addLine(to: corners[corners.count - 1])
    return p
}

// Bottom of the trough arc — where the dot lives.
let troughCenter = arcCenter(corners, 3, troughRadius)
let trough = CGPoint(x: troughCenter.x, y: troughCenter.y + troughRadius)
let peakY = arcCenter(corners, 2, peakRadius).y - peakRadius

let wave = wavePath()
let waveOutline = wave.copy(strokingWithWidth: strokeWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
let glyphTop: CGFloat = peakY - strokeWidth / 2
let glyphBottom: CGFloat = trough.y + strokeWidth / 2
let dotRadius: CGFloat = knob("T_DOT", 50)

// MARK: - Rendering

enum Variant: String, CaseIterable { case light, dark, tinted }

func render(_ variant: Variant) -> CGImage {
    let scale = CGFloat(pixelWidth) / 1024
    let ctx = CGContext(
        data: nil, width: pixelWidth, height: pixelWidth, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    ctx.translateBy(x: 0, y: CGFloat(pixelWidth))
    ctx.scaleBy(x: scale, y: -scale)
    let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)

    // 1. Field.
    switch variant {
    case .light:
        ctx.setFillColor(color(0x0B0C1E))
        ctx.fill(full)
        // Lifted navy toward the top-center: gives the field a lit, dimensional feel.
        ctx.drawRadialGradient(
            gradient([(0x1F2148, 1, 0), (0x1A1A2E, 1, 0.45), (0x0B0C1E, 1, 1)]),
            startCenter: CGPoint(x: 512, y: 300), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 420), endRadius: 820, options: [.drawsAfterEndLocation])
    case .dark:
        ctx.setFillColor(color(0x000000))
        ctx.fill(full)
        ctx.drawRadialGradient(
            gradient([(0x12121C, 1, 0), (0x000000, 1, 1)]),
            startCenter: CGPoint(x: 512, y: 380), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 380), endRadius: 720, options: [.drawsAfterEndLocation])
    case .tinted:
        ctx.setFillColor(color(0x000000))
        ctx.fill(full)
    }

    // 2. Faint chart dot grid (light only), registered so one row runs exactly through the trough;
    //    that row is brighter and denser — the trough baseline. Invisible at home-screen size, rewarding up close.
    if variant == .light {
        let step: CGFloat = 64
        let showBaseline = knob("T_BASE", 1) > 0
        var y = trough.y.truncatingRemainder(dividingBy: step)
        while y < 1024 {
            let isBaseline = showBaseline && abs(y - trough.y) < 1
            let xStep = isBaseline ? step / 2 : step
            var x = trough.x.truncatingRemainder(dividingBy: xStep)
            while x < 1024 {
                let d = hypot(x - 512, y - 512)
                if isBaseline {
                    ctx.setFillColor(color(0xFFFFFF, alpha: max(0, 1 - d / 520) * 0.30))
                    ctx.fillEllipse(in: CGRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9))
                } else if d < 480 {
                    ctx.setFillColor(color(0xFFFFFF, alpha: 0.05))
                    ctx.fillEllipse(in: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7))
                }
                x += xStep
            }
            y += step
        }
    }

    // 3. Soft coral glow behind the wave (light only; Apple's dark icons drop big glows).
    if variant == .light {
        ctx.drawRadialGradient(
            gradient([(0xE94560, 0.42, 0), (0xE94560, 0.14, 0.5), (0xE94560, 0, 1)]),
            startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 560), endRadius: 480, options: [])
    }

    // 4. The wave.
    let fill: CGGradient
    switch variant {
    case .light:  fill = gradient([(0xFFB547, 1, 0), (0xFF7A6B, 1, 0.45), (0xE94560, 1, 1)])
    case .dark:   fill = gradient([(0xE8A443, 1, 0), (0xE56E61, 1, 0.45), (0xD13E57, 1, 1)])
    case .tinted: fill = gradient([(0xBDBDBD, 1, 0), (0x8A8A8A, 1, 1)])
    }

    // 4a. Depth: a soft shadow below and a colored bloom (light only).
    if variant == .light {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 60, color: color(0xFF5A5F, alpha: 0.55))
        ctx.addPath(waveOutline)
        ctx.setFillColor(color(0xE94560))
        ctx.fillPath()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.addPath(waveOutline)
    ctx.clip()
    ctx.drawLinearGradient(fill, start: CGPoint(x: 512, y: glyphTop), end: CGPoint(x: 512, y: glyphBottom),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // 4b. Glossy rim: the band of the stroke not covered by a copy of itself shifted down.
    if variant != .tinted {
        let shifted = CGMutablePath()
        shifted.addPath(waveOutline, transform: CGAffineTransform(translationX: 0, y: 16))
        let rim = CGMutablePath()
        rim.addPath(waveOutline)
        rim.addPath(shifted)
        ctx.addPath(rim)
        ctx.clip(using: .evenOdd)
        ctx.setFillColor(color(0xFFFFFF, alpha: variant == .light ? 0.42 : 0.22))
        ctx.fill(full)
    }
    ctx.restoreGState()

    // 4c. Volume: a soft darker band along the underside of the stroke.
    if variant != .tinted {
        ctx.saveGState()
        ctx.addPath(waveOutline)
        ctx.clip()
        let lifted = CGMutablePath()
        lifted.addPath(waveOutline, transform: CGAffineTransform(translationX: 0, y: -14))
        let under = CGMutablePath()
        under.addPath(waveOutline)
        under.addPath(lifted)
        ctx.addPath(under)
        ctx.clip(using: .evenOdd)
        ctx.setFillColor(color(0x5A0A28, alpha: variant == .light ? 0.22 : 0.20))
        ctx.fill(full)
        ctx.restoreGState()
    }

    // 5. The trough dot: white-hot core with a halo so it reads as the brightest thing on the icon.
    let dotRect = CGRect(x: trough.x - dotRadius, y: trough.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
    let ringGap = knob("T_RING", 0)
    if ringGap > 0 && variant != .tinted {
        // Punch a dark moat around the dot so it sits IN the trough like a bead.
        ctx.setFillColor(color(variant == .light ? 0x14142A : 0x000000))
        ctx.fillEllipse(in: dotRect.insetBy(dx: -ringGap, dy: -ringGap))
    }
    switch variant {
    case .light:
        ctx.drawRadialGradient(
            gradient([(0xFFFFFF, 0.75, 0), (0xFFE3B0, 0.35, 0.35), (0xFFB547, 0, 1)]),
            startCenter: trough, startRadius: 0, endCenter: trough, endRadius: 150, options: [])
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 40, color: color(0xFFFFFF, alpha: 0.95))
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dotRect)
        ctx.restoreGState()
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dotRect)
    case .dark:
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 22, color: color(0xFFFFFF, alpha: 0.6))
        ctx.setFillColor(color(0xF4F4F4))
        ctx.fillEllipse(in: dotRect)
        ctx.restoreGState()
    case .tinted:
        // Pure white on a mid-gray stroke: after the system tint the dot stays the brightest element.
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dotRect)
    }

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("could not create \(url.path)"); exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { print("could not write \(url.path)"); exit(1) }
    print("wrote \(url.path) (\(pixelWidth)x\(pixelWidth))")
}

for variant in Variant.allCases {
    let name: String
    switch variant {
    case .light: name = "AppIcon-1024.png"
    case .dark: name = "AppIcon-1024-dark.png"
    case .tinted: name = "AppIcon-1024-tinted.png"
    }
    write(render(variant), to: outDir.appendingPathComponent(name))
}
