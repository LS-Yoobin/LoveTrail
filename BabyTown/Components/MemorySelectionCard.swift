import SwiftUI

struct MemorySelectionCard: View {

    let title: String
    let subtitle: String
    let image: UIImage?
    var isOptional: Bool = false

    @State private var heartPopScale: CGFloat = 0
    @State private var heartPopOpacity: Double = 0

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
            textContent
            Spacer()
            trailingIcon
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
        .onChange(of: image) { _, newValue in
            if newValue != nil {
                triggerHeartPop()
            }
        }
    }

    // MARK: - Subviews

    private var thumbnailView: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.pink.opacity(0.06))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "heart")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(.pink.opacity(0.3))
                    )
            }

            Image(systemName: "heart.fill")
                .font(.system(size: 26))
                .foregroundStyle(.pink)
                .scaleEffect(heartPopScale)
                .opacity(heartPopOpacity)
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)

                if isOptional {
                    Text("Optional")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.pink.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.pink.opacity(0.08))
                        )
                }
            }

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.6))
        }
    }

    private var trailingIcon: some View {
        Image(systemName: image == nil ? "plus.circle.fill" : "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(image == nil ? .pink.opacity(0.4) : .green.opacity(0.7))
            .animation(.easeInOut(duration: 0.25), value: image == nil)
    }

    // MARK: - Animation

    private func triggerHeartPop() {
        heartPopScale = 0.3
        heartPopOpacity = 1.0

        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            heartPopScale = 1.3
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.45)) {
            heartPopOpacity = 0
            heartPopScale = 1.6
        }
    }
}

#Preview("Empty") {
    MemorySelectionCard(
        title: "When we first met",
        subtitle: "The moment it all started",
        image: nil,
        isOptional: true
    )
    .padding(.horizontal, 20)
}
