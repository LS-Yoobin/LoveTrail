import SwiftUI

struct CaptionEditorSheet: View {
    
    let section: DaySection
    var onSave: (UUID, String) -> Void
    var onAddPhotos: (([UIImage]) -> Void)?
    var onRemovePhoto: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var captionText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showPhotoPicker = false
    @State private var selectedImages: [UIImage] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoManagementSection
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a love note for this memory")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                        
                        TextField("Type your caption here...", text: $captionText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray4))
                            )
                            .lineLimit(3...6)
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let firstMoment = section.moments.first {
                            onSave(firstMoment.id, captionText)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                captionText = section.moments.first?.caption ?? ""
                isTextFieldFocused = true
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView(selectedImages: $selectedImages, selectionLimit: 10)
                    .onDisappear {
                        if !selectedImages.isEmpty {
                            onAddPhotos?(selectedImages)
                            selectedImages = []
                        }
                    }
            }
        }
        .presentationDetents([.large])
    }
    
    private var photoManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.accent)
                Text("Photos in this Memory")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(section.moments.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(section.moments) { moment in
                        photoThumbnail(moment)
                    }
                    
                    addPhotoButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private func photoThumbnail(_ moment: Moment) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            if section.moments.count > 1 {
                Button {
                    onRemovePhoto?(moment.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 20, height: 20)
                        )
                }
                .offset(x: 5, y: -5)
            }
        }
    }
    
    private var addPhotoButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("Add")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(BabyTownTheme.accent)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(BabyTownTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BabyTownTheme.accent.opacity(0.1))
                    )
            )
        }
    }
    

}
