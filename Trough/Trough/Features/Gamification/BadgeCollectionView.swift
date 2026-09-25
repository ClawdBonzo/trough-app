import SwiftUI

/// Sheet wrapper around the 1.4 badge wall (kept for existing call sites).
struct BadgeCollectionView: View {
    @ObservedObject var viewModel: GamificationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BadgeWallView(viewModel: viewModel)
                .navigationTitle(Text(verbatim: gLoc("ach.badges.title", "Badge wall")))
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
