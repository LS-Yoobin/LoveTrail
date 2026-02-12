import SwiftUI
import Combine

struct BabyTownHeader: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.accent)

            Text("Baby Town")
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(BabyTownTheme.background.opacity(0.96))
    }
}

#Preview {
    BabyTownHeader()
}
