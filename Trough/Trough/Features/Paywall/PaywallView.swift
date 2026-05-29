import SwiftUI
import RevenueCat

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
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
            case .monthly:  return "Monthly"
            case .yearly:   return "Yearly"
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
            case .monthly:  return "/mo"
            case .yearly:   return "/yr"
            }
        }

        var hasTrial: Bool { true }

        var isBestValue: Bool { self == .monthly }

        var savingsTag: String? {
            switch self {
            case .yearly:   return "Save 58%"
            default:        return nil
            }
        }

        // Gold badge color for best value, teal for savings
        var badgeColor: Color {
            self == .monthly ? Color(hex: "#D4A017") : Color(hex: "#0AB4A6")
        }
    }

    @State private var offerings: Offerings? = nil
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

    private var ctaLabel: String {
        "Start 3-Day Free Trial"
    }

    private var ctaSubLabel: String? {
        switch selected {
        case .monthly: return "then \(price(for: .monthly))/mo · cancel anytime"
        case .yearly:  return "then \(price(for: .yearly))/yr · cancel anytime"
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#0D0D1A"), Color(hex: "#1A1A2E"), Color(hex: "#0F1A2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle radial glow top-center
            RadialGradient(
                colors: [Color(hex: "#E94560").opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Dismiss handle
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Close button top-right
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                }

                // Compact header
                compactHeader
                    .padding(.top, 4)

                // Feature bullets (compact)
                featureBullets
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                // Plan cards
                planGrid
                    .padding(.top, 14)
                    .padding(.horizontal, 16)

                // CTA
                ctaSection
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                // Footer
                footer
                    .padding(.top, 10)
                    .padding(.bottom, 16)
            }
        }
        .task {
            offerings = await RevenueCatService.shared.fetchOfferings()
        }
        .onChange(of: purchaseSuccess) { _, v in if v { dismiss() } }
        .onChange(of: restoreSuccess) { _, v in if v { dismiss() } }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#E94560"), Color(hex: "#D4A017")],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("Trough Pro")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("Track smarter. Optimize everything.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Feature Bullets

    private var featureBullets: some View {
        HStack(spacing: 0) {
            featurePill(icon: "drop.fill",   text: "Bloodwork")
            featurePill(icon: "waveform.path.ecg", text: "PK Curve")
            featurePill(icon: "pills.fill",  text: "Peptides")
            featurePill(icon: "chart.bar.fill", text: "Trends")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Plan Grid (2x2)

    private var planGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Plan.allCases, id: \.productID) { plan in
                PlanCard(
                    plan: plan,
                    price: price(for: plan),
                    isSelected: selected == plan
                ) {
                    withAnimation(.easeInOut(duration: 0.18)) { selected = plan }
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
                        VStack(spacing: 2) {
                            Text(ctaLabel)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            if let sub = ctaSubLabel {
                                Text(sub)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#C0304A")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color(hex: "#E94560").opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring || package(for: selected) == nil)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 20) {
            Button {
                Task { await doRestore() }
            } label: {
                Group {
                    if isRestoring { ProgressView().tint(.secondary) }
                    else { Text("Restore") }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if let url = URL(string: "https://gwlabs.app/privacy") {
                Link("Privacy", destination: url)
                    .font(.caption).foregroundColor(.secondary)
            }
            if let url = URL(string: "https://gwlabs.app/terms") {
                Link("Terms", destination: url)
                    .font(.caption).foregroundColor(.secondary)
            }
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

// MARK: - PlanCard

private struct PlanCard: View {
    let plan: PaywallView.Plan
    let price: String
    let isSelected: Bool
    let onTap: () -> Void

    private var borderColor: Color {
        if isSelected {
            return plan.isBestValue ? Color(hex: "#D4A017") : AppColors.accent
        }
        return Color.white.opacity(0.1)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Card background — glassmorphism
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.white.opacity(0.08), Color.white.opacity(0.04)]
                                : [Color.white.opacity(0.04), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
                    )

                // Card content
                VStack(alignment: .leading, spacing: 8) {
                    // Plan label row
                    HStack {
                        Text(plan.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(plan.isBestValue ? Color(hex: "#D4A017") : AppColors.accent)
                        }
                    }

                    // Price
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(price)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(plan.period)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    // Trial / savings tags
                    VStack(alignment: .leading, spacing: 4) {
                        if plan.hasTrial {
                            trialBadge
                        }
                        if let savings = plan.savingsTag {
                            savingsBadge(savings)
                        }
                        if !plan.hasTrial && plan.savingsTag == nil {
                            // spacer to keep card height consistent
                            Color.clear.frame(height: 16)
                        }
                    }
                }
                .padding(14)

                // BEST VALUE ribbon top-right
                if plan.isBestValue {
                    bestValueBadge
                        .offset(x: -10, y: -10)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var trialBadge: some View {
        Text("3-day free trial")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: "#0AB4A6"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(hex: "#0AB4A6").opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "#0AB4A6").opacity(0.3), lineWidth: 0.5))
    }

    private func savingsBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: "#0AB4A6"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(hex: "#0AB4A6").opacity(0.15))
            .clipShape(Capsule())
    }

    private var bestValueBadge: some View {
        Text("BEST VALUE")
            .font(.system(size: 8, weight: .black))
            .foregroundColor(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(hex: "#D4A017"))
            .clipShape(Capsule())
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
