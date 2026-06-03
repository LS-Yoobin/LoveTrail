import SwiftUI

/// One circular avatar in the couple header with a black name pill underneath.
struct ProfileAvatarSlot: View {
    enum Variant {
        case you(image: UIImage?, name: String, onTap: () -> Void)
        case invitePartner(title: String, onTap: () -> Void)
    }

    let variant: Variant
    var slotSize: CGFloat = ProfileSticker.cutoutBaseSize

    var body: some View {
        switch variant {
        case let .you(image, name, onTap):
            Button(action: onTap) {
                slotColumn {
                    avatarCircle(image: image, placeholderSystemName: "person.crop.circle.badge.plus")
                    namePill(name.isEmpty ? "You" : name)
                }
            }
            .buttonStyle(.plain)

        case let .invitePartner(title, onTap):
            Button(action: onTap) {
                slotColumn {
                    partnerPlaceholder
                    namePill(title)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func slotColumn<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
        }
    }

    private func namePill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.black, in: Capsule())
    }

    private var partnerPlaceholder: some View {
        slotPlaceholder(systemImage: "heart.circle")
    }

    private static let emptyAvatarFill = Color(red: 0.36, green: 0.56, blue: 0.90)

    private func slotPlaceholder(systemImage: String) -> some View {
        ZStack {
            Circle().fill(Self.emptyAvatarFill)
            Circle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.white.opacity(0.7))
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: slotSize, height: slotSize)
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(radius: 4, y: 2)
    }

    private func avatarCircle(image: UIImage?, placeholderSystemName: String) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: slotSize, height: slotSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(radius: 4, y: 2)
            } else {
                slotPlaceholder(systemImage: placeholderSystemName)
            }
        }
    }
}
