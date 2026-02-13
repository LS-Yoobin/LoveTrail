import SwiftUI

struct PromptPhotoViewer: View {
    
    let photos: [PromptPhoto]
    let initialIndex: Int
    var onDismiss: () -> Void
    
    @State private var currentIndex: Int
    
    init(
        photos: [PromptPhoto],
        initialIndex: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }
    
    var currentPhoto: PromptPhoto {
        photos[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    photoView(for: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                topBar
                Spacer()
                if photos.count > 1 {
                    photoPreviewStrip
                }
            }
        }
        .statusBarHidden(true)
    }
    
    private func photoView(for photo: PromptPhoto) -> some View {
        Image(uiImage: photo.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))
            }
            
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }
    
    private var photoPreviewStrip: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            thumbnailView(for: photo, at: index)
                                .id(index)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.bottom, 20)
    }
    
    private func thumbnailView(for photo: PromptPhoto, at index: Int) -> some View {
        let isSelected = index == currentIndex
        
        return Image(uiImage: photo.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1.5)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .shadow(color: .black.opacity(isSelected ? 0.5 : 0.3), radius: isSelected ? 8 : 4, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
