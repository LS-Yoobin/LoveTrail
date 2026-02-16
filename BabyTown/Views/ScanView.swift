import SwiftUI
import Photos

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
                    await viewModel.scanPhotosForYear(viewModel.selectedYear)
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
                Task {
                    await viewModel.scanPhotosForYear(viewModel.selectedYear)
                }
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
                Task {
                    await viewModel.scanPhotosForYear(viewModel.selectedYear)
                }
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
        } else if viewModel.isScanning {
            scanningView
        } else if viewModel.potentialCards.isEmpty {
            emptyStateView
        } else {
            resultsListView
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Cat image with animation (matching launch screen style)
            Image("First Page Cat")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .padding(.bottom, 20)
            
            // Pulsing dots loading animation
            PulsingDotsLoader()
            
            Text("Scanning photos...")
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.textSecondary)
            
            if viewModel.scanProgress > 0 {
                Text("\(Int(viewModel.scanProgress * 100))%")
                    .font(.system(size: 13))
                    .foregroundStyle(BabyTownTheme.textTertiary)
            }
            
            Spacer()
        }
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.potentialCards) { card in
                    PotentialMemoryCardView(card: card) {
                        Task {
                            let moments = await viewModel.addCardToHome(card)
                            onMemoriesAdded(moments)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
