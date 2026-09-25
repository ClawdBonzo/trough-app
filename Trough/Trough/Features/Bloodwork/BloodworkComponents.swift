import SwiftUI

// Shared building blocks for the 1.4 secondary screens (Bloodwork, Peptides, Settings,
// Export, Import). Built on the design tokens in DesignSystem/ (`TR`).

// MARK: - Icon tile

/// SF Symbol in a tinted, continuous rounded square — like iOS Settings, in Trough colours.
struct GlassIconTile: View {
    let systemImage: String
    var tint: Color = TR.Palette.coral
    var size: CGFloat = 32
    /// Filled gradient tile (white glyph) instead of a soft tinted wash.
    var filled: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        Image(systemName: systemImage)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(filled ? Color.white : tint)
            .frame(width: size, height: size)
            .background {
                if filled {
                    shape.fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.7)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(tint.opacity(0.16))
                }
            }
            .overlay(shape.strokeBorder(tint.opacity(filled ? 0.0 : 0.28), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - Empty state

/// Premium empty state: gradient icon disc, rounded title, secondary message, primary button.
struct GlassEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var tint: Color = TR.Palette.coral
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.35), .clear], center: .center,
                                         startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(LinearGradient(colors: [TR.Palette.coralLight, tint],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                    .trGlow(tint, radius: 18, opacity: 0.45)
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(TR.Font.display(.title2))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(TR.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(TRPrimaryButtonStyle(fullWidth: false))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

// MARK: - Grouped glass section

/// Kicker header + glass card holding rows. Use `GlassDivider()` between rows.
struct GlassSection<Content: View>: View {
    var title: String?
    var footer: String?
    var tint: Color?
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, footer: String? = nil, tint: Color? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.tint = tint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                TRKicker(Text(title))
                    .padding(.leading, 6)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                content()
            }
            .trCard(tint: tint, padding: 0)
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(TR.Palette.textTertiary)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Hairline between rows inside a `GlassSection`, inset past the icon tile.
struct GlassDivider: View {
    var leadingInset: CGFloat = 60
    var body: some View {
        Rectangle()
            .fill(TR.Palette.hairline)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

/// Standard settings-style row content: icon tile, title/subtitle, trailing slot.
struct GlassRowLabel<Trailing: View>: View {
    let systemImage: String
    var tint: Color = TR.Palette.coral
    let title: String
    var subtitle: String? = nil
    var titleColor: Color = TR.Palette.textPrimary
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            GlassIconTile(systemImage: systemImage, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TR.Palette.textSecondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

extension GlassRowLabel where Trailing == GlassChevron {
    init(systemImage: String, tint: Color = TR.Palette.coral, title: String, subtitle: String? = nil,
         titleColor: Color = TR.Palette.textPrimary) {
        self.init(systemImage: systemImage, tint: tint, title: title, subtitle: subtitle,
                  titleColor: titleColor) { GlassChevron() }
    }
}

struct GlassChevron: View {
    var systemImage = "chevron.right"
    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.bold))
            .foregroundStyle(TR.Palette.textTertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - Pill picker

/// Horizontal capsule picker (selected = coral gradient, others = raised surface).
struct GlassPillPicker<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var scrolls: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if scrolls {
                ScrollView(.horizontal, showsIndicators: false) { row.padding(.horizontal, TR.Metrics.gutter) }
            } else {
                row.padding(.horizontal, TR.Metrics.gutter)
            }
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isOn = item == selection
                Button {
                    withAnimation(TR.Motion.respecting(reduceMotion, TR.Motion.snappy)) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isOn ? Color.white : TR.Palette.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 38)
                        .frame(maxWidth: scrolls ? nil : .infinity)
                        .background {
                            if isOn {
                                Capsule().fill(TR.Gradients.cta)
                                    .shadow(color: TR.Palette.coral.opacity(0.4), radius: 8, y: 4)
                            } else {
                                Capsule().fill(TR.Palette.surfaceRaised)
                            }
                        }
                        .overlay(Capsule().strokeBorder(.white.opacity(isOn ? 0.18 : 0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

// MARK: - Form field card

/// Labelled input block for card-style forms: kicker label above a big rounded field.
struct GlassField<Content: View>: View {
    let label: String
    var systemImage: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.bold)).accessibilityHidden(true)
                }
                Text(label)
            }
            .font(TR.Font.kicker)
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(TR.Palette.textSecondary)

            content()
                .font(.title3.weight(.semibold))
                .foregroundStyle(TR.Palette.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(TR.Palette.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
                    .strokeBorder(TR.Palette.hairline, lineWidth: 1))
        }
    }
}

// MARK: - Marker range status

/// Neutral, non-diagnostic description of where a value sits relative to its reference range.
enum MarkerRangeStatus {
    case inRange, below, above, unknown

    init(value: Double, low: Double?, high: Double?) {
        if low == nil && high == nil { self = .unknown; return }
        if let low, value < low { self = .below; return }
        if let high, value > high { self = .above; return }
        self = .inRange
    }

    /// Calm tints only — out-of-range is informational, never alarming.
    var tint: Color {
        switch self {
        case .inRange: return TR.Palette.teal
        case .below, .above: return TR.Palette.lilac
        case .unknown: return TR.Palette.textTertiary
        }
    }

    var symbol: String {
        switch self {
        case .inRange: return "circle.fill"
        case .below: return "arrow.down"
        case .above: return "arrow.up"
        case .unknown: return "circle"
        }
    }

    var label: String {
        switch self {
        case .inRange: return NSLocalizedString("bloodwork.range.within", value: "Within ref", comment: "Marker value is within its lab reference range")
        case .below:   return NSLocalizedString("bloodwork.range.below", value: "Below ref", comment: "Marker value is below its lab reference range")
        case .above:   return NSLocalizedString("bloodwork.range.above", value: "Above ref", comment: "Marker value is above its lab reference range")
        case .unknown: return NSLocalizedString("bloodwork.range.none", value: "No ref range", comment: "Marker has no reference range")
        }
    }
}

enum MarkerFormat {
    static func value(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 && abs(v) >= 10 { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }

    static func range(_ low: Double?, _ high: Double?) -> String? {
        switch (low, high) {
        case let (l?, h?): return "\(value(l))–\(value(h))"
        case let (l?, nil): return "≥ \(value(l))"
        case let (nil, h?): return "≤ \(value(h))"
        default: return nil
        }
    }

    /// "Ref 300–1000"
    static func refLabel(_ range: String) -> String {
        String(format: NSLocalizedString("bloodwork.refShort", value: "Ref %@", comment: "Reference range, short form"), range)
    }

    /// Short display name for chips.
    static func short(_ name: String) -> String {
        switch name {
        case "Total Testosterone": return "Total T"
        case "Free Testosterone":  return "Free T"
        case "Estradiol (E2)":     return "E2"
        case "Total Cholesterol":  return "Total Chol."
        default: return name
        }
    }
}

// MARK: - Marker chip

/// Compact marker tile: name, value + unit, and a small reference-range line.
struct BloodworkMarkerChip: View {
    let name: String
    let value: Double
    let unit: String
    let low: Double?
    let high: Double?

    var body: some View {
        let status = MarkerRangeStatus(value: value, low: low, high: high)
        VStack(alignment: .leading, spacing: 4) {
            Text(MarkerFormat.short(name))
                .font(.caption.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(MarkerFormat.value(value))
                    .font(TR.Font.number(.title3, weight: .heavy))
                    .foregroundStyle(TR.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TR.Palette.textTertiary)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                Image(systemName: status.symbol)
                    .font(.system(size: status == .inRange ? 5 : 8, weight: .heavy))
                    .foregroundStyle(status.tint)
                Text(MarkerFormat.range(low, high).map { MarkerFormat.refLabel($0) } ?? status.label)
                    .font(.caption2)
                    .foregroundStyle(TR.Palette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(TR.Palette.surfaceRaised.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: TR.Metrics.controlRadius, style: .continuous)
            .strokeBorder(status.tint.opacity(status == .unknown ? 0.08 : 0.22), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(MarkerFormat.value(value)) \(unit), \(status.label)")
    }
}

// MARK: - Stat block

/// Big rounded number + caption, for header summary cards.
struct GlassStat: View {
    let value: String
    let label: String
    var tint: Color = TR.Palette.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TR.Font.number(.title, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TR.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
