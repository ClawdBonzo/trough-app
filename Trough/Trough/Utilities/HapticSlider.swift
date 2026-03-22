import SwiftUI
import UIKit

/// A 1–5 integer slider that fires UIImpactFeedbackGenerator on each step.
/// Thumb and filled track use AppColors.accent.
struct HapticSlider: View {
    let emoji: String
    let label: String
    @Binding var value: Double

    @State private var lastHapticValue: Double = 0
    private let generator = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(emoji)
                    .font(.title3)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.accent)
                    .monospacedDigit()
                    .frame(minWidth: 20, alignment: .trailing)
            }
            Slider(value: $value, in: 1...5, step: 1)
                .tint(AppColors.accent)
                .onChange(of: value) { _, newValue in
                    guard newValue != lastHapticValue else { return }
                    generator.impactOccurred()
                    lastHapticValue = newValue
                }
        }
        .onAppear {
            generator.prepare()
            lastHapticValue = value
        }
    }
}
