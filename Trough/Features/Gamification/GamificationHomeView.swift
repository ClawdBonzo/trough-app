import SwiftUI

struct GamificationHomeView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @State private var showQuestSheet = false
    @State private var showBadgesSheet = false

    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Level Hero Section
            HStack(spacing: 20) {
                // Level circle with XP progress
                VStack(spacing: 8) {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(Color(#colorLiteral(red: 0.086, green: 0.131, blue: 0.243, alpha: 1)))
                            .frame(width: 100, height: 100)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: viewModel.levelProgressPercent)
                            .stroke(
                                Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: viewModel.levelProgressPercent)

                        // Level text
                        VStack(spacing: 2) {
                            Text(String(viewModel.currentLevel))
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(.white)
                            Text("\(Int(viewModel.levelProgressPercent * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Level info
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.levelName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(viewModel.currentXP) XP Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // XP Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.xpUntilNextLevel) XP until level \(viewModel.currentLevel + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        ProgressView(value: viewModel.levelProgressPercent)
                            .tint(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                            .frame(height: 6)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
            .cornerRadius(12)

            // MARK: - Streaks Section
            if !viewModel.streakStates.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔥 Your Streaks")
                        .font(.headline)
                        .foregroundColor(.white)

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
                                        .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                                    flameEmoji(streak.flameLevel)
                                        .font(.title2)
                                }
                            }
                            .padding(12)
                            .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // MARK: - Quests Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("⚔️ Daily Quests")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    let completed = viewModel.activeQuests.filter { $0.isCompleted }.count
                    Text("\(completed)/\(viewModel.activeQuests.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                                        .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                                    if quest.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(#colorLiteral(red: 0.153, green: 0.682, blue: 0.376, alpha: 1)))
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
                            .cornerRadius(8)
                        }
                    }

                    if viewModel.activeQuests.count > 3 {
                        Button(action: { showQuestSheet = true }) {
                            Text("View all quests →")
                                .font(.caption.bold())
                                .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(10)
                        }
                    }
                }
            }

            // MARK: - Badges Preview
            if !viewModel.allBadges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("🏆 Badges")
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(viewModel.unlockedBadges.count)/\(viewModel.allBadges.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        ForEach(viewModel.unlockedBadges.prefix(3), id: \.id) { badge in
                            Text(badge.emoji)
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
                                .cornerRadius(8)
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
                                .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
                                .cornerRadius(8)
                            }
                        }
                    }

                    if viewModel.allBadges.count > 3 {
                        Button(action: { showBadgesSheet = true }) {
                            Text("View all badges →")
                                .font(.caption.bold())
                                .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(10)
                        }
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

    // MARK: - Helper Functions

    private func streakTypeLabel(_ type: String) -> String {
        switch type {
        case "checkin": return "Check-in Streak"
        case "injection": return "Injection Streak"
        case "supplement_compliance": return "Supplement Streak"
        default: return type
        }
    }

    private func flameEmoji(_ level: Int) -> Text {
        switch level {
        case 0: return Text("")
        case 1: return Text("🔥")
        case 2: return Text("🔥🔥")
        case 3: return Text("🔥🔥🔥")
        case 4: return Text("🔥🔥🔥🔥")
        case 5: return Text("🔥🔥🔥🔥🔥")
        default: return Text("🔥")
        }
    }
}

#Preview {
    Text("Preview not available")
}
