import SwiftUI

struct PreludeChapterView: View {

    let chapter: PreludeChapter
    let captures: [PreludeCapture]
    var isReadOnly: Bool = false
    var onDismiss: () -> Void

    private var giftCaptures: [PreludeCapture] {
        let ids = Set(chapter.giftCaptureIds)
        return captures
            .filter { ids.contains($0.id) || $0.isPartnerRetroactive }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    chapterHeader
                        .padding(.horizontal, 24)

                    Divider().padding(.horizontal, 24)

                    ForEach(giftCaptures) { capture in
                        chapterCaptureRow(capture)
                            .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Before We Were Official")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before We Were Official")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Text("\(chapter.startDate, style: .date) – \(chapter.officialDate, style: .date)")
                .font(.system(size: 13))
                .foregroundStyle(BabyTownTheme.textSecondary)

            if isReadOnly {
                Label("Read-only", systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
    }

    private func chapterCaptureRow(_ capture: PreludeCapture) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Image(systemName: capture.typeIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(capture.isPartnerRetroactive ? .purple : BabyTownTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(capture.isPartnerRetroactive ? Color.purple.opacity(0.1) : BabyTownTheme.accentSoft)
                    )

                if capture.isPartnerRetroactive {
                    Text("Partner")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.purple)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(capture.isPartnerRetroactive ? .purple : BabyTownTheme.accent)
                    .textCase(.uppercase)

                Text(capture.displayTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text(capture.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
    }
}

#Preview {
    PreludeChapterView(
        chapter: PreludeChapter(
            startDate: Date().addingTimeInterval(-60 * 60 * 24 * 30),
            officialDate: Date(),
            creatorUserId: "local",
            partnerUserId: "partner",
            giftCaptureIds: []
        ),
        captures: [
            PreludeCapture(type: .note, isIncludedInGift: true, noteText: "I keep thinking about the way you laugh."),
            PreludeCapture(type: .reason, isIncludedInGift: true, reasonText: "You remember everything I've told you.")
        ],
        onDismiss: {}
    )
}
