import SwiftUI
import RevenueCat

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    enum BillingCycle { case monthly, annual }

    @State private var offerings: Offerings? = nil
    @State private var selected: BillingCycle = .annual
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String? = nil

    // BULLETPROOF SUCCESS FLAG (eliminates race condition with RevenueCat + dismiss)
    @State private var purchaseSuccess = false
    @State private var restoreSuccess = false

    private var monthlyPackage: Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == "trough_pro_monthly"
        }
    }

    private var annualPackage: Package? {
        offerings?.current?.availablePackages.first {
            $0.storeProduct.productIdentifier == "trough_pro_annual"
        }
    }

    private var activePackage: Package? {
        selected == .monthly ? monthlyPackage : annualPackage
    }

    private var ctaLabel: String {
        let priceString: String
        if let pkg = activePackage {
            priceString = selected == .monthly
                ? "then \(pkg.storeProduct.localizedPriceString)/mo"
                : "then \(pkg.storeProduct.localizedPriceString)/yr"
        } else {
            priceString = selected == .monthly ? "then $6.99/mo" : "then $49.99/yr"
        }
        return "Start Free Trial — 14 days free, \(priceString)"
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    featureList
                    billingToggle
                    ctaButton
                    footerLinks
                    disclaimerText
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
            AnalyticsService.paywallShown()
        }
        // BULLETPROOF: dismiss only after the view is fully settled
        .onChange(of: purchaseSuccess) { _, newValue in
            if newValue { dismiss() }
        }
        .onChange(of: restoreSuccess) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColors.accent)

            Text("TROUGH PRO")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("Go from 42 → 85 Protocol Score.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Everything. Free for 14 days.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    // MARK: Feature list

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Unlimited history & Protocol Score trends")
            FeatureRow(icon: "waveform.path.ecg",         text: "PK curves with confidence bands")
            FeatureRow(icon: "drop.fill",                 text: "Bloodwork tracking & trend charts")
            FeatureRow(icon: "chart.bar.doc.horizontal",  text: "Weekly reports & CSV/PDF export")
            FeatureRow(icon: "pills.fill",                text: "Peptide & GLP-1 tracking")
            FeatureRow(icon: "figure.walk.circle",        text: "Injection site rotation map")
            FeatureRow(icon: "bell.badge.fill",           text: "Injection reminders & calendar")
            FeatureRow(icon: "heart.text.square.fill",    text: "HealthKit auto-sync (always free)")
                .opacity(0.6)
        }
        .padding(18)
        .background(AppColors.card)
        .cornerRadius(16)
    }

    // MARK: Billing toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            billingOption(
                cycle: .monthly,
                title: "Monthly",
                price: monthlyPackage.map { $0.storeProduct.localizedPriceString + "/mo" } ?? "$6.99/mo",
                badge: nil
            )
            billingOption(
                cycle: .annual,
                title: "Annual",
                price: annualPackage.map { $0.storeProduct.localizedPriceString + "/yr" } ?? "$49.99/yr",
                badge: "Save 40%"
            )
        }
        .background(AppColors.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func billingOption(
        cycle: BillingCycle,
        title: String,
        price: String,
        badge: String?
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selected = cycle }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(selected == cycle ? .white : .secondary)
                    if let badge {
                        Text(badge)
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                }
                Text(price)
                    .font(.caption)
                    .foregroundColor(selected == cycle ? AppColors.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selected == cycle
                    ? AppColors.accent.opacity(0.12)
                    : Color.clear
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: CTA

    private var ctaButton: some View {
        VStack(spacing: 10) {
            Button {
                guard let pkg = activePackage else { return }
                Task { await doPurchase(package: pkg) }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaLabel)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppColors.accent)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring || activePackage == nil)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Footer

    private var footerLinks: some View {
        HStack(spacing: 24) {
            Button {
                Task { await doRestore() }
            } label: {
                Group {
                    if isRestoring {
                        ProgressView().tint(.secondary)
                    } else {
                        Text("Restore Purchases")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if let privacyURL = URL(string: "https://gettrough.app/privacy") {
                Link("Privacy Policy", destination: privacyURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let termsURL = URL(string: "https://gettrough.app/terms") {
                Link("Terms of Use", destination: termsURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var disclaimerText: some View {
        VStack(spacing: 6) {
            Text("Cancel anytime in Settings → Subscriptions.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("No charge during your 14-day free trial. Subscription auto-renews after trial unless cancelled at least 24 hours before the end of the trial period.")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Actions — BULLETPROOF VERSION

    @MainActor
    private func doPurchase(package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            _ = try await RevenueCatService.shared.purchase(package: package)
            await subscriptionManager.refresh()

            if subscriptionManager.isSubscribed {
                AnalyticsService.paywallConverted(productID: package.storeProduct.productIdentifier)
                purchaseSuccess = true   // triggers .onChange dismiss
                return
            }
        } catch {
            if (error as NSError).code == 1 /* RevenueCat userCancelled */ {
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
                restoreSuccess = true   // triggers .onChange dismiss
                return
            }
        } catch {
            if (error as NSError).code == 1 /* RevenueCat userCancelled */ {
                isRestoring = false
                return
            }
            errorMessage = error.localizedDescription
        }
        isRestoring = false
    }
}

// MARK: - FeatureRow

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
