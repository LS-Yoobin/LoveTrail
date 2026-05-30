import SwiftUI

/// Subtle top fade so close, edit, and navigation controls stay legible over bright photos.
struct PhotoViewerTopScrim: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.48),
                Color.black.opacity(0.2),
                Color.black.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}
