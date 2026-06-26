import SwiftUI

struct UserLetterDetailView: View {

    let letterID: UUID
    var onLetterUpdated: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var letter: UserLetter
    @State private var stickerImages: [UUID: UIImage] = [:]
    @State private var photoImages: [UUID: UIImage] = [:]
    @State private var showLetter = false
    @State private var showScheduleSheet = false
    @State private var scheduledDate: Date

    init(letter: UserLetter, onLetterUpdated: (() -> Void)? = nil) {
        letterID = letter.id
        self.onLetterUpdated = onLetterUpdated
        _letter = State(initialValue: letter)
        _scheduledDate = State(
            initialValue: letter.scheduledFor
                ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                ?? Date()
        )
    }

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        deliveryStatusCard
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        letterCard
                            .padding(.horizontal, 20)

                        Image("First Page Cat")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                            .padding(.bottom, letter.isScheduled ? 120 : 40)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if letter.isScheduled {
                rescheduleActionBar
            }
        }
        .sheet(isPresented: $showScheduleSheet) {
            scheduleSheet
        }
        .onAppear {
            refreshLetter()
            loadStickerImages()
            loadPhotoImages()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
                showLetter = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.3))
            }

            Spacer()

            Image(systemName: letter.isScheduled ? "clock.fill" : "envelope.open.fill")
                .font(.system(size: 20))
                .foregroundStyle(BabyTownTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Delivery Status

    private var deliveryStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(letter.isScheduled ? "Scheduled delivery" : "Sent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)

            Text(deliveryStatusDetail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.accent.opacity(0.08))
        )
    }

    private var deliveryStatusDetail: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"

        if letter.isScheduled, let scheduledFor = letter.scheduledFor {
            return formatter.string(from: scheduledFor)
        }
        if let sentAt = letter.sentAt {
            return formatter.string(from: sentAt)
        }
        return formatter.string(from: letter.createdAt)
    }

    private var inlineBlocks: [LetterBlock] {
        letter.blocks.filter { $0.type != .sticker }
    }

    private var stickerBlocks: [LetterBlock] {
        letter.blocks.filter { $0.type == .sticker }
    }

    private var letterContentWidth: CGFloat {
        BabyTownLetterCardStyle.referenceCanvasWidth - 56
    }

    // MARK: - Letter Card

    private var letterCard: some View {
        BabyTownLetterCardStyle.letterChrome(
            cornerRadius: 20,
            canvasWidth: BabyTownLetterCardStyle.referenceCanvasWidth
        ) {
            ZStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(letter.displayTitle)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Rectangle()
                        .fill(BabyTownTheme.accent.opacity(0.3))
                        .frame(height: 1)

                    if !letter.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(letter.body)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.8))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !inlineBlocks.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(inlineBlocks) { block in
                                inlineBlockView(block)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(28)

                if !stickerBlocks.isEmpty {
                    LetterStickersOverlay(
                        stickerBlocks: stickerBlocks,
                        images: stickerImages,
                        isEditing: false,
                        selectedID: .constant(nil),
                        onPositionChanged: { _, _ in },
                        onScaleChanged: { _, _ in },
                        onRotationChanged: { _, _ in },
                        onDelete: { _ in }
                    )
                }
            }
        }
        .scaleEffect(showLetter ? 1.0 : 0.95)
        .opacity(showLetter ? 1.0 : 0.0)
    }

    @ViewBuilder
    private func inlineBlockView(_ block: LetterBlock) -> some View {
        switch block.type {
        case .photo:
            LetterInlinePhotoView(
                image: photoImages[block.id],
                rotation: block.photoRotation ?? LetterPhotoLayout.defaultRotation,
                scale: block.photoScale ?? LetterPhotoLayout.defaultScale,
                contentWidth: letterContentWidth,
                isEditing: false,
                isSelected: false,
                onSelect: {},
                onDelete: {},
                onScaleChanged: { _ in },
                onRotationChanged: { _ in }
            )

        case .voiceMemo:
            LetterBlockDetailView(block: block)

        case .sticker:
            EmptyView()
        }
    }

    // MARK: - Reschedule

    private var rescheduleActionBar: some View {
        Button {
            scheduledDate = letter.scheduledFor
                ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                ?? Date()
            showScheduleSheet = true
        } label: {
            Text("Change delivery time")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            BabyTownTheme.backgroundGradient
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var scheduleSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Deliver on",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Change Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showScheduleSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRescheduledDate()
                        showScheduleSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func refreshLetter() {
        if let latest = DataPersistenceManager.shared.loadUserLetters().first(where: { $0.id == letterID }) {
            letter = latest
            if let scheduledFor = latest.scheduledFor {
                scheduledDate = scheduledFor
            }
            loadStickerImages()
            loadPhotoImages()
        }
    }

    private func loadStickerImages() {
        var images: [UUID: UIImage] = [:]
        for block in letter.blocks where block.type == .sticker {
            if let imageID = block.stickerImageId,
               let image = DataPersistenceManager.shared.loadLetterStickerImage(id: imageID) {
                images[block.id] = image
            }
        }
        stickerImages = images
    }

    private func loadPhotoImages() {
        var images: [UUID: UIImage] = [:]
        for block in letter.blocks where block.type == .photo {
            if let imageID = block.photoImageId,
               let image = DataPersistenceManager.shared.loadLetterPhotoImage(id: imageID) {
                images[block.id] = image
            }
        }
        photoImages = images
    }

    private func saveRescheduledDate() {
        guard letter.isScheduled else { return }

        var updated = letter
        updated.scheduledFor = scheduledDate
        DataPersistenceManager.shared.updateUserLetter(updated)
        letter = updated
        onLetterUpdated?()
    }
}

#Preview {
    UserLetterDetailView(
        letter: UserLetter(
            id: UUID(),
            title: "Thinking of you",
            body: "Just wanted to say I love you and I am grateful for every moment we share together.",
            createdAt: Date(),
            scheduledFor: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            sentAt: nil
        )
    )
}
