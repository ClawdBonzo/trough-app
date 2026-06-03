import WidgetKit
import SwiftUI
import ActivityKit

struct InjectionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InjectionActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack(spacing: 14) {
                Image(systemName: "syringe.fill")
                    .font(.title2)
                    .foregroundColor(WColors.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.compoundName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(context.state.statusLine)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.nextInjectionDate, style: .relative)
                        .font(.callout.bold().monospacedDigit())
                        .foregroundColor(.white)
                    Text("until next")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding()
            .activityBackgroundTint(WColors.card)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Injection", systemImage: "syringe.fill")
                        .font(.caption)
                        .foregroundColor(WColors.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.nextInjectionDate, style: .relative)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.compoundName) · \(context.state.statusLine)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            } compactLeading: {
                Image(systemName: "syringe.fill")
                    .foregroundColor(WColors.accent)
            } compactTrailing: {
                Text(context.state.nextInjectionDate, style: .relative)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "syringe.fill")
                    .foregroundColor(WColors.accent)
            }
            .widgetURL(URL(string: "trough://injections"))
        }
    }
}
