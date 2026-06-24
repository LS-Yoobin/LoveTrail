import SwiftUI

struct VaultedLetterRow: View {
    let letter: UserLetter
    var onUnlockForever: () -> Void

    private var accent: Color { BabyTownTheme.accentDeep }

    var body: some View {
        Button(action: onUnlockForever) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accent.opacity(0.6))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(letter.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.35))
                        .redacted(reason: .placeholder)
                    Text("Unlock Forever to read this letter")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.35))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}
