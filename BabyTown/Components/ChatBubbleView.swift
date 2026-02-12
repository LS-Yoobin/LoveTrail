import SwiftUI

struct ChatBubbleView: View {
    
    let message: String
    let isFromJinky: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromJinky {
                avatarCircle
            }
            
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(isFromJinky ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isFromJinky ? AnyShapeStyle(Color(.systemGray6)) : AnyShapeStyle(BabyTownTheme.accentGradient))
                )
                .frame(maxWidth: .infinity, alignment: isFromJinky ? .leading : .trailing)
            
            if !isFromJinky {
                Spacer()
            }
        }
    }
    
    private var avatarCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay(
                Text("J")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
