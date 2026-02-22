import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class SelfieManager {
    static let shared = SelfieManager()

    private let fileManager = FileManager.default
    private let selfieFileName = "jude_selfie.jpg"
    private let hasCompletedSetupKey = "hasCompletedSelfieSetup"

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
        // Crop to square centered on face area, then apply comic filter
        let squared = cropToSquare(image)
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

    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let side = min(cgImage.width, cgImage.height)
        let xOffset = (cgImage.width - side) / 2
        let yOffset = (cgImage.height - side) / 2
        let cropRect = CGRect(x: xOffset, y: yOffset, width: side, height: side)
        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Applies a posterize + vibrant look to make the selfie feel cartoon/emoji-like
    func applyComicStyle(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext()

        // Posterize for cartoon effect
        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = ciImage
        posterize.levels = 8

        guard let posterized = posterize.outputImage else { return image }

        // Boost vibrance
        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = posterized
        vibrance.amount = 0.8

        guard let output = vibrance.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }
}
