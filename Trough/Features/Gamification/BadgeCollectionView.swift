import SwiftUI

struct BadgeCollectionView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @Environment(\.dismiss) var dismiss

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.allBadges, id: \.id) { badge in
                        badgeCard(badge)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Badges")
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

    private func badgeCard(_ badge: BadgeDisplayModel) -> some View {
        VStack(spacing: 8) {
            Text(badge.emoji)
                .font(.system(size: 40))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)

                if badge.isUnlocked {
                    if let date = badge.unlockedDate {
                        Text(dateString(date))
                            .font(.caption2)
                            .foregroundColor(Color(#colorLiteral(red: 0.153, green: 0.682, blue: 0.376, alpha: 1)))
                    }
                } else {
                    Text("Locked")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !badge.isUnlocked {
                Text(badge.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding(12)
        .background(
            badge.isUnlocked
                ? Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1))
                : Color(#colorLiteral(red: 0.060, green: 0.060, blue: 0.095, alpha: 1))
        )
        .cornerRadius(8)
        .opacity(badge.isUnlocked ? 1.0 : 0.6)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "Unlocked \(formatter.string(from: date))"
    }
}

#Preview {
    Text("Preview not available")
}
