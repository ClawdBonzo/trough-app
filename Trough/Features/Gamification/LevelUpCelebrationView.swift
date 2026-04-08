import SwiftUI

struct LevelUpCelebrationView: View {
    let event: CelebrationEvent
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var particles: [ParticleInfo] = []
    @State private var dismissTimer: Timer?

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Main celebration content
                VStack(spacing: 20) {
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

                    Button(action: { dismiss() }) {
                        Text("🔥 Awesome!")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                            .cornerRadius(8)
                    }
                }
                .padding(20)
                .background(Color(#colorLiteral(red: 0.087, green: 0.130, blue: 0.241, alpha: 1)))
                .cornerRadius(16)
                .scaleEffect(scale)
                .opacity(opacity)

                Spacer()
            }
            .padding(20)

            // Particle effects
            ForEach(particles, id: \.id) { particle in
                ParticleView(particle: particle)
            }
        }
        .onAppear {
            animateAppearance()
            generateParticles()
            startDismissTimer()
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }

    // MARK: - Content Builders

    @ViewBuilder
    private func levelUpContent(level: Int, levelName: String, totalXP: Int) -> some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 48))

            VStack(spacing: 4) {
                Text("LEVEL UP!")
                    .font(.title.bold())
                    .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                HStack(spacing: 0) {
                    Text("Level ")
                        .foregroundColor(.white)
                    Text(String(level))
                        .font(.title.bold())
                        .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                    Text(" - ")
                        .foregroundColor(.white)
                    Text(levelName)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
            }

            Text("Total XP: \(totalXP)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func badgeUnlockContent(name: String, emoji: String) -> some View {
        VStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 48))

            VStack(spacing: 4) {
                Text("BADGE UNLOCKED!")
                    .font(.headline.bold())
                    .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                Text(name)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
        }
    }

    @ViewBuilder
    private func streakMilestoneContent(days: Int, type: String, xpGained: Int) -> some View {
        VStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 48))

            VStack(spacing: 4) {
                Text("STREAK MILESTONE!")
                    .font(.headline.bold())
                    .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                HStack(spacing: 0) {
                    Text(String(days))
                        .font(.title.bold())
                        .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))
                    Text(" day streak")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }

            Text("+\(xpGained) XP")
                .font(.caption.bold())
                .foregroundColor(Color(#colorLiteral(red: 0.153, green: 0.682, blue: 0.376, alpha: 1)))
        }
    }

    @ViewBuilder
    private func questCompletedContent(name: String, xpGained: Int) -> some View {
        VStack(spacing: 12) {
            Text("✅")
                .font(.system(size: 48))

            VStack(spacing: 4) {
                Text("QUEST COMPLETE!")
                    .font(.headline.bold())
                    .foregroundColor(Color(#colorLiteral(red: 0.914, green: 0.271, blue: 0.376, alpha: 1)))

                Text(name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            Text("+\(xpGained) XP")
                .font(.caption.bold())
                .foregroundColor(Color(#colorLiteral(red: 0.153, green: 0.682, blue: 0.376, alpha: 1)))
        }
    }

    // MARK: - Animations

    private func animateAppearance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
    }

    private func generateParticles() {
        for _ in 0..<15 {
            let randomX = CGFloat.random(in: -100...100)
            let randomY = CGFloat.random(in: -100...100)
            let randomDuration = Double.random(in: 0.5...1.5)
            let particle = ParticleInfo(
                id: UUID(),
                x: randomX,
                y: randomY,
                duration: randomDuration,
                emoji: ["⭐", "✨", "🎉", "🔥"].randomElement() ?? "⭐"
            )
            particles.append(particle)
        }
    }

    private func startDismissTimer() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            scale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            .font(.title)
            .offset(x: position.x, y: position.y)
            .opacity(opacity)
            .onAppear {
                animate()
            }
    }

    private func animate() {
        withAnimation(.easeOut(duration: particle.duration)) {
            position = CGPoint(
                x: particle.x * 2,
                y: particle.y * 2 - 100
            )
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
        event: .levelUp(level: 5, levelName: "DRIVEN", totalXP: 360)
    ) { }
        .background(Color.black)
}
