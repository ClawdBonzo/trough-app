import SwiftUI

struct LevelUpCelebrationView: View {
    let event: CelebrationEvent
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var particles: [ParticleInfo] = []
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    // Main content
                    Group {
                        switch event {
                        case .levelUp(let level, let levelName, let totalXP):
                            levelUpContent(level: level, levelName: levelName, totalXP: totalXP)

                        case .badgeUnlock(let name, let emoji):
                            badgeUnlockContent(name: name, emoji: emoji)

                        case .streakMilestone(let days, let type, let xpGained):
                            streakMilestoneContent(days: days, type: type, xpGained: xpGained)

                        case .questCompleted(let name, let xpGained):
                            questCompletedContent(name: name, xpGained: xpGained)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Button(action: { dismiss() }) {
                        Text("Awesome!")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(AppColors.accent)
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("Dismiss celebration")
                    .accessibilityHint("Double tap to close")
                }
                .padding(20)
                .background(AppColors.card)
                .cornerRadius(16)
                .scaleEffect(scale)
                .opacity(opacity)
            }
            .padding(20)

            // Particle effects — hidden from VoiceOver, suppressed when reduce motion is on
            if !reduceMotion {
                ForEach(particles, id: \.id) { particle in
                    ParticleView(particle: particle)
                }
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            animateAppearance()
            if !reduceMotion { generateParticles() }
            scheduleDismiss()
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    // MARK: - Content Builders

    @ViewBuilder
    private func levelUpContent(level: Int, levelName: String, totalXP: Int) -> some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 48))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("LEVEL UP!")
                    .font(.title.bold())
                    .foregroundColor(AppColors.accent)

                HStack(spacing: 0) {
                    Text("Level ")
                        .foregroundColor(.white)
                    Text(String(level))
                        .font(.title.bold())
                        .foregroundColor(AppColors.accent)
                    Text(" · \(levelName)")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
            }

            Text("Total XP: \(totalXP)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Level up! You reached level \(level): \(levelName). Total XP: \(totalXP).")
    }

    @ViewBuilder
    private func badgeUnlockContent(name: String, emoji: String) -> some View {
        VStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 48))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("BADGE UNLOCKED!")
                    .font(.headline.bold())
                    .foregroundColor(AppColors.accent)

                Text(name)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("Badge unlocked: \(name).")
    }

    @ViewBuilder
    private func streakMilestoneContent(days: Int, type: String, xpGained: Int) -> some View {
        VStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 48))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("STREAK MILESTONE!")
                    .font(.headline.bold())
                    .foregroundColor(AppColors.accent)

                HStack(spacing: 0) {
                    Text(String(days))
                        .font(.title.bold())
                        .foregroundColor(AppColors.accent)
                    Text(" day streak")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }

            Text("+\(xpGained) XP")
                .font(.caption.bold())
                .foregroundColor(Color(hex: "#27AE60"))
        }
        .accessibilityLabel("\(days)-day streak milestone! You earned \(xpGained) XP.")
    }

    @ViewBuilder
    private func questCompletedContent(name: String, xpGained: Int) -> some View {
        VStack(spacing: 12) {
            Text("✅")
                .font(.system(size: 48))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("QUEST COMPLETE!")
                    .font(.headline.bold())
                    .foregroundColor(AppColors.accent)

                Text(name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            Text("+\(xpGained) XP")
                .font(.caption.bold())
                .foregroundColor(Color(hex: "#27AE60"))
        }
        .accessibilityLabel("Quest completed: \(name). You earned \(xpGained) XP.")
    }

    // MARK: - Animations

    private func animateAppearance() {
        let animation: Animation = reduceMotion
            ? .easeIn(duration: 0.15)
            : .spring(response: 0.6, dampingFraction: 0.7)
        withAnimation(animation) {
            scale = 1.0
            opacity = 1.0
        }
    }

    private func generateParticles() {
        // Throttle to 10 particles max for performance
        for _ in 0..<10 {
            particles.append(ParticleInfo(
                id: UUID(),
                x: CGFloat.random(in: -120...120),
                y: CGFloat.random(in: -120...120),
                duration: Double.random(in: 0.6...1.4),
                emoji: ["⭐", "✨", "🎉", "🔥"].randomElement() ?? "⭐"
            ))
        }
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.1)
            : .easeOut(duration: 0.25)
        withAnimation(animation) {
            opacity = 0
            scale = 0.85
        }
        // Use a Task instead of DispatchQueue.main.asyncAfter
        Task { @MainActor in
            let ns: UInt64 = reduceMotion ? 100_000_000 : 250_000_000
            try? await Task.sleep(nanoseconds: ns)
            onDismiss()
        }
    }
}

// MARK: - Particle View

struct ParticleView: View {
    let particle: ParticleInfo

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 1.0

    var body: some View {
        Text(particle.emoji)
            .font(.title2)
            .offset(x: position.x, y: position.y)
            .opacity(opacity)
            .onAppear { animate() }
            .accessibilityHidden(true)
    }

    private func animate() {
        withAnimation(.easeOut(duration: particle.duration)) {
            position = CGPoint(x: particle.x * 2, y: particle.y * 2 - 100)
            opacity = 0
        }
    }
}

struct ParticleInfo {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let duration: Double
    let emoji: String
}

#Preview {
    LevelUpCelebrationView(
        event: .levelUp(level: 5, levelName: "Driven", totalXP: 360)
    ) { }
    .background(Color.black)
}
