import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - Links

/// Public links printed on share cards. Plain App Store URL — no campaign or tracking token
/// (Trough is strictly on-device; nothing about the sharer is encoded in the link).
enum TroughLinks {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6760955550")!
}

// MARK: - QR code

/// A crisp QR code generated on-device with CoreImage (`CIQRCodeGenerator`), scaled with
/// nearest-neighbour so the modules stay sharp in exported PNGs. The link survives apps that
/// strip URLs from shared images.
enum TRQRCode {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// - Parameters:
    ///   - size: target size in points; rendered at 3× pixels.
    static func image(for url: URL, size: CGFloat, foreground: UIColor = .black, background: UIColor = .white) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let colored = output.applyingFilter("CIFalseColor", parameters: [
            "inputColor0": CIColor(color: foreground),
            "inputColor1": CIColor(color: background),
        ])
        // Integer scale factor = nearest-neighbour, no blurry module edges.
        let scale = max(1, (size * 3 / output.extent.width).rounded(.down))
        let scaled = colored.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 3, orientation: .up)
    }
}

/// SwiftUI wrapper for `TRQRCode`. Decorative (hidden from VoiceOver).
struct TRQRCodeView: View {
    var url: URL = TroughLinks.appStoreURL
    var size: CGFloat
    var foreground: UIColor = UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1)
    var background: UIColor = .white

    var body: some View {
        Group {
            if let image = TRQRCode.image(for: url, size: size, foreground: foreground, background: background) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
            } else {
                Color(background)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
