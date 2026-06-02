import SwiftUI

struct PetMarketSheet: View {

    @ObservedObject var viewModel: PetViewModel
    var initialCategory: PetShopCategory
    var onFramePurchased: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: PetShopCategory
    @State private var toast: String?

    init(
        viewModel: PetViewModel,
        initialCategory: PetShopCategory = .catTrees,
        onFramePurchased: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.initialCategory = initialCategory
        self.onFramePurchased = onFramePurchased
        _category = State(initialValue: initialCategory)
    }

    private let previewBoxHeight: CGFloat = 128

    private let marketBackground = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 0.99, green: 0.94, blue: 0.96),
            Color(red: 0.98, green: 0.88, blue: 0.91),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                marketHero
                categoryPicker

                TabView(selection: $category) {
                    ForEach(PetShopCategory.allCases) { cat in
                        categoryGrid(for: cat)
                            .tag(cat)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: category)
            }
            .background(marketBackground.ignoresSafeArea())
            .navigationTitle("Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep)
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
    }

    // MARK: - Header

    private var marketHero: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spruce up the room")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text("Spend coins on trees, beds, bowls, cat food, collars, and room décor.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 96)

            PetCoinBalancePill(coins: viewModel.coins)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Categories

    private var categoryPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PetShopCategory.allCases) { cat in
                        categoryPill(cat)
                            .id(cat)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .onChange(of: category) { _, new in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func categoryGrid(for category: PetShopCategory) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(PetShopCatalog.items(in: category)) { item in
                    shopCard(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
    }

    private func categoryPill(_ cat: PetShopCategory) -> some View {
        let isSelected = category == cat

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                category = cat
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(cat.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : BabyTownTheme.accentDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                        .shadow(color: BabyTownTheme.buttonShadow, radius: 6, y: 2)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .overlay(
                            Capsule()
                                .strokeBorder(BabyTownTheme.accent.opacity(0.2), lineWidth: 1.5)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shop cards

    @ViewBuilder
    private func shopCard(_ item: PetShopItem) -> some View {
        let owned = viewModel.ownsShopItem(item.id)
        let selected = viewModel.isShopItemSelected(item.id)
        let canAfford = viewModel.coins >= item.cost
        let isCatFood = item.isCatFood

        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BabyTownTheme.accentIconBackdropGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                    )

                previewContent(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if owned, !isCatFood {
                    Text(selected ? "Active" : "Owned")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selected ? BabyTownTheme.accentDeep : Color.black.opacity(0.42))
                        )
                        .padding(8)
                }
            }
            .frame(height: previewBoxHeight)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(item.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isCatFood {
                catFoodPurchaseButton(item: item, canAfford: canAfford)
            } else {
                purchaseButton(
                    item: item,
                    owned: owned,
                    selected: selected,
                    canAfford: canAfford
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: BabyTownTheme.accent.opacity(selected && !isCatFood ? 0.18 : 0.08), radius: selected && !isCatFood ? 12 : 8, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    selected && !isCatFood ? BabyTownTheme.accent.opacity(0.45) : BabyTownTheme.accent.opacity(0.12),
                    lineWidth: selected && !isCatFood ? 2 : 1
                )
        }
    }

    private func catFoodPurchaseButton(item: PetShopItem, canAfford: Bool) -> some View {
        Button {
            purchase(item)
        } label: {
            Group {
                if canAfford {
                    Label("Buy · \(item.cost)", systemImage: "bitcoinsign.circle.fill")
                } else {
                    Label("Need \(item.cost - viewModel.coins) more", systemImage: "lock.fill")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(canAfford ? .white : Color.black.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if canAfford {
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                        .shadow(color: BabyTownTheme.buttonShadow, radius: 6, y: 2)
                } else {
                    Capsule()
                        .fill(BabyTownTheme.cardBackground.opacity(0.55))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
            }
        }
        .disabled(!canAfford)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func previewContent(for item: PetShopItem) -> some View {
        if item.isWallColor {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PetShopCatalog.wallColor(for: item.id))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .padding(18)
        } else if let imageName = item.imageName, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
                .offset(previewImageOffset(for: item))
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(BabyTownTheme.accentIconGradient)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Offsets preview art when assets sit off-center inside their image bounds.
    private func previewImageOffset(for item: PetShopItem) -> CGSize {
        switch item.equipSlot {
        case .foodBowl, .waterBowl:
            return CGSize(width: -14, height: 0)
        default:
            return .zero
        }
    }

    @ViewBuilder
    private func purchaseButton(
        item: PetShopItem,
        owned: Bool,
        selected: Bool,
        canAfford: Bool
    ) -> some View {
        Button {
            purchase(item)
        } label: {
            Group {
                if owned {
                    Label(selected ? "Selected" : "Select", systemImage: selected ? "checkmark.circle.fill" : "hand.tap.fill")
                } else if canAfford {
                    Label("\(item.cost)", systemImage: "bitcoinsign.circle.fill")
                } else {
                    Label("Need \(item.cost - viewModel.coins) more", systemImage: "lock.fill")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(buttonForeground(owned: owned, selected: selected, canAfford: canAfford))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(buttonBackground(owned: owned, selected: selected, canAfford: canAfford))
        }
        .disabled((owned && selected) || (!owned && !canAfford))
        .buttonStyle(.plain)
    }

    private func buttonForeground(owned: Bool, selected: Bool, canAfford: Bool) -> Color {
        if owned {
            return selected ? BabyTownTheme.accentDeep.opacity(0.55) : .white
        }
        return canAfford ? .white : Color.black.opacity(0.45)
    }

    @ViewBuilder
    private func buttonBackground(owned: Bool, selected: Bool, canAfford: Bool) -> some View {
        if owned {
            if selected {
                Capsule().fill(BabyTownTheme.accentSoft)
            } else {
                Capsule().fill(BabyTownTheme.accentGradient)
            }
        } else if canAfford {
            Capsule()
                .fill(BabyTownTheme.accentGradient)
                .shadow(color: BabyTownTheme.buttonShadow, radius: 6, y: 2)
        } else {
            Capsule()
                .fill(BabyTownTheme.cardBackground.opacity(0.55))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func purchase(_ item: PetShopItem) {
        let wasOwned = viewModel.ownsShopItem(item.id)
        let wasStashed = viewModel.isShopItemStashed(item.id)
        let outcome = viewModel.purchaseShopItem(item.id)
        if let reason = outcome.result.blockedReason {
            showToast(reason)
            return
        }
        if outcome.openFramePicker {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFramePurchased()
            }
            return
        }
        if let servings = item.servingsGranted {
            let label = servings == 1 ? "serving" : "servings"
            showToast("Added \(servings) \(label) to your pantry!")
        } else if item.isWallColor {
            showToast("Walls updated!")
        } else if item.equipSlot != nil {
            showToast("Equipped!")
        } else if wasStashed {
            showToast("Back in your room!")
        } else if !wasOwned {
            showToast("Added to your room!")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toast == message { withAnimation { toast = nil } }
        }
    }
}
