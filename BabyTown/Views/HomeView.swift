import SwiftUI
import PhotosUI

enum PinnedMemoryType {
    case firstMet
    case official
}

struct HomeView: View {

    @StateObject private var viewModel: HomeViewModel

    var onSelectPhotos: () -> Void
    var onOpenPhotoViewer: (_ moment: Moment, _ allInDay: [Moment]) -> Void
    var onResetApp: (() -> Void)? = nil
    @Binding var selectedPrompt: PromptItem?
    
    @State private var showCameraSheet = false
    @State private var showCameraFullScreen = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var firstMetPickerItem: PhotosPickerItem?
    @State private var officialPickerItem: PhotosPickerItem?
    @State private var showingPinnedViewer: PinnedMemoryType?
    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0
    @State private var showPromptSheet = false

    init(
        pinnedFirstMet: UIImage?,
        pinnedOfficial: UIImage,
        moments: [Moment] = [],
        onSelectPhotos: @escaping () -> Void,
        onOpenPhotoViewer: @escaping (Moment, [Moment]) -> Void,
        onResetApp: (() -> Void)? = nil,
        selectedPrompt: Binding<PromptItem?> = .constant(nil)
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            pinnedFirstMet: pinnedFirstMet,
            pinnedOfficial: pinnedOfficial,
            moments: moments
        ))
        self.onSelectPhotos = onSelectPhotos
        self.onOpenPhotoViewer = onOpenPhotoViewer
        self.onResetApp = onResetApp
        _selectedPrompt = selectedPrompt
    }

    init(
        viewModel: HomeViewModel,
        onSelectPhotos: @escaping () -> Void = {},
        onOpenPhotoViewer: @escaping (Moment, [Moment]) -> Void = { _, _ in },
        onResetApp: (() -> Void)? = nil,
        selectedPrompt: Binding<PromptItem?> = .constant(nil)
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectPhotos = onSelectPhotos
        self.onOpenPhotoViewer = onOpenPhotoViewer
        self.onResetApp = onResetApp
        _selectedPrompt = selectedPrompt
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    BabyTownHeader(onSettingsTap: {
                        showSettings = true
                    })
                    StickyActionBar(
                        onSelectPhotos: onSelectPhotos,
                        onPrompt: {
                            showPromptSheet = true
                        }
                    )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        pinnedSection
                        divider

                        if viewModel.isEmpty && viewModel.promptMemories.isEmpty {
                            emptyState
                        } else {
                            timelineSection
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 100)
                }
            }
            
            VStack {
                Spacer()
                GeometryReader { geometry in
                    GIFImageView(gifName: "TransparentFlowers")
                        .frame(width: geometry.size.width, height: geometry.size.width * 0.5)
                        .position(x: geometry.size.width / 2, y: geometry.size.height)
                }
                .frame(height: 0)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            
            cameraButton
            
            if let viewerType = showingPinnedViewer {
                FullScreenPinnedMemoryViewer(
                    title: viewerType == .firstMet ? "First Photo Taken Together" : "First Photo As Official Jinkies",
                    date: "Pinned",
                    image: viewerType == .firstMet ? viewModel.pinnedFirstMet : viewModel.pinnedOfficial,
                    pickerItem: viewerType == .firstMet ? $firstMetPickerItem : $officialPickerItem,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingPinnedViewer = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
            
            if showingMomentViewer {
                MomentPhotoViewer(
                    moments: viewerMoments,
                    initialIndex: viewerInitialIndex,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingMomentViewer = false
                        }
                    },
                    onUpdateMoments: { updatedMoments in
                        var newMoments = viewModel.moments
                        for moment in updatedMoments {
                            if let index = newMoments.firstIndex(where: { $0.id == moment.id }) {
                                newMoments[index] = moment
                            }
                        }
                        viewModel.moments = newMoments
                    }
                )
                .transition(.opacity)
                .zIndex(11)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingPinnedViewer != nil)
        .animation(.easeInOut(duration: 0.25), value: showingMomentViewer)
        .sheet(isPresented: $showPromptSheet) {
                JinkyPromptSheetView { prompt in
                    self.selectedPrompt = prompt
                    showPromptSheet = false
                    onSelectPhotos()
                }
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showCameraFullScreen) {
            PolaroidCameraView(
                polaroidStore: viewModel.polaroidStore,
                onPhotosReleased: { releasedEntries in
                    viewModel.releasePolaroids(releasedEntries)
                    viewModel.checkAndReleasePhotos()
                }
            )
        }
        .sheet(isPresented: $showCameraSheet) {
            CameraCaptureView(
                polaroidStore: viewModel.polaroidStore,
                onPhotosReleased: { releasedEntries in
                    viewModel.releasePolaroids(releasedEntries)
                    viewModel.checkAndReleasePhotos()
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(onResetApp: {
                onResetApp?()
            })
        }
        .fullScreenCover(isPresented: $showSearch) {
            MemorySearchView(
                allMoments: viewModel.moments,
                onOpenPhoto: { moment, allMoments in
                    showSearch = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewerMoments = allMoments
                        if let idx = allMoments.firstIndex(where: { $0.id == moment.id }) {
                            viewerInitialIndex = idx
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingMomentViewer = true
                        }
                    }
                },
                onEditCaption: { momentId, caption, voiceNotePath in
                    viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
                },
                onRemove: { section in
                    withAnimation {
                        viewModel.removeMoments(from: section)
                    }
                },
                onTogglePin: { section in
                    withAnimation {
                        viewModel.togglePin(for: section)
                    }
                }
            )
        }
        }
        .onAppear {
            viewModel.checkAndReleasePhotos()
        }
    }

    // MARK: - Pinned Memories

    private var pinnedSection: some View {
        VStack(spacing: 12) {
            sectionLabel("Pinned Memories", icon: "pin.fill")
                .padding(.horizontal, 20)
            
            if !viewModel.pinnedMoments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.pinnedMoments) { moment in
                            PinnedMemoryCard(
                                moment: moment,
                                onTap: {
                                    viewerMoments = [moment]
                                    viewerInitialIndex = 0
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showingMomentViewer = true
                                    }
                                },
                                onUnpin: {
                                    withAnimation {
                                        viewModel.unpinMoment(moment)
                                    }
                                }
                            )
                            .frame(width: 180)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                Text("No pinned memories yet")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Section Helpers

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(BabyTownTheme.accent.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 32)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(spacing: 12) {
            sectionLabel("Jinky Adventures", icon: "heart.text.square")
                .padding(.horizontal, 20)

            ZStack(alignment: .top) {
                HeartTrailBackground(
                    sectionCount: viewModel.daySections.count + viewModel.promptMemories.count + viewModel.polaroidStore.processingMemories.count
                )

                VStack(spacing: 24) {
                    ForEach(Array(combinedTimelineItems.enumerated()), id: \.offset) { index, item in
                        switch item {
                        case .daySection(let section):
                            DayClusterCard(
                                section: section,
                                onOpenPhoto: { moment, allMoments in
                                    viewerMoments = allMoments
                                    if let idx = allMoments.firstIndex(where: { $0.id == moment.id }) {
                                        viewerInitialIndex = idx
                                    }
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showingMomentViewer = true
                                    }
                                },
                                onEditCaption: { momentId, caption, voiceNotePath in
                                    viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
                                },
                                onRemove: { section in
                                    withAnimation {
                                        viewModel.removeMoments(from: section)
                                    }
                                },
                                onTogglePin: { section in
                                    withAnimation {
                                        viewModel.togglePin(for: section)
                                    }
                                },
                                onAddPhotos: { section, images in
                                    viewModel.addPhotosToMemory(section: section, images: images)
                                },
                                onRemovePhoto: { section, momentId in
                                    viewModel.removePhotoFromMemory(section: section, momentId: momentId)
                                }
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )
                            
                        case .promptMemory(let memory):
                            PromptMemoryCard(
                                memory: memory,
                                onTap: {
                                    // TODO: Open prompt memory detail view
                                }
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )
                            
                        case .processingMemory(let memory):
                            ProcessingMemoryCard(
                                memory: memory,
                                image: viewModel.polaroidStore.loadImage(for: PolaroidEntry(
                                    id: memory.id,
                                    capturedAt: memory.date,
                                    imageFileName: memory.imageFileName,
                                    released: false,
                                    manuallyReleasedAt: nil,
                                    isFifthPhoto: true
                                ))
                            )
                            .padding(
                                .leading,
                                index.isMultiple(of: 2) ? 20 : 46
                            )
                            .padding(
                                .trailing,
                                index.isMultiple(of: 2) ? 46 : 20
                            )
                        }
                    }
                }
            }
        }
    }
    
    private enum TimelineItem {
        case daySection(DaySection)
        case promptMemory(PromptMemory)
        case processingMemory(ProcessingMemory)
        
        var date: Date {
            switch self {
            case .daySection(let section):
                return section.date
            case .promptMemory(let memory):
                return memory.date
            case .processingMemory(let memory):
                return memory.date
            }
        }
    }
    
    private var combinedTimelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        
        items += viewModel.daySections.map { .daySection($0) }
        items += viewModel.promptMemories.map { .promptMemory($0) }
        items += viewModel.polaroidStore.processingMemories.map { .processingMemory($0) }
        
        return items.sorted { $0.date > $1.date }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 40)

            PulsingHeartView()
                .frame(height: 70)

            Text("Ready to add our moments?")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundStyle(.white)

            Text("Tap Select Photos and I'll\nbuild our love timeline.")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var cameraButton: some View {
        VStack {
            Spacer()
            
            Button {
                let todaysCount = viewModel.polaroidStore.todaysCaptureCount()
                if todaysCount >= 5 {
                    showCameraSheet = true
                } else {
                    showCameraFullScreen = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(BabyTownTheme.accentGradient)
                        .frame(width: 64, height: 64)
                        .shadow(color: BabyTownTheme.buttonShadow, radius: 12, y: 4)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pulsing Heart (Empty State)

private struct PulsingHeartView: View {

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 40))
            .foregroundStyle(
                BabyTownTheme.accent.opacity(0.3)
            )
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.18
                }
            }
    }
}

// MARK: - Previews

#Preview("Filled") {
    HomeView(viewModel: .filledPreview)
}

#Preview("Empty") {
    HomeView(viewModel: .emptyPreview)
}
