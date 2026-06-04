import AppKit
import Foundation

let srcPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/justinseo/.cursor/projects/Users-justinseo-Desktop-BabyTown/assets/prop_record_player-97ae3699-ce1e-431d-8e08-bf5330c8968a.png"
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
let cols = 2
let rows = 2
let cellW = width / cols
let topH = height / rows + (height % rows)
let bottomH = height / rows

/// Visual order: top-left, top-right, bottom-left, bottom-right.
let placements: [(col: Int, rowFromTop: Int, name: String)] = [
    (0, 0, "prop_record_player_0"),
    (1, 0, "prop_record_player_1"),
    (0, 1, "prop_record_player_2"),
    (1, 1, "prop_record_player_3"),
]

func nearBlack(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8, thresh: UInt8 = 32) -> Bool {
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
    let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    return keyed.cropping(to: crop)
}

var trimmedFrames: [(name: String, image: CGImage)] = []

for placement in placements {
    let cellH = placement.rowFromTop == 0 ? topH : bottomH
    let cgY = placement.rowFromTop == 0 ? height - topH : 0
    let rect = CGRect(
        x: placement.col * cellW,
        y: cgY,
        width: cellW,
        height: cellH
    )
    guard let cell = cg.cropping(to: rect), let trimmed = trimAndKey(cell) else {
        fputs("Failed to crop \(placement.name)\n", stderr)
        continue
    }
    trimmedFrames.append((placement.name, trimmed))
}

let canvasW = trimmedFrames.map(\.image.width).max() ?? 0
let canvasH = trimmedFrames.map(\.image.height).max() ?? 0

func centerOnCanvas(_ image: CGImage, width: Int, height: Int) -> CGImage? {
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return image }
    ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
    let x = (width - image.width) / 2
    let y = (height - image.height) / 2
    ctx.draw(image, in: CGRect(x: x, y: y, width: image.width, height: image.height))
    return ctx.makeImage()
}

for (name, trimmed) in trimmedFrames {
    guard let normalized = centerOnCanvas(trimmed, width: canvasW, height: canvasH) else { continue }

    let imageset = URL(fileURLWithPath: outRoot).appendingPathComponent("\(name).imageset")
    try? FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
    let pngURL = imageset.appendingPathComponent("\(name).png")

    let rep = NSBitmapImageRep(cgImage: normalized)
    rep.size = NSSize(width: normalized.width, height: normalized.height)
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
    print("\(name): \(normalized.width)x\(normalized.height)")
}

print("done")
