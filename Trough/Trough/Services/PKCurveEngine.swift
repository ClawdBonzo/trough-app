import Foundation

// MARK: - Data Types

struct PKPoint: Identifiable {
    let id = UUID()
    let time: Double       // days from now (negative = past, 0 = now, positive = future)
    let level: Double      // estimated serum level ng/dL
    let upperBand: Double  // +20% individual variation
    let lowerBand: Double  // -20% individual variation
}

struct CompoundCurve: Identifiable {
    let id = UUID()
    let compound: String
    let colorHex: String
    let points: [PKPoint]
}

struct PKCurveData {
    let curves: [CompoundCurve]
    let combinedPoints: [PKPoint]
    let currentDayIndex: Int  // index in combinedPoints closest to "now" (t≈0)
    let peakDay: Double       // t-value at maximum combined level
    let troughDay: Double     // t-value at minimum future level post-peak
}

// MARK: - Decoupled Inputs (no SwiftData dependency)

struct PKProtocolInput {
    let compoundName: String
    let doseAmountMg: Double
    let frequencyDays: Int
    let colorHex: String
    let customHalfLife: Double?
    let route: String  // "intramuscular" | "subcutaneous"
}

struct PKInjectionInput {
    let compoundName: String
    let doseAmountMg: Double
    let injectedAt: Date
    let route: String
}

// MARK: - Engine

final class PKCurveEngine {
    static let shared = PKCurveEngine()
    private init() {}

    // Half-lives in days (from literature)
    static let defaultHalfLives: [String: Double] = [
        "Testosterone Cypionate":   8.0,
        "Testosterone Enanthate":   4.5,
        "Testosterone Propionate":  0.8,
        "Testosterone Undecanoate": 21.0,
        "HCG":                      1.5,
        "Nandrolone Decanoate":     7.0,
    ]

    private static let compoundColors: [String: String] = [
        "Testosterone Cypionate":   "#4A90D9",
        "Testosterone Enanthate":   "#27AE60",
        "Testosterone Propionate":  "#F39C12",
        "Testosterone Undecanoate": "#9B59B6",
        "HCG":                      "#E74C3C",
        "Nandrolone Decanoate":     "#1ABC9C",
    ]

    func effectiveHalfLife(compound: String, custom: Double? = nil) -> Double {
        custom ?? Self.defaultHalfLives[compound] ?? 7.0
    }

    // MARK: - Main computation

