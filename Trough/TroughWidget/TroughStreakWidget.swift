import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        // Gallery previews show the sample until the app has written anything.
        let stored = WidgetSnapshot.load()
        completion(StreakEntry(date: Date(), snapshot: context.isPreview && stored.updatedAt == nil ? Self.sample : stored))
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

    /// Gallery / placeholder sample. Counts only — no doses or compounds.
    static let sample: WidgetSnapshot = {
        var s = WidgetSnapshot(streak: 7, level: 4, levelName: "Dedicated",
                               levelProgress: 0.6, xpToNext: 80,
                               checkedInToday: false, daysUntilInjection: 2)
        s.nextBadgeName = "Fortnight Focus"
        s.nextBadgeSymbol = "flame.circle.fill"
        s.nextBadgeCurrent = 11
        s.nextBadgeTarget = 14
        s.nextBadgeRemaining = 3
        s.nextBadgeProgress = 11.0 / 14.0
        return s
    }()
}

// MARK: - Shared strings

enum WStrings {
    static func injection(_ days: Int) -> String {
        if days <= 0 { return NSLocalizedString("widget.injectionDueToday", comment: "Injection is due today") }
        if days == 1 { return NSLocalizedString("widget.injectionInOneDay", comment: "Injection due tomorrow") }
        return String(format: NSLocalizedString("widget.injectionInDays", comment: "Injection due in %d days"), days)
    }

    static func streak(_ days: Int) -> String {
        String(format: wLoc("widget.lock.streak", "%d-day streak"), days)
    }

    static func toGo(_ remaining: Int) -> String {
        String(format: wLoc("widget.badge.toGo", "%d to go"), remaining)
    }

    static func ofTarget(_ current: Int, _ target: Int) -> String {
        String(format: wLoc("widget.badge.progress", "%1$d of %2$d"), current, target)
    }
}

// MARK: - Streak & Level widget (home screen)

