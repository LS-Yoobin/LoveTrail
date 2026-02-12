import SwiftUI
import Photos

struct PromptPhotoSelectionView: View {
    
    @StateObject private var viewModel = SelectPhotosViewModel()
    
    var onBack: () -> Void
    var onSavePhotos: ([PromptPhoto]) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private let monthSymbols = Calendar.current.shortMonthSymbols
    
    var body: some View {
        ZStack {
            BabyTownTheme.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                yearChips
                monthChips
                
                Divider().padding(.horizontal, 20)
                
                content
            }
            
            if let index = viewModel.viewerIndex {
                FullScreenPhotoViewer(
                    assets: viewModel.assets,
                    initialIndex: index,
                    imageManager: viewModel.imageManager
                ) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        viewModel.viewerIndex = nil
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
            
            if viewModel.selectionMode && viewModel.selectedCount > 0 {
                VStack {
                    Spacer()
                    saveButton
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.viewerIndex != nil)
        .task {
            await viewModel.checkAuthorization()
            viewModel.selectionMode = true
        }
        .onChange(of: viewModel.selectedYear) { _, _ in
            Task { await viewModel.fetchAssets() }
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            Task { await viewModel.fetchAssets() }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(BabyTownTheme.accent)
                }
                
                Spacer()
            }
            
            VStack(spacing: 2) {
                Text("Select Photos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                
                if viewModel.selectedCount > 0 {
                    Text("\(viewModel.selectedCount) selected")
                        .font(.system(size: 11))
                        .foregroundStyle(BabyTownTheme.accent)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(BabyTownTheme.background)
    }
    
    // MARK: - Year Chips
    
    private var yearChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedYear = year
                        }
                    } label: {
                        Text(String(year))
                            .font(.system(size: 14, weight: viewModel.selectedYear == year ? .semibold : .regular))
                            .foregroundStyle(viewModel.selectedYear == year ? .white : BabyTownTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedYear == year ? BabyTownTheme.accentGradient : LinearGradient(colors: [Color(.systemGray6)], startPoint: .leading, endPoint: .trailing))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Month Chips
    
    private var monthChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedMonth = month
                        }
                    } label: {
                        Text(monthSymbols[month - 1])
                            .font(.system(size: 13, weight: viewModel.selectedMonth == month ? .semibold : .regular))
                            .foregroundStyle(viewModel.selectedMonth == month ? .white : BabyTownTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedMonth == month ? BabyTownTheme.accentGradient : LinearGradient(colors: [Color(.systemGray6)], startPoint: .leading, endPoint: .trailing))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
            deniedState
        } else if viewModel.isLoading {
            loadingState
        } else if viewModel.assets.isEmpty {
            emptyState
        } else {
            photoGrid
        }
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(
                    Array(viewModel.assets.enumerated()),
                    id: \.element.localIdentifier
                ) { index, asset in
                    PhotoGridCell(
                        thumbnail: viewModel.thumbnails[asset.localIdentifier],
                        isSelected: viewModel.selectedAssets.contains(asset.localIdentifier),
                        selectionMode: viewModel.selectionMode
                    ) {
                        if viewModel.selectionMode {
                            viewModel.toggleSelection(asset)
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.viewerIndex = index
                            }
                        }
                    }
                    .onAppear {
                        viewModel.loadThumbnail(for: asset)
                    }
                }
            }
            .padding(2)
            .padding(.bottom, viewModel.selectedCount > 0 ? 100 : 0)
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            Task {
                let promptPhotos = await convertToPromptPhotos()
                onSavePhotos(promptPhotos)
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text("Continue (\(viewModel.selectedCount))")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(BabyTownTheme.accentGradient)
                    .shadow(color: BabyTownTheme.accent.opacity(0.4), radius: 12, y: 6)
            )
        }
        .disabled(viewModel.isSaving)
        .padding(.bottom, 40)
    }
    
    // MARK: - States
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(BabyTownTheme.accent)
            Text("Loading photos...")
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.textTertiary)
            Text("No photos for this period")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var deniedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.accent)
            
            VStack(spacing: 8) {
                Text("Photos Access Required")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                
                Text("Please enable photo access in Settings to select photos for your memory.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Helpers
    
    private func convertToPromptPhotos() async -> [PromptPhoto] {
        var promptPhotos: [PromptPhoto] = []
        
        for assetId in viewModel.selectedAssets {
            if let asset = viewModel.assets.first(where: { $0.localIdentifier == assetId }) {
                let image = await loadFullImage(for: asset)
                if let image = image {
                    let photo = PromptPhoto(
                        dateTaken: asset.creationDate ?? Date(),
                        thumbnail: image,
                        assetIdentifier: assetId
                    )
                    promptPhotos.append(photo)
                }
            }
        }
        
        return promptPhotos.sorted { $0.dateTaken > $1.dateTaken }
    }
    
    private func loadFullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            viewModel.imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 1000, height: 1000),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