    /// Computes multi-compound PK curves from protocol definitions and injection history.
    /// Pure function — no SwiftData or UI dependencies.
    func computeMultiCompoundCurve(
        protocols: [PKProtocolInput],
        injections: [PKInjectionInput],
        includeAbsorptionDelay: Bool,
        resolution: Int = 96
    ) -> PKCurveData {
        guard !protocols.isEmpty else {
            return PKCurveData(curves: [], combinedPoints: [], currentDayIndex: 0, peakDay: 0, troughDay: 0)
        }

        let now = Date.now
        let maxHL    = protocols.map { effectiveHalfLife(compound: $0.compoundName, custom: $0.customHalfLife) }.max() ?? 8.0
        let maxFreq  = protocols.map { Double($0.frequencyDays) }.max() ?? 7.0
        let startT   = -maxHL * 3
        let endT     = maxFreq + maxHL * 2.5
        let step     = (endT - startT) / Double(max(resolution - 1, 1))
        let timeGrid = (0..<resolution).map { startT + Double($0) * step }

        var allCurves: [CompoundCurve] = []
        var totalLevels = [Double](repeating: 0, count: resolution)

        for proto in protocols {
            let hl     = effectiveHalfLife(compound: proto.compoundName, custom: proto.customHalfLife)
            let ke     = log(2.0) / hl
            let ka     = proto.route.lowercased().contains("sub") ? 1.0 : 1.5
            let scale  = scalingFactor(for: proto.compoundName)

            // Historical injections for this compound (within 5 half-lives of display range)
            let matching = injections.filter { compoundsMatch($0.compoundName, proto.compoundName) }
            var offsets: [(t: Double, dose: Double)] = matching.compactMap { inj in
                let t = -now.timeIntervalSince(inj.injectedAt) / 86400  // negative = past
                return t > startT - hl ? (t, inj.doseAmountMg) : nil
            }

            // Project future injections from last known
            if let lastInj = matching.sorted(by: { $0.injectedAt < $1.injectedAt }).last {
                let lastT = -now.timeIntervalSince(lastInj.injectedAt) / 86400
                var nextT = lastT + Double(proto.frequencyDays)
                while nextT <= endT {
                    offsets.append((t: nextT, dose: proto.doseAmountMg))
                    nextT += Double(proto.frequencyDays)
                }
            }

            // Compute level at each grid point
            let compLevels: [Double] = timeGrid.map { t in
                offsets.reduce(0.0) { acc, inj in
                    let dt = t - inj.t
                    guard dt >= 0 else { return acc }
                    return acc + singleDoseLevel(dt: dt, doseMg: inj.dose, ke: ke, ka: ka, scale: scale, withDelay: includeAbsorptionDelay)
                }
            }

            for (i, lvl) in compLevels.enumerated() { totalLevels[i] += lvl }

            let color  = Self.compoundColors[proto.compoundName] ?? proto.colorHex
            let points = zip(timeGrid, compLevels).map { PKPoint(time: $0, level: $1, upperBand: $1 * 1.2, lowerBand: $1 * 0.8) }
            allCurves.append(CompoundCurve(compound: proto.compoundName, colorHex: color, points: points))
        }

        let combinedPoints = zip(timeGrid, totalLevels).map {
            PKPoint(time: $0, level: $1, upperBand: $1 * 1.2, lowerBand: $1 * 0.8)
        }

        // Current index = t closest to 0
        let currentIdx = timeGrid.enumerated().min(by: { abs($0.element) < abs($1.element) })?.offset ?? 0

        // Peak = global max
        let peakIdx = totalLevels.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let peakDay = timeGrid[peakIdx]

        // Trough = min future level after the peak
        let postPeakPairs = zip(timeGrid, totalLevels).dropFirst(peakIdx)
        let troughDay = postPeakPairs.min(by: { $0.1 < $1.1 })?.0 ?? endT

        return PKCurveData(
            curves: allCurves,
            combinedPoints: combinedPoints,
            currentDayIndex: currentIdx,
            peakDay: peakDay,
            troughDay: troughDay
        )
    }

    // MARK: - Private helpers

    /// Bateman function (with delay) or simple first-order decay (without delay).
    ///
    /// With absorption delay (IM default):
    ///   C(t) = dose * scale * (ka/(ka-ke)) * (e^(-ke*t) - e^(-ka*t))
    ///   ka ≈ 1.5/day for IM (Tmax ~16-24 h), 1.0/day for SubQ (Tmax ~24-36 h)
    ///
    /// Without delay:
    ///   C(t) = dose * scale * e^(-ke*t)   [instant peak at t=0]
    private func singleDoseLevel(
        dt: Double,
        doseMg: Double,
        ke: Double,
        ka: Double,
        scale: Double,
        withDelay: Bool
    ) -> Double {
        guard dt >= 0 else { return 0 }
        if withDelay {
            guard abs(ka - ke) > 0.001 else { return 0 }
            let raw = doseMg * scale * (ka / (ka - ke)) * (exp(-ke * dt) - exp(-ka * dt))
            return max(0, raw)
        } else {
            return max(0, doseMg * scale * exp(-ke * dt))
        }
    }

    /// Empirical ng/dL per mg scaling factor (100 mg → approximate peak).
    private func scalingFactor(for compound: String) -> Double {
        let c = compound.lowercased()
        if c.contains("undecanoate") { return 3.5 }
        if c.contains("propionate")  { return 6.5 }
        if c.contains("hcg")         { return 2.0 }
        return 5.5  // cypionate, enanthate, decanoate
    }

    private func compoundsMatch(_ a: String, _ b: String) -> Bool {
        let al = a.lowercased(), bl = b.lowercased()
        return al == bl || al.contains(bl) || bl.contains(al)
    }
}
