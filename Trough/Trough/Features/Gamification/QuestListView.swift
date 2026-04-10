import SwiftUI

struct QuestListView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @Environment(\.dismiss) var dismiss

    var dailyQuests: [QuestDisplayModel] {
        viewModel.activeQuests.filter { $0.frequency == "daily" }
    }

    var weeklyQuests: [QuestDisplayModel] {
        viewModel.activeQuests.filter { $0.frequency == "weekly" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Daily Quests Section
                    if !dailyQuests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Quests")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            VStack(spacing: 10) {
                                ForEach(dailyQuests, id: \.id) { quest in
                                    questRow(quest)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // MARK: - Weekly Quests Section
                    if !weeklyQuests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Weekly Quests")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            VStack(spacing: 10) {
                                ForEach(weeklyQuests, id: \.id) { quest in
                                    questRow(quest)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if viewModel.activeQuests.isEmpty {
                        VStack(spacing: 12) {
                            Text("🎯")
                                .font(.system(size: 48))
                            Text("No quests yet")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Come back tomorrow for new quests!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(20)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("All Quests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                }
            }
            .background(Color(#colorLiteral(red: 0.102, green: 0.102, blue: 0.180, alpha: 1)))
        }
    }

    private func questRow(_ quest: QuestDisplayModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(quest.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(quest.xpReward) XP")
                    .font(.caption.bold())
                    .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                if quest.isCompleted {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(Color(#colorLiteral(red: 0.153, green: 0.682, blue: 0.376, alpha: 1)))
                }
            }
        }
        .padding(12)
        .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
        .cornerRadius(8)
    }
}

#Preview {
    Text("Preview not available")
}
