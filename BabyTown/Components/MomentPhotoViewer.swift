import SwiftUI
import Photos
import PhotosUI

struct MomentPhotoViewer: View {
    
    let moments: [Moment]
    let initialIndex: Int
    var onDismiss: () -> Void
    var onUpdateMoments: ([Moment]) -> Void
    
    @State private var currentIndex: Int
    @State private var editMode = false
    @State private var editingCaption = false
    @State private var captionText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var updatedMoments: [Moment]
    
    init(
        moments: [Moment],
        initialIndex: Int,
        onDismiss: @escaping () -> Void,
        onUpdateMoments: @escaping ([Moment]) -> Void
    ) {
        self.moments = moments
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self.onUpdateMoments = onUpdateMoments
        _currentIndex = State(initialValue: initialIndex)
        _updatedMoments = State(initialValue: moments)
    }
    
    var currentMoment: Moment {
        updatedMoments[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(updatedMoments.enumerated()), id: \.element.id) { index, moment in
                    photoView(for: moment)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                topBar
                Spacer()
                if editMode {
                    editControls
                }
            }
        }
        .statusBarHidden(true)
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                await handlePhotoSelection(newItems)
            }
        }
    }
    
    // MARK: - Photo View
    
    private func photoView(for moment: Moment) -> some View {
        Image(uiImage: moment.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: {
                if editMode {
                    onUpdateMoments(updatedMoments)
                }
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))
            }
            
            Spacer()
            
            Button(action: {
                editMode.toggle()
            }) {
                Text(editMode ? "Done" : "Edit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(editMode ? Color.green.opacity(0.3) : Color.white.opacity(0.2))
                    )
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Edit Controls
    
    private var editControls: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Caption")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack {
                    Text(currentMoment.caption ?? "Add Love Note or Spunky Will Bite")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button {
                        captionText = currentMoment.caption ?? ""
                        editingCaption = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                )
            }
            
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 1,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16))
                    Text("Replace Photo")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .sheet(isPresented: $editingCaption) {
            captionEditorSheet
        }
    }
    
    // MARK: - Caption Editor
    
    private var captionEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit your love note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                    
                    TextField("Type your caption here...", text: $captionText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .lineLimit(3...6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Edit Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingCaption = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updatedMoments[currentIndex].caption = captionText.isEmpty ? nil : captionText
                        editingCaption = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(280)])
    }
    
    // MARK: - Photo Selection
    
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            updatedMoments[currentIndex] = Moment(
                id: updatedMoments[currentIndex].id,
                dateTaken: updatedMoments[currentIndex].dateTaken,
                assetIdentifier: nil,
                thumbnail: image,
                placeName: updatedMoments[currentIndex].placeName,
                caption: updatedMoments[currentIndex].caption
            )
        }
        
        selectedPhotos = []
    }
}
