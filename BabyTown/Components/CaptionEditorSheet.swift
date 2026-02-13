import SwiftUI
import AVFoundation

struct CaptionEditorSheet: View {
    
    let section: DaySection
    var onSave: (UUID, String, String?) -> Void
    var onAddPhotos: (([UIImage]) -> Void)?
    var onRemovePhoto: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var captionText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var voiceRecorder = VoiceRecorder()
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
                                    .fill(Color(.systemGray6))
                            )
                            .lineLimit(3...6)
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    voiceNoteSection
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        voiceRecorder.deleteRecording()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let firstMoment = section.moments.first {
                            let audioPath = voiceRecorder.saveRecording(for: firstMoment.id)
                            onSave(firstMoment.id, captionText, audioPath)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                captionText = section.moments.first?.caption ?? ""
                if let voicePath = section.moments.first?.voiceNotePath {
                    voiceRecorder.loadRecording(from: voicePath)
                }
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
    
    private var voiceNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.accent)
                Text("Voice Love Note")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            HStack(spacing: 12) {
                if voiceRecorder.isRecording {
                    recordingIndicator
                } else if voiceRecorder.hasRecording {
                    playbackControls
                } else {
                    recordButton
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var recordButton: some View {
        Button {
            voiceRecorder.startRecording()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                Text("Record Voice Note")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BabyTownTheme.accentGradient)
            )
        }
    }
    
    private var recordingIndicator: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text(formatDuration(voiceRecorder.recordingDuration))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.red)
            }
            
            Spacer()
            
            Button {
                voiceRecorder.stopRecording()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.red)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                if voiceRecorder.isPlaying {
                    voiceRecorder.stopPlaying()
                } else {
                    voiceRecorder.playRecording()
                }
            } label: {
                Image(systemName: voiceRecorder.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(BabyTownTheme.accentGradient)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Note")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black)
                Text(formatDuration(voiceRecorder.recordingDuration))
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Button {
                voiceRecorder.deleteRecording()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
