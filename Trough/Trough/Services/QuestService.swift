import SwiftData
import Foundation

/// Seeds daily and weekly quests for the given user. Safe to call on every app launch —
/// it checks for existing quests before inserting new ones.
enum QuestService {

    // MARK: - Quest definitions

    private struct QuestDef {
        let questID: String
        let questType: String
        let frequency: String
        let title: String
        let description: String
        let xpReward: Int
    }

    private static let dailyDefs: [QuestDef] = [
        QuestDef(questID: "log_checkin_daily",
                 questType: "log_checkin",
                 frequency: "daily",
                 title: "Log Today's Check-in",
                 description: "Complete your daily wellness check-in",
                 xpReward: 20),
        QuestDef(questID: "view_insights_daily",
                 questType: "view_insights",
                 frequency: "daily",
                 title: "View Today's Insights",
                 description: "Check your protocol insights on the Dashboard",
                 xpReward: 5),
        QuestDef(questID: "daily_login",
                 questType: "daily_login",
                 frequency: "daily",
                 title: "Daily Check-in",
                 description: "Open the app and stay on track",
                 xpReward: 5),
    ]

    private static let weeklyDefs: [QuestDef] = [
        QuestDef(questID: "inject_on_schedule_weekly",
                 questType: "inject_on_schedule",
                 frequency: "weekly",
                 title: "Inject On Schedule",
                 description: "Log your injection within 24h of your scheduled day",
                 xpReward: 25),
        QuestDef(questID: "complete_bloodwork_weekly",
                 questType: "complete_bloodwork",
                 frequency: "weekly",
                 title: "Log a Bloodwork Result",
                 description: "Track your lab results this week",
                 xpReward: 30),
        QuestDef(questID: "hit_streak_7_weekly",
                 questType: "hit_streak",
                 frequency: "weekly",
                 title: "7-Day Check-in Streak",
                 description: "Check in every day this week",
                 xpReward: 25),
        QuestDef(questID: "supplement_adherence_weekly",
                 questType: "supplement_adherence",
                 frequency: "weekly",
                 title: "Supplement Adherence",
                 description: "Hit ≥80% supplement compliance this week",
                 xpReward: 20),
    ]

    // MARK: - Public API

    /// Seeds today's daily quests and this week's weekly quests if not yet present.
    /// Also purges quests from past periods so dead rows don't accumulate.
    static func seedIfNeeded(context: ModelContext, userID: UUID) {
        purgeExpired(context: context)
        seedDaily(context: context, userID: userID)
        seedWeekly(context: context, userID: userID)
        try? context.save()
    }

    // MARK: - Hygiene

    /// Deletes quests whose period has ended (dueDate before today). Daily quests
    /// expire at yesterday's endOfDay and weekly quests at last week's endOfWeek,
    /// so `dueDate < startOfToday` matches exactly the past-period rows. Applies
    /// to all userIDs so pre-v1.1.4 orphaned rows are swept too.
    private static func purgeExpired(context: ModelContext) {
        let todayStart = Date().startOfDay
        let pred = #Predicate<SDQuest> { $0.dueDate < todayStart }
        try? context.delete(model: SDQuest.self, where: pred)
    }

    // MARK: - Seeding helpers

    private static func seedDaily(context: ModelContext, userID: UUID) {
        let today = Date().startOfDay
        let todayEnd = Date().endOfDay

        for def in dailyDefs {
            // Check if this quest already exists for today
            let uniqueID = "\(def.questID)_\(today.iso8601String)"
            let pred = #Predicate<SDQuest> {
                $0.questID == uniqueID && $0.userID == userID
            }
            var desc = FetchDescriptor<SDQuest>(predicate: pred)
            desc.fetchLimit = 1

            if (try? context.fetch(desc).first) == nil {
                let quest = SDQuest(
                    userID: userID,
                    questID: uniqueID,
                    questType: def.questType,
                    frequency: def.frequency,
                    title: def.title,
                    questDescription: def.description,
                    xpReward: def.xpReward,
                    dueDate: todayEnd
                )
                context.insert(quest)
            }
        }
    }

    private static func seedWeekly(context: ModelContext, userID: UUID) {
        let weekEnd = Date().endOfWeek
        // Use the start-of-week as part of the key so we seed once per week
        let cal = Calendar.current
        let weekStart = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let weekKey = "wk\(weekStart.weekOfYear ?? 0)_\(weekStart.yearForWeekOfYear ?? 0)"

        for def in weeklyDefs {
            let uniqueID = "\(def.questID)_\(weekKey)"
            let pred = #Predicate<SDQuest> {
                $0.questID == uniqueID && $0.userID == userID
            }
            var desc = FetchDescriptor<SDQuest>(predicate: pred)
            desc.fetchLimit = 1

            if (try? context.fetch(desc).first) == nil {
                let quest = SDQuest(
                    userID: userID,
                    questID: uniqueID,
                    questType: def.questType,
                    frequency: def.frequency,
                    title: def.title,
                    questDescription: def.description,
                    xpReward: def.xpReward,
                    dueDate: weekEnd
                )
                context.insert(quest)
            }
        }
    }

    // MARK: - Quest ID helpers for completion hooks

    /// Week key matching the one used in seedWeekly — keep in sync.
    private static func currentWeekKey() -> String {
        let cal = Calendar.current
        let weekStart = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "wk\(weekStart.weekOfYear ?? 0)_\(weekStart.yearForWeekOfYear ?? 0)"
    }

    /// Returns the questID for today's daily check-in quest (for use in completeQuest).
    static func dailyCheckinQuestID() -> String {
        "\("log_checkin_daily")_\(Date().startOfDay.iso8601String)"
    }

    /// Returns the questID for today's daily-login quest.
    static func dailyLoginQuestID() -> String {
        "\("daily_login")_\(Date().startOfDay.iso8601String)"
    }

    /// Returns the questID for today's view-insights quest.
    static func viewInsightsQuestID() -> String {
        "\("view_insights_daily")_\(Date().startOfDay.iso8601String)"
    }

    /// Returns the questID for this week's injection quest.
    static func weeklyInjectionQuestID() -> String {
        "inject_on_schedule_weekly_\(currentWeekKey())"
    }

    /// Returns the questID for this week's bloodwork quest.
    static func weeklyBloodworkQuestID() -> String {
        "complete_bloodwork_weekly_\(currentWeekKey())"
    }

    /// Returns the questID for this week's 7-day streak quest.
    static func weeklyStreakQuestID() -> String {
        "hit_streak_7_weekly_\(currentWeekKey())"
    }

    /// Returns the questID for this week's supplement adherence quest.
    static func weeklySupplementQuestID() -> String {
        "supplement_adherence_weekly_\(currentWeekKey())"
    }
}
