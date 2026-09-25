import SwiftUI
import RevenueCat

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    enum Plan: CaseIterable {
        case monthly, yearly

        var productID: String {
            switch self {
            case .monthly:  return "trough_pro_monthly"
            case .yearly:   return "trough_pro_annual"
            }
        }

        var label: String {
            switch self {
            case .monthly:  return NSLocalizedString("paywall.monthly", comment: "")
            case .yearly:   return NSLocalizedString("paywall.annual", comment: "")
            }
        }

        var fallbackPrice: String {
            switch self {
            case .monthly:  return "$9.99"
            case .yearly:   return "$49.99"
            }
        }

        var period: String {
            switch self {
            case .monthly:  return NSLocalizedString("paywall.perMo", comment: "")
            case .yearly:   return NSLocalizedString("paywall.perYr", comment: "")
            }
        }

        var isBestValue: Bool { self == .monthly }
    }

    @State private var offerings: Offerings? = nil
    @State private var trialEligible: [String: Bool] = [:]
    @State private var selected: Plan = .monthly
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String? = nil
    @State private var purchaseSuccess = false
    @State private var restoreSuccess = false

    private func package(for plan: Plan) -> Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == plan.productID
        }
    }

    private func price(for plan: Plan) -> String {
        package(for: plan).map { $0.storeProduct.localizedPriceString } ?? plan.fallbackPrice
    }

    /// True only when the App Store confirmed intro eligibility for this plan's product.
    private func hasTrial(for plan: Plan) -> Bool {
        trialEligible[plan.productID] ?? false
    }

    /// "Save N%" computed from the fetched monthly vs annual store prices.
    /// Hidden when either product is missing or there is no actual saving.
    private var yearlySavingsTag: String? {
        guard let monthly = package(for: .monthly)?.storeProduct.price,
              let yearly = package(for: .yearly)?.storeProduct.price,
              monthly > 0 else { return nil }
        let fullYear = monthly * 12
        guard fullYear > yearly else { return nil }
        let pct = Int((NSDecimalNumber(decimal: (fullYear - yearly) / fullYear).doubleValue * 100).rounded())
        guard pct > 0 else { return nil }
        return String(format: NSLocalizedString("paywall.savePct", comment: ""), pct)
    }

    private var ctaLabel: String {
        hasTrial(for: selected)
            ? NSLocalizedString("onboarding.startTrial", comment: "")
            : NSLocalizedString("dashboard.trial.subscribeButton", comment: "")
    }

    private var ctaSubLabel: String? {
        let key = hasTrial(for: selected) ? "paywall.ctaSub.trial" : "paywall.ctaSub.noTrial"
        let pricePeriod: String
        switch selected {
        case .monthly: pricePeriod = price(for: .monthly) + Plan.monthly.period
        case .yearly:  pricePeriod = price(for: .yearly) + Plan.yearly.period
        }
        return String(format: NSLocalizedString(key, comment: ""), pricePeriod)
    }

    var body: some View {
        ZStack {
            TRBackground(glow: TR.Palette.coral, glowOpacity: 0.2)
            ProSunsetGlow()

            VStack(spacing: 0) {
                // Close button top-right
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TR.Palette.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(TR.Palette.surfaceRaised.opacity(0.8), in: Circle())
                            .overlay(Circle().strokeBorder(TR.Palette.hairline))
                            .frame(width: TR.Metrics.minTap, height: TR.Metrics.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(onbLoc("onb14.close", "Close")))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        header
                            .trRevealOnAppear()

                        featureList
                            .trRevealOnAppear(delay: 0.1)

                        planGrid
                            .padding(.top, 4)
                            .trRevealOnAppear(delay: 0.18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                ctaSection
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                footer
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { ReviewPromptService.paywallShownThisSession = true }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
            let products = offerings?.current?.availablePackages.map(\.storeProduct) ?? []
            trialEligible = await RevenueCatService.shared.trialEligibility(for: products)
        }
        .onChange(of: purchaseSuccess) { _, v in if v { dismiss() } }
        .onChange(of: restoreSuccess) { _, v in if v { dismiss() } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            OnboardingIconTile(systemImage: "waveform.path.ecg",
                               colors: [TR.Palette.coralLight, TR.Palette.coral, Color(trHex: 0x5B2A6E)],
                               size: 64)
                .trPopOnAppear()
            TRKicker(Text(verbatim: "Trough Pro"), color: TR.Palette.gold)
            Text(NSLocalizedString("paywall.tagline", comment: ""))
                .font(TR.Font.display(.title2, weight: .black))
                .foregroundStyle(TR.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 14) {
            OnboardingFeatureRow(icon: "waveform.path.ecg",
                                 title: NSLocalizedString("pro.pkCurves", comment: ""),
                                 detail: NSLocalizedString("pro.pkCurvesDesc", comment: ""),
                                 tint: OnboardingTint.coral)
            OnboardingFeatureRow(icon: "drop.fill",
                                 title: NSLocalizedString("pro.bloodwork", comment: ""),
                                 detail: NSLocalizedString("pro.bloodworkDesc", comment: ""),
                                 tint: OnboardingTint.sky)
            OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis",
                                 title: NSLocalizedString("pro.trendHistory", comment: ""),
                                 detail: NSLocalizedString("pro.trendHistoryDesc", comment: ""),
                                 tint: OnboardingTint.gold)
            OnboardingFeatureRow(icon: "pills.fill",
                                 title: NSLocalizedString("pro.peptides", comment: ""),
                                 detail: NSLocalizedString("pro.peptidesDesc", comment: ""),
                                 tint: OnboardingTint.mint)
            OnboardingFeatureRow(icon: "chart.bar.doc.horizontal",
                                 title: NSLocalizedString("pro.reports", comment: ""),
                                 detail: NSLocalizedString("pro.reportsDesc", comment: ""),
                                 tint: OnboardingTint.lilac)
        }
        .trCard(tint: TR.Palette.coral, padding: 16)
    }

    // MARK: - Plans

    private var planGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Plan.allCases, id: \.productID) { plan in
                ProPlanCard(
                    title: plan.label,
                    price: price(for: plan),
                    period: plan.period,
                    ribbon: plan.isBestValue ? NSLocalizedString("paywall.bestValue", comment: "") : nil,
                    trialText: hasTrial(for: plan) ? ProTrialCopy.badge(for: package(for: plan)?.storeProduct) : nil,
                    savingsText: plan == .yearly ? yearlySavingsTag : nil,
                    isSelected: selected == plan
                ) {
                    withAnimation(TR.Motion.respecting(reduceMotion, TR.Motion.snappy)) { selected = plan }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 6) {
            Button {
                guard let pkg = package(for: selected) else { return }
                Task { await doPurchase(package: pkg) }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaLabel)
                    }
                }
            }
            .buttonStyle(.trPrimary)
            .disabled(isPurchasing || isRestoring || package(for: selected) == nil)

            if let sub = ctaSubLabel {
                Text(sub)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TR.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.coralLight)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text(onbLoc("onb14.paywall.autoRenew", "Payment is charged to your Apple ID at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings."))
                .font(.caption2)
                .foregroundStyle(TR.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                Button {
                    Task { await doRestore() }
                } label: {
                    Group {
                        if isRestoring { ProgressView().tint(TR.Palette.textSecondary) }
                        else { Text(NSLocalizedString("paywall.restore", comment: "")) }
                    }
                    .frame(minHeight: 32)
                }
                .buttonStyle(.plain)

                if let url = URL(string: "https://gwlabs.app/privacy") {
                    Link(NSLocalizedString("paywall.privacy", comment: ""), destination: url)
                }
                if let url = URL(string: "https://gwlabs.app/terms") {
                    Link(NSLocalizedString("paywall.terms", comment: ""), destination: url)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(TR.Palette.textSecondary)
            .tint(TR.Palette.textSecondary)
        }
    }

    // MARK: - Purchase / Restore

    @MainActor
    private func doPurchase(package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            _ = try await RevenueCatService.shared.purchase(package: package)
            await subscriptionManager.refresh()
            if subscriptionManager.isSubscribed {
                purchaseSuccess = true
                return
            }
        } catch {
            if (error as NSError).code == 1 { isPurchasing = false; return }
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    @MainActor
    private func doRestore() async {
        isRestoring = true
        errorMessage = nil
        do {
            _ = try await RevenueCatService.shared.restorePurchases()
            await subscriptionManager.refresh()
            if subscriptionManager.isSubscribed { restoreSuccess = true; return }
        } catch {
            if (error as NSError).code == 1 { isRestoring = false; return }
            errorMessage = error.localizedDescription
        }
        isRestoring = false
    }
}

