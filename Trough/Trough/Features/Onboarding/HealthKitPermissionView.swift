import SwiftUI

// MARK: - HealthKitPermissionView

/// Shown once before onboarding. Explains what data Trough reads and why.
struct HealthKitPermissionView: View {
    @AppStorage("hkPermissionRequested") private var hkPermissionRequested = false
    @State private var isRequesting = false
    @State private var errorMessage: String?

    private let dataPoints: [(icon: String, title: String, detail: String)] = [
        ("waveform.path.ecg.rectangle.fill", NSLocalizedString("hk.hrv", comment: ""),          NSLocalizedString("hk.hrvDesc", comment: "")),
        ("bed.double.fill",                  NSLocalizedString("hk.sleep", comment: ""),         NSLocalizedString("hk.sleepDesc", comment: "")),
        ("figure.walk",                      NSLocalizedString("hk.stepsEnergy", comment: ""),         NSLocalizedString("hk.stepsEnergyDesc", comment: "")),
        ("heart.fill",                       NSLocalizedString("hk.restingHR", comment: ""),     NSLocalizedString("hk.restingHRDesc", comment: "")),
    ]

    private let tints: [[Color]] = [OnboardingTint.coral, OnboardingTint.lilac, OnboardingTint.teal, [Color(trHex: 0xFF6B81), Color(trHex: 0xE0245E)]]

    var body: some View {
        ZStack {
            TRBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Icon + headline
                        VStack(spacing: 16) {
                            OnboardingIconTile(systemImage: "heart.text.square.fill",
                                               colors: [Color(trHex: 0xFF6B81), TR.Palette.coral, Color(trHex: 0xC2304F)],
                                               size: 76)
                                .trPopOnAppear()

                            VStack(spacing: 8) {
                                Text(NSLocalizedString("hk.title", comment: ""))
                                    .font(TR.Font.display(.title, weight: .black))
                                    .foregroundStyle(TR.Palette.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .accessibilityAddTraits(.isHeader)
                                Text(NSLocalizedString("hk.subtitle", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(TR.Palette.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .trRevealOnAppear()

                        // Data list
                        VStack(spacing: 16) {
                            ForEach(Array(dataPoints.enumerated()), id: \.element.title) { index, point in
                                OnboardingFeatureRow(icon: point.icon, title: point.title, detail: point.detail,
                                                     tint: tints[index % tints.count])
                            }
                        }
                        .trCard(padding: 16)
                        .trRevealOnAppear(delay: 0.1)

                        // Privacy note
                        Label(NSLocalizedString("hk.privacy", comment: ""), systemImage: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(TR.Palette.textSecondary)
                            .multilineTextAlignment(.center)

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(TR.Palette.coralLight)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 16)
                }

                // CTA buttons
                VStack(spacing: 8) {
                    Button {
                        isRequesting = true
                        Task {
                            do {
                                try await HealthKitService.shared.requestPermissions()
                            } catch {
                                errorMessage = NSLocalizedString("hk.permissionError", comment: "")
                            }
                            isRequesting = false
                            hkPermissionRequested = true
                        }
                    } label: {
                        Group {
                            if isRequesting {
                                ProgressView().tint(.white)
                            } else {
                                Text(NSLocalizedString("hk.allow", comment: ""))
                            }
                        }
                    }
                    .buttonStyle(.trPrimary)
                    .disabled(isRequesting)

                    Button {
                        hkPermissionRequested = true
                    } label: {
                        Text(NSLocalizedString("hk.notNow", comment: ""))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TR.Palette.textSecondary)
                            .frame(minHeight: TR.Metrics.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
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
                    Text(NSLocalizedString("hk.denied", comment: ""))
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text(NSLocalizedString("hk.deniedDesc", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(TR.Palette.surface, in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                    .strokeBorder(TR.Palette.coral.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - No-data placeholder

struct HealthKitNoDataView: View {
    let label: String

    var body: some View {
        Text(NSLocalizedString("hk.noData", comment: ""))
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
    }
}
