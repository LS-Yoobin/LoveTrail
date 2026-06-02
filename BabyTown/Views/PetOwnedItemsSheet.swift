import SwiftUI

/// Inventory sheet opened from the pet-room coin pill — same layout language as the
/// Market, but only lists décor the user owns.
struct PetOwnedItemsSheet: View {

    @ObservedObject var viewModel: PetViewModel
    var initialCategory: PetShopCategory
    var onFrameEquipped: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: PetShopCategory
    @State private var toast: String?

    init(
        viewModel: PetViewModel,
        initialCategory: PetShopCategory = .catTrees,
        onFrameEquipped: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.initialCategory = initialCategory
        self.onFrameEquipped = onFrameEquipped
        _category = State(initialValue: initialCategory)
    }

    private let previewBoxHeight: CGFloat = 128

    private var availableCategories: [PetShopCategory] {
        viewModel.ownedItemCategories
    }

    private let sheetBackground = LinearGradient(
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
            Group {
                if viewModel.hasOwnedShopItems {
                    inventoryContent
                } else {
                    emptyState
                }
            }
            .background(sheetBackground.ignoresSafeArea())
            .navigationTitle("My Items")
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
            .onAppear {
                syncCategorySelection()
            }
            .onChange(of: viewModel.ownedItemCategories) { _, _ in
                syncCategorySelection()
            }
        }
    }

    private var inventoryContent: some View {
        VStack(spacing: 0) {
            inventoryHero
            categoryPicker

            TabView(selection: $category) {
                ForEach(availableCategories) { cat in
                    categoryGrid(for: cat)
                        .tag(cat)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: category)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            PetCoinIcon(size: 48)

            Text("No items yet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.88))

            Text("Buy trees, beds, bowls, and décor in the Market. Anything you own will show up here so you can equip it or bring stashed pieces back.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Header

    private var inventoryHero: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your room items")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text("Equip trees, beds, bowls, and décor you own. Tap Select on stashed pieces to place them back in the room.")
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
                    ForEach(availableCategories) { cat in
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
                ForEach(viewModel.ownedInventoryItems(in: category)) { item in
                    ownedCard(item)
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

    // MARK: - Cards

    @ViewBuilder
    private func ownedCard(_ item: PetShopItem) -> some View {
        let selected = viewModel.isShopItemSelected(item.id)
        let stashed = viewModel.isShopItemStashed(item.id)

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

                Text(statusLabel(selected: selected, stashed: stashed))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor(selected: selected, stashed: stashed))
                    )
                    .padding(8)
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

            selectButton(item: item, selected: selected)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: BabyTownTheme.accent.opacity(selected ? 0.18 : 0.08), radius: selected ? 12 : 8, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    selected ? BabyTownTheme.accent.opacity(0.45) : BabyTownTheme.accent.opacity(0.12),
                    lineWidth: selected ? 2 : 1
                )
        }
    }

    private func statusLabel(selected: Bool, stashed: Bool) -> String {
        if stashed { return "Stashed" }
        if selected { return "Active" }
        return "Owned"
    }

    private func statusColor(selected: Bool, stashed: Bool) -> Color {
        if stashed { return Color.black.opacity(0.42) }
        if selected { return BabyTownTheme.accentDeep }
        return Color.black.opacity(0.42)
    }

    private func selectButton(item: PetShopItem, selected: Bool) -> some View {
        Button {
            equip(item)
        } label: {
            Label(selected ? "Selected" : "Select", systemImage: selected ? "checkmark.circle.fill" : "hand.tap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? BabyTownTheme.accentDeep.opacity(0.55) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if selected {
                        Capsule().fill(BabyTownTheme.accentSoft)
                    } else {
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                            .shadow(color: BabyTownTheme.buttonShadow, radius: 6, y: 2)
                    }
                }
        }
        .disabled(selected)
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

    private func previewImageOffset(for item: PetShopItem) -> CGSize {
        switch item.equipSlot {
        case .foodBowl, .waterBowl:
            return CGSize(width: -14, height: 0)
        default:
            return .zero
        }
    }

    // MARK: - Actions

    private func equip(_ item: PetShopItem) {
        let wasStashed = viewModel.isShopItemStashed(item.id)
        let outcome = viewModel.purchaseShopItem(item.id)
        if let reason = outcome.result.blockedReason {
            showToast(reason)
            return
        }
        if outcome.openFramePicker {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFrameEquipped()
            }
            return
        }
        if item.isWallColor {
            showToast("Walls updated!")
        } else if item.equipSlot != nil {
            showToast("Equipped!")
        } else if wasStashed {
            showToast("Back in your room!")
        } else {
            showToast("Updated!")
        }
    }

    private func syncCategorySelection() {
        guard !availableCategories.isEmpty else { return }
        if availableCategories.contains(category) { return }
        if availableCategories.contains(initialCategory) {
            category = initialCategory
        } else {
            category = availableCategories[0]
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toast == message { withAnimation { toast = nil } }
        }
    }
}
