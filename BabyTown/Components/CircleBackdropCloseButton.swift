import SwiftUI

struct CircleBackdropCloseButton: View {
    var circleSize: CGFloat = 36
    var iconSize: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: circleSize, height: circleSize)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: iconSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .buttonStyle(.plain)
    }
}
