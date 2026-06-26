import SwiftUI

struct PlannerCircleButton: View {
    enum Style {
        case filled
        case glass
    }

    let systemImage: String
    var size: CGFloat = 52
    var iconWeight: Font.Weight = .bold
    var style: Style = .filled
    let action: () -> Void

    private var iconSize: CGFloat { size * (22 / 52) }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundStyle(AnyShapeStyle(.white))
                .frame(width: size, height: size)
                .background {
                    switch style {
                    case .filled:
                        Circle()
                            .fill(BabyTownTheme.accentGradient)
                            .shadow(
                                color: BabyTownTheme.accent.opacity(0.4),
                                radius: size * (8 / 52),
                                y: size * (4 / 52)
                            )
                    case .glass:
                        Circle()
                            .fill(BabyTownTheme.accentDeep)
                            .shadow(
                                color: BabyTownTheme.accentDeep.opacity(0.35),
                                radius: size * (6 / 52),
                                y: size * (3 / 52)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
