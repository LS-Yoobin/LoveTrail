import UIKit

/// Layout math for sticker cutouts — maps opaque image content to on-screen frames
/// so name pills sit a consistent distance below the visible sticker, not the square bounds.
enum StickerImageLayout {
    /// Gap between visible sticker bottom and the label pill top.
    static let labelGap: CGFloat = 6
    /// Approximate rendered height of the black name pill (subheadline + vertical padding).
    static let labelPillHeight: CGFloat = 34

    private static let boundsCache = NSCache<NSString, NSValue>()

    /// Opaque content bounds normalized to 0…1 in image coordinates (origin top-left).
    static func normalizedOpaqueBounds(for image: UIImage, alphaThreshold: UInt8 = 12) -> CGRect {
        let key = cacheKey(for: image)
        if let cached = boundsCache.object(forKey: key) {
            return cached.cgRectValue
        }
        let bounds = computeNormalizedOpaqueBounds(for: image, alphaThreshold: alphaThreshold)
        boundsCache.setObject(NSValue(cgRect: bounds), forKey: key)
        return bounds
    }

    /// Distance from the top of a `scaledToFit` square frame to the bottom of visible content.
    static func visibleContentBottom(inSquareSide side: CGFloat, image: UIImage) -> CGFloat {
        let bounds = normalizedOpaqueBounds(for: image)
        let imgW = image.size.width
        let imgH = image.size.height
        guard imgW > 0, imgH > 0 else { return side }

        let fitScale = min(side / imgW, side / imgH)
        let renderH = imgH * fitScale
        let originY = (side - renderH) / 2
        return originY + renderH * bounds.maxY
    }

    /// Vertical offset for the label pill relative to sitting directly below the square frame.
    /// Negative values pull the pill closer to the sticker art.
    static func labelVerticalOffset(inSquareSide side: CGFloat, image: UIImage?) -> CGFloat {
        guard let image else { return 0 }
        let contentBottom = visibleContentBottom(inSquareSide: side, image: image)
        return contentBottom - side
    }

    /// Total stacked height of sticker square + label block when a label is shown.
    static func labeledStackHeight(squareSide side: CGFloat, image: UIImage?) -> CGFloat {
        let contentBottom = image.map { visibleContentBottom(inSquareSide: side, image: $0) } ?? side
        return contentBottom + labelGap + labelPillHeight
    }

    private static func cacheKey(for image: UIImage) -> NSString {
        let cg = image.cgImage
        let pointer = cg.map { Unmanaged.passUnretained($0).toOpaque() } ?? Unmanaged.passUnretained(image).toOpaque()
        return "\(pointer)-\(image.size.width)x\(image.size.height)" as NSString
    }

    private static func computeNormalizedOpaqueBounds(
        for image: UIImage,
        alphaThreshold: UInt8
    ) -> CGRect {
        guard let cg = image.cgImage else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let width = cg.width
        let height = cg.height
        guard width > 0, height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let step = max(1, min(width, height) / 96)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundOpaque = false

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let index = (y * width + x) * bytesPerPixel
                if pixels[index + 3] > alphaThreshold {
                    foundOpaque = true
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
                x += step
            }
            y += step
        }

        guard foundOpaque else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let normalizedMinX = CGFloat(minX) / CGFloat(width)
        let normalizedMinY = CGFloat(minY) / CGFloat(height)
        let normalizedMaxX = CGFloat(maxX + 1) / CGFloat(width)
        let normalizedMaxY = CGFloat(maxY + 1) / CGFloat(height)

        return CGRect(
            x: normalizedMinX,
            y: normalizedMinY,
            width: normalizedMaxX - normalizedMinX,
            height: normalizedMaxY - normalizedMinY
        )
    }
}