struct TroughStreakWidget: Widget {
    let kind = "TroughStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            TroughStreakView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WColors.widgetBackground }
        }
        .configurationDisplayName(NSLocalizedString("widget.displayName", comment: "Widget gallery title"))
        .description(NSLocalizedString("widget.description", comment: "Widget gallery description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TroughStreakView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumBody
            } else {
                smallBody
            }
        }
        .widgetURL(URL(string: "trough://checkin"))
    }

    // MARK: Small

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                WFlameIcon(size: 15)
                WKicker(wLoc("widget.kicker.streak", "Streak"))
                Spacer(minLength: 0)
                WRankPill(level: snapshot.level, coverKey: snapshot.rankCoverKey)
            }

            Text("\(snapshot.streak)")
                .font(.system(size: 42, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(WColors.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
                .padding(.top, 2)
            Text(NSLocalizedString("widget.dayStreak", comment: "Caption under streak count (small widget)"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WColors.textSecondary)

            Spacer(minLength: 4)

            levelRow
                .padding(.bottom, 5)
            checkinStatus
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium

    private var mediumBody: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    WFlameIcon(size: 15)
                    WKicker(wLoc("widget.kicker.checkInStreak", "Check-in streak"))
                }
                Text("\(snapshot.streak)")
                    .font(.system(size: 46, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(WColors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .widgetAccentable()
                    .padding(.top, 2)
                Text(NSLocalizedString("widget.dayCheckInStreak", comment: "Caption under streak count (medium widget)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WColors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let d = snapshot.daysUntilInjection {
                    HStack(spacing: 5) {
                        Image(systemName: "syringe.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WColors.coralLight)
                        Text(WStrings.injection(d))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WColors.textPrimary.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WColors.surfaceRaised.opacity(0.9), in: Capsule())
                    .overlay(Capsule().strokeBorder(WColors.hairline))
                } else {
                    checkinStatus
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Level panel with the rank-cover strip on its leading edge.
            HStack(spacing: 10) {
                Capsule()
                    .fill(LinearGradient(colors: WColors.rankCover(snapshot.rankCoverKey), startPoint: .top, endPoint: .bottom))
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(format: NSLocalizedString("widget.level", comment: "Level heading, %d = level number"), snapshot.level))
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(WColors.textPrimary)
                    Text(snapshot.levelName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WColors.textSecondary)
                        .lineLimit(1)
                    WBar(value: snapshot.levelProgress, colors: WColors.xpColors)
                        .padding(.top, 2)
                    Text(String(format: NSLocalizedString("widget.xpToNext", comment: "XP remaining to next level, %d = XP amount"), snapshot.xpToNext))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(WColors.gold)
                    Spacer(minLength: 0)
                    if snapshot.daysUntilInjection != nil {
                        checkinStatus
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(WColors.card.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WColors.hairline))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Parts

    private var levelRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: NSLocalizedString("widget.levelLine", comment: "Compact level line, %d = level, %@ = level name"), snapshot.level, snapshot.levelName))
                .font(.caption2.weight(.bold))
                .foregroundStyle(WColors.textPrimary)
                .lineLimit(1)
            WBar(value: snapshot.levelProgress, colors: WColors.xpColors)
        }
    }

    @ViewBuilder
    private var checkinStatus: some View {
        if snapshot.checkedInToday {
            Label {
                Text(wLoc("widget.checkedInToday", "Checked in today"))
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(WColors.teal)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(WColors.textSecondary)
            .lineLimit(1)
        } else {
            Label {
                Text(family == .systemMedium
                     ? NSLocalizedString("widget.tapToCheckIn", comment: "Tap prompt when not yet checked in (medium widget)")
                     : NSLocalizedString("widget.checkInToday", comment: "Prompt when not yet checked in (small widget)"))
            } icon: {
                Image(systemName: "plus.circle.fill")
            }
            .font(.caption2.weight(.heavy))
            .foregroundStyle(WColors.coralLight)
            .lineLimit(1)
        }
    }
}

// MARK: - Next badge widget

struct TroughNextBadgeWidget: Widget {
    let kind = "TroughNextBadgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            TroughNextBadgeView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { WColors.widgetBackground }
        }
        .configurationDisplayName(wLoc("widget.nextBadge.displayName", "Next Badge"))
        .description(wLoc("widget.nextBadge.description", "The badge you're closest to, and how many to go."))
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct TroughNextBadgeView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private enum BadgeState {
        case badge(name: String, symbol: String)
        case allEarned
        case notYet
    }

    private var state: BadgeState {
        guard let name = snapshot.nextBadgeName else { return .notYet }
        if name.isEmpty { return .allEarned }
        return .badge(name: name, symbol: snapshot.nextBadgeSymbol ?? "rosette")
    }

    var body: some View {
        content
            .widgetURL(URL(string: "trough://badges"))
    }

    @ViewBuilder
    private var content: some View {
        switch (state, family) {
        case let (.badge(name, symbol), .accessoryCircular):
            Gauge(value: snapshot.nextBadgeProgress) {
                Image(systemName: symbol)
            } currentValueLabel: {
                Image(systemName: symbol)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel(Text(verbatim: name))
            .accessibilityValue(Text(WStrings.toGo(snapshot.nextBadgeRemaining)))

        case let (.badge(name, symbol), .accessoryRectangular):
            VStack(alignment: .leading, spacing: 2) {
                Label { Text(verbatim: name) } icon: { Image(systemName: symbol) }
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Gauge(value: snapshot.nextBadgeProgress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                Text(WStrings.toGo(snapshot.nextBadgeRemaining))
                    .font(.caption)
            }

        case let (.badge(name, symbol), _):
            smallBadge(name: name, symbol: symbol)

        case (.allEarned, .accessoryCircular), (.notYet, .accessoryCircular):
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "rosette").font(.title3.weight(.semibold))
            }
            .accessibilityLabel(Text(emptyTitle))

        case (.allEarned, .accessoryRectangular), (.notYet, .accessoryRectangular):
            VStack(alignment: .leading, spacing: 2) {
                Label { Text(emptyTitle) } icon: { Image(systemName: "rosette") }
                    .font(.headline)
                    .lineLimit(1)
                Text(emptySubtitle).font(.caption).lineLimit(2)
            }

        default:
            smallEmpty
        }
    }

    private var isAllEarned: Bool {
        if case .allEarned = state { return true }
        return false
    }

    private var emptyTitle: String {
        isAllEarned
            ? wLoc("widget.badge.allEarned", "Every badge earned")
            : wLoc("widget.nextBadge.displayName", "Next Badge")
    }

    private var emptySubtitle: String {
        isAllEarned
            ? wLoc("widget.badge.allEarnedSub", "The full collection. Keep the streak alive.")
            : wLoc("widget.badge.openApp", "Open Trough to start collecting.")
    }

    private func smallBadge(name: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WKicker(wLoc("widget.kicker.nextBadge", "Next badge"))
                Spacer(minLength: 0)
                WRankStrip(coverKey: snapshot.rankCoverKey)
            }
            Spacer(minLength: 4)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.02, snapshot.nextBadgeProgress))
                    .stroke(AngularGradient(colors: WColors.flameColors + [WColors.gold], center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: WColors.tangerine.opacity(0.5), radius: 5)
                Circle()
                    .fill(RadialGradient(colors: [WColors.surfaceRaised, WColors.card], center: .topLeading, startRadius: 0, endRadius: 50))
                    .padding(8)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(WColors.gold)
                    .widgetAccentable()
            }
            .frame(width: 60, height: 60)
            .accessibilityHidden(true)
            Spacer(minLength: 4)
            Text(verbatim: name)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(WColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 4) {
                Text(WStrings.toGo(snapshot.nextBadgeRemaining))
                    .foregroundStyle(WColors.gold)
                Text(verbatim: "·").foregroundStyle(WColors.textTertiary)
                Text(WStrings.ofTarget(snapshot.nextBadgeCurrent, snapshot.nextBadgeTarget))
                    .foregroundStyle(WColors.textSecondary)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var smallEmpty: some View {
        VStack(alignment: .leading, spacing: 4) {
            WKicker(wLoc("widget.kicker.nextBadge", "Next badge"))
            Spacer(minLength: 0)
            Image(systemName: isAllEarned ? "crown.fill" : "rosette")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(LinearGradient(colors: WColors.xpColors, startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            Text(emptyTitle)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(WColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(emptySubtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WColors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Lock Screen: streak + next injection

struct TroughLockScreenWidget: Widget {
    let kind = "TroughLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            TroughLockScreenView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "trough://checkin"))
        }
        .configurationDisplayName(wLoc("widget.lock.displayName", "Streak"))
        .description(wLoc("widget.lock.description", "Your check-in streak and next injection, on the Lock Screen."))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TroughLockScreenView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Image(systemName: snapshot.checkedInToday ? "flame.fill" : "flame")
                        .font(.system(size: 13, weight: .bold))
                        .widgetAccentable()
                    Text("\(snapshot.streak)")
                        .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(WStrings.streak(snapshot.streak)))

        case .accessoryInline:
            Label {
                Text(snapshot.checkedInToday
                     ? WStrings.streak(snapshot.streak)
                     : String(format: wLoc("widget.lock.inlineCheckIn", "%d-day streak · check in"), snapshot.streak))
            } icon: {
                Image(systemName: "flame.fill")
            }

        default:
            VStack(alignment: .leading, spacing: 1) {
                Label { Text(WStrings.streak(snapshot.streak)) } icon: { Image(systemName: "flame.fill") }
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Label {
                    Text(snapshot.checkedInToday
                         ? wLoc("widget.checkedInToday", "Checked in today")
                         : NSLocalizedString("widget.checkInToday", comment: ""))
                } icon: {
                    Image(systemName: snapshot.checkedInToday ? "checkmark.circle.fill" : "circle.dashed")
                }
                .font(.caption)
                .lineLimit(1)
                if let d = snapshot.daysUntilInjection {
                    Label { Text(WStrings.injection(d)) } icon: { Image(systemName: "syringe.fill") }
                        .font(.caption)
                        .lineLimit(1)
                        .privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Lock Screen: next injection

struct TroughInjectionLockWidget: Widget {
    let kind = "TroughInjectionLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            TroughInjectionLockView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "trough://injections"))
        }
        .configurationDisplayName(wLoc("widget.injLock.displayName", "Next Injection"))
        .description(wLoc("widget.injLock.description", "Days until your next scheduled injection."))
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

struct TroughInjectionLockView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var shortDays: String {
        guard let d = snapshot.daysUntilInjection else { return "–" }
        if d <= 0 { return wLoc("widget.injLock.today", "Today") }
        return String(format: wLoc("widget.injLock.daysShort", "%dd"), d)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label {
                Text(snapshot.daysUntilInjection.map(WStrings.injection)
                     ?? wLoc("widget.injLock.none", "No injection scheduled"))
            } icon: {
                Image(systemName: "syringe.fill")
            }
            .privacySensitive()
        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 12, weight: .bold))
                        .widgetAccentable()
                    Text(shortDays)
                        .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(5)
            }
            .privacySensitive()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(snapshot.daysUntilInjection.map(WStrings.injection)
                                     ?? wLoc("widget.injLock.none", "No injection scheduled")))
        }
    }
}

// MARK: - Small shared parts

/// Uppercase caption kicker (mirror of the app's TRKicker).
struct WKicker: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(WColors.textSecondary)
            .lineLimit(1)
    }
}

/// Flame glyph in the gold → coral gradient (no emoji).
struct WFlameIcon: View {
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(LinearGradient(colors: WColors.flameColors, startPoint: .top, endPoint: .bottom))
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}

/// "L4" pill on the rank-cover gradient.
struct WRankPill: View {
    let level: Int
    let coverKey: String

    private var ink: Color {
        switch coverKey {
        case "bronze": return Color(wHex: "#2B1A0C")
        case "silver": return Color(wHex: "#1E2530")
        case "gold": return Color(wHex: "#3A2600")
        case "platinum": return Color(wHex: "#0D2A3A")
        case "diamond": return Color(wHex: "#120A2E")
        default: return Color(wHex: "#3A3326")
        }
    }

    var body: some View {
        Text(String(format: wLoc("widget.levelShort", "L%d"), level))
            .font(.system(size: 11, weight: .black, design: .rounded).monospacedDigit())
            .foregroundStyle(ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(LinearGradient(colors: WColors.rankCover(coverKey), startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
    }
}

/// Short horizontal rank-cover colour strip.
struct WRankStrip: View {
    let coverKey: String

    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: WColors.rankCover(coverKey), startPoint: .leading, endPoint: .trailing))
            .frame(width: 26, height: 5)
            .accessibilityHidden(true)
    }
}

/// Gradient capsule progress bar.
struct WBar: View {
    let value: Double
    var colors: [Color] = WColors.xpColors
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, proxy.size.width * min(1, max(0, value))))
                    .opacity(value > 0 ? 1 : 0)
                    .widgetAccentable()
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
