import SwiftUI
import SwiftData

// MARK: - WeeklyReportView

struct WeeklyReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userType") private var userType = "trt"

    @State private var report: WeeklyReport? = nil
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ZStack {
                TRBackground()

                if let report {
                    ScrollView {
                        VStack(spacing: 16) {
                            WeeklyReportCard(report: report, userType: userType)
                                .padding(.horizontal)

                            Button {
                                renderAndShare(report: report)
                            } label: {
                                HStack(spacing: 8) {
                                    if isRendering {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    Text("Share Report")
                                }
                            }
                            .buttonStyle(TRPrimaryButtonStyle())
                            .padding(.horizontal)
                            .disabled(isRendering)

                            DisclaimerBanner(type: .weeklyReport)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 48))
                            .foregroundStyle(TR.Palette.textSecondary)
                        Text("Not enough data yet")
                            .font(.headline)
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text("Check in for 7 consecutive days to unlock your weekly report.")
                            .font(.subheadline)
                            .foregroundStyle(TR.Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TR.Palette.coral)
                }
            }
            .onAppear { loadReport() }
            .sheet(isPresented: $showShareSheet) {
                if let img = shareImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    private func loadReport() {
        report = WeeklyReportService.generateReport(
            weekEnding: Date.now.startOfDay,
            context: modelContext,
            userType: userType
        )
    }

    @MainActor
    private func renderAndShare(report: WeeklyReport) {
        isRendering = true
        let card = WeeklyReportCard(report: report, userType: userType)
            .frame(width: 390)
            .padding(16)
            .background(TR.Palette.background)
            .environment(\.colorScheme, .dark)
            .environment(\.trStaticRender, true)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        shareImage = renderer.uiImage
        isRendering = false
        showShareSheet = true
    }
}

// MARK: - WeeklyReportCard (shareable)

struct WeeklyReportCard: View {
    let report: WeeklyReport
    let userType: String

    private var weekRangeText: String {
        let fmt = SharedFormatters.monthDay
        return "\(fmt.string(from: report.weekStart)) – \(fmt.string(from: report.weekEnd))"
    }

    var body: some View {
        VStack(spacing: 20) {
            reportHeader
            scoreSection
            metricBarsSection
            if report.avgHRV != nil || report.avgSleepHours != nil {
                hkSection
            }
            if let insight = report.topInsight {
                insightSection(insight)
            }
            reportFooter
        }
        .trCard(tint: TR.Palette.coral, padding: 20)
    }

    // MARK: Header

    private var reportHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                TRKicker(Text(weekRangeText), color: TR.Palette.coral)
                Text("Weekly Report")
                    .font(TR.Font.display(.title2, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
            }
            Spacer()
            TRPill(verbatim: "\(report.streakLength)d", systemImage: "flame.fill", tint: TR.Palette.gold)
        }
    }

    // MARK: Score ring + change badge

    private var scoreSection: some View {
        HStack(spacing: 20) {
            TRRing(progress: report.protocolScore / 100, lineWidth: 9,
                   colors: [TR.Palette.coralDeep, TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]) {
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", report.protocolScore))
                        .font(TR.Font.number(24))
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text("avg")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(TR.Palette.textTertiary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol Score")
                    .font(TR.Font.display(.headline))
                    .foregroundStyle(TR.Palette.textPrimary)
                if report.priorProtocolScore > 0 {
                    HStack(spacing: 6) {
                        changeBadge(report.scoreChange)
                        Text("vs prior week")
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                }
                Text(DashboardViewModel.interpret(report.protocolScore))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: Metric bars

    private var metricBarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TRKicker(Text(verbatim: gLoc("weekly.compareKicker", "This Week vs Prior Week")))

            let metrics: [(String, String, Double, Double)] = [
                ("⚡️", gLoc("checkin.energy", "Energy"),               report.avgEnergy,  report.priorAvgEnergy),
                ("😌", gLoc("checkin.mood", "Mood"),                   report.avgMood,    report.priorAvgMood),
                ("🔥", gLoc("checkin.libido", "Libido"),               report.avgLibido,  report.priorAvgLibido),
                ("🌙", gLoc("checkin.sleepQuality", "Sleep Quality"),  report.avgSleep,   report.priorAvgSleep),
                ("🧠", gLoc("checkin.mentalClarity", "Mental Clarity"), report.avgClarity, report.priorAvgClarity),
            ]

            ForEach(metrics, id: \.1) { emoji, label, current, prior in
                MetricComparisonRow(emoji: emoji, label: label, current: current, prior: prior)
            }
        }
        .padding(14)
        .background(TR.Palette.surfaceRaised.opacity(0.5), in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
    }

    // MARK: HealthKit summary row

    @ViewBuilder
    private var hkSection: some View {
        HStack(spacing: 20) {
            if let hrv = report.avgHRV {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(TR.Palette.coral)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.0f ms", hrv))
                            .font(.subheadline.bold())
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text("Avg HRV")
                            .font(.caption2)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                }
            }
            if let sleep = report.avgSleepHours {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(TR.Palette.lilac)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: String(format: gLoc("unit.hoursShort", "%.1f hrs"), locale: Locale.current, sleep))
                            .font(.subheadline.bold())
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text("Avg Sleep")
                            .font(.caption2)
                            .foregroundStyle(TR.Palette.textSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: Top insight

    @ViewBuilder
    private func insightSection(_ insight: InsightResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insightIcon(insight.type))
                .foregroundColor(insightColor(insight.type))
                .font(.subheadline)
            Text(insight.message)
                .font(.subheadline)
                .foregroundStyle(TR.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(insightColor(insight.type).opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(insightColor(insight.type).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Footer

    private var reportFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if userType == "trt" {
                    Label(
                        report.totalInjections == 1
                            ? gLoc("weekly.injections.one", "1 injection")
                            : String(format: gLoc("weekly.injections.other", "%d injections"), report.totalInjections),
                        systemImage: "syringe"
                    )
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                }
                Spacer()
                Label(String(format: gLoc("weekly.morningWoodPct", "%d%% MW"), Int(report.morningWoodPct)), systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                Label(String(format: gLoc("weekly.workoutPct", "%d%% workouts"), Int(report.workoutCompletionPct)), systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            if let aiSummary = report.aiDosesSummary {
                Label(aiSummary, systemImage: "shield.checkered")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
            if let fertility = report.fertilitySnapshot {
                Label(fertility, systemImage: "figure.2.circle")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            if let doctorNotes = report.doctorNotes {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes for Doctor", systemImage: "stethoscope")
                        .font(.caption.bold())
                        .foregroundStyle(TR.Palette.textPrimary)
                    Text(doctorNotes)
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            if let summary = report.peptideSummary {
                Label(summary, systemImage: "pills.fill")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
            }
        }
    }

    // MARK: Helpers


    private func changeBadge(_ change: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%+.0f", change))
        }
        .font(.caption.bold())
        .foregroundStyle(change >= 0 ? TR.Palette.teal : TR.Palette.coral)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((change >= 0 ? TR.Palette.teal : TR.Palette.coral).opacity(0.15))
        .clipShape(Capsule())
    }

    private func insightColor(_ type: InsightType) -> Color {
        switch type {
        case .warning:  return Color(hex: "#F39C12")
        case .positive: return Color(hex: "#27AE60")
        case .neutral:  return .secondary
        }
    }

    private func insightIcon(_ type: InsightType) -> String {
        switch type {
        case .warning:  return "exclamationmark.triangle.fill"
        case .positive: return "checkmark.seal.fill"
        case .neutral:  return "lightbulb.fill"
        }
    }
}

// MARK: - MetricComparisonRow

struct MetricComparisonRow: View {
    let emoji: String
    let label: String
    let current: Double  // 1–5
    let prior: Double    // 1–5

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(verbatim: "\(emoji) \(label)")
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textSecondary)
                Spacer()
                Text(String(format: "%.1f", current))
                    .font(.caption.bold())
                    .foregroundStyle(TR.Palette.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Prior week (faded)
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: geo.size.width * (prior / 5.0), height: 7)
                    // Current week
                    Capsule()
                        .fill(LinearGradient(colors: current >= prior ? [TR.Palette.teal, TR.Palette.mint] : [TR.Palette.coralDeep, TR.Palette.coral],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * (current / 5.0), height: 7)
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
