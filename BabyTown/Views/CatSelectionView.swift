import SwiftUI

struct CatSelectionView: View {
    @ObservedObject var viewModel: PetViewModel
    var onDismiss: () -> Void
    var onEnterPet: (CatSkin) -> Void

    @State private var selected: CatSkin = .calico
    @State private var showingProfile = false
    @State private var blockedMessage: String?
    @State private var toast: String?

    private var isFirstTimeVariant: Bool {
        !viewModel.hasAnyOwnedPet
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Select One")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text(selectionSubtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                HStack(spacing: 16) {
                    ForEach(CatSkin.allCases) { skin in
                        CatChoiceCard(
                            skin: skin,
                            isSelected: skin == .calico,
                            isOwned: viewModel.ownedSkins.contains(skin)
                        )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selected = skin
                                    blockedMessage = nil
                                    showingProfile = true
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
        .background(BabyTownTheme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: close) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .overlay {
            if showingProfile {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                        .onTapGesture { showingProfile = false }
                    VStack(spacing: 12) {
                        PetProfileCard(
                            skin: selected,
                            displayName: viewModel.displayName(for: selected),
                            birthDate: DataPersistenceManager.shared.loadOrCreateAppJoinedDate(),
                            smartnessLevel: viewModel.smartLevel(for: selected),
                            knownTricks: viewModel.unlockedTricks(for: selected),
                            showsBirthDate: !isFirstTimeVariant,
                            showsTrainingDetails: !isFirstTimeVariant,
                            onClose: { showingProfile = false },
                            onRenameName: nil,
                            onLevelLongPress: toggleSecondPetAdoptionBypassIfNeeded
                        )

                        Button(action: tapProfileCTA) {
                            Text(profileCTATitle)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(BabyTownTheme.buttonGradient)
                                .clipShape(RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
                                .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
                        }
                        .padding(.horizontal, 24)

                        if let blockedMessage {
                            Text(blockedMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                            .shadow(color: BabyTownTheme.buttonShadow, radius: 10, y: 4)
                    )
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var profileCTATitle: String {
        if isFirstTimeVariant { return "Adopt" }
        return viewModel.ownedSkins.contains(selected) ? "Visit \(selected.petName)" : "Adopt"
    }

    private var selectionSubtitle: String {
        if isFirstTimeVariant {
            return "Each pet has their own room, pick who you'd like to adopt today!"
        }
        return "Each pet has their own room, pick who you'd like to visit today!"
    }

    private func close() {
        onDismiss()
    }

    private func tapProfileCTA() {
        let gate = viewModel.canAdopt(selected)
        guard gate.allowed else {
            blockedMessage = gate.reason
            return
        }
        if !viewModel.ownedSkins.contains(selected) {
            viewModel.adopt(selected)
        } else {
            viewModel.visit(selected)
        }
        blockedMessage = nil
        showingProfile = false
        onEnterPet(selected)
    }

    private func toggleSecondPetAdoptionBypassIfNeeded() {
        guard selected == .cowCat, !viewModel.ownedSkins.contains(.cowCat) else { return }
        let enabled = viewModel.toggleSecondPetAdoptionBypass()
        blockedMessage = nil
        if enabled {
            showToast("Secret mode: Arabella unlocked. Long-press the level pill again to undo.")
        } else {
            showToast("Secret mode undone. Level \(PetEconomy.secondPetUnlockLevel) required again.")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toast == message { withAnimation { toast = nil } }
        }
    }
}

private struct CatChoiceCard: View {
    let skin: CatSkin
    let isSelected: Bool
    let isOwned: Bool

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
                Text(isOwned ? "Owned" : "Available to adopt")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }
        }
        .padding(12)
        .background(BabyTownTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                .stroke(isSelected ? BabyTownTheme.accentDeep : Color.black.opacity(0.06),
                        lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: BabyTownTheme.cardShadow, radius: 6, y: 3)
        .scaleEffect(isSelected ? 1.0 : 0.97)
    }

    @ViewBuilder
    private var portrait: some View {
        // Reuse the same sitting photo asset as the profile card hero.
        if UIImage(named: skin.profileSitAsset) != nil {
            Image(skin.profileSitAsset)
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
        CatSelectionView(viewModel: PetViewModel(), onDismiss: {}, onEnterPet: { _ in })
    }
}
