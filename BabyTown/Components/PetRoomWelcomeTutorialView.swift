import SwiftUI

/// First-visit walkthrough after adopting a pet. Explains shared care tasks,
/// coin rewards, and room decorating in a short premium carousel.
struct PetRoomWelcomeTutorialView: View {
    let petName: String
    let petPortraitAsset: String
    var onFinish: () -> Void

    @State private var step = 0
    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0
    @State private var goingForward = true

    private let totalSteps = 3

    private struct CareTaskPreview: Identifiable {
        let id: String
        let imageName: String
        let label: String
        let coinReward: Int
    }

    private var careTasks: [CareTaskPreview] {
        [
            CareTaskPreview(
                id: "litter",
                imageName: "prop_litter_box",
                label: "Litter Box",
                coinReward: PetEconomy.CareTask.cleanLitter.coinReward
            ),
            CareTaskPreview(
                id: "food",
                imageName: "prop_food_bowl",
                label: "Food Bowl",
                coinReward: PetEconomy.CareTask.feed.coinReward
            ),
            CareTaskPreview(
                id: "water",
                imageName: "prop_water_bowl",
                label: "Water Bowl",
                coinReward: PetEconomy.CareTask.fillWater.coinReward
            ),
        ]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            tutorialCard
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

    private var tutorialCard: some View {
        VStack(spacing: 0) {
            heroSection
                .frame(height: 196)

            VStack(spacing: 18) {
                stepContent
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
                    ))

                stepIndicator

                Button(action: advance) {
                    Text(step < totalSteps - 1 ? "Next" : "Let's go")
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
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            BabyTownTheme.accent.opacity(0.28),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: BabyTownTheme.accent.opacity(0.18), radius: 28, y: 14)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < 0 {
                        advance()
                    } else if value.translation.width > 0 {
                        retreat()
                    }
                }
        )
    }

    @ViewBuilder
    private var heroSection: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BabyTownTheme.accent.opacity(0.22),
                    BabyTownTheme.cardTintDeep.opacity(0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            decorativePaws

            Group {
                switch step {
                case 0:
                    petHero
                case 1:
                    careTasksHero
                default:
                    coinsHero
                }
            }
            .id("hero-\(step)")
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28
            )
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            VStack(spacing: 10) {
                Text("Welcome home, \(petName)!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("You adopted \(petName)! You and your partner can take care of them together in this cozy room.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        case 1:
            VStack(spacing: 10) {
                Text("Keep the room happy")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Tap each item in the room when it needs attention. Clean the litter box, fill the food bowl, and refill the water bowl.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        default:
            VStack(spacing: 10) {
                Text("Earn coins, make it yours")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Every care task earns coins. Spend them in the Market to decorate your pet's room.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    private var petHero: some View {
        Group {
            if UIImage(named: petPortraitAsset) != nil {
                Image(petPortraitAsset)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 48)
                    .padding(.vertical, 12)
            } else {
                Image(systemName: "cat.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }
        }
    }

    private var careTasksHero: some View {
        HStack(spacing: 10) {
            ForEach(careTasks) { task in
                VStack(spacing: 8) {
                    Image(task.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.88))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                        )

                    Text(task.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Text("+\(task.coinReward)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(BabyTownTheme.accentDeep)
                        PetCoinIcon(size: 16)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var coinsHero: some View {
        HStack(spacing: 18) {
            VStack(spacing: 8) {
                PetCoinIcon(size: 64)
                    .shadow(color: Color(red: 0.84, green: 0.64, blue: 0.08).opacity(0.35), radius: 10, y: 4)
                Text("Care tasks")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.7))

            VStack(spacing: 8) {
                Image("prop_cat_tree")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.88))
                    )
                Text("Room décor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var decorativePaws: some View {
        ZStack {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 34))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.12))
                .offset(x: -118, y: -52)
                .rotationEffect(.degrees(-18))

            Image(systemName: "pawprint.fill")
                .font(.system(size: 26))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.10))
                .offset(x: 124, y: 58)
                .rotationEffect(.degrees(14))
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == step ? BabyTownTheme.accentDeep : BabyTownTheme.accent.opacity(0.22))
                    .frame(width: index == step ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: step)
            }
        }
        .accessibilityLabel("Step \(step + 1) of \(totalSteps)")
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [BabyTownTheme.cardTintLight, BabyTownTheme.cardTintDeep.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func advance() {
        if step < totalSteps - 1 {
            goingForward = true
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                step += 1
            }
        } else {
            onFinish()
        }
    }

    private func retreat() {
        guard step > 0 else { return }
        goingForward = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            step -= 1
        }
    }
}

#Preview {
    PetRoomWelcomeTutorialView(
        petName: "Artemis",
        petPortraitAsset: "profile_calico_sit",
        onFinish: {}
    )
}
