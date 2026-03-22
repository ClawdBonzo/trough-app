import Foundation

// MARK: - InjectionSite

struct InjectionSite: Hashable, Identifiable {
    let region: String
    let side: String

    var id: String { displayName }
    var displayName: String { "\(region) \(side)" }

    static let all: [InjectionSite] = [
        InjectionSite(region: "Glute",         side: "Left"),
        InjectionSite(region: "Glute",         side: "Right"),
        InjectionSite(region: "Quad",          side: "Left"),
        InjectionSite(region: "Quad",          side: "Right"),
        InjectionSite(region: "Delt",          side: "Left"),
        InjectionSite(region: "Delt",          side: "Right"),
        InjectionSite(region: "Ventro-Glute",  side: "Left"),
        InjectionSite(region: "Ventro-Glute",  side: "Right"),
        InjectionSite(region: "SubQ Abdomen",  side: "Left"),
        InjectionSite(region: "SubQ Abdomen",  side: "Right"),
    ]
}

// MARK: - InjectionCycleService

/// Stateless service. All methods derive values from inputs — never stored.
enum InjectionCycleService {

    // MARK: - CycleInfo

    struct CycleInfo {
        let day: Int
        let totalDays: Int
        var isInjectionDay: Bool { day == totalDays || day == 1 }
        var daysUntilNext: Int { max(0, totalDays - day) }
        var progressFraction: Double { Double(day) / Double(max(1, totalDays)) }
    }

    static func cycleDay(lastInjectionDate: Date, frequencyDays: Int) -> CycleInfo {
        let freq = max(1, frequencyDays)
        let daysSince = max(0, Date.now.daysSince(lastInjectionDate))
        let cycleDay = (daysSince % freq) + 1
        return CycleInfo(day: min(cycleDay, freq), totalDays: freq)
    }

    // MARK: - New methods

    /// Days since the most recent injection, optionally filtered by compound name.
    static func daysSinceLastInjection(
        injections: [SDInjection],
        compound: String? = nil
    ) -> Double {
        let filtered = compound.map { c in injections.filter { $0.compoundName == c } } ?? injections
        guard let latest = filtered.map(\.injectedAt).max() else { return 0 }
        return Date.now.timeIntervalSince(latest) / 86400
    }

    /// Next scheduled injection date based on protocol frequency.
    static func nextInjectionDate(for proto: SDProtocol, injections: [SDInjection]) -> Date {
        let matching = injections.filter {
            $0.compoundName.lowercased() == proto.compoundName.lowercased()
        }
        guard let lastDate = matching.map(\.injectedAt).max() else {
            return Date.now
        }
        // If weekday schedule, find the next weekday from now
        let weekdays = proto.weekdaysString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if !weekdays.isEmpty {
            return nextWeekdayDate(after: lastDate, weekdays: weekdays)
        }
        return Calendar.current.date(
            byAdding: .day, value: proto.frequencyDays, to: lastDate
        ) ?? lastDate
    }

    /// 0.0 = just injected, 1.0 = due now (or overdue).
    static func cycleProgress(for proto: SDProtocol, injections: [SDInjection]) -> Double {
        let days = daysSinceLastInjection(injections: injections, compound: proto.compoundName)
        return min(1.0, days / Double(max(1, proto.frequencyDays)))
    }

    /// True if the next injection date is today or overdue.
    static func isInjectionDueToday(for proto: SDProtocol, injections: [SDInjection]) -> Bool {
        let next = nextInjectionDate(for: proto, injections: injections)
        return next.startOfDay <= Date.now.startOfDay
    }

    // MARK: - Site Rotation

    /// Returns the injection site that has been rested the longest.
    /// Pure function — no SwiftData calls. Pass in last 30 days of injections.
    static func siteRotationSuggestion(recentInjections: [SDInjection]) -> InjectionSite {
        let defaultSite = InjectionSite(region: "Glute", side: "Left")
        guard !recentInjections.isEmpty else { return defaultSite }

        let now = Date.now
        var lastUsed: [String: Date] = [:]
        for inj in recentInjections {
            guard let site = inj.injectionSite else { continue }
            if let existing = lastUsed[site] {
                if inj.injectedAt > existing { lastUsed[site] = inj.injectedAt }
            } else {
                lastUsed[site] = inj.injectedAt
            }
        }

        // Sort: never-used first, then by most-rested (days desc), then alphabetically
        let sorted = InjectionSite.all.sorted { a, b in
            switch (lastUsed[a.displayName], lastUsed[b.displayName]) {
            case (nil, nil): return a.displayName < b.displayName
            case (nil, _):   return true
            case (_, nil):   return false
            case let (da?, db?):
                let daysA = now.timeIntervalSince(da)
                let daysB = now.timeIntervalSince(db)
                return daysA > daysB
            }
        }
        return sorted.first ?? defaultSite
    }

    /// Days since a specific site was last used. Returns nil if never used.
    static func daysSinceLastUse(
        site: InjectionSite,
        recentInjections: [SDInjection]
    ) -> Int? {
        let matching = recentInjections.filter { $0.injectionSite == site.displayName }
        guard let latest = matching.map(\.injectedAt).max() else { return nil }
        return Date.now.daysSince(latest)
    }

    // MARK: - Private

    private static func nextWeekdayDate(after date: Date, weekdays: [Int]) -> Date {
        let cal = Calendar.current
        var candidate = cal.date(byAdding: .day, value: 1, to: date.startOfDay) ?? date
        for _ in 0..<14 {
            let wd = cal.component(.weekday, from: candidate)
            if weekdays.contains(wd) { return candidate }
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}
