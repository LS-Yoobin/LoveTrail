import SwiftUI

struct PetMarketSheet: View {

    @ObservedObject var viewModel: PetViewModel
    /// Bound to the host so the last-viewed category is remembered across opens.
    @Binding var category: PetShopCategory
    var onFramePurchased: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?
    @State private var selectedDetailItem: PetShopItem?
    @State private var showsLevelRequirementAlert = false
    private static let transparentAssetCache = NSCache<NSString, UIImage>()
    private let autoLitterRequiredLevel = 20
    private let autoLitterLockedMessage = "Your pet must be lvl 20."

    init(
        viewModel: PetViewModel,
        category: Binding<PetShopCategory>,
        onFramePurchased: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self._category = category
        self.onFramePurchased = onFramePurchased
    }

    private let previewBoxHeight: CGFloat = 128
    private var orderedCategories: [PetShopCategory] {
        PetShopCategory.pickerCategories
    }

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
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    marketHero
                    categoryPicker

                    TabView(selection: $category) {
                        ForEach(orderedCategories) { cat in
                            categoryGrid(for: cat)
                                .tag(cat)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: category)
                }
                .background(marketBackground.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Market")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                    }
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
            .disabled(selectedDetailItem != nil)

            if let detailItem = selectedDetailItem {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { selectedDetailItem = nil }

                marketDetailModal(for: detailItem)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedDetailItem?.id)
        .alert("Market", isPresented: $showsLevelRequirementAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(autoLitterLockedMessage)
        }
    }

    private func marketDetailModal(for item: PetShopItem) -> some View {
        let owned = viewModel.ownsShopItem(item.id)
        let selected = viewModel.isShopItemSelected(item.id)
        let canAfford = viewModel.coins >= item.cost
        let isAutoLitterLocked = item.isAutoLitter && !owned && viewModel.smartMeterLevel < autoLitterRequiredLevel
        let isCatFood = item.isCatFood

        return VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BabyTownTheme.accentIconBackdropGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                    )

                previewContent(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Button {
                    selectedDetailItem = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .padding(10)

                if isCatFood {
                    Text("x\(viewModel.foodServings)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(BabyTownTheme.accentDeep)
                                .shadow(color: BabyTownTheme.buttonShadow.opacity(0.6), radius: 4, y: 2)
                        )
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if owned {
                    Text(selected ? "Active" : "Owned")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selected ? BabyTownTheme.accentDeep : Color.black.opacity(0.42))
                        )
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(height: 240)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text(item.detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)

                if isAutoLitterLocked {
                    Text("Requires pet level \(autoLitterRequiredLevel)+ to purchase.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(BabyTownTheme.accentSoft.opacity(0.5))
                        )
                }
            }

            if isCatFood {
                catFoodPurchaseButton(item: item, canAfford: canAfford)
            } else {
                detailPurchaseButton(
                    item: item,
                    owned: owned,
                    selected: selected,
                    canAfford: canAfford,
                    isAutoLitterLocked: isAutoLitterLocked
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: BabyTownTheme.accent.opacity(selected && !isCatFood ? 0.18 : 0.12), radius: 16, y: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    selected && !isCatFood ? BabyTownTheme.accent.opacity(0.45) : BabyTownTheme.accent.opacity(0.12),
                    lineWidth: selected && !isCatFood ? 2 : 1
                )
        }
        .frame(maxWidth: 360)
    }

    // MARK: - Header

    private var marketHero: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spruce up the room")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text("Spend coins on trees, beds, bowls, cat food, toys, and room décor.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 96)

            PetCoinBalancePill(coins: viewModel.coins)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1.2)
                        .onEnded { _ in
                            toggleHiddenUnlockAll()
                        }
                )
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
                    ForEach(orderedCategories) { cat in
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
        let isAutoLitterLocked = item.isAutoLitter && !owned && viewModel.smartMeterLevel < autoLitterRequiredLevel

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

                if isCatFood {
                    Text("x\(viewModel.foodServings)")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(BabyTownTheme.accentDeep)
                                .shadow(color: BabyTownTheme.buttonShadow.opacity(0.6), radius: 4, y: 2)
                        )
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

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
            .contentShape(Rectangle())
            .onTapGesture {
                selectedDetailItem = item
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDetailItem = item
                    }

                Text(item.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDetailItem = item
                    }
            }

            if isCatFood {
                catFoodPurchaseButton(item: item, canAfford: canAfford)
            } else {
                purchaseButton(
                    item: item,
                    owned: owned,
                    selected: selected,
                    canAfford: canAfford,
                    isAutoLitterLocked: isAutoLitterLocked
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
    private func detailPurchaseButton(
        item: PetShopItem,
        owned: Bool,
        selected: Bool,
        canAfford: Bool,
        isAutoLitterLocked: Bool
    ) -> some View {
        let isDisabled = (owned && selected) || (!owned && !canAfford && !isAutoLitterLocked)

        Button {
            purchase(item)
        } label: {
            Group {
                if selected {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                } else if owned {
                    Label("Select", systemImage: "hand.tap.fill")
                } else if item.cost == 0 {
                    Label("Free", systemImage: "gift.fill")
                } else if canAfford {
                    Label("Purchase · \(item.cost)", systemImage: "bitcoinsign.circle.fill")
                } else {
                    Label("Need \(item.cost - viewModel.coins) more", systemImage: "lock.fill")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(buttonForeground(owned: owned, selected: selected, canAfford: canAfford))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(buttonBackground(owned: owned, selected: selected, canAfford: canAfford))
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func purchaseButton(
        item: PetShopItem,
        owned: Bool,
        selected: Bool,
        canAfford: Bool,
        isAutoLitterLocked: Bool = false
    ) -> some View {
        let isDisabled = (owned && selected) || (!owned && !canAfford && !isAutoLitterLocked)

        Button {
            purchase(item)
        } label: {
            Group {
                if selected {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                } else if owned {
                    Label("Select", systemImage: "hand.tap.fill")
                } else if item.cost == 0 {
                    Label("Free", systemImage: "gift.fill")
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
        .disabled(isDisabled)
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
            if reason == autoLitterLockedMessage {
                showsLevelRequirementAlert = true
            } else {
                showToast(reason)
            }
            return
        }
        if outcome.openFramePicker {
            selectedDetailItem = nil
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFramePurchased()
            }
            return
        }
        selectedDetailItem = nil
        if let servings = item.servingsGranted {
            let label = servings == 1 ? "serving" : "servings"
            showToast("Added \(servings) \(label) to your pantry!")
        } else if item.isPlayToy {
            showToast(wasOwned ? "Toy selected!" : "Added to your toy bar!")
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

    private func toggleHiddenUnlockAll() {
        let enabled = viewModel.toggleMarketUnlockAllPurchases()
        if enabled {
            showToast("Secret mode: unlocked all market items. Long-press again to undo.")
        } else {
            showToast("Secret mode undone. Restored your previous market state.")
        }
    }
}
