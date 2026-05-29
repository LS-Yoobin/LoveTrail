import SwiftUI
import Photos
import PhotosUI

struct SelectPhotosView: View {

    @StateObject private var viewModel = SelectPhotosViewModel()
    @State private var showAnimation = false
    @State private var photoSelectedInViewer = false
    @State private var showPromptMemoryBuilder = false
    @State private var selectedPhotosForPrompt: [PromptPhoto] = []
    @State private var showSystemGallery = false
    
    var selectedPrompt: PromptItem?
    var onBack: () -> Void
    var onSaveMoments: ([Moment]) -> Void
    var onSavePromptMemory: ((PromptMemory) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private let monthSymbols = Calendar.current.shortMonthSymbols

    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                
                if let prompt = selectedPrompt {
                    promptDisplay(prompt: prompt)
                }
                
                yearChips
                monthChips

                Divider().padding(.horizontal, 20)

                content

                bottomActionBar
            }

            // Full-screen viewer
            if let index = viewModel.viewerIndex {
                FullScreenPhotoViewer(
                    assets: viewModel.assets,
                    initialIndex: index,
                    imageManager: viewModel.imageManager,
                    selectedAssets: viewModel.selectedAssets,
                    onToggleSelection: { asset in
                        viewModel.toggleSelection(asset)
                        photoSelectedInViewer = true
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            viewModel.viewerIndex = nil
                            if photoSelectedInViewer && !viewModel.selectionMode {
                                viewModel.selectionMode = true
                                photoSelectedInViewer = false
                            }
                        }
                    },
                    promptText: selectedPrompt?.text
                )
                .transition(.opacity)
                .zIndex(1)
            }
            
            // Heart Animation Overlay
            if showAnimation {
                HeartSaveAnimationOverlay {
                    onBack()
                }
                .zIndex(3)
            }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.viewerIndex != nil)
        .task {
            await viewModel.checkAuthorization()
        }
        .onChange(of: viewModel.selectedYear) { _, _ in
            Task { await viewModel.fetchAssets() }
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            Task { await viewModel.fetchAssets() }
        }
        .sheet(isPresented: $showSystemGallery) {
            PhotoPickerView(
                selectedImages: .constant([]),
                selectionLimit: 0,
                onFinish: { results in
                    Task { await handleSystemGalleryPicks(results) }
                }
            )
        }
        .navigationDestination(isPresented: $showPromptMemoryBuilder) {
            if let prompt = selectedPrompt {
                PromptMemoryBuilderView(
                    promptText: prompt.text,
                    onSave: { memory in
                        onSavePromptMemory?(memory)
                        showAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            onBack()
                        }
                    },
                    preSelectedPhotos: selectedPhotosForPrompt
                )
                .navigationBarBackButtonHidden(true)
            }
        }
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

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectionMode.toggle()
                        if !viewModel.selectionMode {
                            viewModel.selectedAssets.removeAll()
                        }
                    }
                } label: {
                    Text(viewModel.selectionMode ? "Cancel" : "Select")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.selectionMode ? BabyTownTheme.accentGradient : LinearGradient(colors: [.blue], startPoint: .leading, endPoint: .trailing))
                        )
                }
            }

            VStack(spacing: 2) {
                Text("Select Photos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                if viewModel.selectionMode && viewModel.selectedCount > 0 {
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableYears, id: \.self) { year in
                        chipButton(
                            label: String(year),
                            isActive: viewModel.selectedYear == year
                        ) {
                            viewModel.selectedYear = year
                        }
                        .id(year)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)
            .onAppear {
                proxy.scrollTo(viewModel.selectedYear, anchor: .center)
            }
        }
    }

    // MARK: - Month Chips

    private var monthChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableMonths, id: \.self) { month in
                        chipButton(
                            label: monthSymbols[month - 1],
                            isActive: viewModel.selectedMonth == month
                        ) {
                            viewModel.selectedMonth = month
                        }
                        .id(month)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 10)
            .onAppear {
                proxy.scrollTo(viewModel.selectedMonth, anchor: .center)
            }
        }
    }

    // MARK: - Chip

    private func chipButton(
        label: String,
        isActive: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(
                    isActive
                        ? .white
                        : (isEnabled ? BabyTownTheme.textPrimary : BabyTownTheme.textTertiary)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isActive
                                ? AnyShapeStyle(BabyTownTheme.accentGradient)
                                : AnyShapeStyle(
                                    isEnabled
                                        ? BabyTownTheme.accentSoft
                                        : Color(.systemGray5)
                                )
                        )
                )
                .opacity(isEnabled ? 1 : 0.55)
        }
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.authorizationStatus == .denied
            || viewModel.authorizationStatus == .restricted {
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
            .padding(.bottom, gridBottomPadding)
        }
    }

    private var gridBottomPadding: CGFloat { 16 }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        Group {
            if viewModel.selectionMode {
                saveBarButton
            } else {
                openGalleryBarButton
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectionMode)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            BabyTownTheme.background
                .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
        )
    }

    private var openGalleryBarButton: some View {
        Button {
            showSystemGallery = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 17, weight: .semibold))
                Text("Open Gallery")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(BabyTownTheme.accentGradient)
                    .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 6)
            )
        }
    }

    private var saveBarButton: some View {
        Button {
            performSave()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(viewModel.selectedCount > 0 ? "Save (\(viewModel.selectedCount))" : "Save")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [.blue], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: Color.blue.opacity(0.35), radius: 12, y: 6)
            )
        }
        .disabled(viewModel.isSaving || viewModel.selectedCount == 0)
        .opacity(viewModel.selectedCount == 0 ? 0.5 : 1)
    }

    private func handleSystemGalleryPicks(_ results: [PHPickerResult]) async {
        guard !results.isEmpty else { return }

        if let prompt = selectedPrompt {
            let promptPhotos = await viewModel.createPromptPhotosFromPickerResults(results)
            guard !promptPhotos.isEmpty else { return }

            let memoryDate = promptPhotos.map(\.dateTaken).min() ?? Date()
            let memory = PromptMemory(
                promptText: prompt.text,
                date: memoryDate,
                placeName: nil,
                loveNote: "",
                photos: promptPhotos
            )
            onSavePromptMemory?(memory)
            withAnimation(.easeIn(duration: 0.2)) {
                showAnimation = true
            }
        } else {
            let moments = await viewModel.createMomentsFromPickerResults(results)
            guard !moments.isEmpty else { return }
            onSaveMoments(moments)
            withAnimation(.easeIn(duration: 0.2)) {
                showAnimation = true
            }
        }
    }
    
    private func performSave() {
        Task {
            if let prompt = selectedPrompt {
                let promptPhotos = await viewModel.convertToPromptPhotos()
                let memoryDate = promptPhotos.map { $0.dateTaken }.min() ?? Date()
                let memory = PromptMemory(
                    promptText: prompt.text,
                    date: memoryDate,
                    placeName: nil,
                    loveNote: "",
                    photos: promptPhotos
                )
                onSavePromptMemory?(memory)
                withAnimation(.easeIn(duration: 0.2)) {
                    showAnimation = true
                }
            } else {
                let moments = await viewModel.saveMoments()
                onSaveMoments(moments)
                withAnimation(.easeIn(duration: 0.2)) {
                    showAnimation = true
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(BabyTownTheme.accent)
                .scaleEffect(1.1)
            Text("Loading photos…")
                .font(.system(size: 13))
                .foregroundStyle(BabyTownTheme.textTertiary)
                .padding(.top, 10)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 38, weight: .thin))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.3))
            Text("No photos this month")
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.textSecondary)
            Text("Try a different month or year")
                .font(.system(size: 13))
                .foregroundStyle(BabyTownTheme.textTertiary)
            Spacer()
        }
    }

    private var deniedState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 38, weight: .thin))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
            Text("Photo Access Needed")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Text("Allow photo access in Settings\nso we can build your timeline.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(BabyTownTheme.accentGradient))
            }
            .padding(.top, 4)
            Spacer()
        }
    }
    
    // MARK: - Prompt Display
    
    private func promptDisplay(prompt: PromptItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(prompt.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.3, blue: 0.35))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    SelectPhotosView(selectedPrompt: nil, onBack: {}, onSaveMoments: { _ in })
}
