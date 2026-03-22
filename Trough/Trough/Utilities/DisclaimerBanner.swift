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
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(AppColors.background.opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
