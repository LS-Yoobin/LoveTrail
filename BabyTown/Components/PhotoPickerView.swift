import SwiftUI
import PhotosUI

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var selectionLimit: Int = 10
    var onFinish: (([PHPickerResult]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if let onFinish = parent.onFinish {
                onFinish(results)
                return
            }

            parent.dismiss()
            guard !results.isEmpty else { return }
            
            let group = DispatchGroup()
            var images: [UIImage] = []
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    defer { group.leave() }
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.selectedImages = images
            }
        }
    }
}
