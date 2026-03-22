import SwiftUI
import Charts

// MARK: - PKCurveView

struct PKCurveView: View {
    let protocols: [PKProtocolInput]
    let injections: [PKInjectionInput]
    let overdueDays: Int

    @AppStorage("pkAbsorptionDelay") private var absorptionDelay = true
    @AppStorage("pkShowBands")       private var showBands = true

    private var engine: PKCurveEngine { PKCurveEngine.shared }

    private var data: PKCurveData {
        engine.computeMultiCompoundCurve(
            protocols: protocols,
            injections: injections,
            includeAbsorptionDelay: absorptionDelay
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if protocols.isEmpty || injections.isEmpty {
                emptyState
            } else {
                chart(for: data)
                legendRow(for: data)
                toggleRow
            }
            DisclaimerBanner(type: .pkCurve)
        }
        // No repeatForever animation — it causes visible layout shift
    }

    // MARK: Header

    private var headerRow: some View {
        HStack {
            Text("Estimated Blood Level")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            if overdueDays > 0 {
                Label("Overdue by \(overdueDays)d", systemImage: "exclamationmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(AppColors.accent)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Chart

    @ViewBuilder
    private func chart(for data: PKCurveData) -> some View {
        let combined = data.combinedPoints
        let isMulti  = data.curves.count > 1
        let peakRef  = (combined.map(\.level).max() ?? 700) * 0.8
        let troughRef = max(200, (combined.filter { $0.time > 0 }.map(\.level).min() ?? 300) * 1.4)

        Chart {
            // Confidence bands
            if showBands {
                ForEach(combined) { pt in
                    AreaMark(
                        x: .value("Day", pt.time),
                        yStart: .value("Lower", pt.lowerBand),
                        yEnd: .value("Upper", pt.upperBand)
                    )
                    .foregroundStyle(AppColors.accent.opacity(0.10))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Per-compound curves
            ForEach(data.curves) { curve in
                ForEach(curve.points) { pt in
                    LineMark(
                        x: .value("Day", pt.time),
                        y: .value("Level (ng/dL)", pt.level),
                        series: .value("Compound", curve.compound)
                    )
                    .foregroundStyle(Color(hex: curve.colorHex))
                    .lineStyle(StrokeStyle(lineWidth: isMulti ? 2 : 3))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Combined dashed total (multi-ester only)
            if isMulti {
                ForEach(combined) { pt in
                    LineMark(
                        x: .value("Day", pt.time),
                        y: .value("Level (ng/dL)", pt.level),
                        series: .value("Compound", "Combined")
                    )
                    .foregroundStyle(.white.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Peak reference rule
            RuleMark(y: .value("Peak", peakRef))
                .foregroundStyle(.green.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .trailing, alignment: .bottomTrailing) {
                    Text("Peak").font(.system(size: 9)).foregroundColor(.green.opacity(0.7))
                }

            // Trough reference rule
            RuleMark(y: .value("Trough", troughRef))
                .foregroundStyle(Color(hex: "#F39C12").opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .trailing, alignment: .topTrailing) {
                    Text("Trough").font(.system(size: 9)).foregroundColor(Color(hex: "#F39C12").opacity(0.7))
                }

            // "You are here" dot
            if data.currentDayIndex < combined.count {
                let current = combined[data.currentDayIndex]
                PointMark(
                    x: .value("Day", current.time),
                    y: .value("Level (ng/dL)", current.level)
                )
                .symbolSize(120)
                .foregroundStyle(AppColors.accent)
                .annotation(position: .top) {
                    Text("Now")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 2.0)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                if let d = value.as(Double.self) {
                    AxisValueLabel {
                        Text(dayLabel(d))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(combined.map(\.upperBand).max() ?? 1000))
        .frame(height: 200)
        .chartBackground { _ in AppColors.background }
    }

    // MARK: Legend

    private func legendRow(for data: PKCurveData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                legendItem(color: AppColors.accent.opacity(0.4), label: "Estimated level", dash: false)
                legendItem(color: AppColors.accent.opacity(0.2), label: "±20% variation", dash: false, isArea: true)
            }
            if data.curves.count > 1 {
                HStack(spacing: 12) {
                    ForEach(data.curves) { curve in
                        legendItem(color: Color(hex: curve.colorHex), label: curve.compound.components(separatedBy: " ").last ?? curve.compound, dash: false)
                    }
                    legendItem(color: .white.opacity(0.85), label: "Combined", dash: true)
                }
            }
            HStack(spacing: 16) {
                legendItem(color: .green.opacity(0.6),                   label: "Peak window",         dash: true)
                legendItem(color: Color(hex: "#F39C12").opacity(0.6),    label: "Approaching trough",  dash: true)
            }
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, label: String, dash: Bool, isArea: Bool = false) -> some View {
        HStack(spacing: 4) {
            if isArea {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 16, height: 8)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: dash ? 1.5 : 2)
                    .overlay(
                        dash ? AnyView(Rectangle().fill(Color.clear).frame(width: 16, height: 1.5)) : AnyView(EmptyView())
                    )
            }
            Text(label).foregroundColor(.secondary)
        }
    }

    // MARK: Toggles

    private var toggleRow: some View {
        HStack(spacing: 16) {
            Toggle("Absorption delay", isOn: $absorptionDelay)
                .toggleStyle(SmallToggleStyle())
            Toggle("Show bands", isOn: $showBands)
                .toggleStyle(SmallToggleStyle())
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    // MARK: Empty state

    private var emptyState: some View {
        Text("Log an injection to see your PK curve")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .multilineTextAlignment(.center)
    }

    // MARK: Helper

    private func dayLabel(_ t: Double) -> String {
        if abs(t) < 0.5 { return "Now" }
        let sign = t > 0 ? "+" : ""
        return "D\(sign)\(Int(t))"
    }
}

// MARK: - Compact toggle style

struct SmallToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? AppColors.accent : .secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
