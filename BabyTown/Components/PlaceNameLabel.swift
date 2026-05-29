import SwiftUI

/// Place name with an optional POI pin when the user picked an exact location (map tap or autocomplete).
struct PlaceNameLabel: View {
    let rawPlaceName: String?
    let isUserSet: Bool
    var font: Font = .system(size: 12)
    var foregroundStyle: Color = .black
    var iconSize: CGFloat = 11
    var spacing: CGFloat = 4
    var lineLimit: Int = 1

    private var displayText: String? {
        if let formatted = PlaceNameFormatting.displayName(raw: rawPlaceName, isUserSet: isUserSet) {
            return formatted
        }
        let trimmed = rawPlaceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        if let displayText {
            HStack(spacing: spacing) {
                if isUserSet {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(foregroundStyle)
                }

                Text(displayText)
                    .font(font)
                    .foregroundStyle(foregroundStyle)
                    .lineLimit(lineLimit)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        PlaceNameLabel(rawPlaceName: "Blue Bottle Coffee", isUserSet: true)
        PlaceNameLabel(rawPlaceName: "Santa Cruz", isUserSet: false)
    }
    .padding()
}
