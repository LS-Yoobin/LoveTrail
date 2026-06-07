import SwiftUI

/// White dashed border shown around the selected moveable region in Edit Garden mode.
struct CustomizeDottedOutline: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 8
    var lineWidth: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white,
                            style: StrokeStyle(lineWidth: lineWidth, dash: [6, 4])
                        )
                }
            }
    }
}

/// Gentle alpha pulse for unselected stickers/regions in Edit Garden mode.
struct EditGardenPulse: ViewModifier {
    let isActive: Bool

    @State private var pulse = false

    private static let animation = Animation.easeInOut(duration: 0.55).repeatForever(autoreverses: true)

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? (pulse ? 0.72 : 1.0) : 1.0)
            .onAppear { setPulse(active: isActive) }
            .onChange(of: isActive) { _, active in
                setPulse(active: active)
            }
    }

    private func setPulse(active: Bool) {
        if active {
            pulse = false
            withAnimation(Self.animation) {
                pulse = true
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pulse = false
            }
        }
    }
}

extension View {
    func customizeDottedOutline(
        _ isActive: Bool,
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 8,
        lineWidth: CGFloat = 2
    ) -> some View {
        modifier(CustomizeDottedOutline(
            isActive: isActive,
            cornerRadius: cornerRadius,
            padding: padding,
            lineWidth: lineWidth
        ))
    }

    func editGardenPulse(_ isActive: Bool) -> some View {
        modifier(EditGardenPulse(isActive: isActive))
    }
}

/// Delete control for edit-garden selection. Render at the canvas layer so it
/// stays tappable above overlapping stickers.
struct EditGardenTrashButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.red, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
