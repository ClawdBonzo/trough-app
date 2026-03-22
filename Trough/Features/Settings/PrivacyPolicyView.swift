import SwiftUI

// MARK: - PrivacyPolicyView

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    privacySection(
                        icon: "lock.shield.fill",
                        title: "Your Data Stays Yours",
                        body: "All your check-ins, injections, and protocol data are stored locally on your device first. Sync to our servers happens only while you're online and only to back up your data."
                    )
                    privacySection(
                        icon: "heart.text.square.fill",
                        title: "HealthKit Data Never Leaves Your Device",
                        body: "HRV, sleep, steps, and resting HR are read from HealthKit to auto-fill your check-in. This data is never transmitted to our servers and never shared with third parties."
                    )
                    privacySection(
                        icon: "drop.fill",
                        title: "Bloodwork Photos",
                        body: "Lab result photos are uploaded to secure, encrypted Supabase Storage with row-level security. Only you can access your photos — no Trough employee or third party can view them."
                    )
                    privacySection(
                        icon: "server.rack",
                        title: "Encrypted Sync",
                        body: "When syncing to our servers, all data is transmitted over HTTPS. Your account is secured via Supabase Auth. We store only the data required to provide the service."
                    )
                    privacySection(
                        icon: "hand.raised.fill",
                        title: "We Don't Sell Your Data",
                        body: "Your health data is never sold, rented, or shared with advertisers. We use privacy-focused analytics (PostHog) solely to understand feature usage and improve the app. No personal health data is included in analytics events."
                    )
                    privacySection(
                        icon: "trash.fill",
                        title: "Data Deletion",
                        body: "You can delete your account and all associated data at any time by contacting support@gettrough.app. Deletion is permanent and irreversible."
                    )

                    Divider()
                        .background(Color.secondary.opacity(0.2))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Policy & Terms")
                            .font(.headline)
                            .foregroundColor(.white)
                        Link("Privacy Policy → gettrough.app/privacy",
                             destination: URL(string: "https://gettrough.app/privacy")!)
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                        Link("Terms of Use → gettrough.app/terms",
                             destination: URL(string: "https://gettrough.app/terms")!)
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text(body)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#A0A0C0"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
