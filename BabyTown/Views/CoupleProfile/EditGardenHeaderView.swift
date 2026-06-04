import SwiftUI

/// Top chrome while editing the garden: Back (discard) and Save pills.
struct EditGardenHeaderView: View {
    static let estimatedHeight: CGFloat = 44
    static let overlayTopPadding: CGFloat = 0
    static var scrollTopClearance: CGFloat { estimatedHeight + overlayTopPadding }

    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Text("Back")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onSave) {
                Text("Save")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(BabyTownTheme.savePillFill, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
