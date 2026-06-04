import SwiftUI

/// Inventory sheet opened from the pet-room coin pill — same layout language as the
/// Market, but only lists décor the user owns.
struct PetOwnedItemsSheet: View {

    @ObservedObject var viewModel: PetViewModel
    /// Bound to the host so the last-viewed category is remembered across opens.
    @Binding var category: PetShopCategory
    var onFrameEquipped: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?
    private static let transparentAssetCache = NSCache<NSString, UIImage>()

    init(
        viewModel: PetViewModel,
        category: Binding<PetShopCategory>,
        onFrameEquipped: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self._category = category
        self.onFrameEquipped = onFrameEquipped
    }

    private let previewBoxHeight: CGFloat = 128

    private var availableCategories: [PetShopCategory] {
        viewModel.ownedItemCategories
    }

    private var sheetBackground: LinearGradient {
        LinearGradient(
            colors: [
                BabyTownTheme.cardTintLight,
                BabyTownTheme.cardTintDeep,
                BabyTownTheme.cardTintDeep,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

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
        } else if item.category == .litterBoxes,
                  let sheet = item.imageName,
                  let clean = PetShopCatalog.litterCleanCrop(sheetName: sheet) {
            // Litter `imageName`s are 6-frame sheets; show just the clean box.
            Image(uiImage: clean)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
        } else if let imageName = item.imageName, UIImage(named: imageName) != nil {
            assetImage(name: imageName)
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
        if item.isPlayToy {
            showToast("Toy selected!")
        } else if item.isWallColor {
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
        // Keep the remembered category if it still has owned items; otherwise
        // fall back to the first available one.
        if availableCategories.contains(category) { return }
        category = availableCategories[0]
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toast == message { withAnimation { toast = nil } }
        }
    }

    private func assetImage(name: String) -> Image {
        if let processed = processedAssetImage(named: name) {
            return Image(uiImage: processed)
        }
        return Image(name)
    }

    private func processedAssetImage(named name: String) -> UIImage? {
        let key = NSString(string: name)
        if let cached = Self.transparentAssetCache.object(forKey: key) {
            return cached
        }
        guard let original = UIImage(named: name) else { return nil }
        let processed = removeBlackMatteIfNeeded(from: original)
        Self.transparentAssetCache.setObject(processed, forKey: key)
        return processed
    }

    /// Detects PNGs with opaque black matte and converts that matte to alpha.
    private func removeBlackMatteIfNeeded(from image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = cg.width
        let height = cg.height
        guard width > 1, height > 1 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isNearBlack(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool {
            r <= 24 && g <= 24 && b <= 24
        }

        var borderOpaque = 0
        var borderBlack = 0
        for x in stride(from: 0, to: width, by: max(1, width / 80)) {
            for y in [0, height - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaque += 1
                    if isNearBlack(r, g, b) { borderBlack += 1 }
                }
            }
        }
        for y in stride(from: 0, to: height, by: max(1, height / 80)) {
            for x in [0, width - 1] {
                let i = (y * width + x) * bytesPerPixel
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                if a > 220 {
                    borderOpaque += 1
                    if isNearBlack(r, g, b) { borderBlack += 1 }
                }
            }
        }

        guard borderOpaque > 0 else { return image }
        let borderBlackRatio = Double(borderBlack) / Double(borderOpaque)
        guard borderBlackRatio >= 0.80 else { return image }

        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
            if a >= 245 && isNearBlack(r, g, b) {
                pixels[i + 3] = 0
            }
        }

        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }
}
