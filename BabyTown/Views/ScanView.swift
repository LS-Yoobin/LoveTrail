import SwiftUI
import Photos
import SpriteKit

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var catScene = LaunchCatScene()
    @Environment(\.dismiss) private var dismiss

    private let monthSymbols = Calendar.current.shortMonthSymbols
    private let monthFilterBarHeight: CGFloat = 52
    private let monthFilterListSpacing: CGFloat = 16
    
    let existingAssetIdentifiers: Set<String>
    let onMemoriesAdded: ([Moment]) -> Void
    
    init(existingAssetIdentifiers: Set<String>, onMemoriesAdded: @escaping ([Moment]) -> Void) {
        self.existingAssetIdentifiers = existingAssetIdentifiers
        self.onMemoriesAdded = onMemoriesAdded
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                    
                    // Year selector
                    yearSelector
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Content
                    content
                }
            }
            .task {
                viewModel.existingAssetIdentifiers = existingAssetIdentifiers
                await viewModel.checkPhotoPermission()
                if viewModel.authorizationStatus == .authorized {
                    viewModel.scanPhotosForYear(viewModel.selectedYear)
                }
            }
            .onChange(of: viewModel.isScanning) { _, isScanning in
                if isScanning {
                    catScene.restartParade()
                }
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 15))
                }
                .foregroundStyle(BabyTownTheme.accent)
            }
            
            Spacer()
            
            Text("Scan")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
            
            Spacer()
            
            // Invisible spacer for centering
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var yearSelector: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.selectedYear -= 1
                viewModel.scanPhotosForYear(viewModel.selectedYear)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            
            Text(String(viewModel.selectedYear))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .frame(minWidth: 80)
            
            Button {
                viewModel.selectedYear += 1
                viewModel.scanPhotosForYear(viewModel.selectedYear)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            .disabled(viewModel.selectedYear >= Calendar.current.component(.year, from: Date()))
        }
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
            permissionDeniedView
        } else if viewModel.potentialCards.isEmpty && viewModel.isScanning {
            scanningView
        } else if viewModel.potentialCards.isEmpty {
            emptyStateView
        } else {
            ZStack(alignment: .bottom) {
                resultsListView

                if viewModel.isScanning {
                    scanningFooter
                }
            }
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()

            LaunchRunningCatsView(scene: catScene)
                .frame(height: 240)
                .padding(.bottom, 20)

            PulsingDotsLoader()
            
            Text("Scanning photos...")
                .font(.system(size: 15))
                .foregroundStyle(.black)
            
            if viewModel.scanProgress > 0 {
                Text("\(Int(viewModel.scanProgress * 100))%")
                    .font(.system(size: 13))
                    .foregroundStyle(BabyTownTheme.textTertiary)
            }
            
            Spacer()
        }
    }

    private var scanningFooter: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(BabyTownTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Finding more memories…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                if viewModel.totalClusterCount > 0 {
                    Text("\(viewModel.processedClusterCount) of \(viewModel.totalClusterCount) places")
                        .font(.system(size: 12))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
            }

            Spacer()

            Text("\(Int(viewModel.scanProgress * 100))%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BabyTownTheme.background)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "map")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.3))
            
            Text("No location-based memories found for \(viewModel.selectedYear)")
                .font(.system(size: 16))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Try a different year")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
            
            Text("Photo Access Needed")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
            
            Text("Allow photo access in Settings\nto scan your memories.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var resultsListView: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredPotentialCards) { card in
                        PotentialMemoryCardView(card: card) {
                            Task {
                                let moments = await viewModel.addCardToHome(card)
                                onMemoriesAdded(moments)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, viewModel.isScanning ? 88 : 16)
                .padding(.top, monthFilterBarHeight + monthFilterListSpacing)
            }

            monthFilterBar
        }
    }

    private var monthFilterBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableMonths, id: \.self) { month in
                        monthChipButton(
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
            .frame(height: monthFilterBarHeight)
            .background(
                LinearGradient(
                    colors: [
                        BabyTownTheme.background,
                        BabyTownTheme.background.opacity(0.92),
                        BabyTownTheme.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
            .onAppear {
                proxy.scrollTo(viewModel.selectedMonth, anchor: .center)
            }
            .onChange(of: viewModel.selectedMonth) { _, month in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(month, anchor: .center)
                }
            }
            .onChange(of: viewModel.availableMonths) { _, _ in
                proxy.scrollTo(viewModel.selectedMonth, anchor: .center)
            }
        }
    }

    private func monthChipButton(
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
                        .fill(
                            isActive
                                ? AnyShapeStyle(BabyTownTheme.accentGradient)
                                : AnyShapeStyle(BabyTownTheme.accentSoft)
                        )
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}
