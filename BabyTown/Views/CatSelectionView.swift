import SwiftUI

struct CatSelectionView: View {
    @ObservedObject var viewModel: PetViewModel
    @ObservedObject private var store = StoreManager.shared
    var onDismiss: () -> Void
    var onEnterPet: (CatSkin) -> Void

    @State private var selected: CatSkin = .calico
    @State private var showingProfile = false
    @State private var showForeverPaywall = false
    @State private var blockedMessage: String?
    @State private var toast: String?

    private var isFirstTimeVariant: Bool {
        !viewModel.hasAnyOwnedPet
    }

    var body: some View {
        selectionContent
            .background(BabyTownTheme.background.ignoresSafeArea())
            .toolbar { toolbarContent }
            .overlay { profileOverlay }
            .overlay(alignment: .bottom) { toastOverlay }
            .fullScreenCover(isPresented: $showForeverPaywall) { foreverPaywall }
    }

    private var selectionContent: some View {
        ScrollView(showsIndicators: false) {
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

                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach([CatSkin.calico, .cowCat]) { skin in
                            catChoiceCard(for: skin)
                        }
                    }
                    HStack {
                        Spacer(minLength: 0)
                        catChoiceCard(for: .bombay)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: close) {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private var profileOverlay: some View {
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
                        onLevelLongPress: toggleSecondPetAdoptionBypassIfNeeded,
                        onCardLongPress: premiumPetBypassHandler
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

    @ViewBuilder
    private var toastOverlay: some View {
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

    private var foreverPaywall: some View {
        CovelaForeverPaywallView(
            store: store,
            onUnlock: { showForeverPaywall = false },
            onDismiss: { showForeverPaywall = false }
        )
    }

    private var premiumPetBypassHandler: (() -> Void)? {
        guard selected == .bombay else { return nil }
        return togglePremiumPetBypassIfNeeded
    }

    private var profileCTATitle: String {
        if viewModel.ownedSkins.contains(selected) {
            return "Visit \(selected.petName)"
        }
        if viewModel.isPremiumPetLocked(selected, isForeverUnlocked: store.isForeverUnlocked) {
            return "Unlock"
        }
        if isFirstTimeVariant { return "Adopt" }
        return "Adopt"
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
        if viewModel.isPremiumPetLocked(selected, isForeverUnlocked: store.isForeverUnlocked) {
            showForeverPaywall = true
            return
        }

        let gate = viewModel.canAdopt(selected, isForeverUnlocked: store.isForeverUnlocked)
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
        guard viewModel.ownedSkins.count == 1, let owned = viewModel.ownedSkins.first else { return }
        let viewingUnownedFreeSecond = !viewModel.ownedSkins.contains(selected) && !selected.requiresForeverUnlock
        let viewingOwnedOnlyPet = selected == owned
        guard viewingUnownedFreeSecond || viewingOwnedOnlyPet else { return }

        let enabled = viewModel.toggleSecondPetAdoptionBypass()
        blockedMessage = nil
        if enabled {
            let lockedName = CatSkin.allCases
                .first { !viewModel.ownedSkins.contains($0) && !$0.requiresForeverUnlock }?
                .petName ?? "second pet"
            showToast("Secret mode: \(lockedName) unlocked. Long-press the level pill again to undo.")
        } else {
            showToast("Secret mode undone. Level \(PetEconomy.secondPetUnlockLevel) required again.")
        }
    }

    private func togglePremiumPetBypassIfNeeded() {
        guard selected == .bombay else { return }
        let enabled = viewModel.togglePremiumPetBypass()
        blockedMessage = nil
        if enabled {
            showToast("Secret mode: Spunky unlocked. Long-press the profile card again to undo.")
        } else {
            showToast("Secret mode undone. Covela Forever required again.")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toast == message { withAnimation { toast = nil } }
        }
    }

    private func catChoiceCard(for skin: CatSkin) -> some View {
        CatChoiceCard(
            skin: skin,
            isSelected: showingProfile && skin == selected,
            isOwned: viewModel.ownedSkins.contains(skin),
            isLocked: viewModel.isPremiumPetLocked(skin, isForeverUnlocked: store.isForeverUnlocked)
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

private struct CatChoiceCard: View {
    let skin: CatSkin
    let isSelected: Bool
    let isOwned: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                portrait
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .background(BabyTownTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(BabyTownTheme.accentDeep.opacity(0.92), in: Circle())
                        .padding(8)
                }
            }

            VStack(spacing: 2) {
                Text(skin.petName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                Text(skin.breedName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.38))
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isLocked ? Color(red: 0.45, green: 0.45, blue: 0.48) : BabyTownTheme.accentDeep)
            }
        }
        .frame(width: 148)
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
        .opacity(isLocked ? 0.92 : 1)
    }

    private var statusLabel: String {
        if isOwned { return "Owned" }
        if isLocked { return "Locked" }
        return "Available to adopt"
    }

    @ViewBuilder
    private var portrait: some View {
        if UIImage(named: skin.profileSitAsset) != nil {
            Image(skin.profileSitAsset)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
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
