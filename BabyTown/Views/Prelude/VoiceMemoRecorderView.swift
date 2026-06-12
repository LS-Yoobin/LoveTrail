import SwiftUI
import AVFoundation

struct VoiceMemoRecorderView: View {

    let existingFileId: String?
    var onSaved: (String) -> Void

    @StateObject private var recorder = VoiceRecorder()
    @State private var savedFileId: String?
    @State private var hasMicPermission: Bool = false

    private let maxDuration: TimeInterval = 180

    var body: some View {
        VStack(spacing: 24) {
            durationDisplay

            recordButton

            if recorder.hasRecording || savedFileId != nil {
                playbackControls
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
        .onAppear {
            checkMicPermission()
            if let fileId = existingFileId,
               let data = DataPersistenceManager.shared.loadPreludeVoiceMemoData(fileId: fileId) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileId)
                try? data.write(to: tempURL)
                recorder.loadRecording(from: tempURL.path)
                savedFileId = fileId
            }
        }
        .onChange(of: recorder.recordingDuration) { _, dur in
            if dur >= maxDuration {
                recorder.stopRecording()
                persistRecording()
            }
        }
    }

    private var durationDisplay: some View {
        Text(durationString(recorder.recordingDuration))
            .font(.system(size: 48, weight: .thin, design: .monospaced))
            .foregroundStyle(recorder.isRecording ? BabyTownTheme.accent : BabyTownTheme.textSecondary)
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording()
                persistRecording()
            } else {
                if hasMicPermission {
                    if let old = savedFileId {
                        DataPersistenceManager.shared.deletePreludeVoiceMemo(fileId: old)
                        savedFileId = nil
                        recorder.deleteRecording()
                    }
                    recorder.startRecording()
                } else {
                    requestMicPermission()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? BabyTownTheme.accentDeep : BabyTownTheme.accent)
                    .frame(width: 72, height: 72)

                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 8, y: 4)
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button {
                if recorder.isPlaying {
                    recorder.stopPlaying()
                } else {
                    recorder.playRecording()
                }
            } label: {
                Image(systemName: recorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            .buttonStyle(.plain)

            Button {
                if let old = savedFileId {
                    DataPersistenceManager.shared.deletePreludeVoiceMemo(fileId: old)
                }
                savedFileId = nil
                recorder.deleteRecording()
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func persistRecording() {
        let fileId = "\(UUID().uuidString).m4a"
        guard let tempPath = recorder.saveRecording(for: UUID()) else { return }
        let tempURL = URL(fileURLWithPath: tempPath)
        guard let data = try? Data(contentsOf: tempURL) else { return }
        DataPersistenceManager.shared.savePreludeVoiceMemo(data: data, fileId: fileId)
        savedFileId = fileId
        onSaved(fileId)
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - floor(duration)) * 10)
        return String(format: "%01d:%02d.%01d", minutes, seconds, tenths)
    }

    private func checkMicPermission() {
        hasMicPermission = AVAudioSession.sharedInstance().recordPermission == .granted
    }

    private func requestMicPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in self.hasMicPermission = granted }
        }
    }
}

#Preview {
    VoiceMemoRecorderView(existingFileId: nil, onSaved: { _ in })
        .padding()
}
