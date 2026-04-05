import SwiftUI
import SwiftData

// MARK: - Entry point (tab root + NavigationStack host)

struct DailyCheckinView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("userType") private var userType = "trt"

    @StateObject private var vm = DailyCheckinViewModel()

    var body: some View {
        NavigationStack(path: $vm.navigationPath) {
            MetricsScreenView()
                .navigationDestination(for: DailyCheckinStep.self) { step in
                    switch step {
                    case .binaryTaps: BinaryTapsView()
                    case .completion: CompletionView()
                    }
                }
        }
        .environmentObject(vm)
        .onAppear {
            let uid = SupabaseService.resolvedUserUUID ?? UUID() // FIXED: use real Supabase user ID
            vm.setup(context: modelContext, userID: uid)
        }
    }
}

// MARK: - Screen 1: Metrics

private struct MetricsScreenView: View {
    @EnvironmentObject private var vm: DailyCheckinViewModel
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("trackBodyWeight") private var trackBodyWeight = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    scorePreview
                    slidersCard
                    if userType == "natural" || (userType == "trt" && trackBodyWeight) {
                        naturalExtrasCard
                    }
                    Text(DisclaimerService.standard)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    nextButton
                }
                .padding()
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(NSLocalizedString("common.done", comment: "")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(NSLocalizedString("checkin.title", comment: ""))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Text(vm.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let info = vm.cycleInfo {
                    Text(String(format: NSLocalizedString("checkin.cycleDay", comment: ""), info.day, info.totalDays))
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Score preview

    private var scorePreview: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("checkin.protocolScore", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f", vm.currentScore))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.accent)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: vm.currentScore)
            }
            Spacer()
            CircularProgressView(progress: vm.currentScore / 100)
                .frame(width: 64, height: 64)
        }
        .cardStyle()
    }

    // MARK: Sliders

    private var slidersCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("checkin.wellnessMetrics", comment: ""))
                .font(.headline)
                .foregroundColor(.secondary)

            HapticSlider(emoji: "⚡️", label: NSLocalizedString("checkin.energy", comment: ""),        value: $vm.energyScore)
            HapticSlider(emoji: "😌", label: NSLocalizedString("checkin.mood", comment: ""),          value: $vm.moodScore)
            HapticSlider(emoji: "🔥", label: NSLocalizedString("checkin.libido", comment: ""),        value: $vm.libidoScore)
            HapticSlider(emoji: "🌙", label: NSLocalizedString("checkin.sleepQuality", comment: ""), value: $vm.sleepQualityScore)
            HapticSlider(emoji: "🧠", label: NSLocalizedString("checkin.mentalClarity", comment: ""),value: $vm.mentalClarityScore)
        }
        .cardStyle()
    }

    // MARK: Natural user extras

    private var naturalExtrasCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("checkin.bodyMetrics", comment: ""))
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.usesMetricWeight ? NSLocalizedString("checkin.weight.kg", comment: "") : NSLocalizedString("checkin.weight.lbs", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(vm.usesMetricWeight ? "e.g. 82.5" : "e.g. 182", text: $vm.bodyWeightInput)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(AppColors.background)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("checkin.bodyFat", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("checkin.optional", comment: ""), text: $vm.bodyFatInput)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(AppColors.background)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
        }
        .cardStyle()
    }

    // MARK: Next button

    private var nextButton: some View {
        Button {
            vm.navigationPath = [.binaryTaps]
        } label: {
            HStack {
                Text(NSLocalizedString("common.next", comment: ""))
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.accent)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
    }
}

// MARK: - Circular progress indicator

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.secondary.opacity(0.3), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4), value: progress)
        }
    }
}
