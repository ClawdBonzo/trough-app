import SwiftUI

struct GamificationHomeView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showQuestSheet = false
    @State private var showBadgesSheet = false

    var body: some View {
        VStack(spacing: 20) {
            // MARK: Level Hero
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppColors.card)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: viewModel.levelProgressPercent)
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.5),
                                value: viewModel.levelProgressPercent
                            )

                        VStack(spacing: 2) {
                            Text(String(viewModel.currentLevel))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(Int(viewModel.levelProgressPercent * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("Level \(viewModel.currentLevel), \(Int(viewModel.levelProgressPercent * 100)) percent progress")

                    Text("Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.levelName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(viewModel.currentXP) XP Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.xpUntilNextLevel) XP until level \(viewModel.currentLevel + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        ProgressView(value: viewModel.levelProgressPercent)
                            .tint(AppColors.accent)
                            .frame(height: 6)
                            .accessibilityLabel("\(Int(viewModel.levelProgressPercent * 100)) percent to next level")
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(AppColors.card)
            .cornerRadius(12)

            // MARK: Streaks
            if !viewModel.streakStates.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Streaks")
                        .font(.headline)
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.streakStates.values), id: \.streakType) { streak in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(streakTypeLabel(streak.streakType))
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Text("Best: \(streak.bestCount) days")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 4) {
                                    Text("\(streak.currentCount)")
                                        .font(.title3.bold())
                                        .foregroundColor(AppColors.accent)
                                    Text(flameMark(streak.flameLevel))
                                        .font(.title2)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(12)
                            .background(AppColors.card)
                            .cornerRadius(8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(streakTypeLabel(streak.streakType)): \(streak.currentCount) days, best \(streak.bestCount)")
                        }
                    }
                }
            }

            // MARK: Quests Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Daily Quests")
                        .font(.headline)
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    let completed = viewModel.activeQuests.filter(\.isCompleted).count
                    Text("\(completed)/\(viewModel.activeQuests.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("\(completed) of \(viewModel.activeQuests.count) quests completed")
                }

                if viewModel.activeQuests.isEmpty {
                    Text("No quests available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.activeQuests.prefix(3)) { quest in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(quest.title)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Text(quest.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Text("+\(quest.xpReward) XP")
                                        .font(.caption.bold())
                                        .foregroundColor(AppColors.accent)

                                    if quest.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .accessibilityLabel("Completed")
                                    }
                                }
                            }
                            .padding(10)
                            .background(AppColors.card)
                            .cornerRadius(8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(quest.title). \(quest.xpReward) XP. \(quest.isCompleted ? "Completed." : "Incomplete.")")
                        }
                    }

                    if viewModel.activeQuests.count > 3 {
                        Button(action: { showQuestSheet = true }) {
                            Text("View all quests →")
                                .font(.caption.bold())
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(10)
                        }
                        .accessibilityLabel("View all \(viewModel.activeQuests.count) quests")
                    }
                }
            }

            // MARK: Badges Preview
            if !viewModel.allBadges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Badges")
                            .font(.headline)
                            .foregroundColor(.white)
                            .accessibilityAddTraits(.isHeader)

                        Spacer()

                        Text("\(viewModel.unlockedBadges.count)/\(viewModel.allBadges.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("\(viewModel.unlockedBadges.count) of \(viewModel.allBadges.count) badges unlocked")
                    }

                    HStack(spacing: 8) {
                        ForEach(viewModel.unlockedBadges.prefix(3), id: \.id) { badge in
                            Text(badge.emoji)
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(AppColors.card)
                                .cornerRadius(8)
                                .accessibilityLabel(badge.name)
                        }

                        if viewModel.allBadges.count > viewModel.unlockedBadges.count {
                            Button(action: { showBadgesSheet = true }) {
                                HStack(spacing: 4) {
                                    Text("+\(viewModel.allBadges.count - viewModel.unlockedBadges.count)")
                                        .font(.caption.bold())
                                    Text("more")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(AppColors.card)
                                .cornerRadius(8)
                            }
                            .accessibilityLabel("\(viewModel.allBadges.count - viewModel.unlockedBadges.count) more badges to unlock")
                        }
                    }

                    if viewModel.allBadges.count > 3 {
                        Button(action: { showBadgesSheet = true }) {
                            Text("View all badges →")
                                .font(.caption.bold())
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(10)
                        }
                        .accessibilityLabel("View all \(viewModel.allBadges.count) badges")
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .sheet(isPresented: $showQuestSheet) {
            QuestListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBadgesSheet) {
            BadgeCollectionView(viewModel: viewModel)
        }
    }

    // MARK: Helpers

    private func streakTypeLabel(_ type: String) -> String {
        switch type {
        case "checkin":              return "Check-in Streak"
        case "injection":            return "Injection Streak"
        case "supplement_compliance": return "Supplement Streak"
        default:                     return type.capitalized
        }
    }

    private func flameMark(_ level: Int) -> String {
        String(repeating: "🔥", count: max(0, min(level, 5)))
    }
}

#Preview {
    Text("Preview unavailable in this context")
}
