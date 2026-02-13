import SwiftUI

struct PinnedMemoryCard: View {

    let moment: Moment
    var onTap: (() -> Void)? = nil
    var onUnpin: (() -> Void)? = nil
    
    @State private var showMenu = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                photoArea
                textArea
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            
            Menu {
                Button(role: .destructive) {
                    onUnpin?()
                } label: {
                    Label("Unpin Memory", systemImage: "pin.slash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
                    .contentShape(Rectangle())
            }
            .padding(8)
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 150)
                .blur(radius: moment.isLocked ? 20 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            if moment.isLocked {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black.opacity(0.4))
                
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    if let unlockTime = moment.unlockTime {
                        TimeUntilUnlockView(unlockTime: unlockTime)
                    }
                }
            }
        }
        .frame(height: 150)
    }

    // MARK: - Text

    private var textArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let promptText = moment.promptText {
                Text(promptText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)
            }
            
            Text(formattedDate)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                Text("Pinned")
                    .font(.system(size: 10))
            }
            .foregroundStyle(BabyTownTheme.accent.opacity(0.7))

            if let placeName = moment.placeName {
                Text("Near \(placeName)")
                    .font(.system(size: 10))
                    .foregroundStyle(BabyTownTheme.textTertiary)
                    .lineLimit(1)
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: moment.dateTaken)
    }
}

#Preview {
    HStack(spacing: 14) {
        PinnedMemoryCard(
            moment: Moment.sampleMoments[0],
            onUnpin: { print("Unpin") }
        )
        PinnedMemoryCard(
            moment: Moment.sampleMoments[1],
            onUnpin: { print("Unpin") }
        )
    }
    .padding(20)
}
