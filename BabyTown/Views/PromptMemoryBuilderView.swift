import SwiftUI
import PhotosUI
import Photos
import CoreLocation
import MapKit

struct PromptMemoryBuilderView: View {
    
    let promptText: String
    var onSave: (PromptMemory) -> Void
    var preSelectedPhotos: [PromptPhoto]?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var placeName: String = "Somewhere with you"
    @State private var loveNote: String = ""
    @State private var selectedPhotos: [PromptPhoto] = []
    @State private var showPhotoSelection = false
    @State private var isLoadingLocation = false
    @State private var latitude: Double?
    @State private var longitude: Double?
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
        .navigationDestination(isPresented: $showPhotoSelection) {
            PromptPhotoSelectionView(
                onBack: {
                    showPhotoSelection = false
                },
                onSavePhotos: { photos in
                    selectedPhotos = photos
                    if let firstPhoto = photos.first {
                        Task {
                            await extractLocationFromAsset(firstPhoto.assetIdentifier)
                            // Store photo coordinates to memory if provided
                            self.latitude = firstPhoto.latitude
                            self.longitude = firstPhoto.longitude
                        }
                    }
                    showPhotoSelection = false
                }
            )
            .navigationBarBackButtonHidden(true)
        }
        .onAppear {
            if let preSelected = preSelectedPhotos, !preSelected.isEmpty {
                selectedPhotos = preSelected
                if let firstPhoto = preSelected.first {
                    Task {
                        await extractLocationFromAsset(firstPhoto.assetIdentifier)
                        // Preserve coordinates from pre-selected photo
                        self.latitude = firstPhoto.latitude
                        self.longitude = firstPhoto.longitude
                    }
                }
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
        Button {
            showPhotoSelection = true
        } label: {
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
        Button {
            showPhotoSelection = true
        } label: {
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
    
    private func extractLocationFromAsset(_ assetIdentifier: String?) async {
        guard let assetId = assetIdentifier else { return }
        
        isLoadingLocation = true
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        if let asset = fetchResult.firstObject, let location = asset.location {
            if let request = MKReverseGeocodingRequest(location: location) {
                do {
                    let mapItems = try await request.mapItems
                    if let mapItem = mapItems.first {
                        let name = mapItem.name
                            ?? mapItem.placemark.locality
                            ?? mapItem.placemark.subLocality
                            ?? mapItem.placemark.administrativeArea
                        
                        if let name = name {
                            await MainActor.run {
                                placeName = name
                                self.latitude = location.coordinate.latitude
                                self.longitude = location.coordinate.longitude
                            }
                        }
                    }
                } catch {
                    print("Failed to reverse geocode location:", error)
                }
            }
        }
        
        await MainActor.run {
            isLoadingLocation = false
        }
    }
    
    private func saveMemory() {
        let memory = PromptMemory(
            promptText: promptText,
            date: selectedDate,
            placeName: placeName == "Somewhere with you" ? nil : placeName,
            loveNote: loveNote,
            photos: selectedPhotos,
            latitude: latitude,
            longitude: longitude
        )
        
        onSave(memory)
        dismiss()
    }
}
