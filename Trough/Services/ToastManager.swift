import SwiftUI

// MARK: - ToastManager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    private init() {}

    @Published var current: Toast? = nil

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let type: ToastType
        let actionLabel: String?
        let action: (() -> Void)?
    }

    enum ToastType {
        case error, info, success
        var color: Color {
            switch self {
            case .error:   return AppColors.accent
            case .info:    return Color(hex: "#4A90D9")
            case .success: return Color(hex: "#27AE60")
            }
        }
        var icon: String {
            switch self {
            case .error:   return "exclamationmark.circle.fill"
            case .info:    return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }

    func show(
        _ message: String,
        type: ToastType = .error,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil,
        autoDismiss: TimeInterval = 4
    ) {
        current = Toast(message: message, type: type, actionLabel: actionLabel, action: action)
        guard autoDismiss > 0 else { return }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(autoDismiss * 1_000_000_000))
            if current?.message == message { current = nil }
        }
    }

    func showNetworkError(_ error: Error, retry: (() -> Void)? = nil) {
        show(
            "Offline — changes saved locally",
            type: .info,
            actionLabel: retry != nil ? "Retry" : nil,
            action: retry
        )
    }

    func dismiss() { current = nil }
}

// MARK: - ToastView

struct ToastView: View {
    let toast: ToastManager.Toast
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let label = toast.actionLabel, let action = toast.action {
                Button(label) {
                    action()
                    toastManager.dismiss()
                }
                .font(.subheadline.bold())
                .foregroundColor(toast.type.color)
                .accessibilityLabel("\(label) — \(toast.message)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.card)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 90)  // above tab bar
        .accessibilityElement(children: .combine)
    }
}

// MARK: - View modifier

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}

private struct ToastOverlayModifier: ViewModifier {
    @EnvironmentObject private var toastManager: ToastManager

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let toast = toastManager.current {
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastManager.current?.id)
    }
}
