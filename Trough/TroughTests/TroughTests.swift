import XCTest
import SwiftData
@testable import Trough

final class TroughTests: XCTestCase {

    // MARK: - Protocol Score

    func testProtocolScoreMinimum() {
        let score = Double.protocolScore(from: 1.0)
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    func testProtocolScoreMaximum() {
        let score = Double.protocolScore(from: 5.0)
        XCTAssertEqual(score, 100.0, accuracy: 0.001)
    }

    func testProtocolScoreMidpoint() {
        let score = Double.protocolScore(from: 3.0)
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    func testProtocolScoreClampedBelow() {
        let score = Double.protocolScore(from: 0.5)
        XCTAssertEqual(score, 0.0)
    }

    func testCheckinWeightedScore() throws {
        let container = try ModelContainer(
            for: Schema(TroughSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        let userID = UUID()
        let checkin = SDCheckin(
            userID: userID,
            date: Date.now.startOfDay,
            energyScore: 5,
            moodScore: 4,
            libidoScore: 3,
            sleepQualityScore: 4,
            morningWoodScore: 2
        )
        ctx.insert(checkin)
        // weighted = 5*0.25 + 4*0.25 + 3*0.20 + 4*0.20 + 2*0.10 = 1.25+1.0+0.6+0.8+0.2 = 3.85
        let expected = Double.protocolScore(from: 3.85)
        XCTAssertEqual(checkin.protocolScore, expected, accuracy: 0.001)
    }

    // MARK: - Sample Data Filter

    func testSampleDataNotSynced() throws {
        let container = try ModelContainer(
            for: Schema(TroughSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        let userID = UUID()

        let sample = SDCheckin(userID: userID, isSampleData: true)
        let real   = SDCheckin(userID: userID, isSampleData: false)
        ctx.insert(sample)
        ctx.insert(real)

        let predicate = #Predicate<SDCheckin> { !$0.isSampleData }
        let results = try ctx.fetch(FetchDescriptor<SDCheckin>(predicate: predicate))
        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].isSampleData)
    }

    // MARK: - Date Helpers

    func testDaysSince() {
        let today = Date.now
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        XCTAssertEqual(today.daysSince(sevenDaysAgo), 7)
    }

    // MARK: - Bateman PK

    func testBatemanLevelAtZero() {
        let vm = DashboardViewModel(modelContext: ModelContext(try! ModelContainer(
            for: Schema(TroughSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
        let level = vm.batemanLevel(daysSinceInjection: 0, doseMg: 100, halfLifeDays: 8)
        XCTAssertEqual(level, 0.0, accuracy: 0.01)
    }

    func testBatemanLevelPositiveAfterDelay() {
        let vm = DashboardViewModel(modelContext: ModelContext(try! ModelContainer(
            for: Schema(TroughSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
        let level = vm.batemanLevel(daysSinceInjection: 1, doseMg: 100, halfLifeDays: 8)
        XCTAssertGreaterThan(level, 0)
    }

    func testBatemanDecaysTowardsZero() {
        let vm = DashboardViewModel(modelContext: ModelContext(try! ModelContainer(
            for: Schema(TroughSchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
        let peak   = vm.batemanLevel(daysSinceInjection: 2,  doseMg: 100, halfLifeDays: 8)
        let trough = vm.batemanLevel(daysSinceInjection: 56, doseMg: 100, halfLifeDays: 8)
        XCTAssertGreaterThan(peak, trough)
    }
}
