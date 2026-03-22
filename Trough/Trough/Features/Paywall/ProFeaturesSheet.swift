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
                            Text("What You Get With Pro")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("14-day free trial included")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)

                        // Feature list
                        VStack(alignment: .leading, spacing: 16) {
                            ProFeatureItem(
                                icon: "waveform.path.ecg",
                                title: "PK Curves",
                                detail: "See your estimated blood levels with confidence bands and multi-ester stacking"
                            )
                            ProFeatureItem(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Full Trend History",
                                detail: "Unlimited energy, mood, libido, and sleep trend charts (free shows 3 days)"
                            )
                            ProFeatureItem(
                                icon: "drop.fill",
                                title: "Bloodwork Tracking",
                                detail: "Log labs, track trends over time, set custom reference ranges"
                            )
                            ProFeatureItem(
                                icon: "chart.bar.doc.horizontal",
                                title: "Weekly Reports & Export",
                                detail: "PDF and CSV export with doctor notes — perfect for clinic visits"
                            )
                            ProFeatureItem(
                                icon: "pills.fill",
                                title: "Adjuncts & Peptides",
                                detail: "Track AI compounds, peptides, and GLP-1 agonists with E2 correlation"
                            )
                            ProFeatureItem(
                                icon: "figure.walk.circle",
                                title: "Injection Site Rotation",
                                detail: "Visual rotation map to prevent scar tissue buildup"
                            )
                            ProFeatureItem(
                                icon: "bell.badge.fill",
                                title: "Injection Reminders",
                                detail: "Never miss a pin day — smart reminders based on your protocol"
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
                                Text("Always Free")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("Protocol Score, daily check-ins, HealthKit sync, and basic insights")
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onStartTrial()
                            }
                        } label: {
                            Text("Start Free Trial")
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
