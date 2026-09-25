import SwiftUI
import RevenueCat

/// Modal sheet listing what Trough Pro includes. Designed to create the "aha moment"
/// before asking the user to open the paywall.
struct ProFeaturesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onStartTrial: () -> Void
    @State private var trialAvailable = false

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground(glow: TR.Palette.coral, glowOpacity: 0.2)
                ProSunsetGlow()

                ScrollView {
                    VStack(spacing: 22) {
                        // Header
                        VStack(spacing: 10) {
                            OnboardingIconTile(systemImage: "star.fill",
                                               colors: [TR.Palette.gold, TR.Palette.tangerine, TR.Palette.coral],
                                               size: 60)
                                .trPopOnAppear()
                            Text(NSLocalizedString("pro.title", comment: ""))
                                .font(TR.Font.display(.title2, weight: .black))
                                .foregroundStyle(TR.Palette.textPrimary)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            if trialAvailable {
                                TRPill(Text(NSLocalizedString("pro.trialIncluded", comment: "")),
                                       systemImage: "gift.fill", tint: TR.Palette.teal)
                            }
                        }
                        .padding(.top, 8)
                        .trRevealOnAppear()

                        // Feature list
                        VStack(alignment: .leading, spacing: 16) {
                            OnboardingFeatureRow(
                                icon: "waveform.path.ecg",
                                title: NSLocalizedString("pro.pkCurves", comment: ""),
                                detail: NSLocalizedString("pro.pkCurvesDesc", comment: ""),
                                tint: OnboardingTint.coral
                            )
                            OnboardingFeatureRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: NSLocalizedString("pro.trendHistory", comment: ""),
                                detail: NSLocalizedString("pro.trendHistoryDesc", comment: ""),
                                tint: OnboardingTint.gold
                            )
                            OnboardingFeatureRow(
                                icon: "drop.fill",
                                title: NSLocalizedString("pro.bloodwork", comment: ""),
                                detail: NSLocalizedString("pro.bloodworkDesc", comment: ""),
                                tint: OnboardingTint.sky
                            )
                            OnboardingFeatureRow(
                                icon: "chart.bar.doc.horizontal",
                                title: NSLocalizedString("pro.reports", comment: ""),
                                detail: NSLocalizedString("pro.reportsDesc", comment: ""),
                                tint: OnboardingTint.lilac
                            )
                            OnboardingFeatureRow(
                                icon: "pills.fill",
                                title: NSLocalizedString("pro.peptides", comment: ""),
                                detail: NSLocalizedString("pro.peptidesDesc", comment: ""),
                                tint: OnboardingTint.mint
                            )
                            OnboardingFeatureRow(
                                icon: "figure.walk.circle.fill",
                                title: NSLocalizedString("pro.siteRotation", comment: ""),
                                detail: NSLocalizedString("pro.siteRotationDesc", comment: ""),
                                tint: OnboardingTint.teal
                            )
                        }
                        .trCard(tint: TR.Palette.coral, padding: 16)
                        .trRevealOnAppear(delay: 0.1)

                        // Always free callout
                        HStack(spacing: 12) {
                            OnboardingIconTile(systemImage: "heart.text.square.fill", colors: OnboardingTint.mint, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("pro.alwaysFree", comment: ""))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(TR.Palette.textPrimary)
                                Text(NSLocalizedString("pro.alwaysFreeDesc", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(TR.Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .trCard(tint: TR.Palette.mint, padding: 14)
                        .accessibilityElement(children: .combine)
                        .trRevealOnAppear(delay: 0.16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // CTA — opens the paywall, which shows price, period and renewal terms.
                    Button {
                        dismiss()
                        onStartTrial()
                    } label: {
                        Text(trialAvailable
                             ? NSLocalizedString("paywall.startTrial", comment: "")
                             : NSLocalizedString("dashboard.trial.subscribeButton", comment: ""))
                    }
                    .buttonStyle(.trPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background {
                        LinearGradient(colors: [TR.Palette.background.opacity(0), TR.Palette.background],
                                       startPoint: .top, endPoint: .center)
                            .ignoresSafeArea()
                    }
                }
            }
            .task {
                guard let offering = await RevenueCatService.shared.fetchOfferings()?.current else { return }
                let products = offering.availablePackages.map(\.storeProduct)
                let eligibility = await RevenueCatService.shared.trialEligibility(for: products)
                trialAvailable = eligibility.values.contains(true)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TR.Palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(TR.Palette.surfaceRaised.opacity(0.8), in: Circle())
                    }
                    .accessibilityLabel(Text(onbLoc("onb14.close", "Close")))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
