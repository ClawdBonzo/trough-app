import SwiftUI

// MARK: - Disclaimer type enum

enum DisclaimerType {
    case standard
    case protocolScore
    case pkCurve
    case bloodwork
    case insight
    case weeklyReport
    case supplementAdvice
    case fertility
}

// MARK: - Banner component

/// Compact disclaimer banner. Use on every screen that shows PK/insight/score/bloodwork data.
struct DisclaimerBanner: View {
    let type: DisclaimerType

    var message: String {
        switch type {
        case .standard:      return DisclaimerService.standard
        case .protocolScore: return DisclaimerService.protocolScore
        case .pkCurve:       return DisclaimerService.pkCurve
        case .bloodwork:     return DisclaimerService.bloodwork
        case .insight:       return DisclaimerService.insight
        case .weeklyReport:      return DisclaimerService.weeklyReport
        case .supplementAdvice:  return DisclaimerService.supplementAdvice
        case .fertility:         return DisclaimerService.fertility
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TR.Palette.sky.opacity(0.85))
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .foregroundStyle(TR.Palette.textSecondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                shape.fill(TR.Palette.surface.opacity(0.55))
                shape.fill(.ultraThinMaterial.opacity(0.35))
                shape.fill(LinearGradient(colors: [.white.opacity(0.04), .clear], startPoint: .top, endPoint: .center))
            }
        }
        .overlay(shape.strokeBorder(TR.Palette.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
