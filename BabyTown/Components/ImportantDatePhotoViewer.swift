import SwiftUI

struct ImportantDatePhotoViewerContext {
    let title: String
    let date: Date
    let image: UIImage
}

/// Full-screen viewer for an important-date photo (foundational or special).
struct ImportantDatePhotoViewer: View {
    let title: String
    let date: Date
    let image: UIImage
    var onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero

    private static let dateFormat: Date.FormatStyle =
        .dateTime.month(.wide).day().year()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                photo
                Spacer()
                bottomInfo
            }
        }
        .statusBarHidden(true)
    }

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
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var photo: some View {
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
    }

    private var bottomInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text(date, format: Self.dateFormat)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}
