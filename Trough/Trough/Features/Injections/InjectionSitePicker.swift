import SwiftUI

// MARK: - InjectionSitePicker

/// Chip-grid site picker with rotation: the most-rested site is suggested (glowing gold, first).
/// Each chip shows a rest dot (green = rested ≥7d, amber 3–6d, coral <3d).
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
        let rec = recommended
        VStack(alignment: .leading, spacing: 10) {
            SiteChip(
                site: rec,
                isSelected: selectedSite == rec.displayName,
                isRecommended: true,
                daysSince: InjectionCycleService.daysSinceLastUse(site: rec, recentInjections: recentInjections)
            ) { selectedSite = rec.displayName }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(sortedSites.filter { $0 != rec }) { site in
                    SiteChip(
                        site: site,
                        isSelected: selectedSite == site.displayName,
                        isRecommended: false,
                        daysSince: InjectionCycleService.daysSinceLastUse(site: site, recentInjections: recentInjections)
                    ) { selectedSite = site.displayName }
                }
            }
        }
    }
}

// MARK: - SiteChip

private struct SiteChip: View {
    let site: InjectionSite
    let isSelected: Bool
    let isRecommended: Bool
    let daysSince: Int?
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var restColor: Color {
        guard let d = daysSince else { return TR.Palette.mint }
        if d >= 7 { return TR.Palette.mint }
        if d >= 3 { return TR.Palette.gold }
        return TR.Palette.coral
    }

    private var restLabel: String {
        guard let d = daysSince else { return NSLocalizedString("inj14.site.never", value: "Never used", comment: "Injection site rest label") }
        if d == 0 { return NSLocalizedString("inj14.site.today", value: "Used today", comment: "Injection site rest label") }
        return String(format: NSLocalizedString("inj14.site.daysAgo", value: "%dd ago", comment: "Injection site rest label, days since last use"), d)
    }

    var body: some View {
        Button {
            HapticManager.shared.toggle()
            onTap()
        } label: {
            HStack(spacing: 10) {
                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(trHex: 0x3A2600))
                        .frame(width: 30, height: 30)
                        .background(TR.Gradients.xp, in: Circle())
                        .shadow(color: TR.Palette.gold.opacity(0.7), radius: 8)
                } else {
                    Circle()
                        .fill(restColor)
                        .frame(width: 9, height: 9)
                        .shadow(color: restColor.opacity(0.8), radius: 4)
                }
                VStack(alignment: .leading, spacing: 1) {
                    if isRecommended {
                        TRKicker(Text(NSLocalizedString("inj14.site.suggested", value: "Suggested next", comment: "Recommended rotation site")), color: TR.Palette.gold)
                    }
                    Text(site.localizedName)
                        .font(isRecommended ? TR.Font.display(.headline, weight: .heavy) : .subheadline.weight(.bold))
                        .foregroundStyle(TR.Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(restLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TR.Palette.textSecondary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white, TR.Palette.coral)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, isRecommended ? 12 : 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(minHeight: 50)
            .background {
                let shape = RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                ZStack {
                    shape.fill(TR.Palette.surfaceRaised)
                    if isRecommended { shape.fill(TR.Palette.gold.opacity(0.12)) }
                    if isSelected { shape.fill(TR.Palette.coral.opacity(0.22)) }
                }
                .shadow(color: isRecommended ? TR.Palette.gold.opacity(0.35) : .clear, radius: 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                    .strokeBorder(
                        isRecommended ? TR.Palette.gold.opacity(isSelected ? 1 : 0.7) : (isSelected ? TR.Palette.coral : TR.Palette.hairline),
                        lineWidth: isSelected || isRecommended ? 1.5 : 1
                    )
            }
            .animation(reduceMotion ? nil : TR.Motion.snappy, value: isSelected)
        }
        .buttonStyle(.trPressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
