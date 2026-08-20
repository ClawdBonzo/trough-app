import XCTest
import SwiftData
@testable import Trough

// MARK: - Shared helpers

/// Mirrors TroughApp's container construction (Schema from TroughSchemaV1.models),
/// but stored in memory only.
private func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema(TroughSchemaV1.models),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

// MARK: - Protocol Score

final class ProtocolScoreTests: XCTestCase {

    func testAllOnesScoresZero() {
        let checkin = SDCheckin(
            userID: UUID(),
            energyScore: 1, moodScore: 1, libidoScore: 1,
            sleepQualityScore: 1, morningWoodScore: 1, mentalClarityScore: 1
        )
        XCTAssertEqual(checkin.protocolScore, 0.0, accuracy: 0.001)
    }

    func testAllFivesScoresHundred() {
        let checkin = SDCheckin(
            userID: UUID(),
            energyScore: 5, moodScore: 5, libidoScore: 5,
            sleepQualityScore: 5, morningWoodScore: 5, mentalClarityScore: 5
        )
        XCTAssertEqual(checkin.protocolScore, 100.0, accuracy: 0.001)
    }

    func testMixedWeightedScore() {
        // Current weights: energy .25, mood .20, libido .20, sleep .20, clarity .15
        // raw = 5*0.25 + 4*0.20 + 3*0.20 + 4*0.20 + 2*0.15
        //     = 1.25 + 0.80 + 0.60 + 0.80 + 0.30 = 3.75
        // score = ((3.75 - 1) / 4) * 100 = 68.75
        let checkin = SDCheckin(
            userID: UUID(),
            energyScore: 5, moodScore: 4, libidoScore: 3,
            sleepQualityScore: 4, morningWoodScore: 1, mentalClarityScore: 2
        )
        XCTAssertEqual(checkin.protocolScore, 68.75, accuracy: 0.001)
    }

    func testMorningWoodScoreDoesNotAffectScore() {
        // morningWoodScore is kept for migration compat only; mentalClarity replaced it.
        let a = SDCheckin(userID: UUID(), morningWoodScore: 1)
        let b = SDCheckin(userID: UUID(), morningWoodScore: 5)
        XCTAssertEqual(a.protocolScore, b.protocolScore, accuracy: 0.0001)
    }

    func testScoreClampBounds() {
        // Raw weighted average is 1–5 by construction, but the formula clamps anyway.
        XCTAssertEqual(Double.protocolScore(from: 0.5), 0.0)
        XCTAssertEqual(Double.protocolScore(from: 6.0), 100.0)
        XCTAssertEqual(Double.protocolScore(from: 3.0), 50.0, accuracy: 0.001)
    }
}

// MARK: - Gamification levels

final class GamificationLevelTests: XCTestCase {

    func testThresholdTable() {
        XCTAssertEqual(SDGamificationState.xpThresholds,
                       [0, 50, 120, 220, 360, 550, 800, 1120, 1520, 2000, 2600])
    }

    func testEveryThresholdMapsToItsLevel() {
        for (index, threshold) in SDGamificationState.xpThresholds.enumerated() {
            XCTAssertEqual(SDGamificationState.level(forXP: threshold), index + 1,
                           "XP \(threshold) should be exactly level \(index + 1)")
        }
    }

    func testBoundaryValues() {
        XCTAssertEqual(SDGamificationState.level(forXP: 0), 1)
        XCTAssertEqual(SDGamificationState.level(forXP: 49), 1)
        XCTAssertEqual(SDGamificationState.level(forXP: 50), 2)
        XCTAssertEqual(SDGamificationState.level(forXP: 119), 2)
        XCTAssertEqual(SDGamificationState.level(forXP: 120), 3)
        XCTAssertEqual(SDGamificationState.level(forXP: 2599), 10)
        XCTAssertEqual(SDGamificationState.level(forXP: 2600), 11)
        XCTAssertEqual(SDGamificationState.level(forXP: 1_000_000), 11, "Level caps at 11")
    }

    func testDerivedLevelUsesXPNotStoredCopy() {
        let state = SDGamificationState(userID: UUID(), currentXP: 360, currentLevel: 1)
        XCTAssertEqual(state.derivedLevel, 5, "derivedLevel must ignore the stale stored currentLevel")
    }
}

// MARK: - PK Curve Engine

final class PKCurveEngineTests: XCTestCase {

