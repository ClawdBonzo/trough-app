import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), snapshot: WidgetSnapshot(streak: 7, level: 4, levelName: "Dedicated",
                                                           levelProgress: 0.6, xpToNext: 80,
                                                           checkedInToday: false, daysUntilInjection: 2))
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let raw = WidgetSnapshot.loadRaw()
        let now = Date()
        let cal = Calendar.current

        // One entry for right now, plus entries just past the next few
        // midnights so "checked in today" clears and the injection countdown
        // ticks down without an app launch.
        var entries = [StreakEntry(date: now, snapshot: raw.resolved(at: now))]
        for dayOffset in 1...3 {
            if let midnight = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)) {
                let entryDate = midnight.addingTimeInterval(1)
                entries.append(StreakEntry(date: entryDate, snapshot: raw.resolved(at: entryDate)))
            }
        }

        // The app pushes reloads on data change; refresh hourly as a fallback
        // so the snapshot stays roughly current.
        let next = cal.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

// MARK: - Widget

struct TroughStreakWidget: Widget {
    let kind = "TroughStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            TroughStreakView(snapshot: entry.snapshot)
                .containerBackground(WColors.background, for: .widget)
        }
        .configurationDisplayName("Streak & Level")
        .description("Your check-in streak, level progress, and next injection.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct TroughStreakView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemMedium {
            mediumBody
        } else {
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("\(snapshot.streak)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(WColors.accent)
                Text("🔥")
                    .font(.title3)
            }
            Text("day streak")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer(minLength: 2)

            levelRow
            if !snapshot.checkedInToday {
                Text("Check in today")
                    .font(.caption2.bold())
                    .foregroundColor(WColors.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "trough://checkin"))
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(snapshot.streak)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(WColors.accent)
                    Text("🔥").font(.title2)
                }
                Text("day check-in streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 4)
                if let d = snapshot.daysUntilInjection {
                    Label(injectionText(d), systemImage: "syringe.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            Divider().overlay(WColors.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(snapshot.level)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(snapshot.levelName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView(value: snapshot.levelProgress)
                    .tint(WColors.accent)
                Text("\(snapshot.xpToNext) XP to next")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if !snapshot.checkedInToday {
                    Text("Tap to check in →")
                        .font(.caption2.bold())
                        .foregroundColor(WColors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "trough://checkin"))
    }

    private var levelRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Lvl \(snapshot.level) · \(snapshot.levelName)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .lineLimit(1)
            ProgressView(value: snapshot.levelProgress)
                .tint(WColors.accent)
        }
    }

    private func injectionText(_ days: Int) -> String {
        if days <= 0 { return "Injection due today" }
        if days == 1 { return "Injection in 1 day" }
        return "Injection in \(days) days"
    }
}
