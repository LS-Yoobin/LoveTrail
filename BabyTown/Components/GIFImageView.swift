import SwiftUI
import UIKit
import ImageIO

struct GIFImageView: UIViewRepresentable {
    let gifName: String
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = false
        
        if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif"),
           let imageData = try? Data(contentsOf: gifURL),
           let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
            
            var images: [UIImage] = []
            var totalDuration: TimeInterval = 0
            
            let count = CGImageSourceGetCount(source)
            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    let image = UIImage(cgImage: cgImage)
                    images.append(image)
                    
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifInfo = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                       let delay = gifInfo[kCGImagePropertyGIFDelayTime as String] as? Double {
                        totalDuration += delay
                    } else {
                        totalDuration += 0.1
                    }
                }
            }
            
            imageView.animationImages = images
            imageView.animationDuration = totalDuration
            imageView.animationRepeatCount = 0
            imageView.startAnimating()
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
