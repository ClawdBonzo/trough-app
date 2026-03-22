import Foundation
import SwiftData

// MARK: - Sample Configuration

struct SampleConfig {
    var userType: String       = "trt"
    var compound: String       = "Testosterone Cypionate"
    var doseMg: Double         = 200
    var frequencyDays: Int     = 7
    /// If true, generates cycle-correlated scores that showcase the PK curve value prop.
    /// If false, generates flat random data (no cycle pattern).
    var showCyclePattern: Bool = true
    var daysOfHistory: Int     = 42
    var includePeptides: Bool  = true
}

// MARK: - Service

enum SampleDataService {

    // MARK: - Status

    static func hasSampleData(context: ModelContext) -> Bool {
        var desc = FetchDescriptor<SDCheckin>(predicate: #Predicate { $0.isSampleData })
        desc.fetchLimit = 1
        return (try? context.fetch(desc).isEmpty == false) ?? false
    }

    static func hasRealData(context: ModelContext) -> Bool {
        var desc = FetchDescriptor<SDCheckin>(predicate: #Predicate { !$0.isSampleData })
        desc.fetchLimit = 1
        return (try? context.fetch(desc).isEmpty == false) ?? false
    }

    // MARK: - Insert

    static func insertSampleData(
        context: ModelContext,
        userID: UUID,
        config: SampleConfig = SampleConfig()
    ) {
        guard !hasSampleData(context: context) else { return }
        if config.userType == "natural" {
            generateNaturalData(config: config, userID: userID, context: context)
        } else {
            generateTRTData(config: config, userID: userID, context: context)
        }
        try? context.save()
    }

    // MARK: - Remove

    static func clearSampleData(context: ModelContext) {
        removeSampleData(context: context)
    }

    static func removeSampleData(context: ModelContext) {
        func deleteAll<T: PersistentModel>(_ type: T.Type, pred: Predicate<T>) {
            let items = (try? context.fetch(FetchDescriptor<T>(predicate: pred))) ?? []
            items.forEach { context.delete($0) }
        }
        // Cascade delete on SDBloodwork handles SDBloodworkMarker children.
        // Listing SDBloodworkMarker here too as belt-and-suspenders.
        deleteAll(SDCheckin.self,          pred: #Predicate { $0.isSampleData })
        deleteAll(SDInjection.self,        pred: #Predicate { $0.isSampleData })
        deleteAll(SDProtocol.self,         pred: #Predicate { $0.isSampleData })
        deleteAll(SDBloodwork.self,        pred: #Predicate { $0.isSampleData })
        deleteAll(SDBloodworkMarker.self,  pred: #Predicate { $0.isSampleData })
        deleteAll(SDPeptideLog.self,       pred: #Predicate { $0.isSampleData })
        deleteAll(SDSupplementConfig.self, pred: #Predicate { $0.isSampleData })
        try? context.save()
    }

    // MARK: - TRT Data Generation

    private static func generateTRTData(config: SampleConfig, userID: UUID, context: ModelContext) {
        let cal   = Calendar.current
        let today = Date.now.startOfDay

        // ── Protocol ────────────────────────────────────────────────────────
        let freqLabel = config.frequencyDays == 7 ? "E7D"
            : config.frequencyDays == 14 ? "E14D"
            : "E\(config.frequencyDays)D"
        let proto = SDProtocol(
            userID: userID,
            name: "\(shortName(config.compound)) \(Int(config.doseMg))mg \(freqLabel) (Sample)",
            compoundName: config.compound,
            doseAmountMg: config.doseMg,
            frequencyDays: config.frequencyDays,
            concentrationMgPerMl: 200,
            isActive: true, isPrimary: true,
            colorHex: compoundHex(config.compound),
            isSampleData: true
        )
        context.insert(proto)

        // ── Per-day generation (d=0 oldest, d=daysOfHistory-1 today) ────────
        let sites = ["Left Glute", "Right Glute", "Left Quad",
                     "Right Quad", "Left Delt",  "Right Delt"]
        var siteIdx        = 0
        let bloodworkDay   = config.daysOfHistory / 2   // midpoint ≈ day 21

        for d in 0..<config.daysOfHistory {
            let daysAgo = (config.daysOfHistory - 1) - d
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            let dayInCycle = d % config.frequencyDays
            var rng = Seeded(seed: d * 137 + 9973)

            // ── Injection on first day of each cycle ─────────────────────
            if dayInCycle == 0 {
                let injTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
                let inj = SDInjection(
                    userID: userID,
                    protocolID: proto.id,
                    injectedAt: injTime,
                    compoundName: config.compound,
                    doseAmountMg: config.doseMg,
                    volumeMl: config.doseMg / 200.0,
                    injectionSite: sites[siteIdx % sites.count],
                    isSampleData: true
                )
                context.insert(inj)
                siteIdx += 1
            }

            // ── Scores ───────────────────────────────────────────────────
            let energy, mood, libido, clarity, sleepScore: Double
            let sleepHrs, hrv: Double
            let steps: Int
            let mwBaseProbability: Double

            if config.showCyclePattern {
                let base = trtBaseScores(dayInCycle: dayInCycle, freq: config.frequencyDays)
                energy     = scoreWithNoise(base.energy,  rng: &rng)
                mood       = scoreWithNoise(base.mood,    rng: &rng)
                libido     = scoreWithNoise(base.libido,  rng: &rng)
                clarity    = scoreWithNoise(base.clarity, rng: &rng)
                sleepScore = scoreWithNoise(base.sleep,   rng: &rng)
                sleepHrs   = trtSleepHours(dayInCycle: dayInCycle, freq: config.frequencyDays, rng: &rng)
                hrv        = trtHRV(dayInCycle: dayInCycle, freq: config.frequencyDays, rng: &rng)
                steps      = trtSteps(dayInCycle: dayInCycle, freq: config.frequencyDays, rng: &rng)
                mwBaseProbability = trtMorningWoodProb(dayInCycle: dayInCycle, freq: config.frequencyDays)
            } else {
                // Flat random — no cycle signal
                energy     = round(rng.uniform(in: 2.5...4.5).clamped(to: 1...5))
                mood       = round(rng.uniform(in: 2.5...4.5).clamped(to: 1...5))
                libido     = round(rng.uniform(in: 2.0...4.5).clamped(to: 1...5))
                clarity    = round(rng.uniform(in: 2.5...4.5).clamped(to: 1...5))
                sleepScore = round(rng.uniform(in: 2.5...4.5).clamped(to: 1...5))
                sleepHrs   = rng.uniform(in: 5.5...8.5)
                hrv        = rng.uniform(in: 30...55)
                steps      = Int(rng.uniform(in: 5000...11000))
                mwBaseProbability = 0.60
            }

            // Morning wood: reduce 30% if sleep < 6.5 hrs
            let mwProb = sleepHrs < 6.5 ? mwBaseProbability * 0.70 : mwBaseProbability
            let mw     = rng.bool(probability: mwProb)

            let checkin = SDCheckin(
                userID: userID, date: date,
                energyScore: energy, moodScore: mood, libidoScore: libido,
                sleepQualityScore: sleepScore, morningWoodScore: mw ? 5 : 1,
                mentalClarityScore: clarity,
                morningWood: mw,
                workoutToday: rng.bool(probability: 0.58),
                bodyWeightKg: 86.0 + rng.uniform(in: -0.8...0.8),   // ~190 lbs
                sleepHours: sleepHrs,
                hrv: hrv,
                stepCount: steps,
                isSampleData: true
            )
            context.insert(checkin)

            // ── Bloodwork at midpoint ─────────────────────────────────────
            if d == bloodworkDay {
                insertTRTBloodwork(userID: userID, date: date, context: context)
            }
        }

        // ── Peptides: BPC-157 250 mcg EOD for first 20 days ─────────────────
        if config.includePeptides {
            for d in stride(from: 0, through: min(19, config.daysOfHistory - 1), by: 2) {
                let daysAgo = (config.daysOfHistory - 1) - d
                guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
                let t = cal.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date
                let log = SDPeptideLog(
                    userID: userID, administeredAt: t,
                    peptideName: "BPC-157", doseMcg: 250,
                    routeOfAdministration: "subcutaneous",
                    injectionSite: "Abdomen",
                    isSampleData: true
                )
                context.insert(log)
            }
        }
    }

    // MARK: Cycle score tables

    /// Base 1–5 scores for each phase of a TRT cycle.
    private static func trtBaseScores(dayInCycle: Int, freq: Int)
        -> (energy: Double, mood: Double, libido: Double, clarity: Double, sleep: Double)
    {
        let pos = normalized(dayInCycle, freq: freq)
        switch pos {
        case 0, 1: return (4.2, 4.0, 4.5, 4.0, 3.5)  // post-injection: energy surge, disrupted sleep
        case 2, 3: return (4.5, 4.3, 4.8, 4.3, 4.2)  // peak: everything dialed in
        case 4:    return (3.8, 3.5, 3.5, 3.6, 3.8)  // plateau: holding
        case 5:    return (2.8, 2.5, 2.2, 2.8, 3.2)  // trough: beginning to fade
        default:   return (2.2, 2.0, 1.8, 2.2, 2.5)  // deep trough: next injection due
        }
    }

    private static func trtSleepHours(dayInCycle: Int, freq: Int, rng: inout Seeded) -> Double {
        let pos = normalized(dayInCycle, freq: freq)
        let (base, noise): (Double, Double) = {
            switch pos {
            case 0, 1: return (6.4, 0.6)  // post-injection: injection-night disruption
            case 2, 3: return (7.5, 0.5)  // peak: best sleep
            case 4:    return (7.2, 0.5)  // plateau: normal
            case 5:    return (6.6, 0.6)  // trough: restless
            default:   return (6.0, 0.7)  // deep trough: poor
            }
        }()
        return (base + rng.uniform(in: -noise...noise)).clamped(to: 4.5...9.5)
    }

    private static func trtHRV(dayInCycle: Int, freq: Int, rng: inout Seeded) -> Double {
        // HRV peaks at testosterone peak, troughs with testosterone (range 28–62 ms)
        let pos = normalized(dayInCycle, freq: freq)
        let (base, noise): (Double, Double) = {
            switch pos {
            case 0, 1: return (44.0, 5.0)
            case 2, 3: return (57.0, 5.0)  // highest at peak
            case 4:    return (48.0, 4.0)
            case 5:    return (36.0, 5.0)
            default:   return (30.0, 4.0)  // lowest at deep trough
            }
        }()
        return (base + rng.uniform(in: -noise...noise)).clamped(to: 28...62)
    }

    private static func trtSteps(dayInCycle: Int, freq: Int, rng: inout Seeded) -> Int {
        let pos = normalized(dayInCycle, freq: freq)
        let (base, noise): (Double, Double) = {
            switch pos {
            case 0, 1: return (8000, 1500)
            case 2, 3: return (9500, 1500)  // more active on peak days
            case 4:    return (8500, 1500)
            case 5:    return (7000, 1500)
            default:   return (6500, 1500)  // less motivated at trough
            }
        }()
        return Int((base + rng.uniform(in: -noise...noise)).clamped(to: 3000...14000))
    }

    private static func trtMorningWoodProb(dayInCycle: Int, freq: Int) -> Double {
        switch normalized(dayInCycle, freq: freq) {
        case 0:       return 0.75  // injection day
        case 1, 2, 3: return 0.90  // peak window
        case 4:       return 0.65  // plateau
        case 5:       return 0.40  // trough
        default:      return 0.25  // deep trough
        }
    }

    /// Map any cycle position to a canonical 0–6 phase index.
    private static func normalized(_ dayInCycle: Int, freq: Int) -> Int {
        guard freq > 7 else { return min(dayInCycle, 6) }
        return Int(Double(dayInCycle) / Double(freq) * 7.0)
    }

    // MARK: Bloodwork at midpoint

    private static func insertTRTBloodwork(userID: UUID, date: Date, context: ModelContext) {
        let bw = SDBloodwork(
            userID: userID, drawnAt: date,
            labName: "Defy Medical (Sample)",
            isSampleData: true
        )
        context.insert(bw)

        let markers: [(name: String, value: Double, unit: String)] = [
            // Core panel — values that show a good protocol response
            ("Total Testosterone",   850.0, "ng/dL"),
            ("Free Testosterone",     22.5, "pg/mL"),
            ("Estradiol (E2)",         35.0, "pg/mL"),
            ("SHBG",                   22.0, "nmol/L"),
            ("Hematocrit",             48.5, "%"),
            ("Hemoglobin",             16.2, "g/dL"),
            ("PSA",                     0.8, "ng/mL"),
            // Suppressed on TRT (expected — good for user to see)
            ("LH",                      0.1, "IU/L"),
            ("FSH",                     0.1, "IU/L"),
            // Lipids
            ("Total Cholesterol",     188.0, "mg/dL"),
            ("LDL",                   112.0, "mg/dL"),
            ("HDL",                    48.0, "mg/dL"),
            ("Triglycerides",         110.0, "mg/dL"),
            // Liver (normal — good for AI analysis demo)
            ("ALT",                    26.0, "U/L"),
            ("AST",                    24.0, "U/L"),
        ]

        for m in markers {
            let marker = SDBloodworkMarker(
                bloodworkID: bw.id,
                markerName: m.name,
                value: m.value,
                unit: m.unit,
                isSampleData: true
            )
            context.insert(marker)
            bw.markers.append(marker)
        }
    }

    // MARK: - Natural User Data Generation

    private static func generateNaturalData(config: SampleConfig, userID: UUID, context: ModelContext) {
        let cal   = Calendar.current
        let today = Date.now.startOfDay

        // ── Supplements ──────────────────────────────────────────────────────
        let suppDefs: [(String, Double, String)] = [
            ("Creatine",  5.0,    "g"),
            ("Vitamin D", 5000.0, "IU"),
        ]
        for (name, dose, unit) in suppDefs {
            context.insert(SDSupplementConfig(
                userID: userID, supplementName: name,
                doseAmount: dose, doseUnit: unit,
                frequencyDays: 1, isActive: true,
                isSampleData: true
            ))
        }

        // ── Check-ins ─────────────────────────────────────────────────────────
        // Weight trending from 185 lbs (83.91 kg) → 183 lbs (83.00 kg)
        let startKg = 185.0 * 0.453592
        let endKg   = 183.0 * 0.453592

        for d in 0..<config.daysOfHistory {
            let daysAgo = (config.daysOfHistory - 1) - d
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            var rng = Seeded(seed: d * 131 + 7919)

            // Mild weekly rhythm: slightly better scores Wed–Fri
            let weekday    = cal.component(.weekday, from: date)      // 1=Sun … 7=Sat
            let midWeek    = weekday >= 4 && weekday <= 6
            let weekBoost  = midWeek ? 0.35 : 0.0

            let energy  = scoreWithNoise(3.6 + weekBoost, rng: &rng)
            let mood    = scoreWithNoise(3.7 + weekBoost, rng: &rng)
            let libido  = scoreWithNoise(3.3 + weekBoost * 0.5, rng: &rng)
            let clarity = scoreWithNoise(3.8 + weekBoost, rng: &rng)
            let sleepQ  = scoreWithNoise(3.6,             rng: &rng)
            let sleepHrs = (7.2 + rng.uniform(in: -0.8...0.8)).clamped(to: 5.0...9.5)
            let hrv      = (52.0 + rng.uniform(in: -8...8)).clamped(to: 35...70)
            let steps    = Int((8500 + rng.uniform(in: -2000...2500)).clamped(to: 4000...14000))

            // Body weight trending down with small daily noise
            let progress = config.daysOfHistory > 1
                ? Double(d) / Double(config.daysOfHistory - 1) : 0
            let weightKg = startKg + (endKg - startKg) * progress
                         + rng.uniform(in: -0.25...0.25)

            let mw      = rng.bool(probability: sleepHrs < 6.5 ? 0.42 : 0.60)
            let workout = rng.bool(probability: 0.55)

            context.insert(SDCheckin(
                userID: userID, date: date,
                energyScore: energy, moodScore: mood, libidoScore: libido,
                sleepQualityScore: sleepQ, morningWoodScore: mw ? 5 : 1,
                mentalClarityScore: clarity,
                morningWood: mw, workoutToday: workout,
                bodyWeightKg: weightKg,
                sleepHours: sleepHrs,
                hrv: hrv,
                stepCount: steps,
                isSampleData: true
            ))
        }
    }

    // MARK: - Helpers

    /// Add noise ±0.5, clamp to 1–5, round to nearest integer value.
    private static func scoreWithNoise(_ base: Double, rng: inout Seeded) -> Double {
        round((base + rng.uniform(in: -0.5...0.5)).clamped(to: 1...5))
    }

    private static func shortName(_ compound: String) -> String {
        switch compound {
        case "Testosterone Cypionate":   return "Test Cyp"
        case "Testosterone Enanthate":   return "Test Enth"
        case "Testosterone Propionate":  return "Test Prop"
        case "Testosterone Undecanoate": return "Test Undec"
        default: return "Test"
        }
    }

    private static func compoundHex(_ compound: String) -> String {
        switch compound {
        case "Testosterone Enanthate":   return "#27AE60"
        case "Testosterone Propionate":  return "#F39C12"
        case "Testosterone Undecanoate": return "#9B59B6"
        default: return "#E94560"
        }
    }
}

// MARK: - Seeded PRNG (xorshift32 — deterministic, same data on every generate)

private struct Seeded {
    private var s: UInt32

    init(seed: Int) {
        let raw = UInt32(truncatingIfNeeded: abs(seed) + 1)
        s = raw == 0 ? 2463534242 : raw
    }

    mutating func next() -> Double {
        s ^= s << 13
        s ^= s >> 17
        s ^= s << 5
        return Double(s) / Double(UInt32.max)
    }

    mutating func uniform(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }

    mutating func bool(probability p: Double) -> Bool { next() < p }
}
