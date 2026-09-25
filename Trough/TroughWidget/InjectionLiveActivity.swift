import WidgetKit
import SwiftUI
import ActivityKit

struct InjectionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InjectionActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack(spacing: 14) {
                LiveSyringeTile(size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("widget.injection", comment: "Dynamic Island expanded leading label"))
                        .font(.caption2.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundStyle(WColors.coralLight)
                    Text(context.attributes.compoundName)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(WColors.textPrimary)
                        .lineLimit(1)
                        .privacySensitive() // redact compound name on the locked Lock Screen
                    Text(context.state.statusLine)
                        .font(.caption)
                        .foregroundStyle(WColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.nextInjectionDate, style: .relative)
                        .font(.system(.title3, design: .rounded).weight(.black).monospacedDigit())
                        .foregroundStyle(LinearGradient(colors: [WColors.textPrimary, WColors.coralLight], startPoint: .top, endPoint: .bottom))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(NSLocalizedString("widget.untilNext", comment: "Caption under countdown to next injection"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WColors.textTertiary)
                }
            }
            .padding(16)
            .background {
                ZStack {
                    WColors.screen
                    RadialGradient(colors: [WColors.coral.opacity(0.28), .clear],
                                   center: .topLeading, startRadius: 0, endRadius: 220)
                }
            }
            .activityBackgroundTint(WColors.abyss)
            .activitySystemActionForegroundColor(WColors.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        LiveSyringeTile(size: 26)
                        Text(NSLocalizedString("widget.injection", comment: "Dynamic Island expanded leading label"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(WColors.coralLight)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.nextInjectionDate, style: .relative)
                        .font(.system(.callout, design: .rounded).weight(.black).monospacedDigit())
                        .foregroundStyle(WColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Text(context.attributes.compoundName)
                            .privacySensitive()
                        Text(verbatim: "·").foregroundStyle(WColors.textTertiary)
                        Text(context.state.statusLine)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WColors.textSecondary)
                    .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(LinearGradient(colors: WColors.ctaColors, startPoint: .top, endPoint: .bottom))
            } compactTrailing: {
                Text(context.state.nextInjectionDate, style: .relative)
                    .font(.system(.caption2, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(WColors.textPrimary)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(WColors.coral)
            }
            .keylineTint(WColors.coral)
            .widgetURL(URL(string: "trough://injections"))
        }
    }
}

/// Coral gradient tile with a syringe glyph (Live Activity / Dynamic Island).
private struct LiveSyringeTile: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: WColors.ctaColors, startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center))
            Image(systemName: "syringe.fill")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: WColors.coral.opacity(0.45), radius: size * 0.2)
        .accessibilityHidden(true)
    }
}
