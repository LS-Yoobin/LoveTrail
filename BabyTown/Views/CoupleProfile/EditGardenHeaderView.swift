import SwiftUI

/// Top chrome while editing the garden: Back (discard) and Save pills.
struct EditGardenHeaderView: View {
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
                    .background(Color(red: 0.22, green: 0.48, blue: 0.96), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
