import SwiftUI

/// Fixed-blue pill label for Save / Next confirmation actions.
/// Uses `BabyTownTheme.savePillFill` so confirmation buttons stay blue regardless of color theme.
struct SavePillLabel: View {
    let title: String
    var isEnabled: Bool = true
    var font: Font = .system(size: 16, weight: .semibold)
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 7
    var fillsWidth: Bool = false

    var body: some View {
        Group {
            if fillsWidth {
                Text(title)
                    .font(font)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, verticalPadding)
                    .background(Capsule().fill(fillStyle))
            } else {
                Text(title)
                    .font(font)
                    .foregroundStyle(.white)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .background(Capsule().fill(fillStyle))
            }
        }
    }

    private var fillStyle: AnyShapeStyle {
        isEnabled
            ? AnyShapeStyle(BabyTownTheme.savePillFill)
            : AnyShapeStyle(Color.gray.opacity(0.35))
    }
}
