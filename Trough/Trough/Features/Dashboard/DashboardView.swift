import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var vm = DashboardViewModel()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var toastManager: ToastManager
    @State var showCheckin = false
    @State var showWeeklyReport = false
    @State var showPaywall = false
    @State var showSampleDataBanner = false
    @State var showProFeatures = false
    @State var showTrialEndedSheet = false
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("userIDString") private var userIDString = UUID().uuidString
    @AppStorage("hasShownTrialEndedScreen") private var hasShownTrialEndedScreen = false
    @AppStorage("hasShownSupplementBanner") private var hasShownSupplementBanner = false
    @State private var showSupplementBanner = false
    @State private var navigateToInjections = false
    @State private var navigateToSupplements = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if vm.isLoading {
                    DashboardSkeletonView()
                        .transition(.opacity)
                } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Greeting + cycle day
                        greetingHeader

                        if showSampleDataBanner { sampleDataBanner }
                        if subscriptionManager.showTrialExpiryWarning {
                            trialExpiryBanner
                        }
                        if subscriptionManager.showGracePeriodWarning {
                            gracePeriodBanner
                        }

                        // Personal best banner
                        if vm.isPersonalBest {
                            personalBestBanner
                        }

                        // Smart insight card
                        if let insight = vm.smartInsight {
                            smartInsightCard(insight)
                        }

                        protocolScoreHero
                        if !vm.activeCompounds.isEmpty || vm.activeProtocol != nil {
                            activeProtocolCard
                        }

                        // Check-in CTA with pulse if not done today
                        checkinCTACard

                        // Injection + supplement compliance side by side
                        if vm.activeProtocol != nil {
                            complianceRow
                        }

                        // NEW: One-time supplement setup banner (post-subscription)
                        if subscriptionManager.isSubscribed && vm.supplementCount == 0 && !hasShownSupplementBanner {
                            supplementSetupBanner
                        }

                        // Weight trend sparkline
                        if vm.latestWeightDisplay != nil {
                            weightTrendCard
                        }

                        streakCard

                        // PK Curve / Body Composition
                        if subscriptionManager.isSubscribed {
                            if userType == "trt" {
                                pkCurveCard
                                if vm.hcgProtocol != nil {
                                    fertilityCard
                                }
                            } else {
                                bodyCompositionCard
                            }
                        } else {
                            if userType == "trt" {
                                pkCurvePreviewCard
                            } else {
                                LockedCard(
                                    icon: "scalemass",
                                    title: NSLocalizedString("dashboard.bodyComposition", comment: ""),
                                    subtitle: NSLocalizedString("dashboard.bodyComposition.subtitle", comment: ""),
                                    onInfo: { showProFeatures = true }
                                ) { showPaywall = true }
                            }
                        }

                        // GLP-1 weight correlation (paid only)
                        if subscriptionManager.isSubscribed && vm.hasGLP1Data {
                            glp1CorrelationCard
                        }

                        // 7-Day Trends bar chart
                        trendChartCard
                        quickStatsCard

                        // Tomorrow's forecast
                        if let forecast = vm.forecastText {
                            forecastCard(forecast)
                        }
                    }
                    .padding()
                }
                } // end else isLoading
            }
            .navigationTitle(NSLocalizedString("dashboard.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.setModelContext(modelContext)
                vm.load()
                showSampleDataBanner = !SampleDataService.hasRealData(context: modelContext)
            }
            .sheet(isPresented: $showCheckin, onDismiss: { vm.load() }) {
                DailyCheckinView()
            }
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showProFeatures) {
                ProFeaturesSheet { showPaywall = true }
            }
            .fullScreenCover(isPresented: $showTrialEndedSheet) {
                TrialEndedView(
                    streak: vm.streak,
                    totalCheckins: vm.streak,  // approximate with streak length
                    latestScore: vm.protocolScore > 0 ? Int(vm.protocolScore) : nil,
                    onSubscribe: {
                        showTrialEndedSheet = false
                        showPaywall = true
                    },
                    onContinueFree: {
                        showTrialEndedSheet = false
                    }
                )
            }
            .onReceive(subscriptionManager.$isInTrial) { inTrial in
                // Show soft downgrade once when trial expires
                if !inTrial && !hasShownTrialEndedScreen && !subscriptionManager.isSubscribed {
                    let trialStarted = UserDefaults.standard.bool(forKey: "trialWasStarted")
                    if trialStarted {
                        hasShownTrialEndedScreen = true
                        showTrialEndedSheet = true
                    }
                }
            }
            .onChange(of: showCheckin) { _, dismissed in
                if !dismissed { vm.checkReviewPrompt() }
            }
            .onAppear {
                // Prompt for review on first dashboard load after onboarding
                vm.checkReviewPrompt()
            }
        }
    }

    // MARK: - Sample Data Banner

    private var sampleDataBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("dashboard.sampleData.title", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
            Text(NSLocalizedString("dashboard.sampleData.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 12) {
                Button(NSLocalizedString("dashboard.sampleData.load", comment: "")) {
                    let userID = SupabaseService.resolvedUserUUID ?? UUID() // FIXED: use real Supabase user ID
                    SampleDataService.insertSampleData(context: modelContext, userID: userID)
                    showSampleDataBanner = false
                    vm.load()
                }
                .font(.subheadline.bold())
                .foregroundColor(AppColors.accent)
                .accessibilityLabel("Load sample check-in and injection data")

                Button(NSLocalizedString("dashboard.sampleData.startCheckin", comment: "")) { showCheckin = true }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .accessibilityLabel("Open daily check-in")
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.accent.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Trial Expiry Banner

    private var trialExpiryBanner: some View {
        let days = subscriptionManager.trialDaysRemaining ?? 0
        return HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title3)
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(days <= 0 ? NSLocalizedString("dashboard.trial.ended", comment: "") : String(format: NSLocalizedString("dashboard.trial.endsIn", comment: ""), days))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(NSLocalizedString("dashboard.trial.subscribe", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(NSLocalizedString("dashboard.trial.subscribeButton", comment: "")) { showPaywall = true }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.accent)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Grace Period Banner

    private var gracePeriodBanner: some View {
        let days = subscriptionManager.graceDaysRemaining ?? 0
        return HStack(spacing: 12) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.title3)
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("dashboard.grace.title", comment: ""))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(String(format: NSLocalizedString("dashboard.grace.subtitle", comment: ""), days))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Active Protocol Card (FREE)

    private var activeProtocolCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(AppColors.accent)
                Text(NSLocalizedString("dashboard.activeProtocol", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            // Primary TRT protocol
            if let proto = vm.activeProtocol {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: proto.colorHex)).frame(width: 8, height: 8)
                    Text(proto.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    if vm.injectionOverdueDays > 0 {
                        Text(NSLocalizedString("dashboard.overdue", comment: ""))
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent)
                            .cornerRadius(4)
                    } else {
                        Text(String(format: NSLocalizedString("dashboard.nextIn", comment: ""), max(0, (vm.activeProtocol?.frequencyDays ?? 7) - vm.daysSinceLastInjection)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Adjuncts / Peptides / GLP-1
            if !vm.activeCompounds.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                ForEach(vm.activeCompounds, id: \.id) { compound in
                    HStack(spacing: 8) {
                        let category = compoundCategory(compound.supplementName)
                        Image(systemName: categoryIcon(category))
                            .font(.caption)
                            .foregroundColor(categoryColor(category))
                            .frame(width: 16)
                        Text(compound.supplementName)
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(formatCompoundDose(compound.doseAmount, unit: compound.doseUnit)) · E\(compound.frequencyDays)D")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.card)
        .cornerRadius(14)
    }

    private func compoundCategory(_ name: String) -> String {
        let glp1 = ["Semaglutide", "Tirzepatide", "Liraglutide"]
        let ai = ["Anastrozole", "Aromasin", "Letrozole", "Cabergoline"]
        if glp1.contains(name) { return "glp1" }
        if ai.contains(name) { return "ai" }
        if name == "hCG" { return "fertility" }
        return "peptide"
    }

    private func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "glp1":      return "scalemass"
        case "ai":        return "shield.lefthalf.filled"
        case "fertility": return "heart.fill"
        default:          return "pills.fill"
        }
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "glp1":      return .green
        case "ai":        return .orange
        case "fertility": return .pink
        default:          return .cyan
        }
    }

    private func formatCompoundDose(_ dose: Double, unit: String) -> String {
        if dose == dose.rounded() { return "\(Int(dose))\(unit)" }
        return String(format: "%.2g%@", dose, unit)
    }

    // MARK: - Protocol Score Hero

    private var protocolScoreHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("dashboard.protocolScore", comment: ""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(vm.interpretation)
                        .font(.title3.bold())
                        .foregroundColor(vm.scoreColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                trendBadge
            }

            HStack(spacing: 24) {
                CircularRingView(score: vm.protocolScore, color: vm.scoreColor)
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: NSLocalizedString("dashboard.7dayAvg", comment: ""), value: String(format: "%.0f", vm.sevenDayAvg))
                    StatRow(label: NSLocalizedString("dashboard.prior7day", comment: ""), value: String(format: "%.0f", vm.priorSevenDayAvg))
                    if vm.recentCheckins.isEmpty {
                        Button {
                            showCheckin = true
                        } label: {
                            Label(NSLocalizedString("dashboard.logToday", comment: ""), systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(AppColors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            DisclaimerBanner(type: .protocolScore)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppColors.card, AppColors.card.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: vm.scoreColor.opacity(0.2), radius: 12)
    }

    private var trendBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: vm.trend >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%+.0f", vm.trend))
        }
        .font(.caption.bold())
        .foregroundColor(vm.trend >= 0 ? .green : AppColors.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((vm.trend >= 0 ? Color.green : AppColors.accent).opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Check-in CTA

    private var checkinCTACard: some View {
        Group {
            if vm.todayCheckin != nil {
                recentBadgesCard
            } else {
                Button { showCheckin = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("dashboard.checkin.title", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(NSLocalizedString("dashboard.checkin.cta", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)
                    }
                    .padding()
                    .background(AppColors.card)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentBadgesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("dashboard.checkin.done", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            HStack(spacing: 12) {
                ForEach(vm.recentCheckins.prefix(5), id: \.id) { checkin in
                    MiniBadge(checkin: checkin)
                }
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        Group {
            if vm.hasWeeklyReport {
                Button {
                    if subscriptionManager.isSubscribed {
                        showWeeklyReport = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    streakCardContent
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    subscriptionManager.isSubscribed
                                        ? AppColors.accent.opacity(0.4)
                                        : Color.secondary.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            } else {
                streakCardContent
            }
        }
    }

    private var streakCardContent: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("dashboard.streak", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(vm.streak)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(vm.streak > 0 ? AppColors.accent : .secondary)
                    Text(NSLocalizedString("dashboard.streak.days", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let milestone = vm.milestoneText {
                    Text(milestone)
                        .font(.caption.bold())
                        .foregroundColor(AppColors.accent)
                }
            }
            Spacer()
            if vm.hasWeeklyReport {
                VStack(spacing: 4) {
                    Image(systemName: subscriptionManager.isSubscribed
                          ? "chart.bar.doc.horizontal.fill"
                          : "lock.fill")
                        .font(.title2)
                        .foregroundColor(subscriptionManager.isSubscribed ? AppColors.accent : .secondary)
                    Text(NSLocalizedString("dashboard.weeklyReport", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }

    // MARK: - PK Curve Preview (free users — blurred with CTA)

    private var pkCurvePreviewCard: some View {
        ZStack {
            PKCurveView(
                protocols: Self.samplePKProtocols,
                injections: Self.samplePKInjections,
                overdueDays: 0
            )
            .blur(radius: 6)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                Text(NSLocalizedString("dashboard.pkCurve.subtitle", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(NSLocalizedString("dashboard.pkCurve", comment: ""))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button { showPaywall = true } label: {
                    Text(NSLocalizedString("dashboard.startFreeTrial", comment: ""))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.softCTA)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.card.opacity(0.5))
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }

    private static let samplePKProtocols: [PKProtocolInput] = [
        PKProtocolInput(
            compoundName: "Testosterone Cypionate",
            doseAmountMg: 100,
            frequencyDays: 4,
            colorHex: "#4A90D9",
            customHalfLife: nil,
            route: "intramuscular"
        )
    ]

    private static let samplePKInjections: [PKInjectionInput] = {
        let now = Date.now
        let cal = Calendar.current
        return [
            PKInjectionInput(compoundName: "Testosterone Cypionate", doseAmountMg: 100,
                             injectedAt: cal.date(byAdding: .day, value: -8, to: now) ?? now, route: "intramuscular"),
            PKInjectionInput(compoundName: "Testosterone Cypionate", doseAmountMg: 100,
                             injectedAt: cal.date(byAdding: .day, value: -4, to: now) ?? now, route: "intramuscular"),
            PKInjectionInput(compoundName: "Testosterone Cypionate", doseAmountMg: 100,
                             injectedAt: now, route: "intramuscular"),
        ]
    }()

    // MARK: - PK Curve Card

    @AppStorage("pkAbsorptionDelay") private var pkAbsorptionDelay = true

    private var pkCurveCard: some View {
        VStack(spacing: 0) {
            PKCurveView(
                protocols: vm.pkProtocols,
                injections: vm.pkInjections,
                overdueDays: vm.injectionOverdueDays
            )
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
        .onAppear { AnalyticsService.pkCurveViewed(absorptionDelay: pkAbsorptionDelay) }
    }

    // MARK: - Fertility Card (hCG users)

    private var fertilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "figure.2.circle")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("dashboard.fertility", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                    if let estimate = vm.fertilityEstimate {
                        Text(estimate)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Spacer()
            }

            if let startDate = vm.hcgStartDate {
                let weeks = max(0, Int(Date.now.timeIntervalSince(startDate) / (7 * 86400)))
                HStack(spacing: 16) {
                    StatRow(label: NSLocalizedString("dashboard.fertility.hcgStarted", comment: ""), value: "\(weeks)w ago")
                    StatRow(label: NSLocalizedString("dashboard.fertility.protocol", comment: ""), value: vm.hcgProtocol?.name ?? "hCG")
                }
            }

            DisclaimerBanner(type: .fertility)
        }
        .padding(16)
        .background(AppColors.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - GLP-1 Weight Correlation Card

    private var glp1CorrelationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("dashboard.glp1", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                    if let change = vm.glp1WeeklyWeightChange {
                        Text(String(format: "%+.1f lbs/week", change))
                            .font(.caption.bold())
                            .foregroundColor(change <= 0 ? .green : Color(hex: "#F39C12"))
                    }
                }
                Spacer()
                if vm.glp1EnergyStable {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text(NSLocalizedString("dashboard.glp1.energyStable", comment: ""))
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            if let change = vm.glp1WeeklyWeightChange, change < 0, vm.glp1EnergyStable {
                Text(NSLocalizedString("dashboard.glp1.workingWell", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(AppColors.background.opacity(0.6))
                    .cornerRadius(8)
            }

            DisclaimerBanner(type: .standard)
        }
        .padding(16)
        .background(AppColors.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Body Composition Card (natural users)

    private var bodyCompositionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("dashboard.bodyComposition", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let delta = vm.weightDelta30d {
                    let isDown = delta <= 0
                    Text(String(format: "%+.0f %@", Locale.usesMetricWeight ? delta : delta / 0.453592, Locale.weightUnit))
                        .font(.caption.bold())
                        .foregroundColor(isDown ? .green : AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((isDown ? Color.green : AppColors.accent).opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if vm.weightSeries30d.isEmpty {
                Text(NSLocalizedString("dashboard.bodyComposition.logWeight", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            } else {
                // Weight trend + 7-day moving average
                Chart {
                    ForEach(vm.weightSeries30d) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value(Locale.weightUnit, Locale.usesMetricWeight ? pt.weightKg : pt.weightKg / 0.453592)
                        )
                        .foregroundStyle(AppColors.accent.opacity(0.35))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(vm.weightMovingAvg) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value(Locale.weightUnit, Locale.usesMetricWeight ? pt.weightKg : pt.weightKg / 0.453592)
                        )
                        .foregroundStyle(AppColors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 100)
                .chartBackground { _ in AppColors.card }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Color.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(Color.secondary)
                    }
                }

                // Stats row
                if let latest = vm.weightSeries30d.last {
                    HStack(spacing: 20) {
                        StatRow(label: NSLocalizedString("dashboard.weight.current", comment: ""), value: String(format: "%.0f %@", Locale.usesMetricWeight ? latest.weightKg : latest.weightKg / 0.453592, Locale.weightUnit))
                        if let bf = vm.bodyFatSeries.last {
                            StatRow(label: NSLocalizedString("dashboard.bodyComposition.bodyFat", comment: ""), value: String(format: "%.1f%%", bf.weightKg))
                        }
                        if let delta = vm.weightDelta30d, abs(delta) > 0.05 {
                            StatRow(label: NSLocalizedString("dashboard.weight.30dChange", comment: ""), value: String(format: "%+.0f %@", Locale.usesMetricWeight ? delta : delta / 0.453592, Locale.weightUnit))
                        }
                    }
                }

                // Body fat overlay chart
                if !vm.bodyFatSeries.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.top, 4)

                    Text(NSLocalizedString("dashboard.bodyComposition.bodyFatPct", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Chart {
                        ForEach(vm.bodyFatSeries) { pt in
                            AreaMark(
                                x: .value("Date", pt.date),
                                y: .value("%", pt.weightKg)
                            )
                            .foregroundStyle(Color.green.gradient.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("%", pt.weightKg)
                            )
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 56)
                    .chartBackground { _ in AppColors.card }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.white.opacity(0.08))
                            AxisValueLabel().foregroundStyle(Color.secondary)
                        }
                    }
                }
            }

            DisclaimerBanner(type: .standard)
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }

    // MARK: - Trend Chart Card

    /// Metric series filtered to 3 days for free users, full for Pro.
    private var visibleMetricSeries: [MetricSeries] {
        if subscriptionManager.isSubscribed {
            return vm.metricSeries
        }
        let cutoff = (Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now).startOfDay
        return vm.metricSeries.map { series in
            var copy = series
            copy.dataPoints = series.dataPoints.filter { $0.date >= cutoff }
            return copy
        }
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("dashboard.trendChart", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if !subscriptionManager.isSubscribed {
                    Text(NSLocalizedString("dashboard.trendChart.3days", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.background.opacity(0.6))
                        .clipShape(Capsule())
                }
            }

            if visibleMetricSeries.isEmpty || visibleMetricSeries.allSatisfy({ $0.dataPoints.isEmpty }) {
                Text(NSLocalizedString("dashboard.trendChart.empty", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            } else {
                Chart {
                    ForEach(visibleMetricSeries.filter(\.isVisible)) { series in
                        ForEach(series.dataPoints) { pt in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Score", pt.value),
                                series: .value("Metric", series.label)
                            )
                            .foregroundStyle(series.color)
                            .interpolationMethod(.catmullRom)

                            // Show dots so single data points are visible
                            PointMark(
                                x: .value("Date", pt.date),
                                y: .value("Score", pt.value)
                            )
                            .foregroundStyle(series.color)
                            .symbolSize(series.dataPoints.count == 1 ? 60 : 20)
                        }
                    }
                }
                .chartYScale(domain: 1...5)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: subscriptionManager.isSubscribed ? 2 : 1)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel()
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(height: 160)
                .chartBackground { _ in AppColors.card }

                metricLegend

                // Upsell for free users
                if !subscriptionManager.isSubscribed {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                            Text(NSLocalizedString("dashboard.trendChart.upsell", comment: ""))
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.softCTA)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }

    private var metricLegend: some View {
        FlowLayout(spacing: 8) {
            ForEach(vm.metricSeries) { series in
                Button {
                    vm.toggleMetric(id: series.id)
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(series.isVisible ? series.color : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text("\(series.emoji) \(series.label)")
                            .font(.caption2)
                            .foregroundColor(series.isVisible ? .primary : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.background.opacity(0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick Stats Card

    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("dashboard.quickStats", comment: ""))
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickStatTile(
                    emoji: "⚡️",
                    label: NSLocalizedString("dashboard.quickStats.avgEnergy", comment: ""),
                    value: String(format: "%.1f", vm.avgEnergy7d),
                    subtitle: "/ 5",
                    delta: vm.energyDelta
                )
                QuickStatTile(
                    emoji: "🔥",
                    label: NSLocalizedString("dashboard.quickStats.avgLibido", comment: ""),
                    value: String(format: "%.1f", vm.avgLibido7d),
                    subtitle: "/ 5",
                    delta: vm.libidoDelta
                )
                QuickStatTile(
                    emoji: "🌅",
                    label: NSLocalizedString("dashboard.quickStats.morningWood", comment: ""),
                    value: String(format: "%.0f%%", vm.morningWoodPct30d),
                    subtitle: NSLocalizedString("dashboard.quickStats.30d", comment: "")
                )
                if userType == "natural" {
                    QuickStatTile(
                        emoji: "💊",
                        label: NSLocalizedString("dashboard.compliance.supplements", comment: ""),
                        value: String(format: "%.0f%%", vm.supplementCompliancePct),
                        subtitle: NSLocalizedString("dashboard.quickStats.adherence", comment: "")
                    )
                } else {
                    QuickStatTile(
                        emoji: "💉",
                        label: NSLocalizedString("dashboard.quickStats.nextInjection", comment: ""),
                        value: vm.injectionOverdueDays > 0 ? NSLocalizedString("dashboard.quickStats.overdue", comment: "") : NSLocalizedString("dashboard.quickStats.onTrack", comment: ""),
                        subtitle: vm.injectionOverdueDays > 0 ? "\(vm.injectionOverdueDays)d late" : ""
                    )
                }
            }
        }
        .padding()
        .background(AppColors.card)
        .cornerRadius(16)
    }
}

// MARK: - Circular Ring View

struct CircularRingView: View {
    let score: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: score)
            VStack(spacing: 2) {
                Text(String(format: "%.0f", score))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("/ 100")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Mini Badge

struct MiniBadge: View {
    let checkin: SDCheckin

    var body: some View {
        VStack(spacing: 2) {
            Text(dayAbbrev(checkin.date))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            ZStack {
                Circle()
                    .fill(scoreColor(checkin.protocolScore).opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(String(format: "%.0f", checkin.protocolScore))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(scoreColor(checkin.protocolScore))
            }
        }
    }

    private func scoreColor(_ s: Double) -> Color {
        s >= 70 ? .green : s >= 40 ? Color(hex: "#F39C12") : AppColors.accent
    }

    private func dayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(2))
    }

}

// MARK: - New Dashboard Cards

extension DashboardView {

    var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.greetingText)
                .font(.title2.bold())
                .foregroundColor(.white)
            if let day = vm.cycleDay, let proto = vm.activeProtocol {
                Text(String(format: NSLocalizedString("dashboard.cycleDay", comment: ""), day, proto.frequencyDays, proto.compoundName))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Smart Insight Card

    private func smartInsightCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundColor(AppColors.accent)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColors.card, AppColors.card.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.accent.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Personal Best Banner

    var personalBestBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundColor(Color(hex: "#FFD700"))
            Text(NSLocalizedString("dashboard.personalBest", comment: ""))
                .font(.subheadline.bold())
                .foregroundColor(Color(hex: "#FFD700"))
            Spacer()
        }
        .padding()
        .background(Color(hex: "#FFD700").opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1))
    }

    // MARK: - Compliance Row (injection + supplement side by side)

    var complianceRow: some View {
        HStack(spacing: 12) {
            // NEW: Injection compliance — tappable, navigates to Injections
            NavigationLink(destination: InjectionsView()) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: vm.injectionsExpectedThisMonth > 0
                                  ? min(1.0, Double(vm.injectionsMadeThisMonth) / Double(vm.injectionsExpectedThisMonth))
                                  : 0)
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(vm.injectionsMadeThisMonth)/\(vm.injectionsExpectedThisMonth)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 56, height: 56)
                    Text(NSLocalizedString("dashboard.compliance.injections", comment: ""))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(NSLocalizedString("dashboard.compliance.thisMonth", comment: ""))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [AppColors.card, AppColors.card.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Injections this month")
            .accessibilityHint("Tap to view and log injections")

            // NEW: Supplement compliance — tappable, navigates to Settings > Supplements
            NavigationLink(destination: SettingsView()) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: vm.supplementCompliancePct / 100)
                            .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        if vm.supplementCompliancePct == 0 && vm.supplementCount == 0 {
                            // NEW: Show + icon when no supplements configured
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("\(Int(vm.supplementCompliancePct))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 56, height: 56)
                    Text(NSLocalizedString("dashboard.compliance.supplements", comment: ""))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(vm.supplementCount == 0 ? NSLocalizedString("dashboard.compliance.tapToAdd", comment: "") : NSLocalizedString("dashboard.compliance.thisWeek", comment: ""))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [AppColors.card, AppColors.card.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Supplements this week")
            .accessibilityHint(vm.supplementCount == 0 ? "Tap to add supplements" : "Tap to manage supplements")
        }
    }

    // MARK: - Supplement Setup Banner (one-time, post-subscription)

    var supplementSetupBanner: some View {
        NavigationLink(destination: SettingsView()) {
            HStack(spacing: 12) {
                Image(systemName: "pills.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("dashboard.supplementSetup.title", comment: ""))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(NSLocalizedString("dashboard.supplementSetup.subtitle", comment: ""))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    hasShownSupplementBanner = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [AppColors.card, AppColors.card.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set up supplement tracking")
        .accessibilityHint("Tap to add supplements and see correlations with your Protocol Score")
    }

    // MARK: - Weight Trend Card

    var weightTrendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("dashboard.weightTrend", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let delta = vm.weightTrendDelta {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.bold())
                        Text(String(format: "%+.1f %@", delta, Locale.weightUnit))
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(delta <= 0 ? .green : Color(hex: "#F39C12"))
                }
            }
            if let weight = vm.latestWeightDisplay {
                Text(String(format: "%.1f %@", weight, Locale.weightUnit))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(NSLocalizedString("dashboard.weightTrend.30day", comment: ""))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [AppColors.card, AppColors.card.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        .cornerRadius(16)
    }

    // MARK: - Forecast Card

    func forecastCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(Color(hex: "#F1C40F"))
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("dashboard.forecast", comment: ""))
                    .font(.caption.bold())
                    .foregroundColor(AppColors.textSecondary)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [AppColors.card, AppColors.card.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(16)
    }
}

// MARK: - Quick Stat Tile

struct QuickStatTile: View {
    let emoji: String
    let label: String
    let value: String
    let subtitle: String
    var delta: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(emoji)
                    .font(.title3)
                Spacer()
                if let d = delta, abs(d) >= 0.1 {
                    HStack(spacing: 2) {
                        Image(systemName: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.bold())
                        Text(String(format: "%+.1f", d))
                            .font(.caption2.bold())
                    }
                    .foregroundColor(d >= 0 ? .green : AppColors.accent)
                }
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(AppColors.background.opacity(0.6))
        .cornerRadius(12)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var row: CGFloat = 0
        var x: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                row += size.height + spacing
                x = 0
            }
            x += size.width + spacing
            height = row + size.height
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Trial Ended (Soft Downgrade) View

struct TrialEndedView: View {
    let streak: Int
    let totalCheckins: Int
    let latestScore: Int?
    let onSubscribe: () -> Void
    let onContinueFree: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Hero
                VStack(spacing: 14) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.accent)

                    Text(NSLocalizedString("dashboard.trial.ended", comment: ""))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(NSLocalizedString("dashboard.trial.accomplished", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Accomplishment stats
                HStack(spacing: 16) {
                    StatBubble(value: "\(totalCheckins)", label: NSLocalizedString("dashboard.totalCheckins", comment: ""))
                    if streak > 0 {
                        StatBubble(value: "\(streak)d", label: NSLocalizedString("dashboard.streak", comment: ""))
                    }
                    if let score = latestScore {
                        StatBubble(value: "\(score)", label: NSLocalizedString("dashboard.protocolScore", comment: ""))
                    }
                }

                // What you keep vs what you lose
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("dashboard.trial.freeForever", comment: ""))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        Text(NSLocalizedString("dashboard.trial.freeFeatures", comment: ""))
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    Text(NSLocalizedString("dashboard.trial.withPro", comment: ""))
                        .font(.caption.bold())
                        .foregroundColor(AppColors.accent)
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").foregroundColor(AppColors.accent).font(.caption)
                        Text(NSLocalizedString("dashboard.trial.proFeatures", comment: ""))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(AppColors.card)
                .cornerRadius(14)

                Spacer()

                // CTAs
                VStack(spacing: 14) {
                    Button(action: onSubscribe) {
                        Text(NSLocalizedString("dashboard.trial.subscribePro", comment: ""))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)

                    Button(action: onContinueFree) {
                        Text(NSLocalizedString("dashboard.trial.continueFree", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(NSLocalizedString("dashboard.trial.dataSafe", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

private struct StatBubble: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(AppColors.accent)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.card)
        .cornerRadius(12)
    }
}
