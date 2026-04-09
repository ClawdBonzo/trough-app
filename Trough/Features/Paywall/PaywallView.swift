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

    @State private var purchaseSuccess = false
    @State private var restoreSuccess = false

    // Entrance animation
    @State private var appeared = false

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
        GeometryReader { geo in
            ZStack {
                AppColors.background.ignoresSafeArea()

                // Subtle radial glow behind content
                RadialGradient(
                    colors: [AppColors.accent.opacity(0.18), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: geo.size.height * 0.55
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Close button
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer(minLength: 0)

                    // MARK: Header
                    VStack(spacing: 6) {
                        Text("TROUGH PRO")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(appeared ? 1 : 0.85)
                            .opacity(appeared ? 1 : 0)

                        Text("Everything you need. Free for 14 days.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .opacity(appeared ? 1 : 0)
                    }
                    .padding(.bottom, 16)

                    // MARK: Feature grid — 2 columns, compact
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        CompactFeatureCell(icon: "waveform.path.ecg",        text: "PK Curves")
                        CompactFeatureCell(icon: "drop.fill",                text: "Bloodwork")
                        CompactFeatureCell(icon: "chart.line.uptrend.xyaxis",text: "Full History")
                        CompactFeatureCell(icon: "chart.bar.doc.horizontal", text: "Weekly Reports")
                        CompactFeatureCell(icon: "pills.fill",               text: "Peptides & GLP-1")
                        CompactFeatureCell(icon: "bell.badge.fill",          text: "Reminders")
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                    Spacer(minLength: 0)

                    // MARK: Billing toggle
                    HStack(spacing: 10) {
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
                            badge: "SAVE 40%"
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)

                    Spacer(minLength: 0)

                    // MARK: CTA
                    VStack(spacing: 8) {
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
                            .padding(.vertical, 16)
                            .background(AppColors.accent)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing || isRestoring || activePackage == nil)
                        .scaleEffect(appeared ? 1 : 0.96)
                        .opacity(appeared ? 1 : 0)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: Footer
                    VStack(spacing: 6) {
                        HStack(spacing: 20) {
                            Button {
                                Task { await doRestore() }
                            } label: {
                                Group {
                                    if isRestoring {
                                        ProgressView().tint(.secondary)
                                    } else {
                                        Text("Restore")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)

                            if let privacyURL = URL(string: "https://gettrough.app/privacy") {
                                Link("Privacy", destination: privacyURL)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let termsURL = URL(string: "https://gettrough.app/terms") {
                                Link("Terms", destination: termsURL)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("Cancel anytime. No charge during 14-day trial.")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
            AnalyticsService.paywallShown()
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
        .onChange(of: purchaseSuccess) { _, newValue in
            if newValue { dismiss() }
        }
        .onChange(of: restoreSuccess) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: Billing option

    private func billingOption(
        cycle: BillingCycle,
        title: String,
        price: String,
        badge: String?
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = cycle }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(selected == cycle ? .white : .secondary)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
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
                    ? AppColors.accent.opacity(0.14)
                    : AppColors.card
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected == cycle ? AppColors.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - CompactFeatureCell

private struct CompactFeatureCell: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.card)
        .cornerRadius(12)
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
