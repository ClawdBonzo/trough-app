// DiagnosticQuizView.swift — Trough v1.1
// 5-slider diagnostic quiz using HapticSlider, calculates first Protocol Score

import SwiftUI

struct DiagnosticQuizView: View {
    @Binding var energy: Double
    @Binding var mood: Double
    @Binding var libido: Double
    @Binding var sleep: Double
    @Binding var clarity: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var currentSlider = 0

    private let sliders: [(emoji: String, label: String)] = [
        ("⚡️", "Energy"),
        ("😊", "Mood"),
        ("🔥", "Libido"),
        ("😴", "Sleep Quality"),
        ("🧠", "Mental Clarity"),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            Text("How are you feeling?")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 15)

                            Text("Rate each area on a scale of 1–5.\nWe'll calculate your baseline Protocol Score.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                        }
                        .padding(.top, 24)

                        // Sliders
                        VStack(spacing: 20) {
                            sliderRow(index: 0, value: $energy)
                            sliderRow(index: 1, value: $mood)
                            sliderRow(index: 2, value: $libido)
                            sliderRow(index: 3, value: $sleep)
                            sliderRow(index: 4, value: $clarity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(AppColors.card)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                }

                // Bottom CTA
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("See My Score")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func sliderRow(index: Int, value: Binding<Double>) -> some View {
        HapticSlider(
            emoji: sliders[index].emoji,
            label: sliders[index].label,
            value: value
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8)
                .delay(0.15 + Double(index) * 0.08),
            value: appeared
        )
    }
}
