import AppKit
import Foundation

let srcPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/justinseo/.cursor/projects/Users-justinseo-Desktop-BabyTown/assets/prop_frame_sheet-b2ef56f8-083f-448d-aab6-af7d5489f4da.png"
let outRoot = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "/Users/justinseo/Desktop/BabyTown/BabyTown/Assets.xcassets"

guard let src = NSImage(contentsOfFile: srcPath),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Failed to load source image\n", stderr)
    exit(1)
}

let width = cg.width
let height = cg.height
let cols = 4
let rows = 2
let cellW = width / cols
let cellH = height / rows

let names = [
    "prop_frame_cat",
    "prop_frame_floral",
    "prop_frame_hearts",
    "prop_frame_ribbon",
    "prop_frame_moon",
    "prop_frame_leaves",
    "prop_frame_bear",
    "prop_frame_ornate",
]

/// Extra pixels to drop from the left after matte trim — removes the previous
/// column's frame edge when cells on the sheet sit close together.
let leftTrimAfterMatte: [String: Int] = [
    "prop_frame_floral": 17,
    "prop_frame_hearts": 14,
    "prop_frame_leaves": 23,
]

func nearBlack(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8, thresh: UInt8 = 30) -> Bool {
    a > 200 && r <= thresh && g <= thresh && b <= thresh
}

func trimAndKey(_ image: CGImage) -> CGImage? {
    let w = image.width
    let h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &pixels,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return image }

    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

    var minX = w, minY = h, maxX = 0, maxY = 0
    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
            if nearBlack(r, g, b, a) {
                pixels[i + 3] = 0
            } else if a > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard let keyed = ctx.makeImage() else { return image }
    guard minX <= maxX, minY <= maxY else { return keyed }

    var crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    return keyed.cropping(to: crop)
}

func applyLeftTrim(_ image: CGImage, pixels: Int) -> CGImage? {
    guard pixels > 0, pixels < image.width else { return image }
    let rect = CGRect(x: pixels, y: 0, width: image.width - pixels, height: image.height)
    return image.cropping(to: rect)
}

for (idx, name) in names.enumerated() {
    let row = idx / cols
    let col = idx % cols
    let rect = CGRect(x: col * cellW, y: row * cellH, width: cellW, height: cellH)
    guard let cell = cg.cropping(to: rect), var trimmed = trimAndKey(cell) else {
        fputs("Failed to crop \(name)\n", stderr)
        continue
    }
    if let extra = leftTrimAfterMatte[name], extra > 0 {
        trimmed = applyLeftTrim(trimmed, pixels: extra) ?? trimmed
    }

    let imageset = URL(fileURLWithPath: outRoot).appendingPathComponent("\(name).imageset")
    try? FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
    let pngURL = imageset.appendingPathComponent("\(name).png")

    let rep = NSBitmapImageRep(cgImage: trimmed)
    rep.size = NSSize(width: trimmed.width, height: trimmed.height)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try data.write(to: pngURL)

    let contents = """
    {
      "images" : [
        {
          "filename" : "\(name).png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try contents.write(to: imageset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("\(name): \(trimmed.width)x\(trimmed.height)")
}

print("done")