    private func maxLevel(_ data: PKCurveData) -> Double {
        data.combinedPoints.map(\.level).max() ?? 0
    }

    func testSingleDoseBatemanShape() {
        // One dose injected "now". Frequency 70d pushes the projected next dose
        // far out so the window (0, 70) is a pure single-dose curve.
        let proto = PKProtocolInput(
            compoundName: "Testosterone Cypionate", doseAmountMg: 100,
            frequencyDays: 70, colorHex: "#FFFFFF",
            customHalfLife: nil, route: "intramuscular"
        )
        let inj = PKInjectionInput(
            compoundName: "Testosterone Cypionate", doseAmountMg: 100,
            injectedAt: Date.now, route: "intramuscular"
        )
        let data = PKCurveEngine.shared.computeMultiCompoundCurve(
            protocols: [proto], injections: [inj],
            includeAbsorptionDelay: true, resolution: 300
        )

        // Zero before the dose (absorption hasn't started).
        let before = data.combinedPoints.filter { $0.time < -0.5 }
        XCTAssertFalse(before.isEmpty)
        XCTAssertTrue(before.allSatisfy { $0.level == 0 },
                      "Levels before the injection must be exactly 0")

        // Positive shortly after the dose.
        let early = data.combinedPoints.first { $0.time > 0.5 && $0.time < 3 }
        XCTAssertNotNil(early)
        XCTAssertGreaterThan(early!.level, 0)

        // Decays toward 0 long after the dose (before the next projected dose at t=70).
        let peak = maxLevel(data)
        XCTAssertGreaterThan(peak, 0)
        let tail = data.combinedPoints.last { $0.time > 60 && $0.time < 69 }
        XCTAssertNotNil(tail)
        XCTAssertLessThan(tail!.level, peak * 0.05,
                          "60+ days (7.5 half-lives) after a dose the level should be near 0")
    }

    func testKaEqualsKeLimitContinuity() {
        // IM route uses ka = 1.5/day. Choose half-lives so ke == ka (limit branch)
        // vs ke = ka - 0.0012 (general Bateman branch, just outside the guard).
        let ka = 1.5
        let hlAtKa = log(2.0) / ka                    // ke == ka exactly
        let hlNear = log(2.0) / (ka - 0.0012)          // ke = ka - 0.0012

        let injectedAt = Date.now
        func run(halfLife: Double) -> Double {
            let proto = PKProtocolInput(
                compoundName: "Test Limit Compound", doseAmountMg: 100,
                frequencyDays: 7, colorHex: "#FFFFFF",
                customHalfLife: halfLife, route: "intramuscular"
            )
            let inj = PKInjectionInput(
                compoundName: "Test Limit Compound", doseAmountMg: 100,
                injectedAt: injectedAt, route: "intramuscular"
            )
            let data = PKCurveEngine.shared.computeMultiCompoundCurve(
                protocols: [proto], injections: [inj],
                includeAbsorptionDelay: true, resolution: 500
            )
            return maxLevel(data)
        }

        let peakLimit = run(halfLife: hlAtKa)
        let peakNear  = run(halfLife: hlNear)
        XCTAssertGreaterThan(peakLimit, 0)
        XCTAssertEqual(peakNear / peakLimit, 1.0, accuracy: 0.015,
                       "Curve must be continuous across the ka≈ke limit switch (within ~1%)")
    }

    func testLooselyNamedInjectionIsNotDoubleCounted() {
        // One injection named just "Testosterone" with BOTH Cypionate and
        // Enanthate protocols active: the dose must be attributed to exactly
        // one protocol, so the total equals the single-protocol result.
        let injectedAt = Date.now
        let cyp = PKProtocolInput(
            compoundName: "Testosterone Cypionate", doseAmountMg: 100,
            frequencyDays: 7, colorHex: "#FFFFFF", customHalfLife: nil, route: "intramuscular"
        )
        let enth = PKProtocolInput(
            compoundName: "Testosterone Enanthate", doseAmountMg: 100,
            frequencyDays: 7, colorHex: "#FFFFFF", customHalfLife: nil, route: "intramuscular"
        )
        let inj = PKInjectionInput(
            compoundName: "Testosterone", doseAmountMg: 100,
            injectedAt: injectedAt, route: "intramuscular"
        )

        let both = PKCurveEngine.shared.computeMultiCompoundCurve(
            protocols: [cyp, enth], injections: [inj],
            includeAbsorptionDelay: true, resolution: 300
        )
        let single = PKCurveEngine.shared.computeMultiCompoundCurve(
            protocols: [cyp], injections: [inj],
            includeAbsorptionDelay: true, resolution: 300
        )

        let peakBoth = maxLevel(both)
        let peakSingle = maxLevel(single)
        XCTAssertGreaterThan(peakSingle, 0)
        XCTAssertEqual(peakBoth / peakSingle, 1.0, accuracy: 0.01,
                       "Total with two matching protocols must equal the single-protocol total, not 2x")

        // Exactly one compound curve got the dose; the other stays flat at zero.
        let flatCurves = both.curves.filter { curve in curve.points.allSatisfy { $0.level == 0 } }
        XCTAssertEqual(flatCurves.count, 1,
                       "The unassigned protocol's curve must be all zeros")
    }
}

