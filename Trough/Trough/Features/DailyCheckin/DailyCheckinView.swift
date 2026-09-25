import SwiftUI
import SwiftData

// MARK: - Entry point (tab root + NavigationStack host)

struct DailyCheckinView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("userType") private var userType = "trt"
    @EnvironmentObject private var gamificationVM: GamificationViewModel

    @StateObject private var vm = DailyCheckinViewModel()
    #if DEBUG
    @State private var didHandleScreenshotHook = false
    #endif

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
            let uid = UUID(uuidString: userIDString) ?? UUID()
            vm.setup(context: modelContext, userID: uid)
            vm.gamificationVM = gamificationVM
            #if DEBUG
            if !didHandleScreenshotHook, ProcessInfo.processInfo.arguments.contains("-TRShowCompletion") {
                didHandleScreenshotHook = true
                vm.presentLatestCompletionForScreenshots()
            }
            #endif
        }
    }
}

// MARK: - Metric descriptor

private struct CheckinMetric: Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let tint: Color
    let value: ReferenceWritableKeyPath<DailyCheckinViewModel, Double>
}

// MARK: - Screen 1: Metrics

private struct MetricsScreenView: View {
    @EnvironmentObject private var vm: DailyCheckinViewModel
    @EnvironmentObject private var gamificationVM: GamificationViewModel
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("trackBodyWeight") private var trackBodyWeight = false

    private var metrics: [CheckinMetric] {
        [
            CheckinMetric(id: "energy", label: NSLocalizedString("checkin.energy", comment: ""), systemImage: "bolt.fill", tint: TR.Palette.gold, value: \.energyScore),
            CheckinMetric(id: "mood", label: NSLocalizedString("checkin.mood", comment: ""), systemImage: "face.smiling.fill", tint: TR.Palette.sky, value: \.moodScore),
            CheckinMetric(id: "libido", label: NSLocalizedString("checkin.libido", comment: ""), systemImage: "flame.fill", tint: TR.Palette.coral, value: \.libidoScore),
            CheckinMetric(id: "sleep", label: NSLocalizedString("checkin.sleepQuality", comment: ""), systemImage: "moon.stars.fill", tint: TR.Palette.lilac, value: \.sleepQualityScore),
            CheckinMetric(id: "clarity", label: NSLocalizedString("checkin.mentalClarity", comment: ""), systemImage: "brain.head.profile", tint: TR.Palette.teal, value: \.mentalClarityScore),
        ]
    }

