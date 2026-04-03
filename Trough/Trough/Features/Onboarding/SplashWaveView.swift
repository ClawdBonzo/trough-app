// SplashWaveView.swift — Trough v1.1
// Animated sine-wave splash screen with app branding

import SwiftUI

struct SplashWaveView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var phase: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            // Animated sine wave background
            WaveShape(phase: phase, amplitude: 30, frequency: 1.5)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.4), AppColors.accent.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 200)
                .offset(y: 120)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        phase = .pi * 2
                    }
                }

            WaveShape(phase: phase + .pi / 2, amplitude: 20, frequency: 2.0)
                .fill(AppColors.secondary.opacity(0.3))
                .frame(height: 160)
                .offset(y: 160)

            VStack(spacing: 32) {
                Spacer()

                // App icon + name
                VStack(spacing: 16) {
                    Image("AppIcon-Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .scaleEffect(appeared ? 1.0 : 0.6)
                        .opacity(appeared ? 1.0 : 0)

                    Text("TROUGH")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Text("Track your protocol.\nOwn your data.")
                        .font(.title3)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                Spacer()

                // CTA
                VStack(spacing: 16) {
                    Button(action: onContinue) {
                        Text("Let's Dial You In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 20)

                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Wave Shape

struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let y = midY + amplitude * sin((relativeX * frequency * .pi * 2) + phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}
