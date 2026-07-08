import AVFoundation
import SwiftUI

/// Paged parchment reader for prelude gift captures — used in partner onboarding
/// and when reopening the gift from Secret Garden.
struct PreludeGiftBookView: View {
    var onComplete: () -> Void
    var completeButtonTitle: String = "Open our space"

    @State private var captures: [PreludeCapture] = []
    @State private var currentIndex = 0
    @State private var giftSong: PreludeGiftSong?
    @State private var giftSongPlayer: AVAudioPlayer?
    @State private var isGiftSongPlaying = false
    @State private var voiceMemoPlayer: AVAudioPlayer?
    @State private var isVoiceMemoPlaying = false
    #if DEBUG
    @AppStorage("debugPreludePhotoLoadSource") private var debugPhotoLoadSource = PreludePhotoLoader.PhotoLoadSource.localFirst.rawValue
    #endif

    private static let parchmentGradient = LinearGradient(
        colors: [
            Color(red: 0.992, green: 0.965, blue: 0.925),
            Color(red: 0.973, green: 0.910, blue: 0.816),
            Color(red: 0.953, green: 0.875, blue: 0.753)
        ],
        startPoint: .top,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Self.parchmentGradient
                .ignoresSafeArea()

            ZStack {
                ruledLines()
                parchmentPage()
            }
        }
        .overlay(alignment: .topTrailing) {
            if giftSong != nil {
                VinylRecordPlayerView(isPlaying: isGiftSongPlaying, scale: 1.0)
                    .padding(16)
            }
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            debugPhotoSourcePicker
                .padding(.top, 56)
                .padding(.leading, 16)
        }
        #endif
        .task {
            await refreshCapturesAndGiftSong()
        }
        .onDisappear {
            stopGiftSongPlayback()
            stopVoiceMemoPlayback()
        }
    }

    private func refreshCapturesAndGiftSong() async {
        let dpm = DataPersistenceManager.shared
        if await AuthService.shared.authToken != nil {
            if let serverCaptures = try? await PreludeAPIClient.shared.listOwnCaptureSummaries() {
                dpm.mergeServerPhotoPaths(from: serverCaptures)
            }
        }
        captures = dpm.loadAccessiblePreludeGiftCaptures()
        giftSong = dpm.loadPreludeGiftSong()
        if giftSong != nil {
            startGiftSongPlayback()
        }
    }

    private func ruledLines() -> some View {
        Canvas { ctx, size in
            let lineCount = Int(size.height / 28) + 1
            for i in 0..<lineCount {
                let y = CGFloat(i) * 28
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(
                    path,
                    with: .color(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.06)),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }

    private func parchmentPage() -> some View {
        VStack(spacing: 0) {
            if captures.count > 1 {
                Text("PAGE \(currentIndex + 1) OF \(captures.count)")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.4))
                    .tracking(2)
                    .padding(.top, 60)
            } else {
                Spacer().frame(height: 60)
            }

            Spacer()

            if captures.isEmpty {
                Text("Nothing here yet. Check back soon.")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Color(red: 0.239, green: 0.094, blue: 0.000))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                captureContent(captures[currentIndex])
            }

            Spacer()

            navigationRow
                .padding(.bottom, 52)
        }
    }

    private func captureContent(_ capture: PreludeCapture) -> some View {
        VStack(spacing: 12) {
            if capture.firstPhotoId != nil || capture.notePhotoId != nil || capture.remotePhotoPath != nil {
                PreludeCapturePhotoView(capture: capture, height: 180, cornerRadius: 12)
            } else {
                Image(systemName: capture.typeIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(BabyTownTheme.accent)
            }

            Text(capture.typeLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.761, green: 0.392, blue: 0.165))
                .tracking(2)

            if capture.type != .voiceMemo || capture.voiceMemoFileId == nil {
                Text(capture.displayTitle)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Color(red: 0.239, green: 0.094, blue: 0.000))
                    .lineSpacing(17 * 0.6)
                    .lineLimit(6)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if capture.type == .voiceMemo, capture.voiceMemoFileId != nil {
                Button(action: toggleVoiceMemoPlayback) {
                    HStack(spacing: 8) {
                        Image(systemName: isVoiceMemoPlaying ? "pause.fill" : "play.fill")
                        Text(isVoiceMemoPlaying ? "Playing…" : "Play voice memo")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.761, green: 0.392, blue: 0.165))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.761, green: 0.392, blue: 0.165).opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }

            Text(capture.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Color(red: 0.627, green: 0.439, blue: 0.314))
        }
    }

    private func toggleVoiceMemoPlayback() {
        guard captures.indices.contains(currentIndex) else { return }
        let capture = captures[currentIndex]
        guard let fileId = capture.voiceMemoFileId else { return }
        if isVoiceMemoPlaying {
            stopVoiceMemoPlayback()
        } else {
            playVoiceMemo(fileId: fileId)
        }
    }

    private func playVoiceMemo(fileId: String) {
        let url = DataPersistenceManager.shared.preludeVoiceMemoFileURL(fileId: fileId)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        stopGiftSongPlayback()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            voiceMemoPlayer = try AVAudioPlayer(contentsOf: url)
            voiceMemoPlayer?.play()
            isVoiceMemoPlaying = true
        } catch {
            // silent failure — scrapbook remains usable
        }
    }

    private func stopVoiceMemoPlayback() {
        voiceMemoPlayer?.stop()
        voiceMemoPlayer = nil
        isVoiceMemoPlaying = false
    }

    private var navigationRow: some View {
        HStack {
            Button {
                stopVoiceMemoPlayback()
                withAnimation(.easeInOut(duration: 0.25)) { currentIndex -= 1 }
            } label: {
                Text("\u{2190} Prev Page")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Color(red: 0.392, green: 0.235, blue: 0.078))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.10))
                    )
            }
            .opacity(currentIndex == 0 ? 0 : 1)
            .allowsHitTesting(currentIndex != 0)

            Spacer()

            if captures.isEmpty || currentIndex == captures.count - 1 {
                Button(action: onComplete) {
                    Text(completeButtonTitle)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(AnyShapeStyle(BabyTownTheme.accentGradient))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    stopVoiceMemoPlayback()
                    withAnimation(.easeInOut(duration: 0.25)) { currentIndex += 1 }
                } label: {
                    Text("Next Page \u{2192}")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.761, green: 0.392, blue: 0.165))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
    }

    private func startGiftSongPlayback() {
        let url = DataPersistenceManager.shared.preludeGiftSongAudioURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            giftSongPlayer = try AVAudioPlayer(contentsOf: url)
            giftSongPlayer?.numberOfLoops = -1
            giftSongPlayer?.play()
            isGiftSongPlaying = true
        } catch {
            // silent failure — vinyl won't spin but scrapbook remains usable
        }
    }

    private func stopGiftSongPlayback() {
        giftSongPlayer?.stop()
        giftSongPlayer = nil
        isGiftSongPlaying = false
    }

    #if DEBUG
    private var debugPhotoSourcePicker: some View {
        Picker("Photo source", selection: $debugPhotoLoadSource) {
            ForEach(PreludePhotoLoader.PhotoLoadSource.allCases, id: \.rawValue) { source in
                Text(source.label).tag(source.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
        .accessibilityLabel("Debug photo source")
    }
    #endif
}
