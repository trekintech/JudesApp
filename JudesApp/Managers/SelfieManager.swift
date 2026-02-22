import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class SelfieManager {
    static let shared = SelfieManager()

    private let fileManager = FileManager.default
    private let selfieFileName = "jude_selfie.jpg"
    private let hasCompletedSetupKey = "hasCompletedSelfieSetup"
    private let context = CIContext()

    private init() {}

    // MARK: - Setup State

    var hasCompletedSetup: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }

    func markSetupComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedSetupKey)
    }

    // MARK: - Photo Storage

    private var selfieURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(selfieFileName)
    }

    func saveSelfie(_ image: UIImage) {
        let normalized = normalizeOrientation(image)
        let squared = cropToSquare(normalized)
        let styled = applyComicStyle(squared)
        if let data = styled.jpegData(compressionQuality: 0.85) {
            try? data.write(to: selfieURL, options: .atomic)
        }
    }

    func loadSelfie() -> UIImage? {
        guard let data = try? Data(contentsOf: selfieURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Image Processing

    /// Redraws the image with .up orientation so CGImage operations don't flip it
    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }

    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let side = min(cgImage.width, cgImage.height)
        let xOffset = (cgImage.width - side) / 2
        let yOffset = (cgImage.height - side) / 2
        let cropRect = CGRect(x: xOffset, y: yOffset, width: side, height: side)
        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    /// Applies CIComicEffect for a true cartoon/comic-book look
    func applyComicStyle(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let comic = CIFilter.comicEffect()
        comic.inputImage = ciImage

        guard let comicOutput = comic.outputImage else { return image }

        // Boost vibrance to make it pop
        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = comicOutput
        vibrance.amount = 0.6

        guard let output = vibrance.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }
}
