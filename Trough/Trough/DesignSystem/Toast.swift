import SwiftUI
import UIKit

// 1.4 toast look for the existing `ToastManager` (Services/ToastManager.swift), whose API is
// unchanged: keep calling `ToastManager.shared.show(_:type:actionLabel:action:)`.
// Adopt the new look by swapping `.toastOverlay()` for `.trToastOverlay()` at the root.

// MARK: - Tints

extension ToastManager.ToastType {
    /// 1.4 palette tint for this toast type.
    var trTint: Color {
        switch self {
        case .error:   return TR.Palette.coral
        case .info:    return TR.Palette.sky
        case .success: return TR.Palette.mint
        }
    }
}

// MARK: - Capsule

/// The toast itself: ultra-thin material capsule, tinted icon, message, optional action.
/// Usable standalone (e.g. in previews or custom banners).
struct TRToastCapsule: View {
    let message: Text
    var systemImage: String?
    var tint: Color = TR.Palette.coral
    var actionTitle: Text?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.6), radius: 6)
                    .accessibilityHidden(true)
            }
            message
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TR.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(action: action) {
                    actionTitle
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(tint)
                        .frame(minWidth: TR.Metrics.minTap, minHeight: TR.Metrics.minTap)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, actionTitle == nil ? 18 : 10)
        .padding(.vertical, 6)
        .frame(minHeight: 52)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(TR.Palette.surface.opacity(0.55))
                Capsule().fill(
                    RadialGradient(colors: [tint.opacity(0.22), .clear], center: .leading, startRadius: 0, endRadius: 160)
                )
            }
        }
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: 560) // iPad: a toast, not a banner.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ToastManager adapter

/// `ToastManager.Toast` rendered in the 1.4 style. Tapping the action runs it and dismisses.
struct TRToastView: View {
    let toast: ToastManager.Toast
    var onDismiss: () -> Void = {}

    var body: some View {
        TRToastCapsule(
            message: Text(toast.message),
            systemImage: toast.type.icon,
            tint: toast.type.trTint,
            actionTitle: toast.actionLabel.map { Text($0) },
            action: toast.action.map { action in
                {
                    action()
                    onDismiss()
                }
            }
        )
        .accessibilityIdentifier("toast")
    }
}

// MARK: - Overlay

private struct TRToastOverlayModifier: ViewModifier {
    var edge: VerticalEdge
    @ObservedObject private var manager = ToastManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(edge: VerticalEdge) { self.edge = edge }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: edge == .top ? .top : .bottom) {
                if let toast = manager.current {
                    TRToastView(toast: toast, onDismiss: { manager.dismiss() })
                        .padding(.horizontal, TR.Metrics.gutter)
                        .padding(edge == .top ? .top : .bottom, edge == .top ? 8 : 90) // bottom: clear the tab bar
                        .transition(reduceMotion ? .opacity : .move(edge: edge == .top ? .top : .bottom).combined(with: .opacity))
                        .id(toast.id)
                        .zIndex(999)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : TR.Motion.snappy, value: manager.current?.id)
            .onChange(of: manager.current?.id) { _, newID in
                guard newID != nil, let message = manager.current?.message else { return }
                UIAccessibility.post(notification: .announcement, argument: message)
            }
    }
}

extension View {
    /// 1.4 toast overlay driven by `ToastManager.shared` (drop-in replacement for
    /// `.toastOverlay()`; does not need the environment object). Default: top of the screen.
    func trToastOverlay(edge: VerticalEdge = .top) -> some View {
        modifier(TRToastOverlayModifier(edge: edge))
    }
}

#if DEBUG
#Preview("Toast") {
    VStack(spacing: 16) {
        TRToastCapsule(message: Text(verbatim: "Injection logged · +25 XP"), systemImage: "checkmark.circle.fill", tint: TR.Palette.mint)
        TRToastCapsule(message: Text(verbatim: "Check-in deleted"), systemImage: "trash.fill", tint: TR.Palette.coral, actionTitle: Text(verbatim: "Undo"), action: {})
        TRToastCapsule(message: Text(verbatim: "Badge unlocked: Night Owl"), systemImage: "rosette", tint: TR.Palette.gold)
    }
    .padding(TR.Metrics.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TRBackground())
}
#endif
