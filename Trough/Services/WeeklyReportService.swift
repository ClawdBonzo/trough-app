import Foundation
import SwiftData
import UserNotifications

// MARK: - WeeklyReport

struct WeeklyReport {
    let weekStart: Date
    let weekEnd: Date
    // This week
    let protocolScore: Double
    let scoreChange: Double        // positive = improved vs prior week
    let avgEnergy: Double
    let avgMood: Double
    let avgLibido: Double
    let avgSleep: Double
    let avgClarity: Double
    let morningWoodPct: Double     // 0–100
    let workoutCompletionPct: Double
    let avgHRV: Double?
    let avgSleepHours: Double?
    let totalInjections: Int
    let topInsight: InsightResult?
    let streakLength: Int
    // Prior week (for comparison bars)
    let priorProtocolScore: Double
    let priorAvgEnergy: Double
    let priorAvgMood: Double
    let priorAvgLibido: Double
    let priorAvgSleep: Double
    let priorAvgClarity: Double
    let peptideSummary: String?    // e.g. "BPC-157 ×3, Semaglutide ×1" or nil
}

// MARK: - WeeklyReportService

enum WeeklyReportService {

    /// True when there are 7+ consecutive check-in days ending today (or yesterday).
    static func canGenerateReport(context: ModelContext) -> Bool {
        let pred = #Predicate<SDCheckin> { !$0.isSampleData }
        let desc = FetchDescriptor<SDCheckin>(
            predicate: pred,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let checkins = (try? context.fetch(desc)) ?? []
        let dates = Set(checkins.map(\.date))

        var count = 0
        var d = Date.now.startOfDay
        if !dates.contains(d) {
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }
        while dates.contains(d) && count < 7 {
            count += 1
            d = Calendar.current.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return count >= 7
    }

    /// Generates a 7-day report ending on `weekEnd`. Returns nil if not enough data.
    static func generateReport(
        weekEnding weekEnd: Date,
        context: ModelContext,
        userType: String
    ) -> WeeklyReport? {
        let cal = Calendar.current
        let weekStart  = cal.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
        let priorEnd   = cal.date(byAdding: .day, value: -7, to: weekEnd) ?? weekEnd
        let priorStart = cal.date(byAdding: .day, value: -6, to: priorEnd) ?? priorEnd

        let pred = #Predicate<SDCheckin> { !$0.isSampleData }
        let desc = FetchDescriptor<SDCheckin>(
            predicate: pred,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = (try? context.fetch(desc)) ?? []

        let thisWeek  = all.filter { $0.date >= weekStart  && $0.date <= weekEnd }
        let priorWeek = all.filter { $0.date >= priorStart && $0.date <= priorEnd }

        guard !thisWeek.isEmpty else { return nil }

        // Injections this week
        let injPred = #Predicate<SDInjection> { !$0.isSampleData }
        let allInjs = (try? context.fetch(FetchDescriptor<SDInjection>(predicate: injPred))) ?? []
        let weekInjs = allInjs.filter { $0.injectedAt >= weekStart && $0.injectedAt <= weekEnd }

        // Streak from weekEnd backwards
        let dates = Set(all.map(\.date))
        var streak = 0
        var d = weekEnd
        while dates.contains(d) {
            streak += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }

        // Top insight from most recent check-in this week
        let protoPred = #Predicate<SDProtocol> { $0.isActive && $0.isPrimary && !$0.isSampleData }
        var protoDesc = FetchDescriptor<SDProtocol>(predicate: protoPred)
        protoDesc.fetchLimit = 1
        let activeProtocol = try? context.fetch(protoDesc).first

        let topInsight: InsightResult?
        if let latest = thisWeek.first {
            let ctx = InsightContext(
                recentCheckins: all,
                recentInjections: Array(allInjs.sorted { $0.injectedAt > $1.injectedAt }.prefix(30)),
                activeProtocol: activeProtocol,
                streak: streak
            )
            topInsight = InsightEngine.shared.generateInsight(
                for: latest, userType: userType, context: ctx
            )
        } else {
            topInsight = nil
        }

        // Helper
        func avg(_ kp: KeyPath<SDCheckin, Double>, in list: [SDCheckin]) -> Double {
            guard !list.isEmpty else { return 0 }
            return list.map { $0[keyPath: kp] }.reduce(0, +) / Double(list.count)
        }

        let mwThis = thisWeek.filter { $0.morningWood != nil }
        let mwPct  = mwThis.isEmpty ? 0.0
            : Double(mwThis.filter { $0.morningWood == true }.count) / Double(mwThis.count) * 100

        let woThis = thisWeek.filter { $0.workoutToday != nil }
        let woPct  = woThis.isEmpty ? 0.0
            : Double(woThis.filter { $0.workoutToday == true }.count) / Double(woThis.count) * 100

        let curScore = thisWeek.map(\.protocolScore).reduce(0, +) / Double(thisWeek.count)
        let prvScore = priorWeek.isEmpty ? 0 : priorWeek.map(\.protocolScore).reduce(0, +) / Double(priorWeek.count)

        let hrvValues = thisWeek.compactMap(\.hrv)
        let sleepValues = thisWeek.compactMap(\.sleepHours)

        // Peptide summary
        let peptPred = #Predicate<SDPeptideLog> { !$0.isSampleData }
        let allPepts = (try? context.fetch(FetchDescriptor<SDPeptideLog>(predicate: peptPred))) ?? []
        let weekPepts = allPepts.filter { $0.administeredAt >= weekStart && $0.administeredAt <= weekEnd }
        let peptideSummary: String? = weekPepts.isEmpty ? nil : Dictionary(grouping: weekPepts, by: \.peptideName)
            .sorted { $0.key < $1.key }
            .map { "\($0.key) ×\($0.value.count)" }
            .joined(separator: ", ")

        return WeeklyReport(
            weekStart: weekStart,
            weekEnd: weekEnd,
            protocolScore: curScore,
            scoreChange: prvScore > 0 ? curScore - prvScore : 0,
            avgEnergy:  avg(\.energyScore,       in: thisWeek),
            avgMood:    avg(\.moodScore,          in: thisWeek),
            avgLibido:  avg(\.libidoScore,        in: thisWeek),
            avgSleep:   avg(\.sleepQualityScore,  in: thisWeek),
            avgClarity: avg(\.mentalClarityScore, in: thisWeek),
            morningWoodPct: mwPct,
            workoutCompletionPct: woPct,
            avgHRV: hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count),
            avgSleepHours: sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count),
            totalInjections: weekInjs.count,
            topInsight: topInsight,
            streakLength: streak,
            priorProtocolScore: prvScore,
            priorAvgEnergy:  avg(\.energyScore,       in: priorWeek),
            priorAvgMood:    avg(\.moodScore,          in: priorWeek),
            priorAvgLibido:  avg(\.libidoScore,        in: priorWeek),
            priorAvgSleep:   avg(\.sleepQualityScore,  in: priorWeek),
            priorAvgClarity: avg(\.mentalClarityScore, in: priorWeek),
            peptideSummary: peptideSummary
        )
    }

    /// Schedules a local notification when the user hits day 7.
    /// `checkinCount` is the total number of check-ins logged so far.
    static func scheduleStreakDay7Notification(checkinCount: Int) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "You're on a roll"
        content.body = "You've logged \(checkinCount) check-ins — see your protocol score."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_day7_upsell",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}
