// Renders the Trough app icon.
//
// Default design ("vial"): an injectable vial whose liquid SURFACE is the pharmacokinetic curve — one wide
// trough centered in the glass, cresting toward the walls — with a white-hot dot sitting at the trough, the
// low point the app is named for. Dark translucent glass, bright rim, left-side speculars, crimped amber flip-top.
//
// Installed 1.4 icon: V_STYLE=clinical V_RIML=0.3 V_FIELD=bold V_CORNERDIM=0.35 swift Trough/Tools/make_icon.swift <outdir>
// Legacy design ("wave", the 1.4 wave-A icon): a bold PK wave (two peaks, one deep trough) with the dot at
// the trough. Still reproducible byte-for-byte:  T_DESIGN=wave swift Trough/Tools/make_icon.swift <outdir>
//
// Usage:  [T_DESIGN=vial|wave] swift Trough/Tools/make_icon.swift <outdir> [pixelWidth]
// Writes:
//   AppIcon-1024.png         default: abyss navy field, coral glow, glossy coral design, white-hot dot
//   AppIcon-1024-dark.png    dark appearance: near-black field, muted colors and glow
//   AppIcon-1024-tinted.png  tinted appearance: pure grayscale on black, dot as the brightest element
//
// Geometry knobs are env vars (T_* for the wave, V_* for the vial) so variations can be tried without edits.
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

