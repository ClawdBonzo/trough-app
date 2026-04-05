// ScoreRevealView.swift — Trough v1.1
// Animated Protocol Score reveal with ring gauge + interpretation

import SwiftUI

struct ScoreRevealView: View {
    let score: Int
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var animatedScore: Int = 0
    @State private var ringProgress: CGFloat = 0
    @State private var appeared = false
    @State private var showInterpretation = false

    private var scoreColor: Color {
        DashboardViewModel.color(for: Double(score))
    }

    private var interpretation: String {
        DashboardViewModel.interpret(Double(score))
    }

    private var encouragement: String {
        switch score {
        case 80...: return NSLocalizedString("scoreReveal.encourage.high", comment: "")
        case 60..<80: return NSLocalizedString("scoreReveal.encourage.mid", comment: "")
        case 40..<60: return NSLocalizedString("scoreReveal.encourage.low", comment: "")
        default: return NSLocalizedString("scoreReveal.encourage.veryLow", comment: "")
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Score ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 12)
                        .frame(width: 180, height: 180)

                    // Fill
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))

                    // Number
                    VStack(spacing: 4) {
                        Text("\(animatedScore)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: false))

                        Text(NSLocalizedString("scoreReveal.protocolScore", comment: ""))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .scaleEffect(appeared ? 1.0 : 0.7)
                .opacity(appeared ? 1.0 : 0)

                Spacer().frame(height: 32)

                // Interpretation badge
                VStack(spacing: 12) {
                    Text(interpretation)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)

                    Text(encouragement)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(showInterpretation ? 1 : 0)
                .offset(y: showInterpretation ? 0 : 15)

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text(NSLocalizedString("scoreReveal.cta", comment: ""))
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
                .opacity(showInterpretation ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }

            // Animate ring fill
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                ringProgress = CGFloat(score) / 100.0
            }

            // Count up the score number
            animateScoreCount()

            // Show interpretation after ring finishes
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(1.4)) {
                showInterpretation = true
            }
        }
    }

    private func animateScoreCount() {
        let duration: Double = 1.2
        let steps = min(score, 60)
        let interval = duration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + interval * Double(i)) {
                withAnimation(.none) {
                    animatedScore = Int(Double(score) * Double(i) / Double(steps))
                }
            }
        }
    }
}
