import SwiftUI
import RevenueCat

// MARK: - Plan

extension PaywallView {
    enum Plan: CaseIterable, Hashable {
        case weekly, monthly, yearly, lifetime

        var productID: String {
            switch self {
            case .weekly:   return "com.clawdbonzo.trough.weekly"
            case .monthly:  return "com.clawdbonzo.trough.monthly"
            case .yearly:   return "com.clawdbonzo.trough.yearly"
            case .lifetime: return "com.clawdbonzo.trough.lifetime"
            }
        }

        var title: String {
            switch self {
            case .weekly:   return "Weekly"
            case .monthly:  return "Monthly"
            case .yearly:   return "Yearly"
            case .lifetime: return "Lifetime"
            }
        }

        var period: String {
            switch self {
            case .weekly:   return "/wk"
            case .monthly:  return "/mo"
            case .yearly:   return "/yr"
            case .lifetime: return ""
            }
        }

        var fallbackPrice: String {
            switch self {
            case .weekly:   return "$4.99"
            case .monthly:  return "$9.99"
            case .yearly:   return "$49.99"
            case .lifetime: return "$79.99"
            }
        }

        /// Monthly and Yearly get a 3-day free trial
        var hasTrial: Bool { self == .monthly || self == .yearly }
        var isBestValue: Bool { self == .monthly }
    }
}

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var offerings: Offerings? = nil
    @State private var selected: Plan = .monthly
    @State private var isPurchasing = false
    @State private var isRestoring  = false
    @State private var errorMessage: String? = nil
    @State private var purchaseSuccess = false
    @State private var restoreSuccess  = false
    @State private var appeared = false

    // MARK: Package helpers

    private func pkg(_ plan: Plan) -> Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == plan.productID
        }
    }

    private var activePackage: Package? { pkg(selected) }

    /// Yearly savings vs. monthly × 12, falls back to 58 %
    private var yearlySavingsPct: Int {
        guard
            let m = pkg(.monthly),
            let y = pkg(.yearly)
        else { return 58 }
        let mAnnual = (m.storeProduct.price as NSDecimalNumber).doubleValue * 12
        let yPrice  = (y.storeProduct.price as NSDecimalNumber).doubleValue
        guard mAnnual > 0 else { return 58 }
        return Int(((mAnnual - yPrice) / mAnnual) * 100)
    }

    private func priceStr(_ plan: Plan) -> String {
        pkg(plan)?.storeProduct.localizedPriceString ?? plan.fallbackPrice
    }

    private var ctaLabel: String {
        switch selected {
        case .weekly:
            return "Subscribe — \(priceStr(.weekly))/week"
        case .monthly:
            return "Start 3-Day Free Trial · then \(priceStr(.monthly))/mo"
        case .yearly:
            return "Start 3-Day Free Trial · then \(priceStr(.yearly))/yr"
        case .lifetime:
            return "Get Lifetime Access — \(priceStr(.lifetime))"
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppColors.background.ignoresSafeArea()

                // Accent glow top
                RadialGradient(
                    colors: [AppColors.accent.opacity(0.18), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0),
                    startRadius: 0,
                    endRadius: geo.size.height * 0.52
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Close ──────────────────────────────────────────────
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.09))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // ── Compact header ─────────────────────────────────────
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 42, height: 42)
                            .background(AppColors.accent.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("TROUGH PRO")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Unlock everything · 3-day free trial on select plans")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.93, anchor: .leading)

                    // ── Feature chips ──────────────────────────────────────
                    featureChipRow
                        .padding(.top, 12)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)

                    // ── Plan cards ─────────────────────────────────────────
                    VStack(spacing: 8) {
                        ForEach(Plan.allCases, id: \.self) { plan in
                            planCard(plan)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    Spacer(minLength: 0)

                    // ── CTA ────────────────────────────────────────────────
                    VStack(spacing: 8) {
                        Button {
                            guard let p = activePackage else { return }
                            Task { await doPurchase(package: p) }
                        } label: {
                            Group {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(ctaLabel)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.8)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppColors.accent)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing || isRestoring || activePackage == nil)

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)

                    // ── Footer ─────────────────────────────────────────────
                    footerLinks
                        .padding(.top, 8)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 8 : 16)
                        .opacity(appeared ? 1 : 0)
                }
            }
        }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
            AnalyticsService.paywallShown()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
        .onChange(of: purchaseSuccess) { _, v in if v { dismiss() } }
        .onChange(of: restoreSuccess)  { _, v in if v { dismiss() } }
    }

    // MARK: Feature chip row

    private var featureChipRow: some View {
        let items: [(String, String)] = [
            ("waveform.path.ecg", "PK Curves"),
            ("drop.fill", "Bloodwork"),
            ("chart.line.uptrend.xyaxis", "Trends"),
            ("chart.bar.doc.horizontal", "Reports"),
            ("pills.fill", "Peptides"),
            ("bell.badge.fill", "Alerts"),
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(items, id: \.0) { icon, label in
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.card)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Plan card

    private func planCard(_ plan: Plan) -> some View {
        let isSelected = selected == plan
        let price = priceStr(plan)

        return Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) {
                selected = plan
            }
        } label: {
            HStack(spacing: 12) {

                // Radio
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? AppColors.accent : Color.white.opacity(0.18),
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 11, height: 11)
                    }
                }

                // Title + badges
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isSelected ? .white : AppColors.textSecondary)

                        if plan.isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(Color(hex: "#1A1A2E"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#FFD700"))
                                .clipShape(Capsule())
                        }

                        if plan == .yearly {
                            Text("SAVE \(yearlySavingsPct)%")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.softCTA)
                                .clipShape(Capsule())
                        }
                    }

                    if plan.hasTrial {
                        Text("3-day free trial")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.softCTA)
                    } else if plan == .lifetime {
                        Text("One-time · never expires")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    } else {
                        // weekly — no trial, no extra label
                        Text("No free trial")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary.opacity(0.55))
                    }
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                    Text(plan.period.isEmpty ? "once" : plan.period)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.6) : AppColors.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppColors.accent.opacity(0.1) : AppColors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                            ? (plan.isBestValue
                               ? Color(hex: "#FFD700").opacity(0.65)
                               : AppColors.accent.opacity(0.55))
                            : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer

    private var footerLinks: some View {
        VStack(spacing: 5) {
            HStack(spacing: 18) {
                Button {
                    Task { await doRestore() }
                } label: {
                    Group {
                        if isRestoring {
                            ProgressView().tint(.secondary).scaleEffect(0.75)
                        } else {
                            Text("Restore")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if let url = URL(string: "https://gettrough.app/privacy") {
                    Link("Privacy", destination: url)
                        .font(.caption).foregroundColor(.secondary)
                }
                if let url = URL(string: "https://gettrough.app/terms") {
                    Link("Terms", destination: url)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Text(selected.hasTrial
                 ? "3-day free trial, then auto-renews. Cancel anytime."
                 : "No trial period. Cancel anytime in Settings → Subscriptions.")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: Actions

    @MainActor
    private func doPurchase(package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            _ = try await RevenueCatService.shared.purchase(package: package)
            await subscriptionManager.refresh()
            if subscriptionManager.isSubscribed {
                AnalyticsService.paywallConverted(productID: package.storeProduct.productIdentifier)
                purchaseSuccess = true
                return
            }
        } catch {
            if (error as NSError).code == 1 {
                isPurchasing = false
                return
            }
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
            if subscriptionManager.isSubscribed {
                restoreSuccess = true
                return
            }
        } catch {
            if (error as NSError).code == 1 {
                isRestoring = false
                return
            }
            errorMessage = error.localizedDescription
        }
        isRestoring = false
    }
}

// MARK: - LockedCard

struct LockedCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var onInfo: (() -> Void)? = nil
    var action: (() -> Void)? = nil

    init(icon: String, title: String, subtitle: String, onInfo: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.onInfo = onInfo
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
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

// MARK: - FeatureRow

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
