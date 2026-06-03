import SwiftUI

private enum PinnedFeedRow: Identifiable {
    case special(SpecialDate)
    case pinned(PinnedItem)

    var id: String {
        switch self {
        case .special(let date): return "special-\(date.id.uuidString)"
        case .pinned(let item): return "pinned-\(item.id.uuidString)"
        }
    }
}

/// Full-screen zigzag feed of pinned memories using Home timeline card styling.
struct PinnedMemoriesFeedView: View {
    @ObservedObject var viewModel: HomeViewModel
    let specialDates: [SpecialDate]
    let userAvatar: UIImage?
    let userName: String
    let partnerSlotTitle: String
    let onBack: () -> Void
    let onPartnerTap: () -> Void
    let onShare: (MemorySharePayload) -> Void
    let onEditSpecialDate: (SpecialDate) -> Void
    let onDeleteSpecialDate: (SpecialDate) -> Void
    let onTogglePinSpecialDate: (SpecialDate) -> Void

    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0
    @State private var showingPromptPhotoViewer = false
    @State private var viewerPromptPhotos: [PromptPhoto] = []
    @State private var viewerPromptPhotoIndex = 0
    @State private var viewerPromptText: String?
    @State private var specialDatePhotoContext: ImportantDatePhotoViewerContext?

    private var feedRows: [PinnedFeedRow] {
        var rows: [PinnedFeedRow] = specialDates.filter(\.isPinned).map { .special($0) }
        rows += viewModel.pinnedItems.map { .pinned($0) }
        return rows.sorted { pinnedAt(for: $0) > pinnedAt(for: $1) }
    }

    private func pinnedAt(for row: PinnedFeedRow) -> Date {
        switch row {
        case .special(let date):
            return date.pinnedAt ?? .distantPast
        case .pinned(let item):
            return item.pinnedAt
        }
    }

