import SwiftUI

// MARK: - SkeletonView

/// A shimmering rectangle used as a placeholder while content loads.
struct SkeletonView: View {
    var cornerRadius: CGFloat = 8
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppColors.card)
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear,                        location: 0),
                            .init(color: Color.white.opacity(0.07),     location: 0.4),
                            .init(color: Color.white.opacity(0.10),     location: 0.5),
                            .init(color: Color.white.opacity(0.07),     location: 0.6),
                            .init(color: .clear,                        location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                    .clipped()
                )
                .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityLabel("Loading")
        .accessibilityHidden(true)
    }
}

// MARK: - Dashboard skeleton

struct DashboardSkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonView(cornerRadius: 20).frame(height: 200)  // score hero
            SkeletonView(cornerRadius: 16).frame(height: 72)   // checkin CTA
            SkeletonView(cornerRadius: 16).frame(height: 90)   // streak
            SkeletonView(cornerRadius: 16).frame(height: 220)  // chart/PK
            SkeletonView(cornerRadius: 16).frame(height: 180)  // trend chart
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Chart skeleton

struct ChartSkeletonView: View {
    var height: CGFloat = 140

    var body: some View {
        VStack(spacing: 8) {
            SkeletonView(cornerRadius: 4).frame(height: height)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonView(cornerRadius: 4).frame(height: 10)
                }
            }
        }
    }
}

// MARK: - Inline loading button state

/// Replaces button label with a spinner while `isLoading` is true.
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    var style: Color = AppColors.accent

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(style)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Loading" : title)
    }
}
