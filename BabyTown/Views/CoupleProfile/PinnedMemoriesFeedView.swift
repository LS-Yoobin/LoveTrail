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
    let isForeverUnlocked: Bool
    let onBack: () -> Void
    let onPartnerTap: () -> Void
    let onShare: (MemorySharePayload) -> Void
    let onEditSpecialDate: (SpecialDate) -> Void
    let onDeleteSpecialDate: (SpecialDate) -> Void
    let onTogglePinSpecialDate: (SpecialDate) -> Void

    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerInitialIndex = 0
    @State private var viewerMemoryPagePromptText: String?
    @State private var viewerImportantDate: MemoryPageImportantDateInfo?
    @State private var viewerPromptMemoryId: UUID?

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
                            clearMemoryPageViewerContext()
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
                    },
                    memoryPagePromptText: viewerMemoryPagePromptText,
                    memoryPageImportantDate: viewerImportantDate,
                    promptMemoryId: viewerPromptMemoryId,
                    onEditPromptMemory: { memoryId, _, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                        viewModel.updatePromptMemory(
                            memoryId: memoryId,
                            primaryPhotoId: viewerMoments.first?.id ?? UUID(),
                            loveNote: caption,
                            placeName: placeName,
                            latitude: latitude,
                            longitude: longitude,
                            isPlaceNameUserSet: isPlaceNameUserSet
                        )
                    },
                    onAddPromptPhotos: { memoryId, images in
                        viewModel.addPhotosToPromptMemory(memoryId: memoryId, images: images)
                    },
                    onRemovePromptPhoto: { memoryId, photoId in
                        viewModel.removePhotoFromPromptMemory(memoryId: memoryId, photoId: photoId)
                    },
                    onSyncPromptMemoryPhotos: { memoryId, assetIds, orphanIds in
                        await viewModel.syncPromptMemoryPhotos(
                            memoryId: memoryId,
                            selectedAssetIds: assetIds,
                            selectedOrphanMomentIds: orphanIds
                        )
                    },
                    onReloadPromptMoments: {
                        guard let memoryId = viewerPromptMemoryId,
                              let memory = viewModel.promptMemories.first(where: { $0.id == memoryId }) else {
                            return viewerMoments
                        }
                        return memory.sortedViewerMoments
                    }
                )
                .transition(.opacity)
                .zIndex(11)
            }
        }
    }

    private func clearMemoryPageViewerContext() {
        viewerMemoryPagePromptText = nil
        viewerImportantDate = nil
        viewerPromptMemoryId = nil
    }

    private func openPromptMemoryPage(memory: PromptMemory, photo: PromptPhoto) {
        let moments = memory.sortedViewerMoments
        guard !moments.isEmpty else { return }
        clearMemoryPageViewerContext()
        viewerMoments = moments
        viewerInitialIndex = moments.firstIndex(where: { $0.id == photo.id }) ?? 0
        viewerMemoryPagePromptText = memory.promptText
        viewerPromptMemoryId = memory.id
        withAnimation(.easeInOut(duration: 0.25)) {
            showingMomentViewer = true
        }
    }

    private func openImportantDateMemoryPage(
        title: String,
        date: Date,
        image: UIImage,
        itemId: String
    ) {
        clearMemoryPageViewerContext()
        viewerMoments = [
            MemoryPageMomentFactory.moment(
                image: image,
                importantDate: MemoryPageImportantDateInfo(title: title, date: date),
                itemId: itemId
            )
        ]
        viewerInitialIndex = 0
        viewerImportantDate = MemoryPageImportantDateInfo(title: title, date: date)
        withAnimation(.easeInOut(duration: 0.25)) {
            showingMomentViewer = true
        }
    }

    @ViewBuilder
    private func feedCard(_ row: PinnedFeedRow, index: Int) -> some View {
        switch row {
        case .special(let special):
            SpecialDateMemoryCard(
                title: special.title,
                date: special.date,
                image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id),
                style: .timeline,
                isPinned: true,
                isLeftAligned: index.isMultiple(of: 2),
                index: index,
                onTap: { openSpecialDate(special) },
                onShare: {
                    onShare(
                        MemorySharePayload(
                            special: special,
                            image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: special.id)
                        )
                    )
                },
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
                        clearMemoryPageViewerContext()
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
                        withAnimation { viewModel.togglePin(for: section, isForeverUnlocked: isForeverUnlocked) }
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
                    onOpenPhoto: { photo, _ in
                        openPromptMemoryPage(memory: memory, photo: photo)
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
        openImportantDateMemoryPage(
            title: special.title,
            date: special.date,
            image: image,
            itemId: special.id.uuidString
        )
    }
}
