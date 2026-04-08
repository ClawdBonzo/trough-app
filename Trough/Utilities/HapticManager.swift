import CoreHaptics
import Foundation

/// Manages haptic feedback for gamification events and user interactions.
final class HapticManager {
    static let shared = HapticManager()

    private var engine: CHHapticEngine?
    private let queue = DispatchQueue(label: "com.trough.haptics", qos: .userInteractive)

    init() {
        setupHapticEngine()
    }

    private func setupHapticEngine() {
        queue.async { [weak self] in
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                self?.engine = engine
            } catch {
                // Haptics not available on this device (simulator or older device)
                // This is non-critical; app continues without haptics
            }
        }
    }

    // MARK: - XP & Quest Haptics

    /// Light buzz when XP is earned (check-in, action completed)
    func xpEarned() {
        let pattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            )
        ], parameters: [])
        play(pattern)
    }

    /// Double buzz when a quest is completed
    func questComplete() {
        let pattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.1
            )
        ], parameters: [])
        play(pattern)
    }

    // MARK: - Level-Up Haptics

    /// Triple ascending buzz pattern for level-up celebrations
    func levelUp() {
        let pattern = try? CHHapticPattern(events: [
            // First buzz: high intensity
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            ),
            // Second buzz: medium
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.15
            ),
            // Third buzz: lower
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.30
            )
        ], parameters: [])
        play(pattern)
    }

    // MARK: - Badge & Milestone Haptics

    /// Special pattern for badge unlocks (exclamation-style buzz)
    func badgeUnlock() {
        let pattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.2
            )
        ], parameters: [])
        play(pattern)
    }

    /// Double buzz for streak milestones (3/7/14/30 day streak)
    func streakMilestone() {
        let pattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.12
            )
        ], parameters: [])
        play(pattern)
    }

    // MARK: - UI Interaction Haptics

    /// Light feedback for button taps
    func buttonTap() {
        let pattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0
            )
        ], parameters: [])
        play(pattern)
    }

    /// Feedback for toggling on/off
    func toggle() {
        let pattern = try? CHHapticPattern(events: [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            )
        ], parameters: [])
        play(pattern)
    }

    // MARK: - Private Helpers

    private func play(_ pattern: CHHapticPattern?) {
        guard let pattern = pattern, CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }

        queue.async { [weak self] in
            do {
                try self?.engine?.playPattern(pattern)
            } catch {
                // Silently fail if haptics unavailable
            }
        }
    }
}
