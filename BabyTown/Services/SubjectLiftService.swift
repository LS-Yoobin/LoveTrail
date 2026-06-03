import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Turns a photo into a sticker-ready cutout using Vision subject lift, with a
/// circular-crop fallback when lift fails (busy backgrounds, unsupported content).
enum SubjectLiftService {

    static func stickerImage(from source: UIImage, maxDimension: CGFloat = 320) -> (image: UIImage, usedSubjectLift: Bool) {
        let scaled = downscaled(source, maxDimension: maxDimension)
        if let lifted = liftSubject(from: scaled) {
            return (lifted, true)
        }
        return (circularCrop(scaled), false)
    }

    private static func liftSubject(from image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: input)
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return nil }
            let maskBuffer = try result.generateScaledMaskForImage(
                forInstances: result.allInstances,
                from: handler
            )
            let mask = CIImage(cvPixelBuffer: maskBuffer)
            let filter = CIFilter.blendWithMask()
            filter.inputImage = input
            filter.maskImage = mask
            filter.backgroundImage = CIImage.empty()
            guard let output = filter.outputImage else { return nil }
            return render(ciImage: output, size: image.size)
        } catch {
            return nil
        }
    }

    private static func render(ciImage: CIImage, size: CGSize) -> UIImage? {
        let context = CIContext(options: nil)
        let rect = CGRect(origin: .zero, size: size)
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    private static func circularCrop(_ image: UIImage) -> UIImage {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2
        )
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        guard let cg = image.cgImage?.cropping(to: cropRect) else { return image }

        let d = side
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: d, height: d))
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.clip()
            UIImage(cgImage: cg).draw(in: rect)
        }
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
