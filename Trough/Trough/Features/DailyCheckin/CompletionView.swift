import SwiftUI

// MARK: - Screen 3: Completion

struct CompletionView: View {
    @EnvironmentObject private var vm: DailyCheckinViewModel

    @State private var visibleItems: Int = 0
    @State private var showTick = false
    @State private var tickPulse = false
    @State private var showInsight = false

    @State private var hkValues: HKSnapshot? = nil

    private let healthItems: [(icon: String, label: String, keyPath: KeyPath<HKSnapshot, String>)] = [
        ("waveform.path.ecg",  NSLocalizedString("completion.hrv", comment: ""),       \.hrv),
        ("moon.zzz.fill",      NSLocalizedString("completion.sleep", comment: ""),     \.sleep),
        ("figure.walk",        NSLocalizedString("completion.steps", comment: ""),     \.steps),
        ("heart.fill",         NSLocalizedString("completion.restingHR", comment: ""), \.hr),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Cycle day badge
                if let info = vm.cycleInfo {
                    VStack(spacing: 4) {
                        Text(String(format: NSLocalizedString("completion.cycleDay", comment: ""), info.day, info.totalDays))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.accent)
                        Text(NSLocalizedString("completion.injectionCycle", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ProgressView(value: info.progressFraction)
                            .tint(AppColors.accent)
                            .frame(width: 140)
                            .padding(.top, 2)
                    }
                }

                // HealthKit sync items
                VStack(spacing: 0) {
                    ForEach(Array(healthItems.enumerated()), id: \.offset) { index, item in
                        if index < visibleItems {
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 20)
                                Text(item.label)
                                    .foregroundColor(.white)
                                Spacer()
                                if let snap = hkValues {
                                    let val = snap[keyPath: item.keyPath]
                                    if val == "–" {
                                        Text(NSLocalizedString("completion.noData", comment: ""))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(val)
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "#27AE60"))
                                    }
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "#27AE60"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .transition(.move(edge: .trailing).combined(with: .opacity))

                            if index < healthItems.count - 1 {
                                Divider()
                                    .background(Color.secondary.opacity(0.15))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .background(AppColors.card)
                .cornerRadius(16)
                .padding(.horizontal)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visibleItems)

                // Instant insight
                if showInsight, let result = vm.insightResult {
                    InsightCard(result: result)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Animated tick
                if showTick {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(tickPulse ? 0.25 : 0.08))
                            .frame(
                                width: tickPulse ? 120 : 96,
                                height: tickPulse ? 120 : 96
                            )
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: tickPulse
                            )

                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(AppColors.accent)
                    }
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .onAppear { tickPulse = true }
                }

                Text(DisclaimerService.standard)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
        .navigationTitle(NSLocalizedString("completion.title", comment: ""))
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Auto-populate checkin with HealthKit data in parallel with animation
            async let populate: () = {
                if let checkin = vm.savedCheckin {
                    await HealthKitService.shared.autoPopulateCheckin(checkin)
                    let snap = HKSnapshot(
                        hrv:   checkin.hrv.map    { String(format: "%.0f ms", $0) } ?? "–",
                        sleep: checkin.sleepHours.map { String(format: "%.1f hrs", $0) } ?? "–",
                        steps: checkin.stepCount.map  { "\($0)" } ?? "–",
                        hr:    checkin.restingHR.map  { String(format: "%.0f bpm", $0) } ?? "–"
                    )
                    await MainActor.run { hkValues = snap }
                }
            }()

            // Stagger checkmarks
            for i in 1...healthItems.count {
                try? await Task.sleep(nanoseconds: 450_000_000)
                withAnimation { visibleItems = i }
            }

            _ = await populate

            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { showTick = true }

            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation { showInsight = true }

            try? await Task.sleep(nanoseconds: 2_500_000_000)
            vm.navigationPath = []
        }
    }
}

// MARK: - HKSnapshot (display values for CompletionView)

struct HKSnapshot {
    let hrv: String
    let sleep: String
    let steps: String
    let hr: String
}

// MARK: - InsightCard

struct InsightCard: View {
    let result: InsightResult

    private var accentColor: Color {
        switch result.type {
        case .warning:  return Color(hex: "#F39C12")
        case .positive: return Color(hex: "#27AE60")
        case .neutral:  return .secondary
        }
    }

    private var icon: String {
        switch result.type {
        case .warning:  return "exclamationmark.triangle.fill"
        case .positive: return "checkmark.seal.fill"
        case .neutral:  return "lightbulb.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                    .font(.subheadline)
                Text(result.message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclaimerBanner(type: .insight)
        }
        .padding(14)
        .background(accentColor.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}
