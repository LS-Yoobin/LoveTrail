import SwiftUI
import PhotosUI

struct FullScreenPinnedMemoryViewer: View {
    
    let title: String
    let date: String
    let image: UIImage?
    @Binding var pickerItem: PhotosPickerItem?
    var onDismiss: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                Spacer()
                
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(y: dragOffset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.height > 0 {
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 150 {
                                        onDismiss()
                                    } else {
                                        withAnimation(.spring(response: 0.3)) {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                        )
                } else {
                    placeholderView
                }
                
                Spacer()
                
                bottomInfo
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.black.opacity(0.3)))
            }
            
            Spacer()
            
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Edit")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.3))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Bottom Info
    
    private var bottomInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                Text(date)
                    .font(.system(size: 14))
            }
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    // MARK: - Placeholder
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No photo selected")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.5))
            
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Add Photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                    )
            }
        }
    }
}

#Preview {
    FullScreenPinnedMemoryViewer(
        title: "First Photo Taken Together",
        date: "Pinned",
        image: Moment.samplePinnedOfficial,
        pickerItem: .constant(nil),
        onDismiss: {}
    )
}
