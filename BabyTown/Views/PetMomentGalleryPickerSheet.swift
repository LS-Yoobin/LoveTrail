import SwiftUI

/// Pick a Baby Town photo to display in the purchased memory frame.
struct PetMomentGalleryPickerSheet: View {

    var onSelect: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photos: [PetGalleryPhoto] = []

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    ContentUnavailableView(
                        "No moments yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Add memories on the home feed, then come back to fill your frame.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photos) { photo in
                                Button {
                                    onSelect(photo.id)
                                    dismiss()
                                } label: {
                                    Image(uiImage: photo.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(BabyTownTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Choose a moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                photos = PetGalleryPhotoLoader.loadAllPhotos()
            }
        }
    }
}
