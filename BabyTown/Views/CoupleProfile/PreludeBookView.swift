import SwiftUI

/// Closed prelude book (BookFlip1) placed on the Secret Garden canvas.
struct PreludeBookView: View {
    var scale: CGFloat = 1
    var onTap: (() -> Void)? = nil

    static let gardenMinScale: CGFloat = 0.8
    static let gardenDefaultScale: CGFloat = 1.1
    static let gardenMaxScale: CGFloat = 2.0
    static let gardenBaseWidth: CGFloat = 96

    private var width: CGFloat { Self.gardenBaseWidth * scale }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    bookContent
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the prelude gift book")
            } else {
                bookContent
            }
        }
        .accessibilityLabel("Book")
    }

    private var bookContent: some View {
        VStack(spacing: 8) {
            Image("BookFlip1")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: width)
                .shadow(color: .black.opacity(0.20), radius: 5, y: 2)

            Text("Book")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.black, in: Capsule())
        }
        .contentShape(Rectangle())
    }
}