// MARK: - Injection Cycle Service

final class InjectionCycleServiceTests: XCTestCase {

    func testInjectTodayIsDayOne() {
        let info = InjectionCycleService.cycleDay(lastInjectionDate: Date.now, frequencyDays: 7)
        XCTAssertEqual(info.day, 1)
        XCTAssertEqual(info.totalDays, 7)
        XCTAssertTrue(info.isInjectionDay)
        XCTAssertEqual(info.daysUntilNext, 7, "E7D: inject today -> next dose a full cycle away")
    }

    func testDayBeforeDue() {
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date.now)!
        let info = InjectionCycleService.cycleDay(lastInjectionDate: sixDaysAgo, frequencyDays: 7)
        XCTAssertEqual(info.day, 7)
        XCTAssertFalse(info.isInjectionDay)
        XCTAssertEqual(info.daysUntilNext, 1)
    }

    func testCycleWrapsOnDueDay() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date.now)!
        let info = InjectionCycleService.cycleDay(lastInjectionDate: sevenDaysAgo, frequencyDays: 7)
        XCTAssertEqual(info.day, 1, "daysSince % freq == 0 -> back to day 1 (due day)")
        XCTAssertTrue(info.isInjectionDay)
    }

    func testCompoundMatchingIsCaseInsensitive() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let userID = UUID()
        let threeDaysAgo = Date.now.addingTimeInterval(-3 * 86400)
        let inj = SDInjection(
            userID: userID,
            injectedAt: threeDaysAgo,
            compoundName: "  testosterone cypionate ",   // lowercase + stray whitespace
            doseAmountMg: 100, volumeMl: 0.5
        )
        ctx.insert(inj)

        let days = InjectionCycleService.daysSinceLastInjection(
            injections: [inj], compound: "Testosterone Cypionate"
        )
        XCTAssertEqual(days, 3.0, accuracy: 0.01,
                       "Compound matching must be case-insensitive and whitespace-trimmed")
    }

    func testNoMatchingCompoundReturnsZero() {
        let days = InjectionCycleService.daysSinceLastInjection(injections: [], compound: "HCG")
        XCTAssertEqual(days, 0)
    }

    func testNextInjectionDateE7DProjection() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let userID = UUID()

        let proto = SDProtocol(
            userID: userID, name: "Test Cyp 100mg E7D",
            compoundName: "Testosterone Cypionate",
            doseAmountMg: 100, frequencyDays: 7, concentrationMgPerMl: 200
        )
        let lastShot = Calendar.current.date(byAdding: .day, value: -2, to: Date.now)!
        let inj = SDInjection(
            userID: userID, injectedAt: lastShot,
            compoundName: "testosterone cypionate",     // case differs from protocol
            doseAmountMg: 100, volumeMl: 0.5
        )
        ctx.insert(proto)
        ctx.insert(inj)

        let next = InjectionCycleService.nextInjectionDate(for: proto, injections: [inj])
        let expected = Calendar.current.date(byAdding: .day, value: 7, to: lastShot)!
        XCTAssertEqual(next.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
    }
}

// MARK: - CSV Import

final class CSVImportServiceTests: XCTestCase {

    // MARK: Numeric normalization

