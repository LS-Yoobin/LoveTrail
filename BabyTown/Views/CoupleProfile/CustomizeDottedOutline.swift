import SwiftUI

/// White dashed border shown around moveable regions in Edit Garden mode.
struct CustomizeDottedOutline: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                }
            }
    }
}

extension View {
    func customizeDottedOutline(_ isActive: Bool, cornerRadius: CGFloat = 12, padding: CGFloat = 8) -> some View {
        modifier(CustomizeDottedOutline(isActive: isActive, cornerRadius: cornerRadius, padding: padding))
    }
}
