import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncEngine: SyncEngine
    @StateObject private var vm = DashboardViewModel()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var toastManager: ToastManager
    @State private var showCheckin = false
    @State private var showWeeklyReport = false
    @State private var showPaywall = false
    @State private var showSampleDataBanner = false
    @State private var showProFeatures = false
    @AppStorage("userType") private var userType = "trt"
    @AppStorage("userIDString") private var userIDString = UUID().uuidString

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
                        if showSampleDataBanner { sampleDataBanner }
                        protocolScoreHero
                        checkinCTACard
                        streakCard
                        // PK Curve / Body Composition — blurred preview for free users
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
                                    title: "Body Composition",
                                    subtitle: "Track weight & body fat trends",
                                    onInfo: { showProFeatures = true }
                                ) { showPaywall = true }
                            }
                        }
                        // GLP-1 weight correlation (paid only)
                        if subscriptionManager.isSubscribed && vm.hasGLP1Data {
                            glp1CorrelationCard
                        }
                        // 7-Day Trends — always show (3 days free, full history paid)
                        trendChartCard
                        quickStatsCard
                    }
                    .padding()
                }
                } // end else isLoading
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if syncEngine.isSyncing {
                        ProgressView().tint(AppColors.accent)
                    } else {
                        Button { vm.triggerSync() } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Sync data")
                    }
                }
            }
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showProFeatures) {
                ProFeaturesSheet { showPaywall = true }
            }
        }
    }

    // MARK: - Sample Data Banner

    private var sampleDataBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("👋 No data yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Load sample data to explore the app, or start your first check-in.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 12) {
                Button("Load Sample Data") {
                    let userID = UUID(uuidString: userIDString) ?? UUID()
                    SampleDataService.insertSampleData(context: modelContext, userID: userID)
                    showSampleDataBanner = false
                    vm.load()
                }
                .font(.subheadline.bold())
                .foregroundColor(AppColors.accent)
                .accessibilityLabel("Load sample check-in and injection data")

                Button("Start Check-in") { showCheckin = true }
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

    // MARK: - Protocol Score Hero

    private var protocolScoreHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocol Score")
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
                    StatRow(label: "7-day avg", value: String(format: "%.0f", vm.sevenDayAvg))
                    StatRow(label: "Prior 7-day", value: String(format: "%.0f", vm.priorSevenDayAvg))
                    if vm.recentCheckins.isEmpty {
                        Button {
                            showCheckin = true
                        } label: {
                            Label("Log today", systemImage: "plus.circle.fill")
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
        .background(AppColors.card)
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
                            Text("Daily Check-in")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tap to log how you feel today")
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
                Text("Today's Check-in")
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
                Text("Check-in Streak")
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(vm.streak)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(vm.streak > 0 ? AppColors.accent : .secondary)
                    Text("days")
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
                    Text("Weekly\nReport")
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
                Text("See your real blood levels")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Personalized PK curve based on your protocol")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button { showPaywall = true } label: {
                    Text("Start Free Trial")
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
                             injectedAt: cal.date(byAdding: .day, value: -8, to: now)!, route: "intramuscular"),
            PKInjectionInput(compoundName: "Testosterone Cypionate", doseAmountMg: 100,
                             injectedAt: cal.date(byAdding: .day, value: -4, to: now)!, route: "intramuscular"),
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
                    Text("Fertility Mode Active")
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
                    StatRow(label: "hCG started", value: "\(weeks)w ago")
                    StatRow(label: "Protocol", value: vm.hcgProtocol?.name ?? "hCG")
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
                    Text("GLP-1 Weight Tracking")
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
                        Text("Energy stable")
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
                Text("GLP-1 + weight trending down + stable energy = protocol working well")
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
                Text("Body Composition")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let delta = vm.weightDelta30d {
                    let isDown = delta <= 0
                    Text(String(format: "%+.0f lbs", delta / 0.453592))
                        .font(.caption.bold())
                        .foregroundColor(isDown ? .green : AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((isDown ? Color.green : AppColors.accent).opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if vm.weightSeries30d.isEmpty {
                Text("Log body weight in your daily check-in")
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
                            y: .value("lbs", pt.weightKg / 0.453592)
                        )
                        .foregroundStyle(AppColors.accent.opacity(0.35))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(vm.weightMovingAvg) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("lbs", pt.weightKg / 0.453592)
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
                        StatRow(label: "Current", value: String(format: "%.0f lbs", latest.weightKg / 0.453592))
                        if let bf = vm.bodyFatSeries.last {
                            StatRow(label: "Body Fat", value: String(format: "%.1f%%", bf.weightKg))
                        }
                        if let delta = vm.weightDelta30d, abs(delta) > 0.05 {
                            StatRow(label: "30d Change", value: String(format: "%+.0f lbs", delta / 0.453592))
                        }
                    }
                }

                // Body fat overlay chart
                if !vm.bodyFatSeries.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.top, 4)

                    Text("Body Fat %")
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
        let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: .now)!.startOfDay
        return vm.metricSeries.map { series in
            var copy = series
            copy.dataPoints = series.dataPoints.filter { $0.date >= cutoff }
            return copy
        }
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(subscriptionManager.isSubscribed ? "7-Day Trends" : "Recent Trends")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if !subscriptionManager.isSubscribed {
                    Text("3 days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.background.opacity(0.6))
                        .clipShape(Capsule())
                }
            }

            if visibleMetricSeries.isEmpty || visibleMetricSeries.allSatisfy({ $0.dataPoints.isEmpty }) {
                Text("Check in daily to see your trends")
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
                            Text("See full 7-day history with Pro")
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
            Text("7-Day Summary")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickStatTile(
                    emoji: "⚡️",
                    label: "Avg Energy",
                    value: String(format: "%.1f", vm.avgEnergy7d),
                    subtitle: "/ 5"
                )
                QuickStatTile(
                    emoji: "🔥",
                    label: "Avg Libido",
                    value: String(format: "%.1f", vm.avgLibido7d),
                    subtitle: "/ 5"
                )
                QuickStatTile(
                    emoji: "🌅",
                    label: "Morning Wood",
                    value: String(format: "%.0f%%", vm.morningWoodPct30d),
                    subtitle: "30d"
                )
                if userType == "natural" {
                    QuickStatTile(
                        emoji: "💊",
                        label: "Supplements",
                        value: String(format: "%.0f%%", vm.supplementAdherence7d),
                        subtitle: "adherence"
                    )
                } else {
                    QuickStatTile(
                        emoji: "💉",
                        label: "Next Injection",
                        value: vm.injectionOverdueDays > 0 ? "Overdue" : "On track",
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

// MARK: - Quick Stat Tile

struct QuickStatTile: View {
    let emoji: String
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(emoji)
                    .font(.title3)
                Spacer()
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
