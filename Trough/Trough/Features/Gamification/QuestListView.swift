import SwiftUI

// MARK: - XP chip

/// Gold "+20 XP" capsule.
struct XPChip: View {
    let xp: Int
    var done: Bool = false

    var body: some View {
        Text(verbatim: String(format: gLoc("ach.xpReward", "+%d XP"), xp))
            .font(TR.Font.number(.caption, weight: .black))
            .foregroundStyle(done ? TR.Palette.textTertiary : Color(trHex: 0x3A2600))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if done {
                    Capsule().fill(TR.Palette.surfaceRaised)
                } else {
                    Capsule().fill(TR.Gradients.xp)
                }
            }
            .overlay(Capsule().strokeBorder(.white.opacity(done ? 0.08 : 0.35), lineWidth: 1))
            .fixedSize()
    }
}

// MARK: - Quest helpers

extension QuestDisplayModel {
    var symbol: String {
        if let challenge {
            switch challenge {
            case .checkin: return "checkmark.circle"
            case .injection: return "syringe"
            case .note: return "note.text"
            case .healthSync: return "heart.text.square"
            }
        }
        return frequency == "weekly" ? "calendar" : "target"
    }

    /// Title without the "Daily Challenge:" prefix (the card's kicker says it).
    var shortTitle: String {
        guard challenge != nil, let range = title.range(of: ": ") else { return title }
        return String(title[range.upperBound...])
    }
}

// MARK: - Quest status ring

private struct QuestStatusRing: View {
    let done: Bool
    var tint: Color
    var symbol: String
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(done ? TR.Palette.mint.opacity(0.16) : tint.opacity(0.12))
            TRRing(progress: done ? 1 : 0.0001, lineWidth: 3.5,
                   colors: done ? [TR.Palette.mint, TR.Palette.teal] : [tint, tint], glow: done)
            Image(systemName: done ? "checkmark" : symbol)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(done ? TR.Palette.mint : tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Quest card

struct QuestCard: View {
    let quest: QuestDisplayModel

    var body: some View {
        let tint = quest.frequency == "weekly" ? TR.Palette.lilac : TR.Palette.sky
        HStack(spacing: 14) {
            QuestStatusRing(done: quest.isCompleted, tint: tint, symbol: quest.symbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: quest.shortTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(quest.isCompleted ? TR.Palette.textSecondary : TR.Palette.textPrimary)
                    .strikethrough(quest.isCompleted, color: TR.Palette.textTertiary)
                Text(verbatim: quest.description)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            XPChip(xp: quest.xpReward, done: quest.isCompleted)
        }
        .padding(14)
        .background(TR.Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(TR.Palette.hairline, lineWidth: 1))
        .opacity(quest.isCompleted ? 0.82 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(quest.shortTitle). \(quest.description). \(String(format: gLoc("ach.xpReward", "+%d XP"), quest.xpReward)). \(quest.isCompleted ? gLoc("ach.quest.done", "Completed") : gLoc("ach.quest.open", "Not done yet"))"))
    }
}

// MARK: - Daily challenge card

struct DailyChallengeCard: View {
    let quest: QuestDisplayModel

    var body: some View {
        let tint = TR.Palette.gold
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TRKicker(Text(verbatim: gLoc("ach.challenge.kicker", "Today's challenge")), color: tint)
                Spacer()
                XPChip(xp: quest.xpReward, done: quest.isCompleted)
            }
            HStack(spacing: 14) {
                QuestStatusRing(done: quest.isCompleted, tint: tint, symbol: quest.symbol, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: quest.shortTitle)
                        .font(TR.Font.display(.title3, weight: .heavy))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(verbatim: quest.isCompleted ? gLoc("ach.challenge.done", "Done for today. Nice.") : quest.description)
                        .font(.subheadline)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: tint)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Quest list (embeddable)

/// Daily + weekly quests as cards (no scroll view — embed it).
struct QuestSection: View {
    @ObservedObject var viewModel: GamificationViewModel

    var body: some View {
        let quests = viewModel.activeQuests.filter { $0.challenge == nil }
        let done = quests.filter(\.isCompleted).count
        VStack(alignment: .leading, spacing: 12) {
            TRSectionHeader(Text(verbatim: gLoc("ach.quests.title", "Quests"))) {
                Text(verbatim: String(format: gLoc("ach.badges.count", "%d of %d"), done, quests.count))
                    .monospacedDigit()
            }
            if quests.isEmpty {
                Text(verbatim: gLoc("ach.quests.empty", "New quests arrive tomorrow."))
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .trCard()
            } else {
                ForEach(quests) { quest in
                    QuestCard(quest: quest)
                }
            }
        }
    }
}

// MARK: - Sheet (legacy entry point)

struct QuestListView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TR.Metrics.sectionSpacing) {
                    if let challenge = viewModel.dailyChallenge {
                        DailyChallengeCard(quest: challenge)
                    }
                    QuestSection(viewModel: viewModel)
                }
                .padding(TR.Metrics.gutter)
            }
            .background(TRBackground())
            .navigationTitle(Text(verbatim: gLoc("ach.quests.title", "Quests")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(TR.Palette.coral)
    }
}
