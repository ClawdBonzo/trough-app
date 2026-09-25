import SwiftUI

// MARK: - Categories

/// Badge wall sections, derived from each badge's metric (and secrecy).
enum BadgeCategory: String, CaseIterable, Identifiable {
    case checkins, streaks, injections, bloodwork, health, adjuncts, levels, notes, specials, secrets

    var id: String { rawValue }

    static func of(_ def: BadgeDef) -> BadgeCategory {
        if def.isSecret { return .secrets }
        switch def.metric {
        case .checkins: return .checkins
        case .checkinStreak: return .streaks
        case .injections, .onScheduleWeeks: return .injections
        case .bloodworkPanels: return .bloodwork
        case .healthSyncedCheckins: return .health
        case .adjunctLogs: return .adjuncts
        case .level: return .levels
        case .notedLogs: return .notes
        case .goodDayCheckin, .perfectWeek, .supplementDays30, .injectionPrecision,
             .nightOwl, .newYear, .daysSinceFirstCheckin:
            return .specials
        }
    }

    var title: String {
        switch self {
        case .checkins:   return gLoc("ach.cat.checkins", "Check-ins")
        case .streaks:    return gLoc("ach.cat.streaks", "Streaks")
        case .injections: return gLoc("ach.cat.injections", "Injection log")
        case .bloodwork:  return gLoc("ach.cat.bloodwork", "Bloodwork records")
        case .health:     return gLoc("ach.cat.health", "Apple Health")
        case .adjuncts:   return gLoc("ach.cat.adjuncts", "Adjuncts")
        case .levels:     return gLoc("ach.cat.levels", "Levels")
        case .notes:      return gLoc("ach.cat.notes", "Notes")
        case .specials:   return gLoc("ach.cat.specials", "Specials")
        case .secrets:    return gLoc("ach.cat.secrets", "Secrets")
        }
    }

    var symbol: String {
        switch self {
        case .checkins:   return "checkmark.circle.fill"
        case .streaks:    return "flame.fill"
        case .injections: return "syringe.fill"
        case .bloodwork:  return "testtube.2"
        case .health:     return "heart.fill"
        case .adjuncts:   return "pills.fill"
        case .levels:     return "star.fill"
        case .notes:      return "note.text"
        case .specials:   return "sparkles"
        case .secrets:    return "questionmark.circle.fill"
        }
    }
}

// MARK: - Model helpers

extension BadgeProgressModel {
    var medallionStatus: BadgeMedallion.Status {
        isUnlocked ? .unlocked : (isHiddenSecret ? .secret : .locked)
    }

    var displayTitle: String {
        isHiddenSecret ? gLoc("badge.secret.title", "Secret Badge") : def.title
    }

    /// Catalog with zero progress — used before the VM has loaded.
    static var emptyCatalog: [BadgeProgressModel] {
        GamificationCatalog.badges.map { BadgeProgressModel(def: $0, current: 0, target: $0.target, unlockedDate: nil) }
    }
}

// MARK: - Grid (embeddable, non-scrolling)

/// All 42 badges grouped by category. Embed inside a ScrollView; tapping opens a detail sheet.
struct BadgeWallGrid: View {
    @ObservedObject var viewModel: GamificationViewModel
    @State private var selected: BadgeProgressModel?

    private var badges: [BadgeProgressModel] {
        viewModel.badgeProgress.isEmpty ? BadgeProgressModel.emptyCatalog : viewModel.badgeProgress
    }

    private let columns = [GridItem(.adaptive(minimum: 98, maximum: 140), spacing: 12, alignment: .top)]

    var body: some View {
        let all = badges
        let unlocked = all.filter(\.isUnlocked).count
        VStack(alignment: .leading, spacing: 18) {
            TRSectionHeader(Text(verbatim: gLoc("ach.badges.title", "Badge wall"))) {
                Text(verbatim: String(format: gLoc("ach.badges.count", "%d of %d"), unlocked, all.count))
                    .monospacedDigit()
            }
            TRProgressBar(value: all.isEmpty ? 0 : Double(unlocked) / Double(all.count), height: 8)

            ForEach(BadgeCategory.allCases) { category in
                let items = all.filter { BadgeCategory.of($0.def) == category }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: category.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TR.Palette.textTertiary)
                                .accessibilityHidden(true)
                            TRKicker(Text(verbatim: category.title))
                            Spacer()
                            Text(verbatim: "\(items.filter(\.isUnlocked).count)/\(items.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(TR.Palette.textTertiary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(items) { badge in
                                Button { selected = badge } label: { BadgeTile(badge: badge) }
                                    .buttonStyle(.trPressable)
                                    .accessibilityIdentifier("badge-\(badge.id)")
                            }
                        }
                    }
                    .trCard(tint: category == .secrets ? TR.Palette.lilac : nil)
                }
            }
        }
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(badge: badge)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Tile

