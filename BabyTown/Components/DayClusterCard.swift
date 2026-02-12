import SwiftUI

struct DayClusterCard: View {

    let section: DaySection
    var onOpenPhoto: (Moment, [Moment]) -> Void
    var onEditCaption: ((UUID, String, String?) -> Void)? = nil
    var isLeftAligned: Bool = true
    
    @State private var showCaptionEditor = false

    var body: some View {
        ZStack(alignment: isLeftAligned ? .trailing : .leading) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                collageView
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius)
                    .fill(BabyTownTheme.cardBackground)
                    .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 4)
            )
            
            connectorNode
                .offset(x: isLeftAligned ? 12 : -12)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
    
    private var connectorNode: some View {
        ZStack {
            Circle()
                .fill(BabyTownTheme.accent.opacity(0.2))
                .frame(width: 24, height: 24)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.6))
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.displayTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)

            Text(locationText)
                .font(.system(size: 12))
                .foregroundStyle(.black)
            
            Button {
                showCaptionEditor = true
            } label: {
                Text(captionText)
                    .font(.system(size: 12))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showCaptionEditor) {
            CaptionEditorSheet(section: section, onSave: { momentId, newCaption, voicePath in
                onEditCaption?(momentId, newCaption, voicePath)
            })
        }
    }
    
    private var locationText: String {
        if let placeName = section.moments.first?.placeName, !placeName.isEmpty {
            return "Near \(placeName)"
        }
        return "Near Unknown Location"
    }
    
    private var captionText: String {
        if let caption = section.moments.first?.caption, !caption.isEmpty {
            return caption
        }
        return "Add Love Note or Spunky Will Bite"
    }

    // MARK: - Collage

    @ViewBuilder
    private var collageView: some View {
        let photos = Array(section.moments.prefix(6))

        switch photos.count {
        case 1:
            singleLayout(photos[0])
        case 2:
            twoLayout(photos)
        case 3:
            threeLayout(photos)
        default:
            gridLayout(photos)
        }
    }

    // 1 photo — full width
    private func singleLayout(_ moment: Moment) -> some View {
        photoButton(moment)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 2 photos — side by side
    private func twoLayout(_ moments: [Moment]) -> some View {
        HStack(spacing: 3) {
            photoButton(moments[0])
            photoButton(moments[1])
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 3 photos — hero top, two below
    private func threeLayout(_ moments: [Moment]) -> some View {
        VStack(spacing: 3) {
            photoButton(moments[0])
                .frame(height: 120)

            HStack(spacing: 3) {
                photoButton(moments[1])
                photoButton(moments[2])
            }
            .frame(height: 85)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 4-6 photos — balanced rows
    private func gridLayout(_ moments: [Moment]) -> some View {
        let topCount = (moments.count + 1) / 2
        let topRow = Array(moments.prefix(topCount))
        let bottomRow = Array(moments.suffix(moments.count - topCount))

        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(topRow) { photoButton($0) }
            }
            .frame(height: 95)

            if !bottomRow.isEmpty {
                HStack(spacing: 3) {
                    ForEach(bottomRow) { photoButton($0) }
                }
                .frame(height: 95)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Photo Button

    private func photoButton(_ moment: Moment) -> some View {
        Button {
            onOpenPhoto(moment, section.moments)
        } label: {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let sections = DaySection.grouped(from: Moment.sampleMoments)
    ScrollView {
        VStack(spacing: 20) {
            ForEach(sections) { section in
                DayClusterCard(section: section) { moment, all in
                    print("Open \(moment.id) from \(all.count)")
                }
            }
        }
        .padding(20)
    }
}
