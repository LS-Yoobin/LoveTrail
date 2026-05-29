import SwiftUI

/// Non-interactive photo collage for share export; fills the height given by its parent.
struct MemorySharePhotoCollage: View {

    static let maxPhotos = 4

    let images: [UIImage]
    var cornerRadius: CGFloat = 12
    var layoutScale: CGFloat = 1

    private func s(_ value: CGFloat) -> CGFloat { value * layoutScale }

    var body: some View {
        GeometryReader { geometry in
            let height = max(geometry.size.height, 1)
            let width = max(geometry.size.width, 1)
            let photos = Array(images.prefix(Self.maxPhotos))

            Group {
                switch photos.count {
                case 0:
                    Color.clear
                case 1:
                    singleLayout(photos[0], height: height)
                case 2:
                    twoLayout(photos, height: height)
                case 3:
                    threeLayout(photos, height: height)
                default:
                    fourLayout(photos, height: height)
                }
            }
            .frame(width: width, height: height)
        }
    }

    private var tileSpacing: CGFloat { s(4) }

    private func singleLayout(_ image: UIImage, height: CGFloat) -> some View {
        photoTile(image)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func twoLayout(_ images: [UIImage], height: CGFloat) -> some View {
        HStack(spacing: tileSpacing) {
            photoTile(images[0])
            photoTile(images[1])
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func threeLayout(_ images: [UIImage], height: CGFloat) -> some View {
        let heroHeight = height * 0.58
        let rowHeight = height - heroHeight - tileSpacing

        return VStack(spacing: tileSpacing) {
            photoTile(images[0])
                .frame(height: heroHeight)
            HStack(spacing: tileSpacing) {
                photoTile(images[1])
                photoTile(images[2])
            }
            .frame(height: max(rowHeight, 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func fourLayout(_ images: [UIImage], height: CGFloat) -> some View {
        let rowHeight = (height - tileSpacing) / 2

        return VStack(spacing: tileSpacing) {
            HStack(spacing: tileSpacing) {
                photoTile(images[0])
                photoTile(images[1])
            }
            .frame(height: rowHeight)
            HStack(spacing: tileSpacing) {
                photoTile(images[2])
                photoTile(images[3])
            }
            .frame(height: rowHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func photoTile(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
    }
}
