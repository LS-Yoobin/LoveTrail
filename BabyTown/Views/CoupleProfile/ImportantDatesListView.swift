import SwiftUI
import GardenCore

enum CoupleProfileSubpage: String, Identifiable {
    case importantDates

    var id: String { rawValue }
}

/// Shared gradient backdrop for full-screen couple profile subpages.
struct CoupleProfileSubpageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.78, blue: 0.92),
                Color(red: 0.62, green: 0.88, blue: 0.82),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Reusable header for Important Dates and Pinned Memories full-screen lists.
struct CoupleProfileSubpageHeader: View {
    let userAvatar: UIImage?
    let userName: String
    let partnerSlotTitle: String
    let onBack: () -> Void
    let onPartnerTap: () -> Void
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                }
                Spacer()
            }

            HStack(spacing: 24) {
                compactAvatar(image: userAvatar, systemName: "person.crop.circle.fill")
                compactAvatar(image: nil, systemName: "heart.fill")
            }

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func compactAvatar(image: UIImage?, systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 48, height: 48)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: systemName)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

/// Full-screen list of all important dates with Add a date at the top.
struct ImportantDatesListView: View {
    let items: [ImportantDateItem]
    let specialDates: [SpecialDate]
    let photoForItem: (ImportantDateItem) -> UIImage?
    let userAvatar: UIImage?
    let userName: String
    let partnerSlotTitle: String
    let onBack: () -> Void
    let onPartnerTap: () -> Void
    let onSaveSpecial: (SpecialDate, UIImage?) -> Void
    let onDeleteSpecial: (SpecialDate) -> Void

    @State private var showingMomentViewer = false
    @State private var viewerMoments: [Moment] = []
    @State private var viewerImportantDate: MemoryPageImportantDateInfo?
    @State private var dateEditorPresentation: SpecialDateEditorPresentation?

    private static let dateFormat: Date.FormatStyle =
        .dateTime.month(.abbreviated).day().year()

    var body: some View {
        ZStack {
            CoupleProfileSubpageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CoupleProfileSubpageHeader(
                        userAvatar: userAvatar,
                        userName: userName,
                        partnerSlotTitle: partnerSlotTitle,
                        onBack: onBack,
                        onPartnerTap: onPartnerTap,
                        title: "Important Dates"
                    )

                    Button(action: beginAddSpecial) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.55, green: 0.45, blue: 0.85))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("Add a date")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            listRow(item)
                            if item.id != items.last?.id {
                                Divider()
                                    .overlay(Color.white.opacity(0.2))
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }

            if showingMomentViewer {
                MomentPhotoViewer(
                    moments: viewerMoments,
                    initialIndex: 0,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingMomentViewer = false
                            viewerImportantDate = nil
                        }
                    },
                    onUpdateMoments: { _ in },
                    memoryPageImportantDate: viewerImportantDate
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .sheet(item: $dateEditorPresentation) { presentation in
            SpecialDateEditorSheet(
                editing: presentation.editing,
                initialImage: presentation.initialImage,
                onSave: { date, image in
                    onSaveSpecial(date, image)
                },
                onDelete: presentation.editing == nil ? nil : { onDeleteSpecial($0) }
            )
        }
    }

    private func beginAddSpecial() {
        dateEditorPresentation = .add()
    }

    private func beginEditSpecial(id: String) {
        guard let uid = UUID(uuidString: id),
              let match = specialDates.first(where: { $0.id == uid }) else { return }
        showingMomentViewer = false
        viewerImportantDate = nil
        dateEditorPresentation = .edit(
            match,
            image: DataPersistenceManager.shared.loadSpecialDatePhoto(id: uid)
        )
    }

    @ViewBuilder
    private func listRow(_ item: ImportantDateItem) -> some View {
        let image = photoForItem(item)

        HStack(spacing: 14) {
            thumbnailControl(image: image, item: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text(item.date, format: Self.dateFormat)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            if item.kind == .special {
                Button { beginEditSpecial(id: item.id) } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func thumbnailControl(image: UIImage?, item: ImportantDateItem) -> some View {
        switch item.kind {
        case .special:
            if image != nil {
                Button { beginEditSpecial(id: item.id) } label: { thumbnail(image) }
                    .buttonStyle(.borderless)
            } else {
                thumbnail(nil)
            }
        case .firstMet, .official:
            if image != nil {
                Button { presentPhoto(for: item) } label: { thumbnail(image) }
                    .buttonStyle(.borderless)
            } else {
                thumbnail(nil)
            }
        }
    }

    private func presentPhoto(for item: ImportantDateItem) {
        guard let image = photoForItem(item) else { return }
        viewerMoments = [
            MemoryPageMomentFactory.moment(
                image: image,
                importantDate: MemoryPageImportantDateInfo(item: item),
                itemId: item.id
            )
        ]
        viewerImportantDate = MemoryPageImportantDateInfo(item: item)
        withAnimation(.easeInOut(duration: 0.25)) {
            showingMomentViewer = true
        }
    }

    private func thumbnail(_ image: UIImage?) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.15))
                Image(systemName: "calendar")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
