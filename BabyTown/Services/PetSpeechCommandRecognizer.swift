import AVFoundation
import Combine
import Speech

/// Listens for spoken trick commands while Trick Training mode is active.
@MainActor
final class PetSpeechCommandRecognizer: ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case listening
        case unavailable(String)
    }

    @Published private(set) var status: Status = .idle
    /// Latest words from the mic for the current utterance (updates on every partial result).
    @Published private(set) var liveTranscript: String?
    /// Smoothed microphone input level (0…1), driven by the live audio buffer so
    /// the UI can visualize that the mic is actively picking up the user's voice.
    @Published private(set) var audioLevel: CGFloat = 0

    var onCommand: ((PetTrick) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var lastFiredTrick: PetTrick?
    private var lastFiredAt: Date = .distantPast
    /// Prevents double-firing from partial + final results on the same utterance.
    private let commandCooldown: TimeInterval = 0.85
    /// Transcript text already handled — lets us keep one live session without compounding commands.
    private var consumedTranscriptPrefix = ""

    func start() {
        guard status != .listening else { return }
        status = .requestingPermission
        consumedTranscriptPrefix = ""
        Task { await beginListening() }
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        status = .idle
        liveTranscript = nil
        audioLevel = 0
        consumedTranscriptPrefix = ""
    }

    /// RMS power of an audio buffer mapped to a 0…1 range tuned for speech.
    private static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sumSquares: Float = 0
        for i in 0..<count {
            let sample = channel[i]
            sumSquares += sample * sample
        }
        let rms = (sumSquares / Float(count)).squareRoot()
        return min(1, max(0, CGFloat(rms) * 9))
    }

    /// Fast attack, slow decay so the level meter pops on speech but eases down.
    private func updateAudioLevel(_ instantaneous: CGFloat) {
        if instantaneous >= audioLevel {
            audioLevel = instantaneous
        } else {
            audioLevel = audioLevel * 0.78 + instantaneous * 0.22
        }
    }

    private func beginListening() async {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            status = .unavailable("Speech recognition isn't available right now.")
            return
        }

        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            status = .unavailable("Microphone access is needed to train tricks.")
            return
        }

        let speechGranted = await requestSpeechPermission()
        guard speechGranted else {
            status = .unavailable("Speech recognition access is needed to train tricks.")
            return
        }

        do {
            try configureAudioSession()
            try startRecognition(with: speechRecognizer)
            status = .listening
        } catch {
            status = .unavailable("Couldn't start listening. Try again.")
            stop()
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { auth in
                continuation.resume(returning: auth == .authorized)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition(with recognizer: SFSpeechRecognizer) throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { throw RecognitionError.requestFailed }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .confirmation
        recognitionRequest.contextualStrings = PetTrick.allCases.flatMap(\.voicePhrases)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            let level = Self.rmsLevel(buffer)
            Task { @MainActor in self?.updateAudioLevel(level) }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.handleTranscript(text, isFinal: result.isFinal)
                } else if let error, !Self.isBenignRecognitionError(error) {
                    self.recoverRecognition(after: error)
                }
            }
        }
    }

    /// Only the transcript spoken since the last successful command — avoids re-firing on old words.
    private func freshTranscriptSlice(from fullTranscript: String) -> String {
        let full = fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else { return "" }

        guard !consumedTranscriptPrefix.isEmpty else { return full }

        let consumed = consumedTranscriptPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerFull = full.lowercased()
        let lowerConsumed = consumed.lowercased()

        if lowerFull.hasPrefix(lowerConsumed) {
            var slice = String(full.dropFirst(consumed.count))
            slice = slice.trimmingCharacters(in: .whitespacesAndNewlines)
            return slice
        }

        // Apple sometimes replaces the whole string instead of appending — treat as new speech.
        consumedTranscriptPrefix = ""
        return full
    }

    private func markTranscriptConsumed(_ fullTranscript: String) {
        consumedTranscriptPrefix = fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = nil
    }

    private func handleTranscript(_ text: String, isFinal: Bool) {
        let slice = freshTranscriptSlice(from: text)
        guard !slice.isEmpty else { return }

        liveTranscript = PetTrickTrainingState.displayTranscript(slice)

        guard let trick = PetTrickTrainingState.trick(matching: slice, isFinal: isFinal) else { return }

        let now = Date()
        guard trick != lastFiredTrick || now.timeIntervalSince(lastFiredAt) >= commandCooldown else { return }

        lastFiredTrick = trick
        lastFiredAt = now
        markTranscriptConsumed(text)
        onCommand?(trick)
    }

    /// Restart the recognition task only after an unexpected failure — not between commands.
    private func recoverRecognition(after error: Error) {
        guard status == .listening, let speechRecognizer else { return }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        do {
            try configureAudioSession()
            try startRecognition(with: speechRecognizer)
        } catch {
            status = .unavailable("Listening stopped unexpectedly.")
            stop()
        }
    }

    private static func isBenignRecognitionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 209 || nsError.code == 216 {
            return true
        }
        if nsError.domain == "kLSRErrorDomain", nsError.code == 301 {
            return true
        }
        return false
    }

    private enum RecognitionError: Error {
        case requestFailed
    }
}
