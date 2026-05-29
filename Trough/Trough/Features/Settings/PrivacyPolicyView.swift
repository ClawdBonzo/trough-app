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
                        title: "Your Data Never Leaves Your Device",
                        body: "All your check-ins, injections, bloodwork, and protocol data are stored only on this device. There is no account and no cloud — nothing is ever uploaded to a server."
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
                        body: "Trough has no analytics and no tracking. We collect nothing about how you use the app, and your data is never sold, rented, or shared with anyone."
                    )
                    privacySection(
                        icon: "trash.fill",
                        title: "Data Deletion",
                        body: "You can delete any entry at any time. Because everything lives on your device, deleting the app permanently and irreversibly erases all of your data."
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