    func testCommaDecimalNormalization() {
        XCTAssertEqual(CSVImportService.normalizeDecimalSeparators("4,5"), "4.5")
        XCTAssertEqual(CSVImportService.normalizeDecimalSeparators("1,234.5"), "1234.5",
                       "With a dot present, commas are thousands separators")
        XCTAssertEqual(CSVImportService.extractNumeric("4,5"), 4.5)
        XCTAssertEqual(CSVImportService.extractNumeric("82,5"), 82.5)
        XCTAssertEqual(CSVImportService.extractNumeric("1,234.5"), 1234.5)
        XCTAssertEqual(CSVImportService.extractNumeric("-2.5"), -2.5, "Sign must be preserved")
        XCTAssertEqual(CSVImportService.extractNumeric("350 ng/dL"), 350)
        XCTAssertEqual(CSVImportService.extractNumeric("12.5%"), 12.5)
        XCTAssertNil(CSVImportService.extractNumeric("n/a"))
    }

    // MARK: Date format detection

    func testUnambiguousISODateDetected() {
        // NOTE: modern ICU leniently parses "2026-01-05" with BOTH "yyyy-MM-dd"
        // and "yyyy/MM/dd", and detectDateFormat breaks the tie via Dictionary
        // iteration order (scores.max), so the exact format string returned is
        // nondeterministic between the two. Both parse identically, so the
        // meaningful contract is: unambiguous ISO-style samples are .detected
        // (never .ambiguous/.unknown) and the chosen format parses them to the
        // right calendar day.
        let result = CSVImportService.detectDateFormat(samples: ["2026-01-05", "2026-01-06", "2026-02-11"])
        guard case .detected(let fmt) = result else {
            return XCTFail("Expected .detected for ISO dates, got \(result)")
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = fmt
        guard let parsed = f.date(from: "2026-01-05") else {
            return XCTFail("Detected format '\(fmt)' cannot parse the samples")
        }
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: parsed)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 1)
        XCTAssertEqual(comps.day, 5, "Detected format must read year-month-day order")
    }

    func testSlashDatesWithLowDayAreAmbiguous() {
        let result = CSVImportService.detectDateFormat(samples: ["01/02/2026", "03/04/2026"])
        guard case .ambiguous = result else {
            return XCTFail("Expected .ambiguous for dates valid as both MM/dd and dd/MM, got \(result)")
        }
    }

    // MARK: Column auto-detection

    /// REAL BUG (documented, not papered over): CSVImportService.detectColumns
    /// walks its alias definitions in a fixed order and lets an EARLIER def
    /// claim a header via fuzzy matching before a LATER def gets to exact-match
    /// it. Header "e2" is an exact alias of the bloodwork "e2" def, but the
    /// check-in "sleep" def runs first and fuzzy-claims it through its 2-char
    /// alias "sq" (Levenshtein("e2","sq") = 2 <= 2 -> score 0.6). The estradiol
    /// column of a bloodwork CSV is therefore auto-mapped to the check-in sleep
    /// field and silently dropped by importBloodwork. Fix direction: exact alias
    /// matches should be resolved globally (all defs) before any fuzzy pass.
    func testExactAliasLosesToEarlierFuzzyMatch_knownBug() {
        let mapping = CSVImportService.detectColumns(headers: ["date", "totalt", "e2"])
        XCTAssertEqual(mapping["date"], 0)
        XCTAssertEqual(mapping["totalt"], 1)
        XCTExpectFailure("Known bug: 'sleep' def fuzzy-steals the 'e2' header via alias 'sq' before the exact 'e2' alias is considered") {
            XCTAssertEqual(mapping["e2"], 2, "'e2' is an exact alias and must map to the e2 field")
            XCTAssertNil(mapping["sleep"], "A bloodwork header must not map to a check-in score field")
        }
    }

    // MARK: End-to-end check-in import + duplicate skip

    func testCheckinImportParsesValuesAndSkipsDuplicatesOnReimport() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let userID = UUID()

        let headers = ["date", "energy", "mood", "libido", "sleep", "clarity", "weight"]
        let data = CSVParseResult(
            headers: headers,
            rows: [
                ["2026-01-05", "4,5", "4", "3", "4", "5", "82,5"],  // comma decimals
                ["2026-01-06", "2",   "3", "3", "3", "3", ""],
            ],
            delimiter: ","
        )
        let mapping = CSVImportService.detectColumns(headers: headers)
        XCTAssertNotNil(mapping["date"])
        XCTAssertNotNil(mapping["energy"])
        XCTAssertNotNil(mapping["bodyweight"])

        let first = await CSVImportService.importCheckins(
            data: data, mapping: mapping, dateFormat: "yyyy-MM-dd",
            userID: userID, context: ctx
        )
        XCTAssertEqual(first.importedCount, 2)
        XCTAssertEqual(first.skippedCount, 0)

        let checkins = try ctx.fetch(FetchDescriptor<SDCheckin>())
        XCTAssertEqual(checkins.count, 2)
        let row1 = checkins.min(by: { $0.date < $1.date })!
        XCTAssertEqual(row1.energyScore, 4.5, accuracy: 0.001, "\"4,5\" must parse as 4.5")
        XCTAssertEqual(row1.bodyWeightKg ?? -1, 82.5, accuracy: 0.001, "\"82,5\" kg weight")
        XCTAssertEqual(row1.mentalClarityScore, 5, accuracy: 0.001)

        // Re-import the identical CSV: every row is a duplicate date -> skipped.
        let second = await CSVImportService.importCheckins(
            data: data, mapping: mapping, dateFormat: "yyyy-MM-dd",
            userID: userID, context: ctx
        )
        XCTAssertEqual(second.importedCount, 0)
        XCTAssertEqual(second.skippedCount, 2)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SDCheckin>()).count, 2,
                       "Row count must be unchanged after re-import")
    }

    // MARK: End-to-end bloodwork import + duplicate skip

    func testBloodworkImportSkipsDuplicateDrawDates() async throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let userID = UUID()

        let headers = ["date", "totalt", "e2"]
        let data = CSVParseResult(
            headers: headers,
            rows: [["2026-02-01", "850 ng/dL", "25"]],
            delimiter: ","
        )
        // Explicit mapping: auto-detection has a known fuzzy-steal bug for
        // short headers like "e2" (see testExactAliasLosesToEarlierFuzzyMatch).
        var mapping = ColumnMapping()
        mapping["date"] = 0
        mapping["totalt"] = 1
        mapping["e2"] = 2

        let first = await CSVImportService.importBloodwork(
            data: data, mapping: mapping, dateFormat: "yyyy-MM-dd",
            userID: userID, context: ctx
        )
        XCTAssertEqual(first.importedCount, 1)

        let draws = try ctx.fetch(FetchDescriptor<SDBloodwork>())
        XCTAssertEqual(draws.count, 1)
        XCTAssertEqual(draws[0].markers.count, 2)
        let tt = draws[0].markers.first { $0.markerName == "Total Testosterone" }
        XCTAssertEqual(tt?.value ?? -1, 850, accuracy: 0.001, "Unit suffix must be stripped")

        let second = await CSVImportService.importBloodwork(
            data: data, mapping: mapping, dateFormat: "yyyy-MM-dd",
            userID: userID, context: ctx
        )
        XCTAssertEqual(second.importedCount, 0)
        XCTAssertEqual(second.skippedCount, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SDBloodwork>()).count, 1,
                       "Bloodwork count must be unchanged after re-import")
    }
}

