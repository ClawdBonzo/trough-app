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
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            if protocols.isEmpty || injections.isEmpty {
                emptyState
            } else {
                let curveData = data  // compute once per render; engine also memoizes across renders
                chart(for: curveData)
                legendRow(for: curveData)
                toggleRow
            }
            DisclaimerBanner(type: .pkCurve)
        }
        // No repeatForever animation — it causes visible layout shift
    }

    private static let lineColors: [Color] = [TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold]

    // MARK: Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TR.Palette.coral)
                .frame(width: 30, height: 30)
                .background(TR.Palette.coral.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            TRKicker(Text(NSLocalizedString("dashboard.estimatedBloodLevel", comment: "")))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 6)
            if overdueDays > 0 {
                TRPill(Text(String(format: NSLocalizedString("pk.overdue", comment: ""), overdueDays)),
                       systemImage: "exclamationmark.circle.fill", tint: TR.Palette.coral)
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
        let lineGradient = LinearGradient(colors: Self.lineColors, startPoint: .bottom, endPoint: .top)

        Chart {
            // Confidence bands, or a soft fill under the curve when bands are off.
            if showBands {
                ForEach(combined) { pt in
                    AreaMark(
                        x: .value("Day", pt.time),
                        yStart: .value("Lower", pt.lowerBand),
                        yEnd: .value("Upper", pt.upperBand)
                    )
                    .foregroundStyle(LinearGradient(colors: [TR.Palette.coral.opacity(0.26), TR.Palette.coral.opacity(0.05)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                }
            } else {
                ForEach(combined) { pt in
                    AreaMark(x: .value("Day", pt.time), y: .value("Level (ng/dL)", pt.level))
                        .foregroundStyle(LinearGradient(colors: [TR.Palette.coral.opacity(0.30), TR.Palette.coral.opacity(0.0)],
                                                        startPoint: .top, endPoint: .bottom))
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
                    .foregroundStyle(isMulti ? AnyShapeStyle(Color(hex: curve.colorHex)) : AnyShapeStyle(lineGradient))
                    .lineStyle(StrokeStyle(lineWidth: isMulti ? 2 : 3.5, lineCap: .round, lineJoin: .round))
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
                .foregroundStyle(TR.Palette.gold.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    refLabel(NSLocalizedString("pk.peak", comment: ""), color: TR.Palette.gold)
                }

            // Trough reference rule
            RuleMark(y: .value("Trough", troughRef))
                .foregroundStyle(TR.Palette.sky.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .bottom, alignment: .leading, spacing: 2) {
                    refLabel(NSLocalizedString("pk.trough", comment: ""), color: TR.Palette.sky)
                }

            // "You are here" — vertical guide + glowing white-hot dot
            if data.currentDayIndex < combined.count {
                let current = combined[data.currentDayIndex]
                RuleMark(x: .value("Now", current.time))
                    .foregroundStyle(.white.opacity(0.12))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(
                    x: .value("Day", current.time),
                    y: .value("Level (ng/dL)", current.level)
                )
                .symbol {
                    ZStack {
                        Circle().fill(TR.Palette.coral.opacity(0.28)).frame(width: 26, height: 26)
                        Circle().fill(TR.Palette.coral.opacity(0.5)).frame(width: 16, height: 16)
                        Circle().fill(.white).frame(width: 9, height: 9)
                    }
                    .shadow(color: TR.Palette.coral.opacity(0.9), radius: 8)
                }
                .annotation(position: .top, spacing: 6) {
                    Text(NSLocalizedString("pk.now", comment: ""))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(TR.Gradients.cta, in: Capsule())
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 7.0)) { value in
                if let d = value.as(Double.self) {
                    AxisValueLabel {
                        Text(dayLabel(d))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(TR.Palette.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v >= 1000 ? "\(Int(v / 1000))k" : "\(Int(v))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(TR.Palette.textTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(combined.map(\.upperBand).max() ?? 1000))
        .frame(height: 220)
        .accessibilityLabel(Text(NSLocalizedString("dashboard.estimatedBloodLevel", comment: "")))
    }

    private func refLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    // MARK: Legend

    private func legendRow(for data: PKCurveData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                legendItem(color: TR.Palette.coral, label: dashL("pk.legend.estimated", "Estimated level"), dash: false)
                legendItem(color: TR.Palette.coral.opacity(0.3), label: dashL("pk.legend.variation", "±20% variation"), dash: false, isArea: true)
            }
            if data.curves.count > 1 {
                HStack(spacing: 12) {
                    ForEach(data.curves) { curve in
                        legendItem(color: Color(hex: curve.colorHex), label: curve.compound.components(separatedBy: " ").last ?? curve.compound, dash: false)
                    }
                    legendItem(color: .white.opacity(0.85), label: dashL("pk.legend.combined", "Combined"), dash: true)
                }
            }
            HStack(spacing: 16) {
                legendItem(color: TR.Palette.gold.opacity(0.7), label: dashL("pk.legend.peak", "Peak window"), dash: true)
                legendItem(color: TR.Palette.sky.opacity(0.7), label: dashL("pk.legend.trough", "Approaching trough"), dash: true)
            }
        }
        .font(.caption2.weight(.semibold))
    }

    private func legendItem(color: Color, label: String, dash: Bool, isArea: Bool = false) -> some View {
        HStack(spacing: 5) {
            if isArea {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 8)
            } else if dash {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in Capsule().fill(color).frame(width: 4, height: 2) }
                }
                .frame(width: 16)
            } else {
                Capsule().fill(color).frame(width: 16, height: 3)
            }
            Text(label).foregroundStyle(TR.Palette.textSecondary)
        }
    }

    // MARK: Toggles

    private var toggleRow: some View {
        HStack(spacing: 16) {
            Toggle(dashL("pk.toggle.absorption", "Absorption delay"), isOn: $absorptionDelay)
                .toggleStyle(SmallToggleStyle())
            Toggle(dashL("pk.toggle.bands", "Show bands"), isOn: $showBands)
                .toggleStyle(SmallToggleStyle())
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(TR.Palette.textSecondary)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            TroughWaveMotif(color: TR.Palette.coral.opacity(0.35), lineWidth: 3)
                .frame(height: 60)
            Text(NSLocalizedString("dashboard.pkCurve.empty", comment: ""))
                .font(.subheadline)
                .foregroundStyle(TR.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: Helper

    private func dayLabel(_ t: Double) -> String {
        if abs(t) < 0.5 { return NSLocalizedString("pk.now", comment: "") }
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
                    .foregroundStyle(configuration.isOn ? TR.Palette.coral : TR.Palette.textTertiary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
