// PersonalizationLoaderView.swift — Trough v1.1
// Pulsing bars "building your plan" loader that auto-advances

import SwiftUI

struct PersonalizationLoaderView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var currentStep = 0
    @State private var barScales: [CGFloat] = Array(repeating: 0, count: 5)

    private let steps = [
        NSLocalizedString("loader.step1", comment: ""),
        NSLocalizedString("loader.step2", comment: ""),
        NSLocalizedString("loader.step3", comment: ""),
        NSLocalizedString("loader.step4", comment: ""),
        NSLocalizedString("loader.step5", comment: ""),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Pulsing bars
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: i))
                            .frame(width: 24, height: 40 + barScales[i] * 60)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.12),
                                value: barScales[i]
                            )
                    }
                }
                .frame(height: 100)

                // Step text
                VStack(spacing: 12) {
                    Text(steps[min(currentStep, steps.count - 1)])
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                        .id(currentStep)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i <= currentStep ? AppColors.accent : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == currentStep ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                        }
                    }
                }

                Spacer()

                // Skip
                Button(action: onSkip) {
                    Text(NSLocalizedString("common.skip", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            appeared = true

            // Start bar pulsing
            for i in 0..<5 {
                barScales[i] = 1.0
            }

            // Step through messages
            for i in 0..<steps.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = i
                    }
                }
            }

            // Auto-advance after all steps
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps.count) * 0.8 + 0.5) {
                onComplete()
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        let colors: [Color] = [
            AppColors.accent,
            AppColors.accent.opacity(0.8),
            Color(hex: "#FFD700"),
            .green.opacity(0.8),
            AppColors.softCTA,
        ]
        return colors[index % colors.count]
    }
}
