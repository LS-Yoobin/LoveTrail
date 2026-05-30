import SwiftUI

/// Lets the user pick one of the two cats to adopt. Uses each skin's portrait
/// asset when present, falling back to a themed placeholder so it works before
/// final art lands.
struct CatSelectionView: View {
    var onAdopt: (CatSkin) -> Void

    @State private var selected: CatSkin = .calico

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Adopt a Pet")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text("Choose a kitty to join your town. They'll live in their own cozy room.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                HStack(spacing: 16) {
                    ForEach(CatSkin.allCases) { skin in
                        CatChoiceCard(skin: skin, isSelected: selected == skin)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selected = skin
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)

                Button {
                    onAdopt(selected)
                } label: {
                    Text("Adopt \(selected.petName)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(BabyTownTheme.buttonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
                        .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            .padding(.bottom, 32)
        }
        .background(BabyTownTheme.background.ignoresSafeArea())
        .navigationTitle("Adopt a Pet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CatChoiceCard: View {
    let skin: CatSkin
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 12) {
            portrait
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(BabyTownTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 2) {
                Text(skin.petName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Text(skin.breedName)
                    .font(.system(size: 13))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
        .padding(12)
        .background(BabyTownTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .stroke(isSelected ? BabyTownTheme.accent : Color.black.opacity(0.06),
                        lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: BabyTownTheme.cardShadow, radius: 6, y: 3)
        .scaleEffect(isSelected ? 1.0 : 0.97)
    }

    @ViewBuilder
    private var portrait: some View {
        if UIImage(named: skin.portraitAsset) != nil {
            Image(skin.portraitAsset)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            // Placeholder until real portraits are added.
            Image(systemName: "cat.fill")
                .font(.system(size: 56))
                .foregroundStyle(skin.placeholderColor)
        }
    }
}

#Preview {
    NavigationStack {
        CatSelectionView(onAdopt: { _ in })
    }
}
