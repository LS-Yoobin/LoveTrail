import SwiftUI
import Photos

struct SelectPhotosView: View {

    @StateObject private var viewModel = SelectPhotosViewModel()
    @State private var showAnimation = false
    
    var onBack: () -> Void
    var onSaveMoments: ([Moment]) -> Void

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

            // Full-screen viewer
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
            
            // Floating Save Button
            if viewModel.selectionMode && viewModel.selectedCount > 0 {
                VStack {
                    Spacer()
                    saveButton
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
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
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BabyTownTheme.accent)
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
                    ForEach(1...12, id: \.self) { month in
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : BabyTownTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive
                              ? AnyShapeStyle(BabyTownTheme.accentGradient)
                              : AnyShapeStyle(BabyTownTheme.accentSoft))
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
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
            .padding(.bottom, viewModel.selectionMode && viewModel.selectedCount > 0 ? 100 : 0)
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            Task {
                let moments = await viewModel.saveMoments()
                onSaveMoments(moments)
                withAnimation(.easeIn(duration: 0.2)) {
                    showAnimation = true
                }
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
                Text("Save (\(viewModel.selectedCount))")
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
}

#Preview {
    SelectPhotosView(onBack: {}, onSaveMoments: { _ in })
}
