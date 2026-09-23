import SwiftUI
import AVFoundation

struct VoiceMemoRecorderView: View {

    let existingFileId: String?
    var storage: VoiceMemoStorage = .prelude
    var onSaved: (String) -> Void

    @StateObject private var recorder = VoiceRecorder()
    @State private var savedFileId: String?
    @State private var hasMicPermission: Bool = false
    /// 0 = ring at rest, 1 = ring fully expanded and faded out.
    @State private var ringPhase: CGFloat = 0

    private let maxDuration: TimeInterval = 60

    private enum Phase {
        case ready, recording, saved
    }

    private var phase: Phase {
        if recorder.isRecording { return .recording }
        if recorder.hasRecording || savedFileId != nil { return .saved }
        return .ready
    }

    var body: some View {
        VStack(spacing: 0) {
            PreludeWaveBars(isLive: recorder.isRecording || recorder.isPlaying)

            durationDisplay
                .padding(.top, 29)

            statusLine
                .padding(.top, 14)

            if phase == .saved {
                playbackControls
                    .padding(.top, 96)
                    .transition(.opacity)
            } else {
                recordStage
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .onAppear {
            checkMicPermission()
            if let fileId = existingFileId,
               let data = storage.load(fileId: fileId) {
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
        .onChange(of: recorder.isRecording) { _, isRecording in
            if isRecording {
                ringPhase = 0
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    ringPhase = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    ringPhase = 0
                }
            }
        }
    }

    // MARK: - Visual Components

    /// Timer. Counts up while recording, then holds the take's length.
    private var durationDisplay: some View {
        Text(durationString(recorder.recordingDuration))
            .font(.system(size: 41, weight: .regular))
            .foregroundStyle(PreludePalette.timerInk)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.1), value: recorder.recordingDuration)
    }

    /// "UP TO 1 MINUTE" until there is a take, then the saved badge.
    @ViewBuilder
    private var statusLine: some View {
        if phase == .saved {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                Text("Voicemail Saved")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(PreludePalette.savedRed)
        } else {
            Text("UP TO 1 MINUTE")
                .font(.system(size: 11))
                .tracking(1.3)
                .foregroundStyle(PreludePalette.captionInk)
        }
    }

    /// The rotary phone with the record button seated on it. Lifting the
    /// handset is what recording looks like: the on-hook art is swapped for the
    /// off-hook handset sliding in at the bottom.
    private var recordStage: some View {
        ZStack(alignment: .top) {
            if recorder.isRecording {
                Image("voice_handset_offhook")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 286)
                    .offset(x: -53.5, y: 183)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            } else {
                Image("voice_phone_onhook")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 252)
                    // The artwork has the red button baked into it, 34.5pt
                    // right of its centre. Shifting the phone left by exactly
                    // that puts the baked button on the container's centre
                    // line, where the live button is drawn — so the two land
                    // on top of each other and read as one button.
                    .offset(x: -34.5, y: 13)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if recorder.isRecording {
                Circle()
                    .strokeBorder(PreludePalette.wavePink, lineWidth: 1.5)
                    .frame(width: 92, height: 92)
                    .scaleEffect(1 + 0.13 * ringPhase)
                    .opacity(0.9 - 0.9 * Double(ringPhase))
                    .offset(y: 32.5)
                    .allowsHitTesting(false)
            }

            recordButton
                .offset(y: 41.5)

            Text(recorder.isRecording ? "Tap to finish" : "Tap to record a voicemail")
                .font(.system(size: 11))
                .foregroundStyle(recorder.isRecording
                                 ? PreludePalette.savedRed
                                 : PreludePalette.captionInk)
                .offset(y: recorder.isRecording ? 145 : 158)
        }
        .frame(height: 250)
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording()
                persistRecording()
            } else {
                if hasMicPermission {
                    if let old = savedFileId {
                        storage.delete(fileId: old)
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
                    .fill(PreludePalette.recordRed)
                    .frame(width: 74, height: 74)
                    .shadow(color: PreludePalette.recordRed.opacity(0.28), radius: 7, y: 4)

                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var playbackControls: some View {
        HStack(spacing: 63) {
            Button {
                if recorder.isPlaying {
                    recorder.stopPlaying()
                } else {
                    recorder.playRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(recorder.isPlaying ? "Playing" : "Play back")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 39)
                .background(Capsule().fill(PreludePalette.savedRed))
            }
            .buttonStyle(.plain)

            Button("Re-record") {
                if let old = savedFileId {
                    storage.delete(fileId: old)
                }
                savedFileId = nil
                recorder.deleteRecording()
            }
            .font(.system(size: 15))
            .foregroundStyle(PreludePalette.rerecordInk)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func persistRecording() {
        let fileId = "\(UUID().uuidString).m4a"
        guard let tempPath = recorder.saveRecording(for: UUID()) else { return }
        let tempURL = URL(fileURLWithPath: tempPath)
        guard let data = try? Data(contentsOf: tempURL) else { return }
        try? FileManager.default.removeItem(at: tempURL)
        storage.save(data: data, fileId: fileId)
        savedFileId = fileId
        onSaved(fileId)
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
