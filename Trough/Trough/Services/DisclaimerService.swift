import Foundation

// MARK: - DisclaimerService

/// Provides standard medical disclaimer strings.
/// CLAUDE.md rule: use on every PK/insight/score/bloodwork screen.
enum DisclaimerService {
    static let standard =
        "This information is for personal tracking only and does not constitute medical advice. " +
        "Consult a licensed healthcare provider before making any changes to your protocol."

    static let bloodwork =
        "Lab values shown are for reference. Normal ranges vary by lab and individual. " +
        "Always discuss your results with your prescribing physician."

    static let pkCurve =
        "Pharmacokinetic curves are estimates based on population averages. " +
        "Individual absorption and metabolism vary significantly. " +
        "This is not a substitute for regular bloodwork monitoring."

    static let protocolScore =
        "Protocol score reflects your self-reported wellness metrics. " +
        "It is not a clinical measurement and should not guide medical decisions."

    static let insight =
        "Insights are generated from your personal tracking data only. " +
        "They are observational patterns, not medical diagnoses or advice."

    static let weeklyReport =
        "This report summarizes your self-reported data. It is not a clinical document " +
        "and should not be used to guide medical decisions. Always consult your prescribing physician."

    static let supplementAdvice =
        "Supplement information is for personal tracking only. " +
        "Consult a qualified healthcare provider before starting any new supplement."

    static let fertility =
        "Fertility recovery estimates are based on published averages. " +
        "Individual timelines vary significantly. Always consult a reproductive endocrinologist."
}