struct BadgeTile: View {
    let badge: BadgeProgressModel
    var size: CGFloat = 76

    var body: some View {
        VStack(spacing: 8) {
            BadgeMedallion(
                systemImage: badge.def.symbol,
                tier: badge.def.tier,
                status: badge.medallionStatus,
                progress: badge.fraction,
                size: size,
                glow: badge.isUnlocked,
                discColors: badge.def.discColors
            )
            .padding(.top, 4)
            Text(verbatim: badge.displayTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(badge.isUnlocked ? TR.Palette.textPrimary : TR.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            subtitle
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var subtitle: some View {
        if badge.isUnlocked {
            Text(verbatim: badge.def.tier.name)
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(badge.def.tier.glowColor)
        } else if badge.isHiddenSecret {
            Text(verbatim: "???")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(TR.Palette.lilac.opacity(0.8))
        } else {
            Text(verbatim: "\(badge.current)/\(badge.target)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(TR.Palette.textTertiary)
        }
    }

    private var accessibilityText: String {
        if badge.isUnlocked {
            return String(format: gLoc("ach.badge.a11y.unlocked", "%@, %@, unlocked"), badge.def.title, badge.def.tier.name)
        }
        if badge.isHiddenSecret { return gLoc("badge.secret.title", "Secret Badge") }
        return String(format: gLoc("ach.badge.a11y.locked", "%@, locked, %d of %d"), badge.def.title, badge.current, badge.target)
    }
}

// MARK: - Detail

struct BadgeDetailSheet: View {
    let badge: BadgeProgressModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareKind: ShareCardKind?

    var body: some View {
        ZStack {
            TRBackground(glow: badge.isUnlocked ? badge.def.accentColor : TR.Palette.lilac, glowOpacity: 0.28)
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        if badge.isUnlocked {
                            SunburstRays(color: badge.def.accentColor, rays: 16)
                                .frame(width: 280, height: 280)
                        }
                        BadgeMedallion(
                            systemImage: badge.def.symbol,
                            tier: badge.def.tier,
                            status: badge.medallionStatus,
                            progress: badge.fraction,
                            size: 148,
                            discColors: badge.def.discColors
                        )
                        .trPopOnAppear()
                    }
                    .frame(height: 200)
                    .padding(.top, 20)

                    if !badge.isHiddenSecret {
                        TRPill(Text(verbatim: badge.def.tier.name), systemImage: "medal.fill", tint: badge.def.tier.glowColor)
                    }

                    Text(verbatim: badge.displayTitle)
                        .font(TR.Font.display(.title, weight: .black))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(verbatim: bodyText)
                        .font(.body)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if badge.isUnlocked {
                        if let date = badge.unlockedDate {
                            TRPill(Text(verbatim: String(format: gLoc("ach.badge.unlockedOn", "Unlocked %@"),
                                                         date.formatted(date: .abbreviated, time: .omitted))),
                                   systemImage: "calendar", tint: TR.Palette.teal)
                        }
                    } else if !badge.isHiddenSecret {
                        VStack(spacing: 8) {
                            TRProgressBar(value: badge.fraction, height: 10, colors: badge.def.tier.discColors.reversed())
                            Text(verbatim: String(format: gLoc("ach.badges.count", "%d of %d"), badge.current, badge.target))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(TR.Palette.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .accessibilityElement(children: .combine)
                    }

                    if badge.isUnlocked {
                        VStack(spacing: 6) {
                            TRKicker(Text(verbatim: gLoc("ach.badge.howEarned", "How you earned it")))
                            Text(verbatim: badge.def.howTo)
                                .font(.subheadline)
                                .foregroundStyle(TR.Palette.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 4)

                        Button {
                            shareKind = .badge(badge.def)
                        } label: {
                            Label(gLoc("ach.share", "Share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.trSecondary)
                        .padding(.top, 8)
                        .accessibilityIdentifier("badge-share")
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $shareKind) { kind in
            ShareCardSheet(kind: kind, data: .current)
        }
    }

    private var bodyText: String {
        if badge.isUnlocked { return badge.def.unlockedLine }
        if badge.isHiddenSecret { return gLoc("ach.badge.secretHint", "A secret badge. It happens when it happens — keep logging.") }
        return badge.def.howTo
    }
}

// MARK: - Standalone screen

/// Scrolling badge wall screen (used by `BadgeCollectionView` and deep links).
struct BadgeWallView: View {
    @ObservedObject var viewModel: GamificationViewModel

    var body: some View {
        ScrollView {
            BadgeWallGrid(viewModel: viewModel)
                .padding(TR.Metrics.gutter)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
        }
        .background(TRBackground())
    }
}