// MARK: - Streaks

@MainActor
final class StreakTests: XCTestCase {

    private func makeVM() throws -> (GamificationViewModel, ModelContext, UUID) {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let userID = UUID()
        let vm = GamificationViewModel()
        return (vm, ctx, userID)
    }

    func testStreakContinuesFromYesterday() throws {
        let (vm, ctx, userID) = try makeVM()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!.startOfDay
        let streak = SDStreakState(
            userID: userID, streakType: "checkin",
            currentCount: 3, bestCount: 3, lastCompletedDate: yesterday, flameLevel: 2
        )
        ctx.insert(streak)
        try ctx.save()

        vm.setup(context: ctx, userID: userID)
        vm.updateStreak(type: "checkin")

        XCTAssertEqual(streak.currentCount, 4, "Yesterday -> today must increment the streak")
        XCTAssertEqual(streak.bestCount, 4)
        XCTAssertEqual(streak.lastCompletedDate, Date().startOfDay)

        // Second call on the same day is a no-op.
        vm.updateStreak(type: "checkin")
        XCTAssertEqual(streak.currentCount, 4, "Already counted today")
    }

    func testStreakResetsAfterGap() throws {
        let (vm, ctx, userID) = try makeVM()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!.startOfDay
        let streak = SDStreakState(
            userID: userID, streakType: "checkin",
            currentCount: 5, bestCount: 5, lastCompletedDate: threeDaysAgo, flameLevel: 2
        )
        ctx.insert(streak)
        try ctx.save()

        vm.setup(context: ctx, userID: userID)
        vm.updateStreak(type: "checkin")

        XCTAssertEqual(streak.currentCount, 1, "A missed day resets the streak")
        XCTAssertEqual(streak.flameLevel, 1)
        XCTAssertEqual(streak.bestCount, 5, "Personal best is preserved")
    }