// MARK: - Trial copy

/// Trial wording derived from the StoreKit intro offer (never hardcoded), with a 7-day
/// fallback matching the live offer when the product hasn't loaded. Only shown when the App
/// Store confirmed eligibility (callers gate on `trialEligibility`).
enum ProTrialCopy {
    static let fallbackDays = 7

    /// Free-trial length in days from the product's introductory offer.
    static func trialDays(for product: StoreProduct?) -> Int {
        guard let discount = product?.introductoryDiscount, discount.paymentMode == .freeTrial else {
            return fallbackDays
        }
        let period = discount.subscriptionPeriod
        switch period.unit {
        case .day:  return period.value
        case .week: return period.value * 7
        default:    return fallbackDays
        }
    }

    /// "7-day free trial"
    static func badge(for product: StoreProduct?) -> String {
        String(format: onbLoc("onb14.trialBadge", "%d-day free trial"), trialDays(for: product))
    }

    /// "7-day free trial, then auto-renews. Cancel anytime."
    static func legal(for product: StoreProduct?) -> String {
        String(format: onbLoc("onb14.trialLegal", "%d-day free trial, then auto-renews. Cancel anytime."), trialDays(for: product))
    }
}

// MARK: - Sunset glow

/// Hero backdrop light for Pro surfaces: plum, coral and tangerine pools at the top.
struct ProSunsetGlow: View {
    var body: some View {
        GeometryReader { proxy in
            let w = max(proxy.size.width, 1)
            ZStack {
                RadialGradient(colors: [Color(trHex: 0x5B2A6E).opacity(0.55), .clear],
                               center: UnitPoint(x: 0.5, y: -0.02), startRadius: 0, endRadius: w * 0.95)
                RadialGradient(colors: [TR.Palette.coral.opacity(0.32), .clear],
                               center: UnitPoint(x: 0.18, y: 0.04), startRadius: 0, endRadius: w * 0.7)
                RadialGradient(colors: [TR.Palette.tangerine.opacity(0.2), .clear],
                               center: UnitPoint(x: 0.88, y: 0.12), startRadius: 0, endRadius: w * 0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Plan card

/// Subscription plan card: price/period from StoreKit, optional ribbon (best value / save %),
/// trial and savings pills, and a coral → gold gradient ring when selected.
struct ProPlanCard: View {
    let title: String
    let price: String
    let period: String
    var ribbon: String? = nil
    var trialText: String? = nil
    var savingsText: String? = nil
    let isSelected: Bool
    let onTap: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    TRKicker(Text(verbatim: title), color: isSelected ? TR.Palette.textPrimary : TR.Palette.textSecondary)
                    Spacer(minLength: 4)
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color.clear : TR.Palette.textTertiary, lineWidth: 1.5)
                        if isSelected {
                            Circle().fill(TR.Gradients.cta)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                }

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(TR.Font.number(22))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(period)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TR.Palette.textSecondary)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let trialText {
                        tag(trialText, systemImage: "gift.fill", color: TR.Palette.teal)
                    }
                    if let savingsText {
                        tag(savingsText, systemImage: "arrow.down.circle.fill", color: TR.Palette.gold)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .padding(.top, ribbon == nil ? 0 : 4)
            .frame(maxWidth: .infinity, minHeight: (trialText == nil && savingsText == nil) ? 96 : 124, alignment: .topLeading)
            .background {
                ZStack {
                    shape.fill(TR.Palette.surface)
                    if isSelected {
                        shape.fill(RadialGradient(colors: [TR.Palette.coral.opacity(0.24), .clear],
                                                  center: .topLeading, startRadius: 0, endRadius: 200))
                    }
                    shape.fill(LinearGradient(colors: [.white.opacity(0.05), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .overlay {
                if isSelected {
                    shape.strokeBorder(
                        AngularGradient(colors: [TR.Palette.coralLight, TR.Palette.coral, TR.Palette.tangerine, TR.Palette.gold, TR.Palette.coralLight],
                                        center: .center),
                        lineWidth: 2
                    )
                } else {
                    shape.strokeBorder(TR.Palette.hairline, lineWidth: 1)
                }
            }
            .shadow(color: isSelected ? TR.Palette.coral.opacity(0.35) : .black.opacity(0.25), radius: isSelected ? 16 : 10, y: 6)
            .overlay(alignment: .top) {
                if let ribbon {
                    Text(ribbon)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(trHex: 0x3A2600))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TR.Gradients.xp, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                        .shadow(color: TR.Palette.gold.opacity(0.45), radius: 6, y: 2)
                        .offset(y: -10)
                }
            }
            .scaleEffect(isSelected ? 1.0 : 0.98)
        }
        .buttonStyle(.trPressable)
        .padding(.top, ribbon == nil ? 0 : 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tag(_ text: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Supporting Views (kept for external use)

struct LockedCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil

    init(icon: String, title: String, subtitle: String, onInfo: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.accent.opacity(0.6))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(AppColors.card)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
