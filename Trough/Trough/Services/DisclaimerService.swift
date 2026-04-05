import Foundation

// MARK: - DisclaimerService

/// Provides standard medical disclaimer strings.
/// CLAUDE.md rule: use on every PK/insight/score/bloodwork screen.
enum DisclaimerService {
    static var standard: String {
        NSLocalizedString("disclaimer.standard", comment: "")
    }

    static var bloodwork: String {
        NSLocalizedString("disclaimer.bloodwork", comment: "")
    }

    static var pkCurve: String {
        NSLocalizedString("disclaimer.pkCurve", comment: "")
    }

    static var protocolScore: String {
        NSLocalizedString("disclaimer.protocolScore", comment: "")
    }

    static var insight: String {
        NSLocalizedString("disclaimer.insight", comment: "")
    }

    static var weeklyReport: String {
        NSLocalizedString("disclaimer.weeklyReport", comment: "")
    }

    static var supplementAdvice: String {
        NSLocalizedString("disclaimer.supplement", comment: "")
    }

    static var fertility: String {
        NSLocalizedString("disclaimer.fertility", comment: "")
    }
}
