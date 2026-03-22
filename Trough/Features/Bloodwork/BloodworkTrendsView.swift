import SwiftUI
import Charts

// MARK: - BloodworkTrendsView

struct BloodworkTrendsView: View {
    @ObservedObject var vm: BloodworkViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Panel selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BloodworkViewModel.TrendPanel.allCases) { panel in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.selectedPanel = panel
                                }
                            } label: {
                                Text(panel.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(vm.selectedPanel == panel ? .white : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        vm.selectedPanel == panel
                                            ? AppColors.accent
                                            : AppColors.card
                                    )
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Chart content
                chartContent
                    .padding(.horizontal)

                DisclaimerBanner(type: .bloodwork)
                    .padding(.horizontal)

                // Results table
                if !vm.results.isEmpty {
                    resultsTable
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: Chart routing

    @ViewBuilder
    private var chartContent: some View {
        switch vm.selectedPanel {
        case .primary:
            VStack(spacing: 12) {
                markerChart(
                    name: "Total Testosterone",
                    color: AppColors.accent,
                    title: "Total Testosterone"
                )
                markerChart(
                    name: "Free Testosterone",
                    color: Color(hex: "#4ECDC4"),
                    title: "Free Testosterone"
                )
            }
        case .e2:
            markerChart(name: "Estradiol (E2)", color: Color(hex: "#F39C12"), title: "Estradiol (E2)")
        case .hematocrit:
            VStack(spacing: 12) {
                markerChart(name: "Hematocrit", color: Color(hex: "#E74C3C"), title: "Hematocrit")
                markerChart(name: "Hemoglobin", color: Color(hex: "#C0392B"), title: "Hemoglobin")
            }
        case .shbg:
            markerChart(name: "SHBG", color: Color(hex: "#9B59B6"), title: "SHBG")
        case .lipids:
            VStack(spacing: 12) {
                markerChart(name: "Total Cholesterol", color: Color(hex: "#3498DB"), title: "Total Cholesterol")
                markerChart(name: "LDL",               color: Color(hex: "#E74C3C"), title: "LDL")
                markerChart(name: "HDL",               color: Color(hex: "#27AE60"), title: "HDL")
                markerChart(name: "Triglycerides",     color: Color(hex: "#F39C12"), title: "Triglycerides")
            }
        }
    }

    // MARK: Single marker chart

    private func markerChart(name: String, color: Color, title: String) -> some View {
        let points = vm.trendPoints[name] ?? []
        let def = vm.def(for: name)
        let unit = def?.unit ?? ""
        let rangeLow = def?.rangeLow
        let rangeHigh = def?.rangeHigh

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                if let last = points.last {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", last.value))
                            .font(.subheadline.bold())
                            .foregroundColor(valueColor(last.value, def: def))
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if points.isEmpty {
                Text("No data — add bloodwork results to see trends")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
            } else {
                referenceRangeChart(
                    points: points,
                    color: color,
                    rangeLow: rangeLow,
                    rangeHigh: rangeHigh,
                    unit: unit
                )
            }

            // Reference range label
            if let low = rangeLow, let high = rangeHigh {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 12, height: 6)
                        .cornerRadius(2)
                    Text("Ref: \(low, specifier: "%.1f")–\(high, specifier: "%.1f") \(unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(AppColors.card)
        .cornerRadius(14)
    }

    private func referenceRangeChart(
        points: [TrendPoint],
        color: Color,
        rangeLow: Double?,
        rangeHigh: Double?,
        unit: String
    ) -> some View {
        let minDate = points.map(\.date).min() ?? .now
        let maxDate = points.map(\.date).max() ?? .now
        let pad: TimeInterval = 86400
        let xStart = minDate.addingTimeInterval(-pad)
        let xEnd   = maxDate.addingTimeInterval(pad)

        return Chart {
            // Reference band
            if let low = rangeLow, let high = rangeHigh {
                RectangleMark(
                    xStart: .value("Start", xStart),
                    xEnd:   .value("End",   xEnd),
                    yStart: .value("Low",   low),
                    yEnd:   .value("High",  high)
                )
                .foregroundStyle(Color.green.opacity(0.08))

                RuleMark(y: .value("Low",  low))
                    .foregroundStyle(Color.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                RuleMark(y: .value("High", high))
                    .foregroundStyle(Color.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }

            // Data line
            ForEach(points) { pt in
                LineMark(
                    x: .value("Date",  pt.date),
                    y: .value("Value", pt.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date",  pt.date),
                    y: .value("Value", pt.value)
                )
                .foregroundStyle(color)
                .symbolSize(40)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartBackground { _ in AppColors.card }
        .frame(height: 140)
    }

    private func valueColor(_ value: Double, def: MarkerDef?) -> Color {
        guard let def else { return .white }
        return (value >= def.rangeLow && value <= def.rangeHigh) ? Color(hex: "#27AE60") : AppColors.accent
    }

    // MARK: Results table

    private var resultsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("All Results")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 8)

            ForEach(vm.results) { bw in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(bw.drawnAt.mediumString)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Spacer()
                        if let lab = bw.labName {
                            Text(lab)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    let keyMarkers = bw.markers.filter {
                        ["Total Testosterone", "Free Testosterone", "Estradiol (E2)", "Hematocrit"].contains($0.markerName)
                    }
                    if !keyMarkers.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            ForEach(keyMarkers, id: \.id) { m in
                                HStack(spacing: 4) {
                                    let inRange = (m.referenceRangeLow.map { m.value >= $0 } ?? true)
                                        && (m.referenceRangeHigh.map { m.value <= $0 } ?? true)
                                    Circle()
                                        .fill(inRange ? Color(hex: "#27AE60") : AppColors.accent)
                                        .frame(width: 6, height: 6)
                                    Text(m.markerName.abbreviated)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f", m.value))
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(AppColors.card)
                .cornerRadius(10)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - String abbreviation helper

private extension String {
    var abbreviated: String {
        switch self {
        case "Total Testosterone": return "Total T"
        case "Free Testosterone":  return "Free T"
        case "Estradiol (E2)":     return "E2"
        default: return self
        }
    }
}