func renderWave(_ variant: Variant) -> CGImage {
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

// MARK: - Vial design (default)
//
// A chunky injectable vial on the abyss field: dark translucent glass with a bright rim and left-side
// speculars, a crimped amber flip-top, and coral liquid whose SURFACE is the PK curve — a wide, gentle
// trough centered in the vial, cresting toward the glass walls. The white-hot dot sits at the trough.

let design = (env["T_DESIGN"] ?? "vial").lowercased()

// Option knobs (all optional; with none set the output is byte-identical to the shipped default):
//   V_STYLE=classic|clinical   clinical = squat pharmaceutical vial, short neck, aluminum crimp + flip-off cap
//   V_FIELD=navy|bold|plum     bold = coral→plum→navy tile; plum = dual-tone plum/navy tile
//   V_LIQ=coral|gold           liquid color (gold ≈ oil-based testosterone)
//   V_CAPC=amber|coral|gold    cap color (clinical flip-off defaults to coral)
//   V_SCALE, V_ROT (deg), V_OX, V_OY   scale / tilt / offset the whole vial (liquid stays level when tilted)
//   V_RIML=<alpha>, V_RIMC=<hex>        colored rim light down the right edge of the glass
//   V_GLASSA=<mult>, V_UNDER=<alpha>    glass tint strength and the dark underlay inside the glass
let vStyle = (env["V_STYLE"] ?? "classic").lowercased()
let clinical = vStyle == "clinical"
func vk(_ key: String, _ classic: CGFloat, _ clin: CGFloat) -> CGFloat { knob(key, clinical ? clin : classic) }

let vCX: CGFloat = 512
let vBodyHalf = vk("V_BW", 212, 238)           // half-width of the glass body
let vNeckHalf = vk("V_NW", 100, 128)           // half-width of the neck
let vBodyBottom = vk("V_BB", 868, 884)
let vShoulderTop = vk("V_ST", 334, 328)        // neck meets the shoulder curve
let vShoulderH = vk("V_SH", 76, 84)           // height of the S-curve from neck to full body width
let vCorner = vk("V_BR", 92, 58)             // bottom corner radius
let vWall = knob("V_WALL", 16)              // glass wall thickness (sides)
let vBase = knob("V_BASE", 34)              // glass base thickness (vials have a thick bottom)
let vNeckTop: CGFloat = vk("V_NT", 250, 290)
let vCapTop = vk("V_CT", 160, 172)
let vCapH = vk("V_CH", 60, 48)
let vCapHalf = vk("V_CW", 134, 168)
let vCrimpTop = vCapTop + vCapH + (clinical ? knob("V_CG", 4) : 6)
let vCrimpBottom = vk("V_CB", 298, 302)
let vCrimpHalf = vk("V_KW", 146, 184)
let vTroughY = vk("V_TY", 646, 672)            // lowest point of the liquid surface
let vPeakY = vk("V_PY", 548, 560)              // crest height near the walls
let vPeakT = knob("V_PT", 0.86)             // crest position as a fraction of the interior half-width
let vDotR = knob("V_DOT", 46)

let vField = (env["V_FIELD"] ?? "navy").lowercased()
let vLiq = (env["V_LIQ"] ?? "coral").lowercased()
let vCapColor = (env["V_CAPC"] ?? (clinical ? "coral" : "amber")).lowercased()
let vScale = knob("V_SCALE", 1), vRot = knob("V_ROT", 0) * .pi / 180
let vOX = knob("V_OX", 0), vOY = knob("V_OY", 0)
let vTransformed = vScale != 1 || vRot != 0 || vOX != 0 || vOY != 0
let vTilted = vRot != 0
/// Vial space → canvas: scale and tilt about the trough, then offset. Liquid space is the same minus the tilt,
/// so a tilted vial keeps a level liquid surface with the dot still on the vial's axis.
func vialTransform(tilt: Bool) -> CGAffineTransform {
    let pivot = CGPoint(x: vCX, y: vTroughY)
    var t = CGAffineTransform(translationX: -pivot.x, y: -pivot.y).concatenating(CGAffineTransform(scaleX: vScale, y: vScale))
    if tilt { t = t.concatenating(CGAffineTransform(rotationAngle: vRot)) }
    return t.concatenating(CGAffineTransform(translationX: pivot.x + vOX, y: pivot.y + vOY))
}

/// Glass silhouette: straight neck, S-curve shoulder, straight walls, rounded bottom corners.
func vialPath(half: CGFloat, neckHalf: CGFloat, top: CGFloat, shoulderTop: CGFloat,
              shoulderH: CGFloat, bottom: CGFloat, corner: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let l = vCX - half, r = vCX + half, nl = vCX - neckHalf, nr = vCX + neckHalf
    let sb = shoulderTop + shoulderH
    p.move(to: CGPoint(x: nl, y: top))
    p.addLine(to: CGPoint(x: nl, y: shoulderTop))
    p.addCurve(to: CGPoint(x: l, y: sb),
               control1: CGPoint(x: nl, y: shoulderTop + shoulderH * 0.55),
               control2: CGPoint(x: l, y: shoulderTop + shoulderH * 0.25))
    p.addLine(to: CGPoint(x: l, y: bottom - corner))
    p.addArc(tangent1End: CGPoint(x: l, y: bottom), tangent2End: CGPoint(x: vCX, y: bottom), radius: corner)
    p.addArc(tangent1End: CGPoint(x: r, y: bottom), tangent2End: CGPoint(x: r, y: sb), radius: corner)
    p.addLine(to: CGPoint(x: r, y: sb))
    p.addCurve(to: CGPoint(x: nr, y: shoulderTop),
               control1: CGPoint(x: r, y: shoulderTop + shoulderH * 0.25),
               control2: CGPoint(x: nr, y: shoulderTop + shoulderH * 0.55))
    p.addLine(to: CGPoint(x: nr, y: top))
    p.closeSubpath()
    return p
}

let vOuter = vialPath(half: vBodyHalf, neckHalf: vNeckHalf, top: vNeckTop, shoulderTop: vShoulderTop,
                      shoulderH: vShoulderH, bottom: vBodyBottom, corner: vCorner)
let vInner = vialPath(half: vBodyHalf - vWall, neckHalf: vNeckHalf - vWall, top: vNeckTop,
                      shoulderTop: vShoulderTop + vWall * 0.6, shoulderH: vShoulderH,
                      bottom: vBodyBottom - vBase, corner: vCorner - vWall)
let vInnerHalf = vBodyHalf - vWall

/// Liquid surface height at x: a raised-cosine trough centered in the vial, cresting at ±vPeakT and
/// easing back down a touch at the wall so the crests read as peaks rather than a bowl.
func surfaceY(_ x: CGFloat) -> CGFloat {
    let t = abs(x - vCX) / vInnerHalf
    let depth = vTroughY - vPeakY
    if t <= vPeakT {
        return vTroughY - depth * (1 - cos(.pi * t / vPeakT)) / 2
    }
    let u = min(1, (t - vPeakT) / (1 - vPeakT))
    return vPeakY + depth * knob("V_EDGE", 0.10) * (1 - cos(.pi * u)) / 2
}

func surfacePath() -> CGMutablePath {
    let p = CGMutablePath()
    let m: CGFloat = vTilted ? 160 : 4   // a tilted vial's walls reach further out at the surface
    let x0 = vCX - vInnerHalf - m, x1 = vCX + vInnerHalf + m
    p.move(to: CGPoint(x: x0, y: surfaceY(x0)))
    var x = x0
    while x < x1 { x += 2; p.addLine(to: CGPoint(x: x, y: surfaceY(x))) }
    return p
}

let vSurface = surfacePath()
let vLiquid: CGPath = {
    let p = vSurface.mutableCopy()!
    let m: CGFloat = vTilted ? 160 : 4
    p.addLine(to: CGPoint(x: vCX + vInnerHalf + m, y: 1024))
    p.addLine(to: CGPoint(x: vCX - vInnerHalf - m, y: 1024))
    p.closeSubpath()
    return p
}()
let vTrough = CGPoint(x: vCX, y: vTroughY)

struct VialPalette {
    var liquid: [(UInt32, CGFloat, CGFloat)]
    var glassFill: [(UInt32, CGFloat, CGFloat)]  // horizontal, across the body
    var rim: CGFloat                             // rim brightness (white alpha)
    var cap: [(UInt32, CGFloat, CGFloat)]
    var crimp: [(UInt32, CGFloat, CGFloat)]
    var meniscus: UInt32
    var specular: CGFloat
    var shade: CGFloat
    var shadeHex: UInt32 = 0x4A0820   // liquid wall-shading tint
    var capShadeHex: UInt32 = 0x6A3208 // cap/crimp shading tint
    var glowHex: UInt32 = 0xE94560     // field glow + bloom body
    var bloomHex: UInt32 = 0xFF4A62    // bloom shadow color
    var bandHex: UInt32 = 0xFFB0A0     // luminous band under the surface
    var wallTintHex: UInt32 = 0xFF6A78 // glass wall below the surface
}

func vialPalette(_ v: Variant) -> VialPalette {
    switch v {
    case .light:
        return VialPalette(
            liquid: [(0xFF7A6B, 1, 0), (0xE94560, 1, 0.45), (0xC2304F, 1, 1)],
            glassFill: [(0xA7ACEB, 0.42, 0), (0x5A5FA0, 0.30, 0.25), (0x4A4E8C, 0.26, 0.7), (0x9A9FE0, 0.38, 1)],
            rim: 0.78,
            cap: [(0xFFC766, 1, 0), (0xFFB547, 1, 0.35), (0xE08A30, 1, 1)],
            crimp: [(0xC77A2C, 1, 0), (0xFFD27A, 1, 0.26), (0xF0A043, 1, 0.55), (0xB86A22, 1, 1)],
            meniscus: 0xFFD9CF, specular: 0.55, shade: 0.34)
    case .dark:
        return VialPalette(
            liquid: [(0xEE6E61, 1, 0), (0xD63F59, 1, 0.45), (0xA82947, 1, 1)],
            glassFill: [(0x7A7EAA, 0.32, 0), (0x34365C, 0.26, 0.25), (0x2E3054, 0.22, 0.7), (0x70749E, 0.28, 1)],
            rim: 0.55,
            cap: [(0xECB257, 1, 0), (0xE0A040, 1, 0.35), (0xC0782A, 1, 1)],
            crimp: [(0x94541A, 1, 0), (0xD89E4E, 1, 0.3), (0xC07828, 1, 0.62), (0x7E4414, 1, 1)],
            meniscus: 0xF2C4BA, specular: 0.36, shade: 0.34)
    case .tinted:
        return VialPalette(
            liquid: [(0xA8A8A8, 1, 0), (0x8C8C8C, 1, 0.5), (0x707070, 1, 1)],
            glassFill: [(0x4A4A4A, 1, 0), (0x262626, 1, 0.28), (0x262626, 1, 0.7), (0x444444, 1, 1)],
            rim: 0.55,
            cap: [(0xD6D6D6, 1, 0), (0xC4C4C4, 1, 0.35), (0x9E9E9E, 1, 1)],
            crimp: [(0x7A7A7A, 1, 0), (0xBEBEBE, 1, 0.3), (0xA0A0A0, 1, 0.62), (0x6A6A6A, 1, 1)],
            meniscus: 0xC8C8C8, specular: 0.30, shade: 0.20,
            shadeHex: 0x000000, capShadeHex: 0x000000)
    }
}

/// Applies the V_LIQ / V_CAPC options on top of the default palette (a no-op when neither is set).
func optionPalette(_ v: Variant) -> VialPalette {
    var p = vialPalette(v)
    if vLiq == "gold" && v != .tinted {
        p.liquid = v == .light
            ? [(0xFFCB6B, 1, 0), (0xF7A23C, 1, 0.40), (0xC9611E, 1, 1)]
            : [(0xE8B560, 1, 0), (0xD99A3E, 1, 0.45), (0xA85E20, 1, 1)]
        p.shadeHex = 0x6A2A08
        p.meniscus = 0xFFF1CF
        p.glowHex = 0xFF9A3C
        p.bloomHex = 0xFFA040
        p.bandHex = 0xFFF0C0
        p.wallTintHex = 0xFFC060
    }
    switch vCapColor {
    case "coral" where v == .light:
        p.cap = [(0xFF8A9A, 1, 0), (0xF2506B, 1, 0.38), (0xBE2C4C, 1, 1)]; p.capShadeHex = 0x5A0A28
    case "coral" where v == .dark:
        p.cap = [(0xEE7686, 1, 0), (0xD8445E, 1, 0.38), (0xA02640, 1, 1)]; p.capShadeHex = 0x4A0820
    case "gold" where v == .light:
        p.cap = [(0xFFD27A, 1, 0), (0xFFB547, 1, 0.38), (0xDB8A2E, 1, 1)]
    case "gold" where v == .dark:
        p.cap = [(0xECB257, 1, 0), (0xE0A040, 1, 0.35), (0xB8742A, 1, 1)]
    default: break
    }
    return p
}

/// Brushed-aluminum crimp band for the clinical vial (horizontal gradient stops).
func aluminum(_ v: Variant) -> [(UInt32, CGFloat, CGFloat)] {
    switch v {
    case .light:  return [(0x5E6478, 1, 0), (0xC9CEDA, 1, 0.14), (0xF4F6FB, 1, 0.27), (0xB4BAC8, 1, 0.52), (0xD6DAE3, 1, 0.74), (0x5A6074, 1, 1)]
    case .dark:   return [(0x3C404C, 1, 0), (0x9A9FAC, 1, 0.16), (0xC4C8D2, 1, 0.28), (0x868B98, 1, 0.55), (0xA2A6B2, 1, 0.76), (0x383C48, 1, 1)]
    case .tinted: return [(0x585858, 1, 0), (0xB4B4B4, 1, 0.16), (0xD4D4D4, 1, 0.28), (0x9A9A9A, 1, 0.55), (0xB0B0B0, 1, 0.76), (0x505050, 1, 1)]
    }
}

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func renderVial(_ variant: Variant) -> CGImage {
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
    let pal = optionPalette(variant)
    let bodyL = vCX - vBodyHalf, bodyR = vCX + vBodyHalf
    // Only non-default options touch the CTM; with none set every draw below matches the original exactly.
    let baseCTM = ctx.ctm
    let big = vTransformed ? full.insetBy(dx: -1024, dy: -1024) : full
    func setSpace(_ t: CGAffineTransform) {
        ctx.concatenate(ctx.ctm.inverted())
        ctx.concatenate(t.concatenating(baseCTM))
    }
    func vialSpace() { if vTilted { setSpace(vialTransform(tilt: true)) } }
    func liquidSpace() { if vTilted { setSpace(vialTransform(tilt: false)) } }
    let glassA = knob("V_GLASSA", 1)
    let glassFill = glassA == 1 ? pal.glassFill : pal.glassFill.map { ($0.0, min(1, $0.1 * glassA), $0.2) }

    // 1. Field.
    switch variant {
    case .light:
        if vField == "bold" {
            // Coral → plum → navy diagonal, lit from the top-left, with a deep pool behind the vial so the
            // glass and the white dot keep their contrast.
            ctx.drawLinearGradient(
                gradient([(0xFF5A6E, 1, 0), (0xE94560, 1, 0.16), (0x9A3470, 1, 0.42), (0x5B2A6E, 1, 0.62), (0x2A2D6A, 1, 0.82), (0x0F3460, 1, 1)]),
                start: CGPoint(x: 90, y: -40), end: CGPoint(x: 900, y: 1080), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            // V_CORNERDIM (0…1, default 0): tones down the hot coral corner so the trough dot stays the brightest element.
            let cornerDim = knob("V_CORNERDIM", 0)
            if cornerDim > 0 {
                ctx.drawRadialGradient(
                    gradient([(0x5B2A6E, cornerDim, 0), (0x5B2A6E, cornerDim * 0.55, 0.45), (0x5B2A6E, 0, 1)]),
                    startCenter: CGPoint(x: 60, y: 20), startRadius: 0,
                    endCenter: CGPoint(x: 60, y: 20), endRadius: 620, options: [.drawsBeforeStartLocation])
            }
            ctx.drawRadialGradient(
                gradient([(0x140F30, knob("V_POOL", 0.62), 0), (0x140F30, knob("V_POOL", 0.62) * 0.55, 0.55), (0x140F30, 0, 1)]),
                startCenter: CGPoint(x: 512 + vOX, y: 600 + vOY), startRadius: 0,
                endCenter: CGPoint(x: 512 + vOX, y: 600 + vOY), endRadius: 470 * vScale, options: [])
        } else if vField == "plum" {
            // Dual-tone: plum top-left, navy bottom-right, with a soft top light.
            ctx.drawLinearGradient(
                gradient([(0x6A2F7E, 1, 0), (0x46286A, 1, 0.4), (0x1E2356, 1, 0.75), (0x0F1C40, 1, 1)]),
                start: CGPoint(x: 160, y: 0), end: CGPoint(x: 860, y: 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.drawRadialGradient(
                gradient([(0xFFFFFF, 0.10, 0), (0xFFFFFF, 0, 1)]),
                startCenter: CGPoint(x: 330, y: 120), startRadius: 0,
                endCenter: CGPoint(x: 330, y: 120), endRadius: 520, options: [])
        } else {
            ctx.setFillColor(color(0x0B0C1E))
            ctx.fill(full)
            ctx.drawRadialGradient(
                gradient([(0x1F2148, 1, 0), (0x1A1A2E, 1, 0.45), (0x0B0C1E, 1, 1)]),
                startCenter: CGPoint(x: 512, y: 280), startRadius: 0,
                endCenter: CGPoint(x: 512, y: 440), endRadius: 820, options: [.drawsAfterEndLocation])
        }
        if vTransformed { ctx.concatenate(vialTransform(tilt: false)) }
        // Soft coral glow behind the vial, centred on the liquid.
        ctx.drawRadialGradient(
            gradient([(pal.glowHex, knob("V_GLOW", 0.40), 0), (pal.glowHex, 0.13, 0.5), (pal.glowHex, 0, 1)]),
            startCenter: CGPoint(x: 512, y: 620), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 620), endRadius: 500, options: [])
    case .dark:
        ctx.setFillColor(color(0x000000))
        ctx.fill(full)
        ctx.drawRadialGradient(
            gradient([(0x14141F, 1, 0), (0x000000, 1, 1)]),
            startCenter: CGPoint(x: 512, y: 520), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 520), endRadius: 700, options: [.drawsAfterEndLocation])
        if vTransformed { ctx.concatenate(vialTransform(tilt: false)) }
        ctx.drawRadialGradient(
            gradient([(pal.glowHex, 0.12, 0), (pal.glowHex, 0, 1)]),
            startCenter: CGPoint(x: 512, y: 640), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 640), endRadius: 380, options: [])
    case .tinted:
        ctx.setFillColor(color(0x000000))
        ctx.fill(full)
        if vTransformed { ctx.concatenate(vialTransform(tilt: false)) }
    }

    // 2. Coral bloom hugging the liquid (light only) so the vial glows from within.
    if variant == .light {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: knob("V_BLUR", 90), color: color(pal.bloomHex, alpha: knob("V_BA", 0.60)))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.addPath(vLiquid)
        ctx.clip()
        vialSpace()
        ctx.addPath(vInner)
        ctx.setFillColor(color(pal.glowHex))
        ctx.fillPath()
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
    vialSpace()

    // 3. Glass body: translucent fill with brighter edges (light passing through more glass).
    ctx.saveGState()
    ctx.addPath(vOuter)
    ctx.clip()
    if variant == .tinted {
        ctx.drawLinearGradient(gradient(glassFill), start: CGPoint(x: bodyL, y: 0), end: CGPoint(x: bodyR, y: 0), options: [])
    } else {
        ctx.setFillColor(color(0x0B0C1E, alpha: variant == .light ? knob("V_UNDER", 0.20) : 0.4))
        ctx.fill(full)
        ctx.drawLinearGradient(gradient(glassFill), start: CGPoint(x: bodyL, y: 0), end: CGPoint(x: bodyR, y: 0), options: [])
    }
    ctx.restoreGState()

    // 4. Liquid, clipped to the glass interior.
    ctx.saveGState()
    ctx.addPath(vInner)
    ctx.clip()
    ctx.saveGState()
    liquidSpace()
    ctx.addPath(vLiquid)
    ctx.clip()
    ctx.drawLinearGradient(gradient(pal.liquid), start: CGPoint(x: 512, y: vPeakY), end: CGPoint(x: 512, y: vBodyBottom - vBase),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // Cylindrical volume: darker toward both walls.
    vialSpace()
    ctx.drawLinearGradient(
        gradient([(pal.shadeHex, pal.shade, 0), (pal.shadeHex, 0, 0.32), (pal.shadeHex, 0, 0.62), (pal.shadeHex, pal.shade * 1.2, 1)]),
        start: CGPoint(x: vCX - vInnerHalf, y: 0), end: CGPoint(x: vCX + vInnerHalf, y: 0), options: [])
    liquidSpace()
    // Luminous band just under the surface.
    if variant != .tinted {
        ctx.addPath(vSurface.copy(strokingWithWidth: 70, lineCap: .round, lineJoin: .round, miterLimit: 10))
        ctx.setFillColor(color(pal.bandHex, alpha: variant == .light ? 0.20 : 0.12))
        ctx.fillPath()
    }
    ctx.restoreGState()
    // Meniscus: a thin bright line along the surface.
    liquidSpace()
    ctx.addPath(vSurface.copy(strokingWithWidth: knob("V_MEN", 11), lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.setFillColor(color(pal.meniscus, alpha: variant == .light ? 0.95 : 0.8))
    ctx.fillPath()
    ctx.restoreGState()
    vialSpace()

    // 5. Glass wall: the ring between outer and inner silhouettes, brightest at top-left.
    ctx.saveGState()
    let wall = CGMutablePath()
    wall.addPath(vOuter)
    wall.addPath(vInner)
    ctx.addPath(wall)
    ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(
        gradient([(0xFFFFFF, pal.rim, 0), (0xFFFFFF, pal.rim * 0.62, 0.55), (0xFFFFFF, pal.rim * 0.8, 1)]),
        start: CGPoint(x: bodyL, y: vShoulderTop), end: CGPoint(x: bodyR, y: vBodyBottom), options: [])
    // Below the surface the glass picks up the liquid's color.
    if variant != .tinted {
        liquidSpace()
        ctx.addPath(vLiquid)
        ctx.clip()
        ctx.setFillColor(color(pal.wallTintHex, alpha: variant == .light ? 0.30 : 0.22))
        ctx.fill(big)
    }
    ctx.restoreGState()
    vialSpace()

    // 5b. Crisp bright outer edge so the silhouette pops off the field at home-screen size.
    ctx.saveGState()
    ctx.addPath(vOuter)
    ctx.clip()
    ctx.addPath(vOuter.copy(strokingWithWidth: knob("V_EDGEW", 10), lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.setFillColor(color(0xFFFFFF, alpha: variant == .dark ? 0.55 : (variant == .tinted ? 0.6 : 0.9)))
    ctx.fillPath()
    ctx.restoreGState()

    // 5c. Optional colored rim light down the right side of the glass (a second, warm light source).
    let rimL = knob("V_RIML", 0)
    if rimL > 0 && variant != .tinted {
        let rimHex = UInt32(env["V_RIMC"] ?? "", radix: 16) ?? 0xFFB547
        ctx.saveGState()
        ctx.addPath(vOuter)
        ctx.clip()
        ctx.addPath(vOuter.copy(strokingWithWidth: knob("V_RIMW", 30), lineCap: .round, lineJoin: .round, miterLimit: 10))
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([(rimHex, 0, 0), (rimHex, 0, 0.62), (rimHex, rimL * (variant == .dark ? 0.6 : 1), 1)]),
            start: CGPoint(x: bodyL, y: 0), end: CGPoint(x: bodyR, y: 0), options: [])
        ctx.restoreGState()
    }

    // 6. Speculars on the left of the glass (over the liquid): a broad soft streak plus a thin sharp one.
    do {
        let top = vShoulderTop + vShoulderH + 14, bottom = vBodyBottom - vBase - 50
        ctx.saveGState()
        ctx.addPath(vInner)
        ctx.clip()
        let broad = CGRect(x: bodyL + vWall + knob("V_S1X", 16), y: top, width: knob("V_S1W", 34), height: bottom - top)
        ctx.addPath(roundedRect(broad, broad.width / 2))
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([(0xFFFFFF, pal.specular, 0), (0xFFFFFF, pal.specular * 0.7, 0.55), (0xFFFFFF, pal.specular * 0.15, 1)]),
            start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: bottom), options: [])
        ctx.restoreGState()
        let thinTop = top + 10, thinBottom = top + (bottom - top) * 0.5
        let thin = CGRect(x: bodyL + vWall + knob("V_S2X", 64), y: thinTop, width: knob("V_S2W", 14), height: thinBottom - thinTop)
        ctx.saveGState()
        ctx.addPath(roundedRect(thin, thin.width / 2))
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([(0xFFFFFF, pal.specular * 0.7, 0), (0xFFFFFF, 0, 1)]),
            start: CGPoint(x: 0, y: thinTop), end: CGPoint(x: 0, y: thinBottom), options: [])
        ctx.restoreGState()
    }

    // 7. Crimped metal collar over the neck, then the flip-top cap.
    let crimp = CGRect(x: vCX - vCrimpHalf, y: vCrimpTop, width: vCrimpHalf * 2, height: vCrimpBottom - vCrimpTop)
    if clinical {
        drawClinicalSeal(ctx, variant, pal, crimp: crimp)
    } else {
    ctx.saveGState()
    ctx.addPath(roundedRect(crimp, 14))
    ctx.clip()
    ctx.drawLinearGradient(gradient(pal.crimp), start: CGPoint(x: crimp.minX, y: 0), end: CGPoint(x: crimp.maxX, y: 0), options: [])
    // Rolled lower lip of the crimp: a soft darker band where the metal folds under the neck.
    ctx.drawLinearGradient(
        gradient([(pal.capShadeHex, 0, 0), (pal.capShadeHex, 0.32, 1)]),
        start: CGPoint(x: 0, y: crimp.maxY - 30), end: CGPoint(x: 0, y: crimp.maxY), options: [])
    ctx.restoreGState()

    let cap = CGRect(x: vCX - vCapHalf, y: vCapTop, width: vCapHalf * 2, height: vCapH)
    ctx.saveGState()
    if variant == .light {
        ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x000000, alpha: 0.45))
    }
    ctx.addPath(roundedRect(cap, knob("V_CR", 20)))
    ctx.setFillColor(color(pal.cap.last!.0))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(roundedRect(cap, knob("V_CR", 20)))
    ctx.clip()
    ctx.drawLinearGradient(gradient(pal.cap), start: CGPoint(x: 0, y: cap.minY), end: CGPoint(x: 0, y: cap.maxY), options: [])
    // Cylindrical shading plus a top gloss band.
    ctx.drawLinearGradient(
        gradient([(pal.capShadeHex, 0.30, 0), (pal.capShadeHex, 0, 0.3), (pal.capShadeHex, 0, 0.7), (pal.capShadeHex, 0.34, 1)]),
        start: CGPoint(x: cap.minX, y: 0), end: CGPoint(x: cap.maxX, y: 0), options: [])
    ctx.addPath(roundedRect(CGRect(x: cap.minX + 30, y: cap.minY + 12, width: cap.width - 60, height: 18), 9))
    ctx.setFillColor(color(0xFFFFFF, alpha: variant == .tinted ? 0.3 : 0.42))
    ctx.fillPath()
    ctx.restoreGState()
    }

    // 8. The trough dot: white-hot core with a warm bloom — the brightest thing on the icon.
    liquidSpace()
    let dotRect = CGRect(x: vTrough.x - vDotR, y: vTrough.y - vDotR, width: vDotR * 2, height: vDotR * 2)
    let ringW = knob("V_RING", 0)
    if ringW > 0 && variant != .tinted {
        // A thin dark halo so a white dot still separates from a bright (gold) liquid.
        ctx.drawRadialGradient(
            gradient([(0x3A0A18, 0.55, 0), (0x3A0A18, 0, 1)]),
            startCenter: vTrough, startRadius: vDotR - 2, endCenter: vTrough, endRadius: vDotR + ringW, options: [])
    }
    switch variant {
    case .light:
        ctx.drawRadialGradient(
            gradient([(0xFFFFFF, 0.80, 0), (0xFFE3B0, 0.40, 0.35), (0xFFB547, 0, 1)]),
            startCenter: vTrough, startRadius: 0, endCenter: vTrough, endRadius: knob("V_BLOOM", 150), options: [])
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 40, color: color(0xFFFFFF, alpha: 0.95))
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dotRect)
        ctx.restoreGState()
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dotRect)
    case .dark:
        ctx.drawRadialGradient(
            gradient([(0xFFFFFF, 0.45, 0), (0xFFD9A0, 0.15, 0.4), (0xFFB547, 0, 1)]),
            startCenter: vTrough, startRadius: 0, endCenter: vTrough, endRadius: 110, options: [])
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 22, color: color(0xFFFFFF, alpha: 0.6))
        ctx.setFillColor(color(0xF6F6F6))
        ctx.fillEllipse(in: dotRect)
        ctx.restoreGState()
    case .tinted:
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dotRect)
    }

    return ctx.makeImage()!
}

