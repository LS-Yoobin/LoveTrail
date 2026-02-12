import SwiftUI

struct StickyActionBar: View {

    var onSelectPhotos: () -> Void
    var onPrompt: (() -> Void)?
    var onCapture: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelectPhotos) {
                Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(BabyTownTheme.accentGradient)
                    )
                    .shadow(color: BabyTownTheme.buttonShadow, radius: 8, y: 3)
            }
            
            if let onPrompt {
                Button(action: onPrompt) {
                    Label("Prompt", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .strokeBorder(BabyTownTheme.accent, lineWidth: 1.5)
                                .background(Capsule().fill(BabyTownTheme.accentSoft))
                        )
                }
            }

            if let onCapture {
                Button(action: onCapture) {
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BabyTownTheme.accent)
                        .padding(11)
                        .background(
                            Circle().fill(BabyTownTheme.accentSoft)
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            BabyTownTheme.background
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }
}

#Preview {
    VStack(spacing: 0) {
        BabyTownHeader()
        StickyActionBar(onSelectPhotos: {}, onCapture: {})
    }
}
