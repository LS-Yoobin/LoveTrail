import SwiftUI
import AVFoundation

struct VoiceMemoPlayerView: View {
    let fileId: String
    var storage: VoiceMemoStorage = .letter

    @StateObject private var recorder = VoiceRecorder()
    @State private var isLoaded = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.85))
                .symbolEffect(.variableColor.iterative.reversing, isActive: recorder.isPlaying)

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice message")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text(durationString(recorder.recordingDuration))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

            Spacer()

            Button {
                if recorder.isPlaying {
                    recorder.stopPlaying()
                } else {
                    recorder.playRecording()
                }
            } label: {
                Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(BabyTownTheme.accent))
            }
            .buttonStyle(.plain)
            .disabled(!isLoaded)
            .opacity(isLoaded ? 1 : 0.45)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.blushSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BabyTownTheme.accent.opacity(0.12), lineWidth: 1)
        )
        .onAppear(perform: loadRecording)
    }

    private func loadRecording() {
        guard let data = storage.load(fileId: fileId) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileId)
        try? data.write(to: tempURL)
        recorder.loadRecording(from: tempURL.path)
        isLoaded = true
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VoiceMemoPlayerView(fileId: "preview.m4a")
        .padding()
}
