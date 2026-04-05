// ProjectedImprovementView.swift — Trough v1.1
// 7-day animated line graph showing projected Protocol Score improvement

import SwiftUI

struct ProjectedImprovementView: View {
    let currentScore: Int
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var graphProgress: CGFloat = 0

    // Projected 7-day scores: start at current, improve toward ~85
    private var projectedScores: [Int] {
        let start = Double(currentScore)
        let target = max(start + 20, 85.0)
        return (0..<7).map { day in
            let t = Double(day) / 6.0
            // Ease-out curve toward target
            let eased = 1 - pow(1 - t, 2.5)
            return Int(start + (target - start) * eased)
        }
    }

    private var targetScore: Int {
        projectedScores.last ?? 85
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(spacing: 8) {
                    Text(NSLocalizedString("projected.title", comment: ""))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(appeared ? 1 : 0)

                    Text(NSLocalizedString("projected.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                }

                Spacer().frame(height: 28)

                // Score change badge
                HStack(spacing: 16) {
                    scoreBadge(label: NSLocalizedString("projected.today", comment: ""), value: currentScore, color: DashboardViewModel.color(for: Double(currentScore)))
                    Image(systemName: "arrow.right")
                        .font(.title3.bold())
                        .foregroundColor(AppColors.textSecondary)
                    scoreBadge(label: NSLocalizedString("projected.day7", comment: ""), value: targetScore, color: DashboardViewModel.color(for: Double(targetScore)))
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)

                Spacer().frame(height: 28)

                // Graph
                ProjectedGraph(scores: projectedScores, progress: graphProgress)
                    .frame(height: 200)
                    .padding(.horizontal, 24)

                // Day labels
                HStack {
                    ForEach(0..<7, id: \.self) { day in
                        Text(day == 0 ? NSLocalizedString("projected.now", comment: "") : "D\(day + 1)")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                        if day < 6 { Spacer() }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 4)

                Spacer()

                // Disclaimer
                DisclaimerBanner(type: .protocolScore)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // CTA
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text(NSLocalizedString("projected.cta", comment: ""))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button(action: onSkip) {
                        Text(NSLocalizedString("common.skip", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 1.5).delay(0.4)) {
                graphProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private func scoreBadge(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(AppColors.card)
        .cornerRadius(12)
    }
}

// MARK: - Projected Graph Shape

private struct ProjectedGraph: View {
    let scores: [Int]
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let minScore = (scores.min() ?? 0) - 10
            let maxScore = (scores.max() ?? 100) + 10
            let range = CGFloat(max(maxScore - minScore, 1))

            ZStack {
                // Grid lines
                ForEach([25, 50, 75], id: \.self) { level in
                    let y = geo.size.height * (1 - CGFloat(level - minScore) / range)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                }

                // Gradient fill under curve
                GraphFillShape(scores: scores, minScore: minScore, range: range)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width * progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )

                // Line
                GraphLineShape(scores: scores, minScore: minScore, range: range)
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppColors.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                // Dots
                ForEach(0..<scores.count, id: \.self) { i in
                    let x = scores.count > 1
                        ? geo.size.width * CGFloat(i) / CGFloat(scores.count - 1)
                        : geo.size.width / 2
                    let y = geo.size.height * (1 - CGFloat(scores[i] - minScore) / range)
                    let dotProgress = CGFloat(i) / CGFloat(max(scores.count - 1, 1))

                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                        .opacity(progress >= dotProgress ? 1 : 0)
                        .scaleEffect(progress >= dotProgress ? 1 : 0.3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress >= dotProgress)
                }
            }
        }
    }
}

private struct GraphLineShape: Shape {
    let scores: [Int]
    let minScore: Int
    let range: CGFloat

    func path(in rect: CGRect) -> Path {
        guard scores.count > 1 else { return Path() }
        var path = Path()

        for (i, score) in scores.enumerated() {
            let x = rect.width * CGFloat(i) / CGFloat(scores.count - 1)
            let y = rect.height * (1 - CGFloat(score - minScore) / range)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let prev = scores[i - 1]
                let prevX = rect.width * CGFloat(i - 1) / CGFloat(scores.count - 1)
                let prevY = rect.height * (1 - CGFloat(prev - minScore) / range)
                let cx1 = prevX + (x - prevX) * 0.4
                let cx2 = x - (x - prevX) * 0.4
                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: cx1, y: prevY),
                    control2: CGPoint(x: cx2, y: y)
                )
            }
        }
        return path
    }
}

private struct GraphFillShape: Shape {
    let scores: [Int]
    let minScore: Int
    let range: CGFloat

    func path(in rect: CGRect) -> Path {
        guard scores.count > 1 else { return Path() }
        var path = GraphLineShape(scores: scores, minScore: minScore, range: range).path(in: rect)

        let lastX = rect.width
        path.addLine(to: CGPoint(x: lastX, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