    /// GamificationViewModel.updateStreak hard-codes `Date()` and
    /// `Calendar.current`, so the DST boundary itself cannot be driven
    /// end-to-end from a test (injectability gap). This test instead pins the
    /// exact calendar contract updateStreak relies on:
    /// `Calendar.date(byAdding: .day, value: 1, to: lastDay) == today`
    /// remains true across a DST fall-back even though the wall-clock gap is
    /// 25 hours — i.e. the implementation is DST-safe precisely because it
    /// uses calendar arithmetic and not `+86400` seconds.
    func testStreakDayArithmeticIsDSTSafe() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!

        // US fall-back: Sunday 2026-11-01 (clocks go 02:00 EDT -> 01:00 EST).
        let nov1 = cal.date(from: DateComponents(year: 2026, month: 11, day: 1))!  // startOfDay, EDT
        let nov2 = cal.date(from: DateComponents(year: 2026, month: 11, day: 2))!  // startOfDay, EST

        let added = cal.date(byAdding: .day, value: 1, to: nov1)
        XCTAssertEqual(added, nov2, "Calendar day arithmetic must land on the next startOfDay across DST")

        // The day is 25 wall-clock hours long — naive seconds arithmetic would break the streak.
        XCTAssertEqual(nov2.timeIntervalSince(nov1), 90_000, accuracy: 1)
        XCTAssertNotEqual(nov1.addingTimeInterval(86_400), nov2,
                          "+86400s does NOT reach the next calendar day across fall-back")
    }
}

// MARK: - Widget snapshot date scoping

final class WidgetSnapshotTests: XCTestCase {

    func testCheckedInTodayResolvesTrueSameDay() {
        let now = Date()
        var s = WidgetSnapshot()
        s.checkedInToday = true
        s.checkedInDate = now
        XCTAssertTrue(s.resolved(at: now).checkedInToday)
    }

    func testYesterdayStampResolvesFalseToday() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        var s = WidgetSnapshot()
        s.checkedInToday = true          // stale stored flag from yesterday
        s.checkedInDate = yesterday
        XCTAssertFalse(s.resolved(at: now).checkedInToday,
                       "The checkmark must clear after midnight")
    }

    func testLegacySnapshotFallsBackToUpdatedAt() {
        // Pre-1.2 builds wrote no checkedInDate; resolved() falls back to updatedAt.
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        var stale = WidgetSnapshot()
        stale.checkedInToday = true
        stale.updatedAt = yesterday
        XCTAssertFalse(stale.resolved(at: now).checkedInToday)

        var fresh = WidgetSnapshot()
        fresh.checkedInToday = true
        fresh.updatedAt = now
        XCTAssertTrue(fresh.resolved(at: now).checkedInToday)

        var noStamp = WidgetSnapshot()
        noStamp.checkedInToday = true    // no dates at all -> cannot verify -> false
        XCTAssertFalse(noStamp.resolved(at: now).checkedInToday)
    }

    func testInjectionCountdownDecrementsAcrossDayBoundary() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        // Next injection: 3 days out, mid-day.
        let next = cal.date(byAdding: .day, value: 3, to: todayStart)!.addingTimeInterval(12 * 3600)

        var s = WidgetSnapshot()
        s.daysUntilInjection = 99        // stale stored int must be overridden
        s.nextInjectionDate = next

        let today = todayStart.addingTimeInterval(3600)
        XCTAssertEqual(s.resolved(at: today).daysUntilInjection, 3)

        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!.addingTimeInterval(3600)
        XCTAssertEqual(s.resolved(at: tomorrow).daysUntilInjection, 2,
                       "Countdown must tick down across the day boundary without an app launch")

        let wayLater = cal.date(byAdding: .day, value: 10, to: todayStart)!
        XCTAssertEqual(s.resolved(at: wayLater).daysUntilInjection, 0,
                       "Overdue clamps at 0, never negative")
    }

    func testStoredIntKeptWhenNoNextInjectionDate() {
        var s = WidgetSnapshot()
        s.daysUntilInjection = 4         // legacy snapshot: int only
        XCTAssertEqual(s.resolved(at: Date()).daysUntilInjection, 4)
    }
}