/// Clinical vial seal: a flat brushed-aluminum crimp band rolled under the neck, topped by a colored
/// plastic flip-off cap that sits slightly narrower than the band.
func drawClinicalSeal(_ ctx: CGContext, _ variant: Variant, _ pal: VialPalette, crimp: CGRect) {
    let alu = aluminum(variant)
    // Band body.
    ctx.saveGState()
    if variant == .light {
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, alpha: 0.35))
    }
    ctx.addPath(roundedRect(crimp, knob("V_KR", 12)))
    ctx.setFillColor(color(alu.last!.0))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(roundedRect(crimp, knob("V_KR", 12)))
    ctx.clip()
    ctx.drawLinearGradient(gradient(alu), start: CGPoint(x: crimp.minX, y: 0), end: CGPoint(x: crimp.maxX, y: 0), options: [])
    // Rolled top edge folded over the flange: a bright lip, then a thin shadow line under it.
    let lipH: CGFloat = knob("V_LIP", 16)
    ctx.setFillColor(color(0xFFFFFF, alpha: variant == .tinted ? 0.18 : 0.26))
    ctx.fill(CGRect(x: crimp.minX, y: crimp.minY, width: crimp.width, height: lipH))
    ctx.setFillColor(color(0x000000, alpha: 0.22))
    ctx.fill(CGRect(x: crimp.minX, y: crimp.minY + lipH, width: crimp.width, height: 4))
    // Rolled lower lip where the metal tucks under the neck: darker band plus a hairline highlight.
    ctx.drawLinearGradient(
        gradient([(0x10121C, 0, 0), (0x10121C, 0.42, 1)]),
        start: CGPoint(x: 0, y: crimp.maxY - 30), end: CGPoint(x: 0, y: crimp.maxY - 6), options: [.drawsAfterEndLocation])
    ctx.setFillColor(color(0xFFFFFF, alpha: variant == .tinted ? 0.2 : 0.30))
    ctx.fill(CGRect(x: crimp.minX, y: crimp.maxY - 6, width: crimp.width, height: 3))
    ctx.restoreGState()

    // Flip-off cap.
    let cap = CGRect(x: vCX - vCapHalf, y: vCapTop, width: vCapHalf * 2, height: vCapH)
    let capPath = CGMutablePath()
    let rTop = knob("V_CR", 22), rBot: CGFloat = 6
    capPath.move(to: CGPoint(x: cap.minX, y: cap.maxY - rBot))
    capPath.addArc(tangent1End: CGPoint(x: cap.minX, y: cap.minY), tangent2End: CGPoint(x: cap.midX, y: cap.minY), radius: rTop)
    capPath.addArc(tangent1End: CGPoint(x: cap.maxX, y: cap.minY), tangent2End: CGPoint(x: cap.maxX, y: cap.maxY), radius: rTop)
    capPath.addArc(tangent1End: CGPoint(x: cap.maxX, y: cap.maxY), tangent2End: CGPoint(x: cap.midX, y: cap.maxY), radius: rBot)
    capPath.addArc(tangent1End: CGPoint(x: cap.minX, y: cap.maxY), tangent2End: CGPoint(x: cap.minX, y: cap.minY), radius: rBot)
    capPath.closeSubpath()
    ctx.saveGState()
    if variant == .light {
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: color(0x000000, alpha: 0.4))
    }
    ctx.addPath(capPath)
    ctx.setFillColor(color(pal.cap.last!.0))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(capPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient(pal.cap), start: CGPoint(x: 0, y: cap.minY), end: CGPoint(x: 0, y: cap.maxY), options: [])
    ctx.drawLinearGradient(
        gradient([(pal.capShadeHex, 0.34, 0), (pal.capShadeHex, 0, 0.26), (pal.capShadeHex, 0, 0.66), (pal.capShadeHex, 0.40, 1)]),
        start: CGPoint(x: cap.minX, y: 0), end: CGPoint(x: cap.maxX, y: 0), options: [])
    // Gloss on the top face.
    ctx.addPath(roundedRect(CGRect(x: cap.minX + 26, y: cap.minY + 9, width: cap.width - 52, height: 13), 6.5))
    ctx.setFillColor(color(0xFFFFFF, alpha: variant == .tinted ? 0.3 : 0.5))
    ctx.fillPath()
    ctx.restoreGState()
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
    write(design == "wave" ? renderWave(variant) : renderVial(variant), to: outDir.appendingPathComponent(name))
}
