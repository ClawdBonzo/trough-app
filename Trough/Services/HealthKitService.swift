import Foundation
import HealthKit

// MARK: - HealthKitService

/// Singleton HealthKit gateway.
/// All reads/writes go through this service — never instantiate HKHealthStore elsewhere.
/// IMPORTANT: Real HealthKit queries only run on device. Simulator returns mock data.
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private(set) var isAuthorized = false

    private init() {}

    // MARK: - Authorization

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let ids: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .stepCount,
            .activeEnergyBurned,
            .bodyMass,
        ]
        ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
            .forEach { types.insert($0) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        if let bw = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(bw) }
        return types
    }()

    /// Request read + write permissions. Safe to call multiple times.
    func requestPermissions() async throws {
#if targetEnvironment(simulator)
        isAuthorized = true
        return
#endif
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        isAuthorized = true
    }

    /// Authorization status for the share (write) side — used for denied detection.
    var authorizationStatus: HKAuthorizationStatus {
#if targetEnvironment(simulator)
        return .sharingAuthorized
#endif
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return .notDetermined
        }
        return store.authorizationStatus(for: type)
    }

    // MARK: - Reads

    /// Morning HRV (average SDNN from midnight → noon today), in milliseconds.
    func fetchTodayHRV() async -> Double? {
#if targetEnvironment(simulator)
        return 45.0
#endif
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        let start = Calendar.current.startOfDay(for: .now)
        let end   = Calendar.current.date(byAdding: .hour, value: 12, to: start) ?? .now
        return await statisticsQuery(type: type, options: .discreteAverage, start: start, end: end)
    }

    /// Last night's sleep: sum of Core + Deep + REM stages in hours.
    func fetchLastNightSleep() async -> Double? {
#if targetEnvironment(simulator)
        return 7.2
#endif
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        // Window: yesterday 8 PM → today 11 AM
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let windowStart = cal.date(byAdding: .hour, value: -16, to: todayStart) ?? todayStart
        let windowEnd   = cal.date(byAdding: .hour, value: 11, to: todayStart) ?? .now

        return await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd)
            let q = HKSampleQuery(
                sampleType: type, predicate: pred,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let secs = (samples as? [HKCategorySample] ?? [])
                    .filter {
                        $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: secs > 0 ? secs / 3600.0 : nil)
            }
            store.execute(q)
        }
    }

    /// Total step count for today.
    func fetchTodaySteps() async -> Int? {
#if targetEnvironment(simulator)
        return 8500
#endif
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let start = Calendar.current.startOfDay(for: .now)
        let val = await statisticsQuery(type: type, options: .cumulativeSum, start: start, end: .now)
        return val.map { Int($0) }
    }

    /// Most recent resting heart rate sample, in bpm.
    func fetchRestingHR() async -> Int? {
#if targetEnvironment(simulator)
        return 62
#endif
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let val = await latestSample(type: type, unit: .count().unitDivided(by: .minute()))
        return val.map { Int($0.rounded()) }
    }

    /// Latest body weight in kg.
    func latestBodyWeightKg() async throws -> Double? {
#if targetEnvironment(simulator)
        return nil  // Don't override user-entered weight on simulator
#endif
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await latestSample(type: type, unit: .gramUnit(with: .kilo))
    }

    // MARK: - Auto-populate

    /// Fetches HRV, sleep, steps, and resting HR in parallel and writes them onto the checkin.
    /// Only fills fields that are currently nil — never overwrites user-entered data.
    /// Called from CompletionView immediately after the checkin is saved.
    func autoPopulateCheckin(_ checkin: SDCheckin) async {
        async let hrv    = fetchTodayHRV()
        async let sleep  = fetchLastNightSleep()
        async let steps  = fetchTodaySteps()
        async let hr     = fetchRestingHR()

        let (hrvVal, sleepVal, stepsVal, hrVal) = await (hrv, sleep, steps, hr)

        if checkin.hrv == nil, let v = hrvVal       { checkin.hrv       = v }
        if checkin.sleepHours == nil, let v = sleepVal { checkin.sleepHours = v }
        if checkin.stepCount == nil, let v = stepsVal  { checkin.stepCount  = v }
        if checkin.restingHR == nil, let v = hrVal  { checkin.restingHR  = Double(v) }
    }

    // MARK: - Writes

    func writeBodyWeight(kg: Double, date: Date = .now) async throws {
#if targetEnvironment(simulator)
        return
#endif
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample   = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    // MARK: - Private helpers

    private func statisticsQuery(
        type: HKQuantityType,
        options: HKStatisticsOptions,
        start: Date,
        end: Date
    ) async -> Double? {
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: options
            ) { _, stats, _ in
                let unit: HKUnit = options == .cumulativeSum ? .count() : .secondUnit(with: .milli)
                let val: Double?
                if options.contains(.cumulativeSum) {
                    val = stats?.sumQuantity()?.doubleValue(for: unit)
                } else {
                    // For HRV, unit is ms; for HR it's count/min
                    let hkUnit: HKUnit = type.identifier == HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue
                        ? .secondUnit(with: .milli)
                        : .count().unitDivided(by: .minute())
                    val = stats?.averageQuantity()?.doubleValue(for: hkUnit)
                }
                cont.resume(returning: val)
            }
            store.execute(q)
        }
    }

    private func latestSample(type: HKQuantityType, unit: HKUnit) async -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                cont.resume(returning: val)
            }
            store.execute(q)
        }
    }
}
