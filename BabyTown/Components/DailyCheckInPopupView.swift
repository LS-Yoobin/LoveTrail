import SwiftUI

enum CheckInPopupMode: Equatable {
    case claiming(coins: Int)
    case reviewing
}

struct DailyCheckInPopupView: View {
    let mode: CheckInPopupMode
    let streak: Int
    let checkedInToday: Bool
    let onDismiss: () -> Void

    @State private var revealed = false
    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0
    @State private var shimmerPulsed = false

    private var todayIndex: Int {
        if checkedInToday && streak == 0 { return 7 }
        if checkedInToday { return streak }
        return min(streak + 1, 7)
    }

    private var claimCoins: Int {
        if case .claiming(let coins) = mode { return coins }
        return 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            card
                .padding(.horizontal, 24)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                cardScale = 1
                cardOpacity = 1
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 20) {
            header
            starRow
            if case .claiming = mode {
                rewardSlot
            }
            buttonArea
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), BabyTownTheme.accent.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: BabyTownTheme.accent.opacity(0.18), radius: 28, y: 14)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Daily Check-in")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Text("Come back each day to keep your streak")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    private let starCellWidth: CGFloat = 44
    private let starRowSpacing: CGFloat = 14

    private var starRowWidth: CGFloat {
        starCellWidth * 3 + starRowSpacing * 2
    }

    private var starRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: starRowSpacing) {
                ForEach(1...3, id: \.self) { index in
                    starCell(for: index)
                }
            }
            .frame(width: starRowWidth)

            HStack(spacing: starRowSpacing) {
                ForEach(4...6, id: \.self) { index in
                    starCell(for: index)
                }
            }
            .frame(width: starRowWidth)

            starCell(for: 7)
                .frame(width: starRowWidth)
        }
    }

    private func starSize(for index: Int) -> CGFloat {
        index == 7 ? 42 : 26
    }

    private func starSlotHeight(for index: Int) -> CGFloat {
        starSize(for: index) + 4
    }

    private var showsTapHint: Bool {
        if case .claiming = mode, !revealed { return true }
        return false
    }

    private func starCell(for index: Int) -> some View {
        VStack(spacing: 4) {
            starView(for: index)
                .frame(width: starCellWidth, height: starSlotHeight(for: index))

            Group {
                if index == todayIndex, showsTapHint {
                    Text("Tap")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.9))
                } else {
                    Color.clear
                }
            }
            .frame(width: starCellWidth, height: 14)
        }
        .frame(width: starCellWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            guard index == todayIndex, showsTapHint else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                revealed = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(index == todayIndex && showsTapHint ? .isButton : [])
        .accessibilityLabel(
            index == todayIndex && showsTapHint ? "Tap to reveal your reward" : "Day \(index) check-in star"
        )
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let size = starSize(for: index)
        if index < todayIndex {
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(BabyTownTheme.accent)
        } else if index == todayIndex {
            todayStar(size: size)
        } else {
            Image(systemName: "star")
                .font(.system(size: size))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.28))
        }
    }

    @ViewBuilder
    private func todayStar(size: CGFloat) -> some View {
        switch mode {
        case .claiming:
            if revealed {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .scaleEffect(shimmerPulsed ? 1.0 : 1.22)
                    .opacity(shimmerPulsed ? 1.0 : 0.72)
                    .frame(width: size, height: size)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.75)
                            .repeatForever(autoreverses: true)
                        ) {
                            shimmerPulsed = true
                        }
                    }
            }
        case .reviewing:
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(BabyTownTheme.accent)
        }
    }

    // Reserves vertical space so the card doesn't jump when the reward appears.
    private var rewardSlot: some View {
        ZStack {
            Color.clear.frame(height: 44)
            if revealed {
                HStack(spacing: 8) {
                    PetCoinIcon(size: 30)
                    Text("+\(claimCoins)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                }
                .transition(
                    .opacity.combined(with: .scale(scale: 0.8))
                )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: revealed)
    }

    @ViewBuilder
    private var buttonArea: some View {
        switch mode {
        case .claiming:
            if revealed {
                dismissButton("Collect")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        case .reviewing:
            dismissButton("Close")
        }
    }

    private func dismissButton(_ title: String) -> some View {
        Button(action: onDismiss) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BabyTownTheme.buttonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: BabyTownTheme.buttonShadow, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [BabyTownTheme.cardTintLight, BabyTownTheme.cardTintDeep.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview("Claiming — Day 3, not yet tapped") {
    DailyCheckInPopupView(
        mode: .claiming(coins: 14),
        streak: 3,
        checkedInToday: true,
        onDismiss: {}
    )
}

#Preview("Claiming — Day 7 bonus") {
    DailyCheckInPopupView(
        mode: .claiming(coins: 100),
        streak: 0,
        checkedInToday: true,
        onDismiss: {}
    )
}

#Preview("Reviewing — Day 5 streak") {
    DailyCheckInPopupView(
        mode: .reviewing,
        streak: 5,
        checkedInToday: true,
        onDismiss: {}
    )
}

#Preview("Reviewing — not yet checked in today") {
    DailyCheckInPopupView(
        mode: .reviewing,
        streak: 2,
        checkedInToday: false,
        onDismiss: {}
    )
}
