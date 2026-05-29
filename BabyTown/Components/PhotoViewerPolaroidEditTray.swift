import SwiftUI
import PhotosUI

/// Polaroid-style edit actions for full-screen photo viewers — solid paper chin, not overlaid on the image.
struct PhotoViewerPolaroidEditTray: View {

    @Binding var selectedPhotos: [PhotosPickerItem]
    var showsReplace: Bool = true
    var onRemove: () -> Void

    private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    private let paperEdge = Color(red: 0.88, green: 0.86, blue: 0.82)
    private let ink = Color(red: 0.24, green: 0.22, blue: 0.21)

    var body: some View {
        VStack(spacing: 0) {
            filmEdge
            paperBody
        }
        .shadow(color: .black.opacity(0.35), radius: 20, y: -6)
    }

    // MARK: - Film edge

    private var filmEdge: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.45),
                        paperEdge.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 3)
    }

    // MARK: - Paper body

    private var paperBody: some View {
        VStack(spacing: 14) {
            Text("Edit photo")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ink.opacity(0.45))

            Group {
                if showsReplace {
                    HStack(spacing: 12) {
                        replaceTile
                        removeTile
                    }
                } else {
                    removeTile
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(paper)
    }

    private var replaceTile: some View {
        PhotosPicker(
            selection: $selectedPhotos,
            maxSelectionCount: 1,
            matching: .images
        ) {
            actionTile(
                icon: "photo.on.rectangle.angled",
                title: "Replace",
                subtitle: "Pick new",
                tint: BabyTownTheme.accent,
                background: BabyTownTheme.accent.opacity(0.12)
            )
        }
        .buttonStyle(.plain)
    }

    private var removeTile: some View {
        Button(action: onRemove) {
            actionTile(
                icon: "trash",
                title: "Remove",
                subtitle: "From album",
                tint: Color(red: 0.78, green: 0.28, blue: 0.32),
                background: Color(red: 0.95, green: 0.88, blue: 0.88)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionTile(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        background: Color
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(paperEdge, lineWidth: 1)
                )
        )
    }
}
