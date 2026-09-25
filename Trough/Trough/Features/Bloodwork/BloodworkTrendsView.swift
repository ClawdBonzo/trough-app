import SwiftUI
import Charts

// MARK: - BloodworkTrendsView

struct BloodworkTrendsView: View {
    @ObservedObject var vm: BloodworkViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Panel selector
                GlassPillPicker(
                    items: vm.availablePanels,
                    selection: $vm.selectedPanel,
                    title: { $0.label }
                )

                // Chart content
                chartContent
                    .padding(.horizontal, TR.Metrics.gutter)

                DisclaimerBanner(type: .bloodwork)
                    .padding(.horizontal, TR.Metrics.gutter)

                // Results table
                if !vm.results.isEmpty {
                    resultsTable
                        .padding(.horizontal, TR.Metrics.gutter)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: Chart routing

    @ViewBuilder
    private var chartContent: some View {
        switch vm.selectedPanel {
        case .primary:
            VStack(spacing: 14) {
                markerChart(name: "Total Testosterone", color: TR.Palette.coral, title: MarkerFormat.displayName("Total Testosterone"))
                markerChart(name: "Free Testosterone", color: TR.Palette.teal, title: MarkerFormat.displayName("Free Testosterone"))
            }
        case .e2:
            markerChart(name: "Estradiol (E2)", color: TR.Palette.gold, title: MarkerFormat.displayName("Estradiol (E2)"))
        case .hematocrit:
            VStack(spacing: 14) {
                markerChart(name: "Hematocrit", color: TR.Palette.coralLight, title: MarkerFormat.displayName("Hematocrit"))
                markerChart(name: "Hemoglobin", color: TR.Palette.tangerine, title: MarkerFormat.displayName("Hemoglobin"))
            }
        case .shbg:
            markerChart(name: "SHBG", color: TR.Palette.lilac, title: MarkerFormat.displayName("SHBG"))
        case .lipids:
            VStack(spacing: 14) {
                markerChart(name: "Total Cholesterol", color: TR.Palette.sky, title: MarkerFormat.displayName("Total Cholesterol"))
                markerChart(name: "LDL",               color: TR.Palette.tangerine, title: MarkerFormat.displayName("LDL"))
                markerChart(name: "HDL",               color: TR.Palette.mint, title: MarkerFormat.displayName("HDL"))
                markerChart(name: "Triglycerides",     color: TR.Palette.gold, title: MarkerFormat.displayName("Triglycerides"))
            }
        case .fertility:
            VStack(spacing: 14) {
                fertilityChart(name: "FSH", color: TR.Palette.mint, title: gLoc("bloodwork.trends.fshTitle", "FSH — Fertility Recovery Zone"),
                               recoveryLow: 1.5, recoveryHigh: 9.0)
                markerChart(name: "LH", color: TR.Palette.teal, title: MarkerFormat.displayName("LH"))
                DisclaimerBanner(type: .fertility)
            }
        }
    }

    // MARK: Card chrome

    private func chartCard<Chart: View, Legend: View>(
        title: String,
        color: Color,
        points: [TrendPoint],
        unit: String,
        emptyText: String,
        @ViewBuilder chart: () -> Chart,
        @ViewBuilder legend: () -> Legend
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 8, height: 8).trGlow(color, radius: 4)
                    Text(title)
                        .font(TR.Font.display(.subheadline, weight: .bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if let last = points.last {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", last.value))
                            .font(TR.Font.number(.title3, weight: .heavy))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(TR.Palette.textTertiary)
                    }
                }
            }

            if points.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(TR.Palette.textTertiary)
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                chart()
            }

