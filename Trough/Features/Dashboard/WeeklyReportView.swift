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
                AppColors.background.ignoresSafeArea()

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
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.accent)
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
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
                            .foregroundColor(.secondary)
                        Text("Not enough data yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Check in for 7 consecutive days to unlock your weekly report.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(AppColors.accent)
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
            .environment(\.colorScheme, .dark)
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
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
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
        .padding(20)
        .background(AppColors.card)
        .cornerRadius(20)
    }

    // MARK: Header

    private var reportHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Report")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(weekRangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(AppColors.accent)
                Text("\(report.streakLength)d")
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.accent.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    // MARK: Score ring + change badge

    private var scoreSection: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: report.protocolScore / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", report.protocolScore))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("avg")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol Score")
                    .font(.headline)
                    .foregroundColor(.white)
                if report.priorProtocolScore > 0 {
                    HStack(spacing: 6) {
                        changeBadge(report.scoreChange)
                        Text("vs prior week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(DashboardViewModel.interpret(report.protocolScore))
                    .font(.caption)
                    .foregroundColor(scoreColor)
            }
            Spacer()
        }
    }

    // MARK: Metric bars

    private var metricBarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week vs Prior Week")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            let metrics: [(String, String, Double, Double)] = [
                ("⚡️", "Energy",        report.avgEnergy,  report.priorAvgEnergy),
                ("😌", "Mood",           report.avgMood,    report.priorAvgMood),
                ("🔥", "Libido",         report.avgLibido,  report.priorAvgLibido),
                ("🌙", "Sleep Quality",  report.avgSleep,   report.priorAvgSleep),
                ("🧠", "Mental Clarity", report.avgClarity, report.priorAvgClarity),
            ]

            ForEach(metrics, id: \.1) { emoji, label, current, prior in
                MetricComparisonRow(emoji: emoji, label: label, current: current, prior: prior)
            }
        }
        .padding(14)
        .background(AppColors.background.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: HealthKit summary row

    @ViewBuilder
    private var hkSection: some View {
        HStack(spacing: 20) {
            if let hrv = report.avgHRV {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(AppColors.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.0f ms", hrv))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Avg HRV")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if let sleep = report.avgSleepHours {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(.indigo)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.1f hrs", sleep))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Avg Sleep")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                .foregroundColor(.white)
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
                        "\(report.totalInjections) injection\(report.totalInjections == 1 ? "" : "s")",
                        systemImage: "syringe"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                Label("\(Int(report.morningWoodPct))% MW", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(Int(report.workoutCompletionPct))% workouts", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let aiSummary = report.aiDosesSummary {
                Label(aiSummary, systemImage: "shield.checkered")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.white)
                    Text(doctorNotes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            if let summary = report.peptideSummary {
                Label(summary, systemImage: "pills.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Helpers

    private var scoreColor: Color { DashboardViewModel.color(for: report.protocolScore) }

    private func changeBadge(_ change: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%+.0f", change))
        }
        .font(.caption.bold())
        .foregroundColor(change >= 0 ? .green : AppColors.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((change >= 0 ? Color.green : AppColors.accent).opacity(0.15))
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
                Text("\(emoji) \(label)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f", current))
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Prior week (faded)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: geo.size.width * (prior / 5.0), height: 6)
                    // Current week
                    RoundedRectangle(cornerRadius: 3)
                        .fill(current >= prior ? Color(hex: "#27AE60") : AppColors.accent)
                        .frame(width: geo.size.width * (current / 5.0), height: 6)
                }
            }
            .frame(height: 6)
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
