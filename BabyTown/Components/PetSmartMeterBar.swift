import SwiftUI

/// Compact Smart Meter progress bar shown during trick training.
struct PetSmartMeterBar: View {
    let level: Int
    let progressFraction: Double
    var compact: Bool = false

    private var isMaxed: Bool { level >= PetSmartMeterRules.maxLevel }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.32, blue: 0.82))
                Text("Smart Lv \(level)")
                    .font(.system(size: compact ? 11 : 12, weight: .bold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                Spacer()
                if isMaxed {
                    Text("Master Trainer")
                        .font(.system(size: compact ? 10 : 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.32, blue: 0.82))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.45, green: 0.32, blue: 0.82).opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.62, green: 0.48, blue: 0.96),
                                    Color(red: 0.45, green: 0.32, blue: 0.82),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(isMaxed ? 1 : progressFraction))
                }
            }
            .frame(height: compact ? 5 : 6)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PetSmartMeterBar(level: 3, progressFraction: 0.55)
        PetSmartMeterBar(level: 15, progressFraction: 1, compact: true)
    }
    .padding()
}
