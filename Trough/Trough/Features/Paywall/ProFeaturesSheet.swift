import SwiftUI

/// Modal sheet listing what Trough Pro includes. Designed to create the "aha moment"
/// before asking the user to open the paywall.
struct ProFeaturesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onStartTrial: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.softCTA)
                            Text(NSLocalizedString("pro.title", comment: ""))
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text(NSLocalizedString("pro.trialIncluded", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)

                        // Feature list
                        VStack(alignment: .leading, spacing: 16) {
                            ProFeatureItem(
                                icon: "waveform.path.ecg",
                                title: NSLocalizedString("pro.pkCurves", comment: ""),
                                detail: NSLocalizedString("pro.pkCurvesDesc", comment: "")
                            )
                            ProFeatureItem(
                                icon: "chart.line.uptrend.xyaxis",
                                title: NSLocalizedString("pro.trendHistory", comment: ""),
                                detail: NSLocalizedString("pro.trendHistoryDesc", comment: "")
                            )
                            ProFeatureItem(
                                icon: "drop.fill",
                                title: NSLocalizedString("pro.bloodwork", comment: ""),
                                detail: NSLocalizedString("pro.bloodworkDesc", comment: "")
                            )
                            ProFeatureItem(
                                icon: "chart.bar.doc.horizontal",
                                title: NSLocalizedString("pro.reports", comment: ""),
                                detail: NSLocalizedString("pro.reportsDesc", comment: "")
                            )
                            ProFeatureItem(
                                icon: "pills.fill",
                                title: NSLocalizedString("pro.peptides", comment: ""),
                                detail: NSLocalizedString("pro.peptidesDesc", comment: "")
                            )
                            ProFeatureItem(
                                icon: "figure.walk.circle",
                                title: NSLocalizedString("pro.siteRotation", comment: ""),
                                detail: NSLocalizedString("pro.siteRotationDesc", comment: "")
                            )
                            ProFeatureItem(
                                icon: "bell.badge.fill",
                                title: NSLocalizedString("pro.reminders", comment: ""),
                                detail: NSLocalizedString("pro.remindersDesc", comment: "")
                            )
                        }
                        .padding(16)
                        .background(AppColors.card)
                        .cornerRadius(16)

                        // Always free callout
                        HStack(spacing: 10) {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("pro.alwaysFree", comment: ""))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(NSLocalizedString("pro.alwaysFreeDesc", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(AppColors.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )

                        // CTA
                        Button {
                            dismiss()
                            onStartTrial()
                        } label: {
                            Text(NSLocalizedString("paywall.startTrial", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppColors.softCTA)
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Feature Item

private struct ProFeatureItem: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.softCTA)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
