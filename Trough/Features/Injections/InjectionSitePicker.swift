import SwiftUI

// MARK: - InjectionSitePicker

/// List-based picker with intelligent rotation. Shows recommended site first.
struct InjectionSitePicker: View {
    @Binding var selectedSite: String
    let recentInjections: [SDInjection]

    private var recommended: InjectionSite {
        InjectionCycleService.siteRotationSuggestion(recentInjections: recentInjections)
    }

    private var sortedSites: [InjectionSite] {
        let rec = recommended
        return InjectionSite.all.sorted { a, b in
            if a == rec { return true }
            if b == rec { return false }
            let da = InjectionCycleService.daysSinceLastUse(site: a, recentInjections: recentInjections)
            let db = InjectionCycleService.daysSinceLastUse(site: b, recentInjections: recentInjections)
            switch (da, db) {
            case (nil, nil): return a.displayName < b.displayName
            case (nil, _):   return true
            case (_, nil):   return false
            case let (da?, db?): return da > db
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sortedSites) { site in
                SiteRow(
                    site: site,
                    isSelected: selectedSite == site.displayName,
                    isRecommended: site == recommended,
                    daysSince: InjectionCycleService.daysSinceLastUse(
                        site: site,
                        recentInjections: recentInjections
                    )
                ) {
                    selectedSite = site.displayName
                }
                if site != sortedSites.last {
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
        .background(AppColors.card)
        .cornerRadius(12)
    }
}

// MARK: - SiteRow

private struct SiteRow: View {
    let site: InjectionSite
    let isSelected: Bool
    let isRecommended: Bool
    let daysSince: Int?
    let onTap: () -> Void

    private var restColor: Color {
        guard let d = daysSince else { return .green }
        if d >= 7 { return .green }
        if d >= 3 { return Color(hex: "#F39C12") }
        return AppColors.accent
    }

    private var restLabel: String {
        guard let d = daysSince else { return "Never used" }
        return d == 0 ? "Used today" : "Last used \(d)d ago"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(restColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(site.displayName)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        if isRecommended {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#F39C12"))
                        }
                    }
                    Text(restLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? AppColors.accent.opacity(0.08) : Color.clear)
    }
}
