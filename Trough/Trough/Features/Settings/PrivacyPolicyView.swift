import SwiftUI

// MARK: - PrivacyPolicyView

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            TRBackground(glow: TR.Palette.teal)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Hero
                    VStack(alignment: .leading, spacing: 10) {
                        GlassIconTile(systemImage: "lock.shield.fill", tint: TR.Palette.teal, size: 48, filled: true)
                        Text(NSLocalizedString("privacy.hero.title", value: "Private by design", comment: "Privacy screen hero title"))
                            .font(TR.Font.display(.title2))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text(NSLocalizedString("privacy.hero.subtitle", value: "No account. No cloud. Your data stays on this device.", comment: "Privacy screen hero subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .trCard(tint: TR.Palette.teal)

                    privacySection(
                        icon: "lock.shield.fill",
                        title: "Your Data Never Leaves Your Device",
                        body: "All your check-ins, injections, bloodwork, and protocol data are stored only on this device. There is no account and no cloud — your health data is never uploaded to a server. The one exception: if you subscribe to Trough Pro, anonymous subscription and receipt data is processed by Apple and RevenueCat to manage your subscription. Your health data is never part of that."
                    )
                    privacySection(
                        icon: "heart.text.square.fill",
                        title: "HealthKit Stays Private",
                        body: "HRV, sleep, steps, and resting HR are read from HealthKit to auto-fill your check-in. This data never leaves your device and is never shared with third parties."
                    )
                    privacySection(
                        icon: "drop.fill",
                        title: "Bloodwork Photos",
                        body: "Lab result photos are stored locally on your device only. They are never uploaded anywhere, and no one but you can ever see them."
                    )
                    privacySection(
                        icon: "hand.raised.fill",
                        title: "No Analytics, No Tracking",
                        body: "Trough has no analytics and no tracking. We collect nothing about how you use the app, and your data is never sold, rented, or shared with anyone. Subscriptions are validated by Apple and RevenueCat using anonymous receipt data only — no health data, no analytics, no tracking."
                    )
                    privacySection(
                        icon: "trash.fill",
                        title: "Data Deletion",
                        body: "You can delete any entry at any time. Because everything lives on your device, deleting the app permanently and irreversibly erases all of your data."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Full Policy & Terms")
                            .font(TR.Font.display(.headline))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Link("Privacy Policy → gwlabs.app/privacy",
                             destination: URL(string: "https://gwlabs.app/privacy")!)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TR.Palette.coralLight)
                            .frame(minHeight: TR.Metrics.minTap)
                        Link("Terms of Use → gwlabs.app/terms",
                             destination: URL(string: "https://gwlabs.app/terms")!)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TR.Palette.coralLight)
                            .frame(minHeight: TR.Metrics.minTap)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .trCard()
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            GlassIconTile(systemImage: icon, tint: TR.Palette.teal, size: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(TR.Font.display(.headline, weight: .bold))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .trCard()
    }
}