            legend()
        }
        .trCard(tint: color)
    }

    private func bandLegend(_ text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(0.3))
                .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3])))
                .frame(width: 14, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundStyle(TR.Palette.textSecondary)
        }
    }

    // MARK: Single marker chart

    private func markerChart(name: String, color: Color, title: String) -> some View {
        let points = vm.trendPoints[name] ?? []
        let def = vm.def(for: name)
        let unit = def?.unit ?? ""
        // Use most-recent stored custom range if available, else fall back to MarkerDef default
        let storedMarkers = vm.results
            .sorted { $0.drawnAt < $1.drawnAt }
            .flatMap(\.markers)
            .filter { $0.markerName == name && $0.referenceRangeLow != nil }
        let rangeLow = storedMarkers.last?.referenceRangeLow ?? def?.rangeLow
        let rangeHigh = storedMarkers.last?.referenceRangeHigh ?? def?.rangeHigh

        return chartCard(
            title: title,
            color: color,
            points: points,
            unit: unit,
            emptyText: gLoc("bloodwork.trends.empty", "No data — add bloodwork results to see trends"),
            chart: {
                gradientAreaChart(points: points, color: color, bandLow: rangeLow, bandHigh: rangeHigh,
                                  bandTint: TR.Palette.teal)
            },
            legend: {
                if let low = rangeLow, let high = rangeHigh {
                    bandLegend(String(format: gLoc("bloodwork.refRangeUnit", "Ref: %.1f–%.1f %@"), locale: Locale.current, low, high, unit), tint: TR.Palette.teal)
                }
            }
        )
    }

    /// Gradient area + line chart with an optional shaded reference band.
    private func gradientAreaChart(
        points: [TrendPoint],
        color: Color,
        bandLow: Double?,
        bandHigh: Double?,
        bandTint: Color
    ) -> some View {
        let minDate = points.map(\.date).min() ?? .now
        let maxDate = points.map(\.date).max() ?? .now
        let pad: TimeInterval = 86400
        let xStart = minDate.addingTimeInterval(-pad)
        let xEnd   = maxDate.addingTimeInterval(pad)

        // Y domain covers the data and the band, with headroom, so the area has a floor
        // near the data rather than at zero.
        let values = points.map(\.value) + [bandLow, bandHigh].compactMap { $0 }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(hi - lo, max(abs(hi) * 0.1, 1))
        let floor = max(0, lo - span * 0.15)
        let ceil = hi + span * 0.15

        return Chart {
            // Reference band
            if let low = bandLow, let high = bandHigh {
                RectangleMark(
                    xStart: .value("Start", xStart),
                    xEnd:   .value("End",   xEnd),
                    yStart: .value("Low",   low),
                    yEnd:   .value("High",  high)
                )
                .foregroundStyle(bandTint.opacity(0.10))

                RuleMark(y: .value("Low",  low))
                    .foregroundStyle(bandTint.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                RuleMark(y: .value("High", high))
                    .foregroundStyle(bandTint.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }

            ForEach(points) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    yStart: .value("Floor", floor),
                    yEnd: .value("Value", pt.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.38), color.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date",  pt.date),
                    y: .value("Value", pt.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date",  pt.date),
                    y: .value("Value", pt.value)
                )
                .foregroundStyle(color)
                .symbolSize(pt.id == points.last?.id ? 90 : 36)
                .annotation(position: .overlay) {
                    if pt.id == points.last?.id {
                        Circle().fill(.white).frame(width: 5, height: 5)
                    }
                }
            }
        }
        .chartYScale(domain: floor...ceil)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(TR.Palette.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(TR.Palette.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(TR.Palette.hairline)
                AxisValueLabel()
                    .foregroundStyle(TR.Palette.textTertiary)
            }
        }
        .frame(height: 160)
    }

    /// Like `markerChart` but adds a labeled "Fertility Recovery Zone" band.
    private func fertilityChart(
        name: String,
        color: Color,
        title: String,
        recoveryLow: Double,
        recoveryHigh: Double
    ) -> some View {
        let points = vm.trendPoints[name] ?? []
        let def = vm.def(for: name)
        let unit = def?.unit ?? ""

        return chartCard(
            title: title,
            color: color,
            points: points,
            unit: unit,
            emptyText: gLoc("bloodwork.trends.emptyFSH", "No data — add bloodwork with FSH to see fertility trends"),
            chart: {
                gradientAreaChart(points: points, color: color, bandLow: recoveryLow, bandHigh: recoveryHigh,
                                  bandTint: TR.Palette.mint)
            },
            legend: {
                bandLegend(String(format: gLoc("bloodwork.trends.recoveryZone", "Fertility Recovery Zone: %.1f–%.1f %@"), locale: Locale.current, recoveryLow, recoveryHigh, unit),
                           tint: TR.Palette.mint)
            }
        )
    }

    // MARK: Results table

    private var resultsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            TRSectionHeader(Text("All Results"))

            ForEach(vm.results) { bw in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(bw.drawnAt.mediumString)
                            .font(TR.Font.display(.subheadline, weight: .bold))
                            .foregroundStyle(TR.Palette.textPrimary)
                        Spacer()
                        if let lab = bw.labName {
                            Text(lab)
                                .font(.caption)
                                .foregroundStyle(TR.Palette.textSecondary)
                        }
                    }

                    let keyMarkers = bw.markers.filter {
                        ["Total Testosterone", "Free Testosterone", "Estradiol (E2)", "Hematocrit"].contains($0.markerName)
                    }
                    if !keyMarkers.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(keyMarkers, id: \.id) { m in
                                BloodworkMarkerChip(name: m.markerName, value: m.value, unit: m.unit,
                                                    low: m.referenceRangeLow, high: m.referenceRangeHigh)
                            }
                        }
                    }
                }
                .trCard(padding: 14)
            }
        }
    }
}
