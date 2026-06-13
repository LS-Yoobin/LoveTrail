import SwiftUI
import AVFoundation

struct VoiceMemoRecorderView: View {

    let existingFileId: String?
    var onSaved: (String) -> Void

    @StateObject private var recorder = VoiceRecorder()
    @State private var savedFileId: String?
    @State private var hasMicPermission: Bool = false
    @State private var pulseScale: CGFloat = 1.0

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
        VStack(spacing: 20) {
            waveformDisplay

            durationDisplay

            if phase != .saved {
                recordButton
                phaseHint
            } else {
                savedBadge
            }

            if phase == .saved {
                playbackControls
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(recorderBackground)
        .animation(.easeInOut(duration: 0.25), value: phase)
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
        .onChange(of: recorder.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulseScale = 1.12
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseScale = 1.0
                }
            }
        }
    }

    // MARK: - Visual Components

    private var recorderBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(BabyTownTheme.blushSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(BabyTownTheme.accent.opacity(phase == .recording ? 0.25 : 0.08), lineWidth: 1)
            )
    }

    private var waveformDisplay: some View {
        Image(systemName: "waveform")
            .font(.system(size: 36, weight: .light))
            .foregroundStyle(BabyTownTheme.accent.opacity(phase == .ready ? 0.3 : 0.85))
            .symbolEffect(.variableColor.iterative.reversing, isActive: phase == .recording || recorder.isPlaying)
            .frame(height: 40)
    }

    private var durationDisplay: some View {
        VStack(spacing: 4) {
            Text(durationString(recorder.recordingDuration))
                .font(.system(size: 44, weight: .thin, design: .monospaced))
                .foregroundStyle(phase == .recording ? BabyTownTheme.accent : BabyTownTheme.textPrimary)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: recorder.recordingDuration)

            if phase == .ready {
                Text("Up to 1 minute")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
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
                if phase == .recording {
                    Circle()
                        .stroke(BabyTownTheme.accent.opacity(0.2), lineWidth: 2)
                        .frame(width: 92, height: 92)
                        .scaleEffect(pulseScale)

                    Circle()
                        .trim(from: 0, to: min(recorder.recordingDuration / maxDuration, 1))
                        .stroke(BabyTownTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 92, height: 92)
                }

                Circle()
                    .fill(
                        phase == .recording
                            ? AnyShapeStyle(BabyTownTheme.accentDeep)
                            : AnyShapeStyle(BabyTownTheme.accentGradient)
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: BabyTownTheme.accent.opacity(phase == .recording ? 0.45 : 0.3), radius: 12, y: 4)

                Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var savedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("Recording saved")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(BabyTownTheme.accent)
    }

    private var phaseHint: some View {
        Text(phaseHintText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(phase == .recording ? BabyTownTheme.accent : BabyTownTheme.textTertiary)
    }

    private var phaseHintText: String {
        switch phase {
        case .ready: return "Tap to record"
        case .recording: return "Tap to finish"
        case .saved: return ""
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 20) {
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
                    Text(recorder.isPlaying ? "Pause" : "Play back")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(BabyTownTheme.accent))
            }
            .buttonStyle(.plain)

            Button("Re-record") {
                if let old = savedFileId {
                    DataPersistenceManager.shared.deletePreludeVoiceMemo(fileId: old)
                }
                savedFileId = nil
                recorder.deleteRecording()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(BabyTownTheme.textSecondary)
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func persistRecording() {
        let fileId = "\(UUID().uuidString).m4a"
        guard let tempPath = recorder.saveRecording(for: UUID()) else { return }
        let tempURL = URL(fileURLWithPath: tempPath)
        guard let data = try? Data(contentsOf: tempURL) else { return }
        try? FileManager.default.removeItem(at: tempURL)
        DataPersistenceManager.shared.savePreludeVoiceMemo(data: data, fileId: fileId)
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
