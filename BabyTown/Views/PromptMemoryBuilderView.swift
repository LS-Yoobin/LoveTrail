import SwiftUI
import PhotosUI
import Photos
import CoreLocation

struct PromptMemoryBuilderView: View {
    
    let promptText: String
    var onSave: (PromptMemory) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var placeName: String = "Somewhere with you"
    @State private var loveNote: String = ""
    @State private var selectedPhotos: [PromptPhoto] = []
    @State private var showPhotoPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isLoadingLocation = false
    @FocusState private var isNoteFieldFocused: Bool
    
    private var laTimeZone: TimeZone {
        TimeZone(identifier: "America/Los_Angeles")!
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                promptHeader
                dateSection
                placeSection
                loveNoteSection
                photoSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .background(BabyTownTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Create Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
        .onChange(of: photoPickerItems) { _, newItems in
            Task {
                await loadPhotos(from: newItems)
            }
        }
    }
    
    // MARK: - Prompt Header
    
    private var promptHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Prompt")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .textCase(.uppercase)
            
            Text(promptText)
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                )
        }
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .textCase(.uppercase)
            
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .environment(\.timeZone, laTimeZone)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
        }
    }
    
    // MARK: - Place Section
    
    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Place")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.accent)
                
                if isLoadingLocation {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding location...")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                } else {
                    Text("Near \(placeName)")
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
        }
    }
    
    // MARK: - Love Note Section
    
    private var loveNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Love Note")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .textCase(.uppercase)
            
            TextEditor(text: $loveNote)
                .font(.system(size: 15))
                .foregroundStyle(.black)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.systemGray5), lineWidth: 1)
                )
                .focused($isNoteFieldFocused)
                .overlay(alignment: .topLeading) {
                    if loveNote.isEmpty {
                        Text("Write something sweet about this memory...")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.placeholderText))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .textCase(.uppercase)
            
            if selectedPhotos.isEmpty {
                selectPhotosButton
            } else {
                photoGrid
                addMoreButton
            }
        }
    }
    
    private var selectPhotosButton: some View {
        PhotosPicker(
            selection: $photoPickerItems,
            maxSelectionCount: 10,
            matching: .images
        ) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18))
                Text("Select Photos")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(BabyTownTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(BabyTownTheme.accent, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BabyTownTheme.accentSoft)
                    )
            )
        }
    }
    
    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(selectedPhotos) { photo in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        selectedPhotos.removeAll { $0.id == photo.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 20, height: 20)
                            )
                    }
                    .padding(6)
                }
            }
        }
    }
    
    private var addMoreButton: some View {
        PhotosPicker(
            selection: $photoPickerItems,
            maxSelectionCount: 10,
            matching: .images
        ) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add More Photos")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(BabyTownTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(BabyTownTheme.accentSoft)
            )
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            saveMemory()
        } label: {
            Text("Save Memory")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(canSave ? BabyTownTheme.accentGradient : LinearGradient(colors: [Color(.systemGray4)], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: canSave ? BabyTownTheme.buttonShadow : .clear, radius: 12, y: 6)
                )
        }
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(BabyTownTheme.background)
    }
    
    private var canSave: Bool {
        !loveNote.isEmpty && !selectedPhotos.isEmpty
    }
    
    // MARK: - Actions
    
    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                
                let photo = PromptPhoto(
                    dateTaken: selectedDate,
                    thumbnail: image,
                    assetIdentifier: nil
                )
                
                if !selectedPhotos.contains(where: { $0.id == photo.id }) {
                    selectedPhotos.append(photo)
                }
            }
        }
        
        if selectedPhotos.count == 1 {
            await extractLocation(from: items.first)
        }
        
        photoPickerItems = []
    }
    
    private func extractLocation(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isLoadingLocation = true
        
        if let assetId = item.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject, let location = asset.location {
                let geocoder = CLGeocoder()
                if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                    let name = placemark.name
                        ?? placemark.locality
                        ?? placemark.subLocality
                        ?? placemark.administrativeArea
                    
                    if let name = name {
                        await MainActor.run {
                            placeName = name
                        }
                    }
                }
            }
        }
        
        isLoadingLocation = false
    }
    
    private func saveMemory() {
        let memory = PromptMemory(
            promptText: promptText,
            date: selectedDate,
            placeName: placeName == "Somewhere with you" ? nil : placeName,
            loveNote: loveNote,
            photos: selectedPhotos
        )
        
        onSave(memory)
        dismiss()
    }
}
