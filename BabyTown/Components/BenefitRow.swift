import SwiftUI
import Combine

struct BenefitRow: View {

    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accentIconGradient)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(BabyTownTheme.accent.opacity(0.08))
                )

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        BenefitRow(icon: "calendar", title: "Auto grouped by day")
        BenefitRow(icon: "mappin.circle", title: "Places detected when possible")
        BenefitRow(icon: "sparkles", title: "Throwbacks get better over time")
    }
    .padding(24)
}
