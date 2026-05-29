import SwiftUI
import Photos

struct PotentialMemoryCardView: View {
    let card: PotentialMemoryCard
    let onAdd: () -> Void
    
    @State private var showToast = false
    @State private var showingPhotoViewer = false
    private let imageManager = PHCachingImageManager()
    
    private var photoAssets: [PHAsset] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: card.assetIdentifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }
    
    private var coverPhotoIndex: Int {
        photoAssets.firstIndex(where: { $0.localIdentifier == card.coverAssetIdentifier }) ?? 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover photo
            Button {
                guard !photoAssets.isEmpty else { return }
                showingPhotoViewer = true
            } label: {
                Image(uiImage: card.coverPhoto)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            // Info section
            VStack(alignment: .leading, spacing: 6) {
                Text(card.locationName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(card.dateRangeDisplay)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                if !card.secondaryThumbnails.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(card.secondaryThumbnails.prefix(3).enumerated()), id: \.offset) { _, thumbnail in
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                
                Text("\(card.photoCount) photo\(card.photoCount == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Add button
            if !card.isAdded {
                Button(action: handleAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(BabyTownTheme.accentGradient)
                }
            } else {
                Text("Added")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .opacity(card.isAdded ? 0.6 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !card.isAdded {
                Button {
                    handleAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .tint(.green)
            }
        }
        .overlay {
            if showToast {
                ToastView(message: "Added to Our Adventures")
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showToast)
        .fullScreenCover(isPresented: $showingPhotoViewer) {
            FullScreenPhotoViewer(
                assets: photoAssets,
                initialIndex: coverPhotoIndex,
                imageManager: imageManager,
                onDismiss: { showingPhotoViewer = false }
            )
        }
    }
    
    private func handleAdd() {
        onAdd()
        
        withAnimation {
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.green.opacity(1))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            )
    }
}
