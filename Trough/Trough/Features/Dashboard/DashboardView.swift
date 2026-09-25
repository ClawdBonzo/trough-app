import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var vm = DashboardViewModel()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var gamificationVM: GamificationViewModel
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
    @State private var showAchievements = false
    @AppStorage("dismissedInsightsReEngage") private var dismissedInsightsReEngage = false

    /// XP granted for a new daily check-in (GamificationViewModel.didSaveCheckin).
    private let checkinXP = 20
    private let isScreenshotMode = DashboardScreenshotMode.isOn

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()

                if vm.isLoading {
                    DashboardSkeletonView()
                        .padding(.horizontal, TR.Metrics.gutter)
                        .transition(.opacity)
                } else {
                    ScrollView {
                        content
                            .padding(.horizontal, TR.Metrics.gutter)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(NSLocalizedString("dashboard.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
            .sheet(isPresented: $showAchievements) {
                NavigationStack {
                    ZStack {
                        TRBackground()
                        ScrollView { GamificationHomeView(viewModel: gamificationVM) }
                    }
                    .navigationTitle(NSLocalizedString("tab.achievements", comment: ""))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(NSLocalizedString("common.done", comment: "")) { showAchievements = false }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showTrialEndedSheet) {
                TrialEndedView(
                    streak: vm.streak,
                    totalCheckins: vm.totalCheckins,
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
                if !inTrial && !hasShownTrialEndedScreen && !subscriptionManager.isSubscribed && !isScreenshotMode {
                    let trialStarted = UserDefaults.standard.bool(forKey: "trialWasStarted")
                    if trialStarted {
                        hasShownTrialEndedScreen = true
                        showTrialEndedSheet = true
                    }
                }
            }
        }
    }

    // MARK: - Layout (ordered by importance)

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            greetingHeader
                .trRevealOnAppear(delay: 0)

            protocolCard
                .trRevealOnAppear(delay: 0.04)

            if !isScreenshotMode {
                if showSampleDataBanner { sampleDataBanner }
                if subscriptionManager.showTrialExpiryWarning { trialExpiryBanner }
                if subscriptionManager.showGracePeriodWarning { gracePeriodBanner }
            }

            // Today
            sectionLabel(dashL("dash.section.today", "Today"))
                .trRevealOnAppear(delay: 0.08)
            DashboardCheckinCTA(isCheckedIn: vm.todayCheckin != nil, xpEarned: checkinXP) { showCheckin = true }
                .trRevealOnAppear(delay: 0.1)
            if let proto = vm.activeProtocol, let days = vm.daysUntilNextInjection {
                HStack(spacing: 12) {
                    NavigationLink(destination: InjectionsView()) {
                        DashboardNextInjectionTile(compound: proto.compoundName, daysUntil: days,
                                                   overdueDays: vm.injectionOverdueDays)
                    }
                    .buttonStyle(.trPressable)
                    if let day = vm.cycleDay {
                        cycleDayTile(day: day, of: proto.frequencyDays)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .trRevealOnAppear(delay: 0.12)
            }
            if let challenge = gamificationVM.dailyChallenge {
                dailyChallenge(challenge)
                    .trRevealOnAppear(delay: 0.14)
            }

            // Score
            DashboardScoreCard(
                score: vm.protocolScore,
                interpretation: vm.interpretation,
                trend: vm.trend,
                hasPriorWeek: vm.hasPriorWeek,
                sevenDayAvg: vm.sevenDayAvg,
                week: vm.weekScores,
                hasData: !vm.recentCheckins.isEmpty,
                onLogToday: { showCheckin = true }
            )
            .trRevealOnAppear(delay: 0.16)

            if vm.isPersonalBest { personalBestBanner }

            if let insight = vm.smartInsight {
                smartInsightCard(insight)
                    .onAppear {
                        // Daily quest: the user actually saw an insight.
                        gamificationVM.completeQuest(QuestService.viewInsightsQuestID())
                    }
            }

            // PK curve / body composition
            if subscriptionManager.isSubscribed {
                if userType == "trt" {
                    pkCurveCard
                    if vm.hcgProtocol != nil { fertilityCard }
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

            // Progress
            sectionLabel(dashL("dash.section.progress", "Progress"))
            if let next = nextBadge {
                Button { showAchievements = true } label: { DashboardNextBadgeCard(badge: next) }
                    .buttonStyle(.trPressable)
                    .accessibilityHint(Text(dashL("dash.hero.a11yHint", "Opens achievements")))
            }
            if let persona = gamificationVM.persona {
                DashboardPersonaCard(persona: persona)
            }
            if vm.activeProtocol != nil { complianceRow }
            if vm.hasWeeklyReport { weeklyReportRow }

            // Trends
            sectionLabel(dashL("dash.section.trends", "Trends"))
            trendChartCard
            quickStatsCard

            if subscriptionManager.isSubscribed && vm.hasGLP1Data {
                glp1CorrelationCard
            }
            if vm.latestWeightLbs != nil && userType != "natural" {
                weightTrendCard
            }
            if let forecast = vm.forecastText {
                forecastCard(forecast)
            }
            if !vm.activeCompounds.isEmpty {
                activeStackCard
            }

            // Tips / upsells — never in screenshots
            if !isScreenshotMode {
                if subscriptionManager.isSubscribed && vm.supplementCount == 0 && !hasShownSupplementBanner {
                    supplementSetupBanner
                }
                if !subscriptionManager.isSubscribed && vm.totalCheckins >= 6 && !dismissedInsightsReEngage {
                    insightsReEngageBanner
                }
                if !subscriptionManager.isSubscribed {
                    peptideTeaserCard
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(TR.Font.display(.title3, weight: .heavy))
            .foregroundStyle(TR.Palette.textPrimary)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Greeting

    var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            TRKicker(Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day()), color: TR.Palette.coral)
            Text(vm.greetingText)
                .font(TR.Font.display(30, weight: .heavy))
                .foregroundStyle(TR.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Protocol Card (hero)

    private var protocolCard: some View {
        let badges = gamificationVM.badgeProgress
        return Button { showAchievements = true } label: {
            DashboardProtocolCard(
                level: gamificationVM.currentLevel,
                levelName: gamificationVM.levelName,
                progress: gamificationVM.levelProgressPercent,
                xpToNext: gamificationVM.xpUntilNextLevel,
                totalXP: gamificationVM.currentXP,
                checkinStreakDays: gamificationVM.checkinStreakDays,
                injectionStreakWeeks: gamificationVM.injectionStreakWeeks,
                showsInjectionStreak: userType == "trt" && vm.activeProtocol != nil,
                badgesUnlocked: badges.filter(\.isUnlocked).count,
                badgesTotal: badges.count
            )
        }
        .buttonStyle(.trPressable)
    }

    // MARK: - Today

    private func cycleDayTile(day: Int, of total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DashCardHeader(icon: "waveform.path.ecg", title: dashL("dash.today.cycle", "Cycle"), tint: TR.Palette.teal)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(dashL("dash.today.dayWord", "Day"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textSecondary)
                Text("\(day)")
                    .font(TR.Font.number(34))
                    .foregroundStyle(TR.Palette.textPrimary)
                Text("/\(total)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TR.Palette.textTertiary)
            }
            // Segmented cycle track.
            HStack(spacing: 3) {
                ForEach(1...max(1, min(total, 14)), id: \.self) { i in
                    Capsule()
                        .fill(i <= day ? AnyShapeStyle(LinearGradient(colors: [TR.Palette.teal, TR.Palette.sky], startPoint: .leading, endPoint: .trailing))
                                       : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(height: 5)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: TR.Palette.teal)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func dailyChallenge(_ challenge: QuestDisplayModel) -> some View {
        if !challenge.isCompleted, challenge.challenge == .checkin || challenge.challenge == .healthSync {
            Button { showCheckin = true } label: { DashboardDailyChallengeCard(challenge: challenge) }
                .buttonStyle(.trPressable)
        } else if !challenge.isCompleted, challenge.challenge == .injection {
            NavigationLink(destination: InjectionsView()) { DashboardDailyChallengeCard(challenge: challenge) }
                .buttonStyle(.trPressable)
        } else {
            DashboardDailyChallengeCard(challenge: challenge)
        }
    }

    /// Locked, non-secret badge closest to completion.
    private var nextBadge: BadgeProgressModel? {
        gamificationVM.badgeProgress
            .filter { !$0.isUnlocked && !$0.isHiddenSecret }
            .min { a, b in
                if a.fraction != b.fraction { return a.fraction > b.fraction }
                return a.def.prestige < b.def.prestige
            }
    }

    // MARK: - Banners

    private var sampleDataBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashCardHeader(icon: "sparkles", title: dashL("dash.sample.kicker", "Getting started"), tint: TR.Palette.gold)
            Text(NSLocalizedString("dashboard.noDataTitle", comment: ""))
                .font(TR.Font.display(.headline))
                .foregroundStyle(TR.Palette.textPrimary)
            Text(NSLocalizedString("dashboard.noDataSubtitle", comment: ""))
                .font(.subheadline)
                .foregroundStyle(TR.Palette.textSecondary)
            HStack(spacing: 10) {
                Button(NSLocalizedString("dashboard.loadSampleData", comment: "")) {
                    let userID = UUID(uuidString: userIDString) ?? UUID()
                    SampleDataService.insertSampleData(context: modelContext, userID: userID)
                    showSampleDataBanner = false
                    vm.load()
                    gamificationVM.refresh()
                }
                .buttonStyle(TRSecondaryButtonStyle(tint: TR.Palette.gold))
                .accessibilityLabel("Load sample check-in and injection data")

                Button(NSLocalizedString("dashboard.startCheckin", comment: "")) { showCheckin = true }
                    .buttonStyle(TRSecondaryButtonStyle())
                    .accessibilityLabel("Open daily check-in")
            }
        }
        .trCard(tint: TR.Palette.gold)
    }

    private var insightsReEngageBanner: some View {
        Button { showPaywall = true } label: {
            DashboardBanner(
                icon: "sparkles", tint: TR.Palette.coral,
                title: String(format: NSLocalizedString("dashboard.reEngage.title", comment: ""), vm.totalCheckins),
                subtitle: NSLocalizedString("dashboard.reEngage.subtitle", comment: "")
            ) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TR.Palette.textTertiary)
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissedInsightsReEngage = true }
                    .accessibilityLabel("Dismiss")
            }
        }
        .buttonStyle(.trPressable)
        .accessibilityHint("Opens Pro free trial")
    }

    private var peptideTeaserCard: some View {
        Button { showPaywall = true } label: {
            DashboardBanner(
                icon: "pills.fill", tint: TR.Palette.lilac,
                title: NSLocalizedString("dashboard.peptideTeaser.title", comment: ""),
                subtitle: NSLocalizedString("dashboard.peptideTeaser.subtitle", comment: "")
            ) {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(TR.Palette.textTertiary)
            }
        }
        .buttonStyle(.trPressable)
        .accessibilityHint("Opens Pro free trial")
    }

    private var trialExpiryBanner: some View {
        let days = subscriptionManager.trialDaysRemaining ?? 0
        return DashboardBanner(
            icon: "clock.badge.exclamationmark", tint: TR.Palette.tangerine,
            title: days <= 0
                ? NSLocalizedString("dashboard.trial.ended", comment: "")
                : String(format: NSLocalizedString("dashboard.trial.endsIn", comment: ""), days),
            subtitle: NSLocalizedString("dashboard.trial.subscribe", comment: "")
        ) {
            Button(NSLocalizedString("dashboard.trial.subscribeButton", comment: "")) { showPaywall = true }
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(TR.Gradients.cta, in: Capsule())
        }
    }

    private var gracePeriodBanner: some View {
        let days = subscriptionManager.graceDaysRemaining ?? 0
        return DashboardBanner(
            icon: "creditcard.trianglebadge.exclamationmark", tint: TR.Palette.gold,
            title: NSLocalizedString("dashboard.grace.title", comment: ""),
            subtitle: String(format: NSLocalizedString("dashboard.grace.subtitle", comment: ""), days)
        ) { EmptyView() }
    }

    var supplementSetupBanner: some View {
        NavigationLink(destination: SettingsView()) {
            DashboardBanner(
                icon: "pills.fill", tint: TR.Palette.teal,
                title: NSLocalizedString("dashboard.supplementSetup.track", comment: ""),
                subtitle: NSLocalizedString("dashboard.supplementSetup.correlations", comment: "")
            ) {
                Button { hasShownSupplementBanner = true } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(TR.Palette.textTertiary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .buttonStyle(.trPressable)
        .accessibilityLabel("Set up supplement tracking")
        .accessibilityHint("Tap to add supplements and see correlations with your Protocol Score")
    }

    var personalBestBanner: some View {
        DashboardBanner(
            icon: "trophy.fill", tint: TR.Palette.gold,
            title: String(format: NSLocalizedString("dashboard.personalBest.new", comment: ""), Int(vm.personalBestScore)),
            subtitle: dashL("dash.personalBest.sub", "Your highest self-rated score this month.")
        ) { EmptyView() }
    }

    // MARK: - Insight

    private func smartInsightCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DashCardHeader(icon: "brain.head.profile", title: dashL("dash.insight.kicker", "Insight"), tint: TR.Palette.lilac)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TR.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            DisclaimerBanner(type: .insight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: TR.Palette.lilac)
    }

    // MARK: - PK Curve

    private var pkCurvePreviewCard: some View {
        ZStack {
            PKCurveView(
                protocols: Self.samplePKProtocols,
                injections: Self.samplePKInjections,
                overdueDays: 0
            )
            .blur(radius: 7)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            DashboardProLockOverlay(
                icon: "waveform.path.ecg",
                title: NSLocalizedString("dashboard.seeBloodLevels", comment: ""),
                message: NSLocalizedString("dashboard.pkCurveDesc", comment: "")
            ) { showPaywall = true }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .trCard(tint: TR.Palette.coral)
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

    private var pkCurveCard: some View {
        PKCurveView(
            protocols: vm.pkProtocols,
            injections: vm.pkInjections,
            overdueDays: vm.injectionOverdueDays
        )
        .trCard(tint: TR.Palette.coral)
    }

    // MARK: - Fertility (hCG)

    private var fertilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashCardHeader(icon: "figure.2.circle", title: NSLocalizedString("dashboard.fertilityActive", comment: ""), tint: TR.Palette.mint)
            if let estimate = vm.fertilityEstimate {
                Text(estimate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TR.Palette.textPrimary)
            }
            if let startDate = vm.hcgStartDate {
                let weeks = max(0, Int(Date.now.timeIntervalSince(startDate) / (7 * 86400)))
                HStack(spacing: 24) {
                    StatRow(label: NSLocalizedString("dashboard.fertility.hcgStarted", comment: ""),
                            value: String(format: NSLocalizedString("dashboard.weeksAgo", comment: ""), weeks))
                    StatRow(label: NSLocalizedString("dashboard.protocol", comment: ""), value: vm.hcgProtocol?.name ?? "hCG")
                }
            }
            DisclaimerBanner(type: .fertility)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: TR.Palette.mint)
    }

    // MARK: - GLP-1

    private var glp1CorrelationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashCardHeader(icon: "chart.line.downtrend.xyaxis", title: NSLocalizedString("dashboard.glp1Weight", comment: ""), tint: TR.Palette.teal) {
                if vm.glp1EnergyStable {
                    TRPill(Text(NSLocalizedString("dashboard.energyStable", comment: "")), systemImage: "bolt.fill", tint: TR.Palette.teal)
                }
            }
            if let change = vm.glp1WeeklyWeightChange {
                Text(String(format: NSLocalizedString("dashboard.glp1.lbsPerWeek", comment: ""), change))
                    .font(TR.Font.display(.title3, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
            }
            if let change = vm.glp1WeeklyWeightChange, change < 0, vm.glp1EnergyStable {
                Text(NSLocalizedString("dashboard.glp1Working", comment: ""))
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            DisclaimerBanner(type: .standard)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: TR.Palette.teal)
    }

    // MARK: - Body Composition (natural users)

    private var bodyCompositionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashCardHeader(icon: "scalemass.fill", title: NSLocalizedString("dashboard.bodyComp", comment: ""), tint: TR.Palette.sky) {
                if let delta = vm.weightDelta30d {
                    TRPill(verbatim: String(format: "%+.0f %@", delta / 0.453592, NSLocalizedString("unit.lbs", comment: "")),
                           tint: TR.Palette.sky)
                }
            }

            if vm.weightSeries30d.isEmpty {
                Text(NSLocalizedString("dashboard.logWeightHint", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            } else {
                Chart {
                    ForEach(vm.weightMovingAvg) { pt in
                        AreaMark(x: .value("Date", pt.date), y: .value("lbs", pt.weightKg / 0.453592))
                            .foregroundStyle(LinearGradient.dashArea(TR.Palette.sky, top: 0.3))
                            .interpolationMethod(.catmullRom)
                    }
                    ForEach(vm.weightSeries30d) { pt in
                        PointMark(x: .value("Date", pt.date), y: .value("lbs", pt.weightKg / 0.453592))
                            .foregroundStyle(TR.Palette.sky.opacity(0.45))
                            .symbolSize(14)
                    }
                    ForEach(vm.weightMovingAvg) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("lbs", pt.weightKg / 0.453592))
                            .foregroundStyle(LinearGradient(colors: [TR.Palette.sky, TR.Palette.teal], startPoint: .leading, endPoint: .trailing))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 110)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis { dashYAxis() }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).foregroundStyle(TR.Palette.textTertiary)
                    }
                }

                if let latest = vm.weightSeries30d.last {
                    HStack(spacing: 20) {
                        StatRow(label: NSLocalizedString("dashboard.weight.current", comment: ""),
                                value: String(format: "%.0f %@", latest.weightKg / 0.453592, NSLocalizedString("unit.lbs", comment: "")))
                        if let bf = vm.bodyFatSeries.last {
                            StatRow(label: NSLocalizedString("dashboard.weight.bodyFat", comment: ""), value: String(format: "%.1f%%", bf.weightKg))
                        }
                        if let delta = vm.weightDelta30d, abs(delta) > 0.05 {
                            StatRow(label: NSLocalizedString("dashboard.weight.30dChange", comment: ""),
                                    value: String(format: "%+.0f %@", delta / 0.453592, NSLocalizedString("unit.lbs", comment: "")))
                        }
                    }
                }

                if !vm.bodyFatSeries.isEmpty {
                    TRKicker(Text(NSLocalizedString("dashboard.bodyComposition.bodyFatPct", comment: "")))
                        .padding(.top, 4)
                    Chart {
                        ForEach(vm.bodyFatSeries) { pt in
                            AreaMark(x: .value("Date", pt.date), y: .value("%", pt.weightKg))
                                .foregroundStyle(LinearGradient.dashArea(TR.Palette.mint))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Date", pt.date), y: .value("%", pt.weightKg))
                                .foregroundStyle(TR.Palette.mint)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 60)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxis { dashYAxis() }
                }
            }

            DisclaimerBanner(type: .standard)
        }
        .trCard(tint: TR.Palette.sky)
    }

    private func dashYAxis() -> some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Color.white.opacity(0.07))
            AxisValueLabel().foregroundStyle(TR.Palette.textTertiary)
        }
    }

    // MARK: - Trend Chart

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
        let shown = visibleMetricSeries.filter(\.isVisible)
        return VStack(alignment: .leading, spacing: 14) {
            DashCardHeader(icon: "chart.xyaxis.line",
                           title: subscriptionManager.isSubscribed
                               ? NSLocalizedString("dashboard.trendChart", comment: "")
                               : NSLocalizedString("dashboard.trendChart.recent", comment: ""),
                           tint: TR.Palette.sky) {
                if !subscriptionManager.isSubscribed {
                    TRPill(Text(NSLocalizedString("dashboard.trendChart.3days", comment: "")))
                }
            }

            if visibleMetricSeries.isEmpty || visibleMetricSeries.allSatisfy({ $0.dataPoints.isEmpty }) {
                Text(NSLocalizedString("dashboard.trendChart.empty", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            } else {
                Chart {
                    ForEach(shown) { series in
                        ForEach(series.dataPoints) { pt in
                            // Only fill under a lone series — overlapping fills turn to mud.
                            if shown.count <= 2 {
                                AreaMark(
                                    x: .value("Date", pt.date),
                                    yStart: .value("Base", 1),
                                    yEnd: .value("Score", pt.value),
                                    series: .value("Metric", series.label)
                                )
                                .foregroundStyle(LinearGradient.dashArea(series.color, top: 0.28))
                                .interpolationMethod(.catmullRom)
                            }
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Score", pt.value),
                                series: .value("Metric", series.label)
                            )
                            .foregroundStyle(series.color)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.catmullRom)

                            if series.dataPoints.count == 1 {
                                PointMark(x: .value("Date", pt.date), y: .value("Score", pt.value))
                                    .foregroundStyle(series.color)
                                    .symbolSize(60)
                            }
                        }
                    }
                }
                .chartYScale(domain: 1...5)
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: subscriptionManager.isSubscribed ? 3 : 1)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(TR.Palette.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 3, 5]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Color.white.opacity(0.07))
                        AxisValueLabel().foregroundStyle(TR.Palette.textTertiary)
                    }
                }
                .frame(height: 170)

                metricLegend

                if !subscriptionManager.isSubscribed {
                    Button { showPaywall = true } label: {
                        Label(NSLocalizedString("dashboard.trendChart.unlock", comment: ""), systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.heavy))
                    }
                    .buttonStyle(TRPrimaryButtonStyle())
                }
            }
        }
        .trCard(tint: TR.Palette.sky)
    }

    private var metricLegend: some View {
        FlowLayout(spacing: 8) {
            ForEach(vm.metricSeries) { series in
                Button {
                    withAnimation(TR.Motion.snappy) { vm.toggleMetric(id: series.id) }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(series.isVisible ? series.color : Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                        Text(series.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(series.isVisible ? TR.Palette.textPrimary : TR.Palette.textTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(series.isVisible ? series.color.opacity(0.14) : Color.white.opacity(0.04))
                    )
                    .overlay(Capsule().strokeBorder(series.isVisible ? series.color.opacity(0.35) : TR.Palette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(series.isVisible ? .isSelected : [])
            }
        }
    }

    // MARK: - Quick Stats (7-day summary + week-over-week)

    private var avgMood7d: Double {
        let last7 = vm.recentCheckins.prefix(7)
        guard !last7.isEmpty else { return 0 }
        return last7.map(\.moodScore).reduce(0, +) / Double(last7.count)
    }

    private var avgSleep7d: Double {
        let last7 = vm.recentCheckins.prefix(7)
        guard !last7.isEmpty else { return 0 }
        return last7.map(\.sleepQualityScore).reduce(0, +) / Double(last7.count)
    }

    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashCardHeader(icon: "square.grid.2x2.fill", title: NSLocalizedString("dashboard.7daySummary", comment: ""), tint: TR.Palette.gold)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                QuickStatTile(icon: "bolt.fill", tint: TR.Palette.gold,
                              label: NSLocalizedString("dashboard.quickStats.avgEnergy", comment: ""),
                              value: String(format: "%.1f", vm.avgEnergy7d), subtitle: "/ 5",
                              delta: vm.hasPriorWeek ? vm.energyDelta : nil)
                QuickStatTile(icon: "flame.fill", tint: TR.Palette.coral,
                              label: NSLocalizedString("dashboard.quickStats.avgLibido", comment: ""),
                              value: String(format: "%.1f", vm.avgLibido7d), subtitle: "/ 5",
                              delta: vm.hasPriorWeek ? vm.libidoDelta : nil)
                QuickStatTile(icon: "face.smiling.inverse", tint: TR.Palette.teal,
                              label: dashL("dash.stats.avgMood", "Avg mood"),
                              value: String(format: "%.1f", avgMood7d), subtitle: "/ 5",
                              delta: vm.hasPriorWeek ? vm.moodDelta : nil)
                QuickStatTile(icon: "moon.stars.fill", tint: TR.Palette.lilac,
                              label: dashL("dash.stats.avgSleep", "Avg sleep"),
                              value: String(format: "%.1f", avgSleep7d), subtitle: "/ 5",
                              delta: vm.hasPriorWeek ? vm.sleepDelta : nil)
                if userType == "natural" {
                    QuickStatTile(icon: "pills.fill", tint: TR.Palette.mint,
                                  label: NSLocalizedString("dashboard.compliance.supplements", comment: ""),
                                  value: String(format: "%.0f%%", vm.supplementCompliancePct),
                                  subtitle: NSLocalizedString("dashboard.quickStats.adherence", comment: ""))
                }
                QuickStatTile(icon: "sunrise.fill", tint: TR.Palette.tangerine,
                              label: NSLocalizedString("dashboard.quickStats.morningWood", comment: ""),
                              value: String(format: "%.0f%%", vm.morningWoodPct30d),
                              subtitle: NSLocalizedString("dashboard.quickStats.30d", comment: ""))
            }
        }
        .trCard(tint: TR.Palette.gold)
    }

    // MARK: - Compliance

    var complianceRow: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: InjectionsView()) {
                DashboardRingTile(
                    progress: vm.injectionsExpectedThisMonth > 0
                        ? min(1.0, Double(vm.injectionsMadeThisMonth) / Double(vm.injectionsExpectedThisMonth)) : 0,
                    valueText: "\(vm.injectionsMadeThisMonth)/\(vm.injectionsExpectedThisMonth)",
                    title: NSLocalizedString("dashboard.compliance.injections", comment: ""),
                    subtitle: NSLocalizedString("dashboard.compliance.thisMonth", comment: ""),
                    colors: [TR.Palette.coral, TR.Palette.tangerine]
                )
            }
            .buttonStyle(.trPressable)
            .accessibilityLabel("Injections this month")
            .accessibilityHint("Tap to view and log injections")

            NavigationLink(destination: SettingsView()) {
                DashboardRingTile(
                    progress: vm.supplementCompliancePct / 100,
                    valueText: "\(Int(vm.supplementCompliancePct))%",
                    title: NSLocalizedString("dashboard.compliance.supplements", comment: ""),
                    subtitle: vm.supplementCount == 0
                        ? NSLocalizedString("dashboard.compliance.tapToAdd", comment: "")
                        : NSLocalizedString("dashboard.compliance.thisWeek", comment: ""),
                    colors: [TR.Palette.teal, TR.Palette.mint],
                    showsPlus: vm.supplementCompliancePct == 0 && vm.supplementCount == 0
                )
            }
            .buttonStyle(.trPressable)
            .accessibilityLabel("Supplements this week")
            .accessibilityHint(vm.supplementCount == 0 ? "Tap to add supplements" : "Tap to manage supplements")
        }
    }

    // MARK: - Weekly report

    private var weeklyReportRow: some View {
        Button {
            if subscriptionManager.isSubscribed { showWeeklyReport = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.image.fill")
                    .font(.title3)
                    .foregroundStyle(TR.Palette.sky)
                    .frame(width: 40, height: 40)
                    .background(TR.Palette.sky.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("dashboard.weeklyReport", comment: "").replacingOccurrences(of: "\n", with: " "))
                        .font(TR.Font.display(.headline))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(vm.milestoneText ?? dashL("dash.weekly.sub", "Your last 7 days at a glance"))
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: subscriptionManager.isSubscribed ? "chevron.right" : "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TR.Palette.textTertiary)
            }
            .trCard(tint: TR.Palette.sky)
        }
        .buttonStyle(.trPressable)
    }

    // MARK: - Weight trend

    var weightTrendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashCardHeader(icon: "scalemass.fill", title: NSLocalizedString("dashboard.weightTrend", comment: ""), tint: TR.Palette.sky) {
                if let delta = vm.weightTrendDelta {
                    TRPill(verbatim: String(format: "%+.1f %@", delta, NSLocalizedString("unit.lbs", comment: "")),
                           systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right", tint: TR.Palette.sky)
                }
            }
            if let weight = vm.latestWeightLbs {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", weight))
                        .font(TR.Font.number(30))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(NSLocalizedString("unit.lbs", comment: ""))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                Text(NSLocalizedString("dashboard.weightTrend.30day", comment: ""))
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trCard(tint: TR.Palette.sky)
    }

    // MARK: - Forecast

    func forecastCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(TR.Palette.gold)
                .frame(width: 40, height: 40)
                .background(TR.Palette.gold.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                TRKicker(Text(NSLocalizedString("dashboard.forecast", comment: "")), color: TR.Palette.gold)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .trCard(tint: TR.Palette.gold)
    }

    // MARK: - Active stack (adjuncts / peptides / GLP-1)

    private var activeStackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashCardHeader(icon: "list.bullet.clipboard", title: NSLocalizedString("dashboard.activeProtocol", comment: ""), tint: TR.Palette.coral)
            if let proto = vm.activeProtocol {
                compoundRow(icon: "syringe.fill", color: Color(hex: proto.colorHex), name: proto.name,
                            detail: "E\(proto.frequencyDays)D")
            }
            ForEach(vm.activeCompounds, id: \.id) { compound in
                let category = compoundCategory(compound.supplementName)
                compoundRow(icon: categoryIcon(category), color: categoryColor(category), name: compound.supplementName,
                            detail: "\(formatCompoundDose(compound.doseAmount, unit: compound.doseUnit)) · E\(compound.frequencyDays)D")
            }
        }
        .trCard()
    }

    private func compoundRow(icon: String, color: Color, name: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15), in: Circle())
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TR.Palette.textPrimary)
            Spacer()
            Text(detail)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(TR.Palette.textSecondary)
        }
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
        case "glp1":      return TR.Palette.mint
        case "ai":        return TR.Palette.tangerine
        case "fertility": return Color(trHex: 0xFF7AC6)
        default:          return TR.Palette.sky
        }
    }

    private func formatCompoundDose(_ dose: Double, unit: String) -> String {
        if dose == dose.rounded() { return "\(Int(dose))\(unit)" }
        return String(format: "%.2g%@", dose, unit)
    }
}