    var body: some View {
        ZStack {
            CoupleProfileSubpageBackground()

            ScrollView {
                ZStack(alignment: .top) {
                    HeartTrailBackground(sectionCount: max(feedRows.count, 1))
                        .padding(.top, 160)

                    LazyVStack(spacing: 24) {
                        CoupleProfileSubpageHeader(
                            userAvatar: userAvatar,
                            userName: userName,
                            partnerSlotTitle: partnerSlotTitle,
                            onBack: onBack,
                            onPartnerTap: onPartnerTap,
                            title: "Pinned Memories"
                        )

                        ForEach(Array(feedRows.enumerated()), id: \.element.id) { index, row in
                            feedCard(row, index: index)
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
                    .padding(.bottom, 32)
                }
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
                            if let idx = newMoments.firstIndex(where: { $0.id == moment.id }) {
                                newMoments[idx] = moment
                            }
                        }
                        viewModel.moments = newMoments
                    },
                    onDeleteMoment: { moment in
                        withAnimation { viewModel.deleteMoment(moment) }
                    }
                )
                .transition(.opacity)
                .zIndex(11)
            }

            if showingPromptPhotoViewer {
                PromptPhotoViewer(
                    photos: viewerPromptPhotos,
                    initialIndex: viewerPromptPhotoIndex,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingPromptPhotoViewer = false
                        }
                    },
                    onUpdatePhotos: { updatedPhotos in
                        viewModel.updatePromptMemoryPhotos(viewerPromptPhotos, with: updatedPhotos)
                    },
                    onDeletePhoto: { photo in
                        withAnimation {
                            viewModel.deletePromptPhoto(photo, from: viewerPromptPhotos)
                        }
                    },
                    promptText: viewerPromptText
                )
                .transition(.opacity)
                .zIndex(12)
            }

            if let context = specialDatePhotoContext {
                ImportantDatePhotoViewer(
                    title: context.title,
                    date: context.date,
                    image: context.image,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            specialDatePhotoContext = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(13)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: specialDatePhotoContext != nil)
    }

    @ViewBuilder
    private func feedCard(_ row: PinnedFeedRow, index: Int) -> some View {
        switch row {
        case .special(let special):
            SpecialDateMemoryCard(
                title: special.title,
                date: special.date,
                image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id),
                isPinned: true,
                onTap: { openSpecialDate(special) },
                onEdit: { onEditSpecialDate(special) },
                onDelete: { onDeleteSpecialDate(special) },
                onTogglePin: { onTogglePinSpecialDate(special) }
            )

        case .pinned(let item):
            switch item {
            case .moment(let representative, let allMoments):
                let section = DaySection(
                    date: Calendar.current.startOfDay(for: representative.dateTaken),
                    placeName: representative.placeName,
                    moments: allMoments.sorted { $0.dateTaken < $1.dateTaken }
                )
                DayClusterCard(
                    section: section,
                    onOpenPhoto: { moment, all in
                        viewerMoments = all
                        viewerInitialIndex = all.firstIndex(where: { $0.id == moment.id }) ?? 0
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingMomentViewer = true
                        }
                    },
                    onEditCaption: { momentId, caption, voiceNotePath in
                        viewModel.updateCaption(
                            for: momentId,
                            caption: caption,
                            voiceNotePath: voiceNotePath
                        )
                    },
                    onEditMemory: { section, momentId, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                        viewModel.updateMemory(
                            section: section,
                            primaryMomentId: momentId,
                            caption: caption,
                            placeName: placeName,
                            latitude: latitude,
                            longitude: longitude,
                            isPlaceNameUserSet: isPlaceNameUserSet
                        )
                    },
                    onRemove: { section in
                        withAnimation { viewModel.removeMoments(from: section) }
                    },
                    onTogglePin: { section in
                        withAnimation { viewModel.togglePin(for: section) }
                    },
                    onAddPhotos: { section, images in
                        viewModel.addPhotosToMemory(section: section, images: images)
                    },
                    onRemovePhoto: { section, momentId in
                        viewModel.removePhotoFromMemory(section: section, momentId: momentId)
                    },
                    onSyncMemoryPhotos: { section, assetIds, orphanIds in
                        Task {
                            await viewModel.syncMemoryPhotos(
                                section: section,
                                selectedAssetIds: assetIds,
                                selectedOrphanMomentIds: orphanIds
                            )
                        }
                    },
                    onShare: onShare,
                    isLeftAligned: index.isMultiple(of: 2),
                    index: index
                )

            case .prompt(let memory):
                PromptMemoryCard(
                    memory: memory,
                    onTap: {},
                    onOpenPhoto: { photo, allPhotos in
                        if let photoIndex = allPhotos.firstIndex(where: { $0.id == photo.id }) {
                            viewerPromptPhotos = allPhotos
                            viewerPromptPhotoIndex = photoIndex
                            viewerPromptText = memory.promptText
                            withAnimation(.easeIn(duration: 0.25)) {
                                showingPromptPhotoViewer = true
                            }
                        }
                    },
                    onRemove: { memory in
                        withAnimation { viewModel.removePromptMemory(memory) }
                    },
                    onEditLoveNote: { memoryId, note in
                        viewModel.updatePromptMemoryLoveNote(for: memoryId, loveNote: note)
                    },
                    onEditMemory: { memoryId, photoId, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                        viewModel.updatePromptMemory(
                            memoryId: memoryId,
                            primaryPhotoId: photoId,
                            loveNote: caption,
                            placeName: placeName,
                            latitude: latitude,
                            longitude: longitude,
                            isPlaceNameUserSet: isPlaceNameUserSet
                        )
                    },
                    onAddPhotos: { memoryId, images in
                        viewModel.addPhotosToPromptMemory(memoryId: memoryId, images: images)
                    },
                    onRemovePhoto: { memoryId, photoId in
                        viewModel.removePhotoFromPromptMemory(memoryId: memoryId, photoId: photoId)
                    },
                    onSyncMemoryPhotos: { memoryId, assetIds, orphanIds in
                        Task {
                            await viewModel.syncPromptMemoryPhotos(
                                memoryId: memoryId,
                                selectedAssetIds: assetIds,
                                selectedOrphanMomentIds: orphanIds
                            )
                        }
                    },
                    onTogglePin: { memory in
                        withAnimation { viewModel.togglePromptMemoryPin(memory) }
                    },
                    onShare: onShare,
                    isLeftAligned: index.isMultiple(of: 2),
                    index: index
                )
            }
        }
    }

    private func openSpecialDate(_ special: SpecialDate) {
        guard let image = DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            specialDatePhotoContext = ImportantDatePhotoViewerContext(
                title: special.title,
                date: special.date,
                image: image
            )
        }
    }
}
