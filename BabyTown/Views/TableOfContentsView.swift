import SwiftUI

struct TableOfContentsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss

    // Internal viewer configurations for item-based presentation (safer)
    struct IdentifiableMemoryPage: Identifiable {
        let id = UUID()
        let moments: [Moment]
        let initialIndex: Int
        let promptText: String?
        let promptMemoryId: UUID?
    }

    @State private var memoryPageConfig: IdentifiableMemoryPage?

    private let backgroundColor = Color(red: 253/255, green: 246/255, blue: 236/255) // #FDF6EC
    private let serifFont = "Georgia" // Fallback to system serif if needed
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                // Add a subtle paper texture effect if we had one, 
                // for now we'll use a very light overlay
                Color.black.opacity(0.02)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .center, spacing: 32) {
                        // 1️⃣ Header
                        VStack(spacing: 8) {
                            Text("BabyTown")
                                .font(.custom(serifFont, size: 18))
                                .italic()
                                .foregroundColor(BabyTownTheme.textPrimary)
                            
                            Text("Table of Contents")
                                .font(.custom(serifFont, size: 32))
                                .fontWeight(.bold)
                                .foregroundColor(BabyTownTheme.textPrimary)
                            
                            
                            Text("\(viewModel.tocMemoryCount) Memories Saved")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(BabyTownTheme.textPrimary)
                                .padding(.top, 4)
                        }
                        .padding(.top, 40)

                        // 2️⃣ Special Milestones Section (Pinned at Top)
                        tocSection(title: "❤️ Pinned Memories") {
                            VStack(spacing: 16) {
                                ForEach(viewModel.tocMilestones) { milestone in
                                    tocRow(
                                        title: milestone.promptText ?? "Special Moment",
                                        date: formatDate(milestone.dateTaken),
                                        loveNote: loveNote(from: milestone),
                                        thumbnail: milestone.thumbnail
                                    ) {
                                        memoryPageConfig = IdentifiableMemoryPage(
                                            moments: [milestone],
                                            initialIndex: 0,
                                            promptText: nil,
                                            promptMemoryId: nil
                                        )
                                    }
                                }

                                ForEach(viewModel.tocPinnedPromptMemories) { memory in
                                    tocRow(
                                        title: memory.promptText,
                                        date: formatDate(memory.date),
                                        loveNote: pinnedPromptLoveNote(memory),
                                        thumbnail: memory.photos.first?.thumbnail
                                    ) {
                                        memoryPageConfig = IdentifiableMemoryPage(
                                            moments: memory.sortedViewerMoments,
                                            initialIndex: 0,
                                            promptText: memory.promptText,
                                            promptMemoryId: memory.id
                                        )
                                    }
                                }
                                
                                // "The Beginning" is a special label in the timeline, let's add it if applicable
                                tocRow(
                                    title: "The Beginning",
                                    date: "Founding",
                                    loveNote: nil,
                                    thumbnail: nil
                                ) {
                                    // Scroll to bottom logic could go here
                                    dismiss()
                                }
                            }
                        }

                        // 3️⃣ Memories Section (Organized by Year and Season)
                        ForEach(viewModel.tocGroups) { yearGroup in
                            tocSection(title: "\(yearGroup.id)") {
                                VStack(spacing: 24) {
                                    ForEach(yearGroup.seasons) { seasonGroup in
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(seasonGroup.season.rawValue)
                                                .font(.custom(serifFont, size: 22))
                                                .fontWeight(.semibold)
                                                .foregroundColor(BabyTownTheme.accent)
                                            
                                            VStack(spacing: 14) {
                                                ForEach(seasonGroup.sections) { section in
                                                    tocRow(
                                                        title: viewModel.tocRowTitle(for: section),
                                                        date: formatDate(section.date),
                                                        loveNote: viewModel.tocLoveNote(for: section),
                                                        thumbnail: section.moments.first?.thumbnail
                                                    ) {
                                                        openSection(section)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
                .background(backgroundColor)
                .scrollEdgeEffectStyle(.hard, for: .top)
                
                // Cat decoration in bottom right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image("cat_variant_4")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(.trailing, -10)
                            .padding(.bottom, -10)
                    }
                }
                .allowsHitTesting(false)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.black.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .presentationBackground(backgroundColor)
            .fullScreenCover(item: $memoryPageConfig) { config in
                MomentPhotoViewer(
                    moments: config.moments,
                    initialIndex: config.initialIndex,
                    onDismiss: {
                        memoryPageConfig = nil
                    },
                    onUpdateMoments: { updatedMoments in
                        var newMoments = viewModel.moments
                        for moment in updatedMoments {
                            if let index = newMoments.firstIndex(where: { $0.id == moment.id }) {
                                newMoments[index] = moment
                            }
                        }
                        viewModel.moments = newMoments
                    },
                    onDeleteMoment: { moment in
                        withAnimation {
                            viewModel.deleteMoment(moment)
                        }
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
                    onEditCaption: { momentId, caption, voiceNotePath in
                        viewModel.updateCaption(for: momentId, caption: caption, voiceNotePath: voiceNotePath)
                    },
                    onAddPhotos: { section, images in
                        viewModel.addPhotosToMemory(section: section, images: images)
                    },
                    onRemovePhoto: { section, momentId in
                        viewModel.removePhotoFromMemory(section: section, momentId: momentId)
                    },
                    onSyncMemoryPhotos: { section, assetIds, orphanIds in
                        await viewModel.syncMemoryPhotos(
                            section: section,
                            selectedAssetIds: assetIds,
                            selectedOrphanMomentIds: orphanIds
                        )
                    },
                    onReloadMemoryMoments: {
                        guard let anchorId = config.moments.first?.id else { return config.moments }
                        return viewModel.flattenedPhotosForMemory(containingMomentId: anchorId)
                    },
                    memoryPagePromptText: config.promptText,
                    promptMemoryId: config.promptMemoryId,
                    onEditPromptMemory: { memoryId, _, caption, placeName, latitude, longitude, isPlaceNameUserSet in
                        viewModel.updatePromptMemory(
                            memoryId: memoryId,
                            primaryPhotoId: config.moments.first?.id ?? UUID(),
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
                        guard let memoryId = config.promptMemoryId,
                              let memory = viewModel.promptMemories.first(where: { $0.id == memoryId }) else {
                            return config.moments
                        }
                        return memory.sortedViewerMoments
                    }
                )
            }
        }
    }

    private func tocSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom(serifFont, size: 26))
                    .fontWeight(.bold)
                    .foregroundColor(BabyTownTheme.textPrimary)
                
                Rectangle()
                    .fill(BabyTownTheme.textPrimary.opacity(0.2))
                    .frame(height: 1)
            }
            
            content()
        }
    }

    private func tocRow(
        title: String,
        date: String,
        loveNote: String?,
        thumbnail: UIImage?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(alignment: .top, spacing: 12) {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BabyTownTheme.accent.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundColor(BabyTownTheme.accent.opacity(0.4))
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.custom(serifFont, size: 16))
                            .foregroundColor(BabyTownTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer(minLength: 8)
                        
                        Text(date)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(BabyTownTheme.textPrimary)
                            .fixedSize()
                    }
                    
                    if let loveNote {
                        Text(loveNote)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(BabyTownTheme.textPrimary.opacity(0.65))
                            .italic()
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loveNote(from moment: Moment) -> String? {
        guard let caption = moment.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else { return nil }
        return caption
    }

    private func pinnedPromptLoveNote(_ memory: PromptMemory) -> String? {
        let note = memory.loveNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : note
    }

    private func openSection(_ section: DaySection) {
        if let memory = viewModel.promptMemory(for: section), !memory.photos.isEmpty {
            memoryPageConfig = IdentifiableMemoryPage(
                moments: memory.sortedViewerMoments,
                initialIndex: 0,
                promptText: memory.promptText,
                promptMemoryId: memory.id
            )
            return
        }
        let photos = viewModel.flattenedPhotos(for: section)
        guard !photos.isEmpty else { return }
        memoryPageConfig = IdentifiableMemoryPage(
            moments: photos,
            initialIndex: 0,
            promptText: nil,
            promptMemoryId: nil
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        return path
    }
}

#Preview {
    TableOfContentsView(viewModel: HomeViewModel.filledPreview)
}