    var body: some View {
        ZStack {
            TRBackground()

            ScrollView {
                VStack(spacing: 14) {
                    headerSection
                        .trRevealOnAppear()
                    scoreHero
                        .trRevealOnAppear(delay: 0.05)
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                        HapticSlider(
                            systemImage: metric.systemImage,
                            label: metric.label,
                            tint: metric.tint,
                            value: Binding(get: { vm[keyPath: metric.value] }, set: { vm[keyPath: metric.value] = $0 })
                        )
                        .trCard(tint: metric.tint)
                        .trRevealOnAppear(delay: 0.1 + Double(index) * 0.05)
                    }
                    if userType == "natural" || (userType == "trt" && trackBodyWeight) {
                        naturalExtrasCard
                    }
                    DisclaimerBanner(type: .protocolScore)
                    nextButton
                        .padding(.top, 4)
                }
                .padding(.horizontal, TR.Metrics.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TR.Palette.abyss.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(NSLocalizedString("common.done", comment: "")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
                .foregroundColor(TR.Palette.coral)
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TRKicker(Text(vm.date, format: .dateTime.weekday(.wide).month(.abbreviated).day()), color: TR.Palette.textSecondary)
                Spacer()
                TRKicker(Text(NSLocalizedString("checkin14.step1", value: "Step 1 of 2", comment: "Check-in progress")), color: TR.Palette.coral)
            }
            Text(NSLocalizedString("checkin.title", comment: ""))
                .font(TR.Font.display(34, weight: .black))
                .foregroundStyle(TR.Palette.textPrimary)
            HStack(spacing: 8) {
                if let info = vm.cycleInfo {
                    TRPill(Text(String(format: NSLocalizedString("checkin.dayOf", comment: ""), info.day, info.totalDays)),
                           systemImage: "drop.circle.fill", tint: TR.Palette.coral)
                }
                if gamificationVM.checkinStreakDays > 0 {
                    TRPill(Text(String(format: NSLocalizedString("checkin14.streakDays", value: "%d-day streak", comment: "Check-in streak pill"), gamificationVM.checkinStreakDays)),
                           systemImage: "flame.fill", tint: TR.Palette.gold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: Score hero

    private var scoreHero: some View {
        HStack(spacing: 18) {
            TRRing(progress: vm.currentScore / 100, lineWidth: 12) {
                VStack(spacing: 0) {
                    CountUp(Int(vm.currentScore.rounded()), duration: 0.9)
                        .font(TR.Font.number(36))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .minimumScaleFactor(0.6)
                    TRKicker(Text(NSLocalizedString("checkin14.scoreKicker", value: "Score", comment: "Under the live Protocol Score number")))
                }
            }
            .frame(width: 124, height: 124)

            VStack(alignment: .leading, spacing: 8) {
                TRKicker(Text(NSLocalizedString("checkin.protocolScore", comment: "")), color: TR.Palette.coral)
                Text(NSLocalizedString("checkin14.scoreHint", value: "Updates live as you rate your day.", comment: "Score preview helper"))
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if vm.existingCheckin == nil {
                    TRPill(Text(NSLocalizedString("checkin14.earnXP", value: "Earn +20 XP", comment: "Reward preview pill")),
                           systemImage: "sparkles", tint: TR.Palette.gold)
                } else {
                    TRPill(Text(NSLocalizedString("checkin14.updatingToday", value: "Updating today", comment: "Editing today's check-in")),
                           systemImage: "pencil", tint: TR.Palette.teal)
                }
            }
            Spacer(minLength: 0)
        }
        .trCard(tint: TR.Palette.coral)
        .accessibilityElement(children: .combine)
    }

    // MARK: Natural user extras

    private var naturalExtrasCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TR.Palette.sky)
                    .frame(width: 36, height: 36)
                    .background(TR.Palette.sky.opacity(0.18), in: Circle())
                Text(NSLocalizedString("checkin.bodyMetrics", comment: ""))
                    .font(TR.Font.display(.headline, weight: .bold))
                    .foregroundStyle(TR.Palette.textPrimary)
            }

            HStack(spacing: 12) {
                field(
                    title: String(format: NSLocalizedString("checkin.weight", comment: ""),
                                  vm.usesMetricWeight ? NSLocalizedString("unit.kg", comment: "") : NSLocalizedString("unit.lbs", comment: "")),
                    placeholder: vm.usesMetricWeight ? "e.g. 82.5" : "e.g. 182",
                    text: $vm.bodyWeightInput
                )
                field(
                    title: String(format: NSLocalizedString("checkin.bodyFat", comment: "")),
                    placeholder: NSLocalizedString("checkin.optional", comment: ""),
                    text: $vm.bodyFatInput
                )
            }
        }
        .trCard(tint: TR.Palette.sky)
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(TR.Font.number(.title3, weight: .bold))
                .foregroundStyle(TR.Palette.textPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(TR.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous).strokeBorder(TR.Palette.hairline))
        }
    }

    // MARK: Next button

    private var nextButton: some View {
        Button {
            vm.navigationPath = [.binaryTaps]
        } label: {
            HStack(spacing: 8) {
                Text(NSLocalizedString("checkin.next", comment: ""))
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.trPrimary)
    }
}

// MARK: - Circular progress indicator (legacy)

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        TRRing(progress: progress, lineWidth: 6)
    }
}
