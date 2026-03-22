import SwiftUI

// MARK: - HealthKitPermissionView

/// Shown once before onboarding. Explains what data Trough reads and why.
struct HealthKitPermissionView: View {
    @AppStorage("hkPermissionRequested") private var hkPermissionRequested = false
    @State private var isRequesting = false
    @State private var errorMessage: String?

    private let dataPoints: [(icon: String, title: String, detail: String)] = [
        ("waveform.path.ecg.rectangle.fill", "HRV",          "Heart rate variability — stress & recovery signal"),
        ("bed.double.fill",                  "Sleep",         "Core, Deep & REM stages from last night"),
        ("figure.walk",                      "Steps & Energy","Daily movement to correlate with protocol"),
        ("heart.fill",                       "Resting HR",    "Cardiovascular baseline over time"),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon + headline
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.accent)
                    }

                    VStack(spacing: 8) {
                        Text("Connect Health")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Trough reads your biometrics to find patterns in your hormone protocol.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer().frame(height: 36)

                // Data list
                VStack(spacing: 0) {
                    ForEach(dataPoints, id: \.title) { point in
                        HStack(spacing: 14) {
                            Image(systemName: point.icon)
                                .font(.title3)
                                .foregroundColor(AppColors.accent)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(point.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        if point.title != dataPoints.last?.title {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(AppColors.card)
                .cornerRadius(16)
                .padding(.horizontal, 20)

                Spacer().frame(height: 16)

                // Privacy note
                Label("Read-only. We never sell your health data.", systemImage: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                Spacer()

                // CTA buttons
                VStack(spacing: 12) {
                    Button {
                        isRequesting = true
                        Task {
                            do {
                                try await HealthKitService.shared.requestPermissions()
                            } catch {
                                errorMessage = "Could not request permissions. You can enable Health access in Settings."
                            }
                            isRequesting = false
                            hkPermissionRequested = true
                        }
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Allow Access")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isRequesting)

                    Button("Not Now") {
                        hkPermissionRequested = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - HealthKitDeniedBanner

/// Inline banner shown when HealthKit is denied. Tap opens Settings.
struct HealthKitDeniedBanner: View {
    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.slash.fill")
                    .foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Health access denied")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("Tap to open Settings and enable Health access.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(AppColors.card)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - No-data placeholder

struct HealthKitNoDataView: View {
    let label: String

    var body: some View {
        Text("No data available")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
    }
}
