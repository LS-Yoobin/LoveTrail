import SwiftUI

/// Horizontal scrollable row of mood stamp chips used in the note editor.
///
/// Each chip shows the custom PNG stamp asset (unselected / selected state) sourced from
/// `stamp_<mood>_unsel` / `stamp_<mood>_sel` image assets. Tapping a selected stamp
/// deselects it (sets mood to nil). Tapping an unselected stamp selects it and fires
/// a light haptic.
struct StampCarouselView: View {

    @Binding var selectedMood: ProfileNoteMood?

    // MARK: - Metrics

    private enum Metrics {
        static let stampSize: CGFloat   = 75
        static let chipSpacing: CGFloat = 6
    }

    /// The moods that have stamp artwork — the label is baked into each PNG.
    static let stampedMoods: [ProfileNoteMood] = [.butterflies, .giddy, .smitten, .dreamy, .playful]

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.chipSpacing) {
                ForEach(Self.stampedMoods, id: \.self) { mood in
                    stampChip(for: mood)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Individual Stamp

    private func stampChip(for mood: ProfileNoteMood) -> some View {
        let isSelected = selectedMood == mood
        let assetName = "stamp_\(mood.displayName.lowercased())_\(isSelected ? "sel" : "unsel")"

        return Button {
            if isSelected {
                selectedMood = nil
            } else {
                selectedMood = mood
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.stampSize, height: Metrics.stampSize)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
        .accessibilityLabel(mood.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 24) {
        Text("Unselected")
            .font(.caption)
        StampCarouselView(selectedMood: .constant(nil))
            .padding(.horizontal, 16)

        Text("Dreamy selected")
            .font(.caption)
        StampCarouselView(selectedMood: .constant(.dreamy))
            .padding(.horizontal, 16)
    }
    .padding(.vertical, 32)
}
