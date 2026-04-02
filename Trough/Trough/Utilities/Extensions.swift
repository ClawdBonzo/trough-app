import SwiftUI
import Foundation

// MARK: - Date Extensions

extension Date {
    /// Returns the start of the day for this date in the current calendar.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// ISO-8601 string for Supabase compatibility.
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    /// True if this date is today.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Formatted as "MMM d, yyyy"
    var mediumString: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    /// Days between self and another date (positive = self is later).
    func daysSince(_ other: Date) -> Int {
        Calendar.current.dateComponents([.day], from: other.startOfDay, to: startOfDay).day ?? 0
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies the standard card background (card color + corner radius).
    func cardStyle() -> some View {
        self
            .padding()
            .background(AppColors.card)
            .cornerRadius(16)
    }

    /// Hides the view conditionally.
    @ViewBuilder
    func hidden(_ isHidden: Bool) -> some View {
        if isHidden { self.hidden() } else { self }
    }
}

// MARK: - Double Helpers

extension Double {
    /// Clamps the value to a closed range.
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    /// Protocol score: ((raw - 1) / 4) * 100 where raw is a 1-5 weighted average.
    static func protocolScore(from weightedAverage: Double) -> Double {
        ((weightedAverage - 1.0) / 4.0 * 100.0).clamped(to: 0...100)
    }
}

// MARK: - Locale-Aware Helpers

extension Locale {
    /// True if the device locale uses metric for body weight (non-US).
    static var usesMetricWeight: Bool {
        Locale.current.measurementSystem != .us
    }

    /// The appropriate weight unit label for the current locale.
    static var weightUnit: String {
        usesMetricWeight ? NSLocalizedString("unit.kg", comment: "") : NSLocalizedString("unit.lbs", comment: "")
    }
}

// MARK: - String Helpers

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
}

// MARK: - Accessibility Helpers

extension View {
    /// Ensures a minimum 44×44 pt tap area per HIG / WCAG AA requirements.
    func minTapTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }

    /// Marks the view as a button for VoiceOver if the system mark is missing.
    func accessibilityButton(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Empty State View

/// Reusable empty-state card with icon, title, subtitle, and optional CTA.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var ctaLabel: String? = nil
    var onCTA: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(AppColors.accent.opacity(0.6))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let label = ctaLabel, let action = onCTA {
                Button(label, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .accessibilityLabel(label)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
