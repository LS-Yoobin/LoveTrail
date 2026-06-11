import SwiftUI

struct HeroPhotoPreview: View {

    let image: UIImage?

    var body: some View {
        ZStack {
            if image == nil {
                placeholderView
                    .transition(.opacity)
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(BabyTownTheme.accent.opacity(0.04))
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.4), value: image)
    }

    private var placeholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.25))
            Text("Select a memory")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }
}

#Preview("Empty") {
    HeroPhotoPreview(image: nil)
        .padding(.top, 60)
}