// MARK: - Quick Stat Tile

struct QuickStatTile: View {
    let icon: String
    var tint: Color = TR.Palette.coral
    let label: String
    let value: String
    let subtitle: String
    var delta: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.15), in: Circle())
                Spacer()
                if let d = delta, abs(d) >= 0.1 {
                    HStack(spacing: 2) {
                        Image(systemName: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%+.1f", d)).monospacedDigit()
                    }
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(d >= 0 ? TR.Palette.teal : TR.Palette.coral)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(TR.Font.number(24, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TR.Palette.textTertiary)
                }
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TR.Palette.surfaceRaised.opacity(0.55), in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous).strokeBorder(TR.Palette.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TR.Font.number(18, weight: .heavy))
                .foregroundStyle(TR.Palette.textPrimary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
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
            TRBackground()

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
                    StatBubble(value: "\(totalCheckins)", label: NSLocalizedString("trial.checkins", comment: ""))
                    if streak > 0 {
                        StatBubble(value: "\(streak)d", label: NSLocalizedString("trial.streak", comment: ""))
                    }
                    if let score = latestScore {
                        StatBubble(value: "\(score)", label: NSLocalizedString("dashboard.protocolScore", comment: ""))
                    }
                }

                // What you keep vs what you lose
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("dashboard.trial.freeForever", comment: "").uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        Text(NSLocalizedString("dashboard.trial.freeFeatures", comment: ""))
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    Text(NSLocalizedString("dashboard.trial.withPro", comment: "").uppercased())
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
