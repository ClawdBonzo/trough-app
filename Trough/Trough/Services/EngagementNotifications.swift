import Foundation
import SwiftData
import UserNotifications

/// Local-only engagement reminders. Each category owns ONE fixed identifier
/// and is always removed/replaced by that exact identifier — never
/// `removeAllPendingNotificationRequests()` — so reminders scheduled elsewhere
/// (see `ReminderID` in SettingsView) are never clobbered.
///
/// - "streak_at_risk" — 20:30 on the next day without a check-in, only while a
///   check-in streak is alive. Re-planned on every check-in and app open.
/// - "weekly_recap"   — Sunday 18:00, counts only ("5 check-ins this week ·
///   1 injection logged"). Never doses, compounds, lab values or scores.
enum EngagementNotifications {

    static let streakAtRiskID = "streak_at_risk"
    static let weeklyRecapID = "weekly_recap"

    static let streakHour = 20, streakMinute = 30
    static let recapWeekday = 1 /* Sunday (Gregorian) */, recapHour = 18

    struct Plan: Equatable {
        var streakFireDate: Date?
        var streakDays = 0
        var recapFireDate: Date?
        var recapCheckins = 0
        var recapInjections = 0
    }

    /// Pure planner (unit-tested).
    static func plan(checkinDays: Set<Date>, injectionDates: [Date], now: Date, calendar: Calendar = .current) -> Plan {
        var plan = Plan()
        let today = calendar.startOfDay(for: now)

        // Streak at risk
        let streak = DayStreak.current(days: checkinDays, now: now, calendar: calendar)
        if streak > 0 {
            let checkedInToday = checkinDays.contains(today)
            let day = checkedInToday ? calendar.date(byAdding: .day, value: 1, to: today) : today
            if let day, let fire = calendar.date(bySettingHour: streakHour, minute: streakMinute, second: 0, of: day),
               fire > now {
                plan.streakFireDate = fire
                plan.streakDays = streak
            }
        }

        // Weekly recap: next Sunday 18:00, counting the 7 days that end then.
        if let fire = calendar.nextDate(after: now,
                                        matching: DateComponents(hour: recapHour, minute: 0, weekday: recapWeekday),
                                        matchingPolicy: .nextTime),
           let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: fire)) {
            let checkins = checkinDays.filter { $0 >= weekStart && $0 <= fire }.count
            let injections = injectionDates.filter { $0 >= weekStart && $0 <= fire }.count
            if checkins + injections > 0 {
                plan.recapFireDate = fire
                plan.recapCheckins = checkins
                plan.recapInjections = injections
            }
        }
        return plan
    }

    static func recapBody(checkins: Int, injections: Int) -> String {
        var parts: [String] = []
        if checkins > 0 {
            parts.append(checkins == 1
                ? gLoc("notif.recap.checkins.one", "1 check-in this week")
                : String(format: gLoc("notif.recap.checkins.other", "%d check-ins this week"), checkins))
        }
        if injections > 0 {
            parts.append(injections == 1
                ? gLoc("notif.recap.injections.one", "1 injection logged")
                : String(format: gLoc("notif.recap.injections.other", "%d injections logged"), injections))
        }
        return parts.joined(separator: " · ")
    }

    /// Re-plans both reminders from current data. Safe to call often.
    @MainActor
    static func replan(context: ModelContext, now: Date = .now) async {
        let checkins = (try? context.fetch(FetchDescriptor<SDCheckin>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        let injections = (try? context.fetch(FetchDescriptor<SDInjection>(predicate: #Predicate { !$0.isSampleData }))) ?? []
        let planned = Self.plan(checkinDays: Set(checkins.map { $0.date.startOfDay }),
                                injectionDates: injections.map(\.injectedAt),
                                now: now)
        await apply(planned)
    }

    /// Replaces the pending requests for our fixed identifiers only.
    static func apply(_ plan: Plan, includeRecap: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: includeRecap ? [streakAtRiskID, weeklyRecapID] : [streakAtRiskID])
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }
        let cal = Calendar.current

        if let fire = plan.streakFireDate {
            let content = UNMutableNotificationContent()
            content.title = String(format: gLoc("notif.streakRisk.title", "Your %d-day streak is waiting"), plan.streakDays)
            content.body = gLoc("notif.streakRisk.body", "A quick check-in keeps it going.")
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            try? await center.add(UNNotificationRequest(
                identifier: streakAtRiskID, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }

        if includeRecap, let fire = plan.recapFireDate {
            let content = UNMutableNotificationContent()
            content.title = gLoc("notif.recap.title", "Your week in Trough")
            content.body = recapBody(checkins: plan.recapCheckins, injections: plan.recapInjections)
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            try? await center.add(UNNotificationRequest(
                identifier: weeklyRecapID, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    static var englishStrings: [(key: String, value: String)] {
        [
            ("notif.recap.checkins.one", "1 check-in this week"),
            ("notif.recap.checkins.other", "%d check-ins this week"),
            ("notif.recap.injections.one", "1 injection logged"),
            ("notif.recap.injections.other", "%d injections logged"),
            ("notif.streakRisk.title", "Your %d-day streak is waiting"),
            ("notif.streakRisk.body", "A quick check-in keeps it going."),
            ("notif.recap.title", "Your week in Trough"),
        ]
    }
}
