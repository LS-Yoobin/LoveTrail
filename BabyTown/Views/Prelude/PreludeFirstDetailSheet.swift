import SwiftUI

struct PreludeFirstDetailSheet: View {

    let capture: PreludeCapture
    var onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var photo: UIImage? {
        guard let id = capture.firstPhotoId else { return nil }
        return DataPersistenceManager.shared.loadPreludePhoto(photoId: id)
    }

    private var displayDate: Date {
        capture.firstDate ?? capture.createdAt
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    photoOrPlaceholder
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(Self.dateFormatter.string(from: displayDate))
                            .font(.system(size: 13))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                            .padding(.top, 20)

                        Text(capture.firstLabel ?? "A First")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }

            editButton
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
        }
        .background(BabyTownTheme.cardBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        Capsule()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 14)
            .padding(.bottom, 20)
    }

    @ViewBuilder
    private var photoOrPlaceholder: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BabyTownTheme.accent.opacity(0.12),
                            BabyTownTheme.accent.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .overlay {
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.35))
                }
        }
    }

    private var editButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onEdit()
            }
        } label: {
            Text("Edit")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BabyTownTheme.accentGradient)
                )
        }
        .buttonStyle(.plain)
    }
}
