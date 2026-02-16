import SwiftUI

struct TableOfContentsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss

    // Internal viewer configurations for item-based presentation (safer)
    struct IdentifiableMoments: Identifiable {
        let id = UUID()
        let moments: [Moment]
        let initialIndex: Int
    }
    
    struct IdentifiablePromptPhotos: Identifiable {
        let id = UUID()
        let photos: [PromptPhoto]
        let initialIndex: Int
        let promptText: String?
    }
    
    @State private var momentsViewerConfig: IdentifiableMoments?
    @State private var promptPhotosViewerConfig: IdentifiablePromptPhotos?

    private let backgroundColor = Color(red: 253/255, green: 246/255, blue: 236/255) // #FDF6EC
    private let serifFont = "Georgia" // Fallback to system serif if needed
    
    private var totalMemoriesCount: Int {
        // Count unique moments (group by date and place to avoid counting duplicates from same memory)
        let uniqueMomentSections = DaySection.grouped(from: viewModel.moments)
        let momentCount = uniqueMomentSections.count
        
        // Count prompt memories
        let promptMemoryCount = viewModel.promptMemories.count
        
        return momentCount + promptMemoryCount
    }

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
                            
                            
                            Text("\(totalMemoriesCount) Memories Saved")
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
                                        thumbnail: milestone.thumbnail
                                    ) {
                                        momentsViewerConfig = IdentifiableMoments(
                                            moments: [milestone],
                                            initialIndex: 0
                                        )
                                    }
                                }
                                
                                // "The Beginning" is a special label in the timeline, let's add it if applicable
                                tocRow(
                                    title: "The Beginning",
                                    date: "Founding",
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
                                                        title: section.placeDisplay,
                                                        date: formatDate(section.date),
                                                        thumbnail: section.moments.first?.thumbnail
                                                    ) {
                                                        let photos = viewModel.flattenedPhotos(for: section)
                                                        if !photos.isEmpty {
                                                            momentsViewerConfig = IdentifiableMoments(
                                                                moments: photos,
                                                                initialIndex: 0
                                                            )
                                                        }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
            }
            .fullScreenCover(item: $momentsViewerConfig) { config in
                MomentPhotoViewer(
                    moments: config.moments,
                    initialIndex: config.initialIndex,
                    onDismiss: {
                        momentsViewerConfig = nil
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
                    }
                )
            }
            .fullScreenCover(item: $promptPhotosViewerConfig) { config in
                PromptPhotoViewer(
                    photos: config.photos,
                    initialIndex: config.initialIndex,
                    onDismiss: {
                        promptPhotosViewerConfig = nil
                    },
                    onUpdatePhotos: { updatedPhotos in
                        viewModel.updatePromptMemoryPhotos(config.photos, with: updatedPhotos)
                    },
                    onDeletePhoto: { photo in
                        withAnimation {
                            viewModel.deletePromptPhoto(photo, from: config.photos)
                        }
                    },
                    promptText: config.promptText
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

    private func tocRow(title: String, date: String, thumbnail: UIImage?, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(alignment: .bottom, spacing: 12) {
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
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(title)
                            .font(.custom(serifFont, size: 16))
                            .foregroundColor(BabyTownTheme.textPrimary)
                        
                        Spacer()
                        
                        Text(date)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(BabyTownTheme.textPrimary)
                            .fixedSize()
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
