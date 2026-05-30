import SwiftUI

struct PetMarketSheet: View {

    @ObservedObject var viewModel: PetViewModel
    var onFramePurchased: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: PetShopCategory = .furniture
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Category", selection: $category) {
                    ForEach(PetShopCategory.allCases) { cat in
                        Label(cat.title, systemImage: cat.systemImage).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(PetShopCatalog.items(in: category)) { item in
                            shopCard(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(BabyTownTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(BabyTownTheme.accentDeep)
                        Text("\(viewModel.coins)")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func shopCard(_ item: PetShopItem) -> some View {
        let owned = viewModel.ownsShopItem(item.id)
        let selected = viewModel.isShopItemSelected(item.id)
        let canAfford = viewModel.coins >= item.cost

        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)

                if item.isWallColor {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PetShopCatalog.wallColor(for: item.id))
                        .frame(height: 56)
                        .padding(12)
                } else if let imageName = item.imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)
                        .padding(10)
                } else {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 32))
                        .foregroundStyle(BabyTownTheme.accentIconGradient)
                }
            }
            .frame(height: 88)

            Text(item.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(item.detail)
                .font(.system(size: 11))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                purchase(item)
            } label: {
                Group {
                    if owned {
                        Text(selected ? "Selected" : "Select")
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "bitcoinsign.circle.fill")
                            Text("\(item.cost)")
                        }
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(
                        owned
                            ? (selected
                                ? AnyShapeStyle(Color.gray.opacity(0.45))
                                : AnyShapeStyle(BabyTownTheme.accentGradient))
                            : AnyShapeStyle(canAfford ? BabyTownTheme.accentGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                    )
                )
            }
            .disabled((owned && selected) || (!owned && !canAfford))
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }

    private func purchase(_ item: PetShopItem) {
        let wasOwned = viewModel.ownsShopItem(item.id)
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
        if item.isWallColor {
            showToast("Walls updated!")
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
