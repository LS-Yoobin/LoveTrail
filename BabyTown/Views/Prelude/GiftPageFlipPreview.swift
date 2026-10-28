import AVFoundation
import Combine
import SwiftUI

// MARK: - GiftPageFlipPreview

/// Gift step two, opened by Create on `GiftCurationView`: every included
/// capture as a page of a ring-bound notebook, oldest first. Swipe, or tap the
/// right / left half of the page, to turn; each turn plays the eight-frame
/// `gift_page_turn_N` sprite. Voice memos start playing when their page lands,
/// and the gift song (if one was added) runs underneath, ducked while a memo
/// plays.
struct GiftPageFlipPreview: View {
    /// Already filtered to the gift and sorted oldest first.
    let captures: [PreludeCapture]
    var giftSong: PreludeGiftSong?
    var onDone: () -> Void

    @StateObject private var audio = GiftPreviewAudio()
    @State private var index = 0
    @State private var frame = 1
    @State private var isTurning = false
    @State private var contentVisible = true

    /// Per sprite frame. Seven frames ≈ 0.42s for a full turn.
    private static let frameDuration: Duration = .milliseconds(60)

    var body: some View {
        ZStack {
            PreludePalette.sheetBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 26)
                    .padding(.top, 14)

                Spacer(minLength: 0)

                if captures.isEmpty {
                    Text("Nothing is included in your gift yet.")
                        .font(.system(size: 15))
                        .foregroundStyle(PreludePalette.voiceCopy)
                } else {
                    book
                        // The sprite canvas carries a little empty space to the
                        // right of the page; nudge so the page itself is centred.
                        .offset(x: GiftNotebookPage<EmptyView>.centringNudge)
                }

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            audio.startSong(giftSong)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                landOnPage()
            }
        }
        .onDisappear { audio.stopAll() }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text(captures.isEmpty ? "Preview" : "Preview (\(index + 1)/\(captures.count))")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .monospacedDigit()

            HStack {
                Spacer()
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                        .frame(width: 86, height: 39)
                        .background(
                            Capsule()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Book

    private var book: some View {
        GiftNotebookPage(frame: frame) {
            GiftPageContent(capture: captures[index], audio: audio)
                .opacity(contentVisible ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            turn(forward: location.x > GiftNotebookPage<EmptyView>.pageSize.width / 2)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -40 {
                        turn(forward: true)
                    } else if value.translation.width > 40 {
                        turn(forward: false)
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next page") { turn(forward: true) }
        .accessibilityAction(named: "Previous page") { turn(forward: false) }
    }

    // MARK: Turning

    private func turn(forward: Bool) {
        guard !isTurning else { return }
        let target = index + (forward ? 1 : -1)
        guard captures.indices.contains(target) else { return }

        isTurning = true
        audio.stopMemo()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeOut(duration: 0.12)) { contentVisible = false }

        // Forward runs the sheet left to right (lift → settle → next page);
        // back runs the curl in reverse so the page returns from the rings.
        let sequence: [Int] = forward ? [2, 3, 4, 5, 6, 7, 8] : [6, 5, 4, 3, 2, 1]

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            for f in sequence {
                frame = f
                try? await Task.sleep(for: Self.frameDuration)
            }
            index = target
            withAnimation(.easeIn(duration: 0.2)) { contentVisible = true }
            isTurning = false
            landOnPage()
        }
    }

    /// Anything that should happen once a page is face up: voice memos play.
    private func landOnPage() {
        guard captures.indices.contains(index) else { return }
        let capture = captures[index]
        if capture.type == .voiceMemo {
            audio.play(capture)
        }
    }
}

// MARK: - Notebook page

/// One sprite frame with page content laid over the flat page. Content is laid
/// out on a fixed 333pt-wide page, the width of the page in the design mocks.
struct GiftNotebookPage<Content: View>: View {
    let frame: Int
    @ViewBuilder var content: Content

    /// In the 312×364 (@1x) sprite canvas the flat page spans x 2…296, y 16…362.
    private static var scale: CGFloat { 333.0 / 294.0 }
    static var canvasSize: CGSize { CGSize(width: 312 * scale, height: 364 * scale) }
    static var pageOrigin: CGPoint { CGPoint(x: 2 * scale, y: 16 * scale) }
    static var pageSize: CGSize { CGSize(width: 333, height: 346 * scale) }
    static var centringNudge: CGFloat { (canvasSize.width - pageSize.width) / 2 - pageOrigin.x }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("gift_page_turn_\(frame)")
                .resizable()
                .interpolation(.high)
                .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                .shadow(color: .black.opacity(0.10), radius: 5, x: 1, y: 3)
                .accessibilityHidden(true)

            content
                .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .top)
                .padding(.leading, Self.pageOrigin.x)
                .padding(.top, Self.pageOrigin.y)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height, alignment: .topLeading)
    }
}

// MARK: - Page content

/// What is written on a page, measured off the Preview mocks (393×852, page at
/// x 25, y 253). Everything hangs off a 52pt left margin (clear of the ring
/// holes) and a 236pt column.
struct GiftPageContent: View {
    let capture: PreludeCapture
    @ObservedObject var audio: GiftPreviewAudio

    private static let leftMargin: CGFloat = 52
    private static let column: CGFloat = 236

    private var hasPhoto: Bool {
        capture.firstPhotoId != nil || capture.notePhotoId != nil || capture.remotePhotoPath != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PreludePalette.promptBrown)
                .frame(width: Self.column)
                .padding(.top, 39)

            switch capture.type {
            case .reason: reasonPage
            case .voiceMemo: voicePage
            case .note: notePage
            case .first: firstPage
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, Self.leftMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var title: String {
        switch capture.type {
        case .reason: return "Reason"
        case .voiceMemo: return "Voice Memo"
        case .note: return "Note"
        case .first: return "First"
        }
    }

    // MARK: Reason

    private var reasonPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            PreludeTapedPromptBar(text: PreludeViewModel.reasonPrompt, barHeight: 37, tapeWidth: 50)
                .frame(width: Self.column)
                .padding(.top, 28)

            pinnedField(capture.reasonText ?? "", height: 98)
                .padding(.top, 18)
        }
    }

    // MARK: Voice memo

    private var isPlaying: Bool { audio.isPlaying(capture) }

    private var voicePage: some View {
        Button { audio.toggle(capture) } label: {
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundStyle(PreludePalette.savedRed)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)

                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    Text(Self.clock(isPlaying ? audio.elapsed : audio.duration(of: capture)))
                        .font(.system(size: 41))
                        .foregroundStyle(PreludePalette.timerInk)
                        .monospacedDigit()
                }

                Text(isPlaying ? "Tap to pause" : "Tap to play")
                    .font(.system(size: 11))
                    .foregroundStyle(PreludePalette.captionInk)
                    .opacity(0.8)
            }
            .frame(width: Self.column)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 63)
        .accessibilityLabel(isPlaying ? "Pause voice memo" : "Play voice memo")
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Note

    private var notePage: some View {
        let hasExtras = hasPhoto || capture.noteMood != nil
        return VStack(alignment: .leading, spacing: 0) {
            pinnedField(capture.noteText ?? "", height: hasExtras ? 118 : 200)
                .padding(.top, 38)

            if hasExtras {
                HStack(alignment: .top, spacing: 0) {
                    if hasPhoto {
                        GiftPagePolaroid(capture: capture)
                            .padding(.leading, -5)
                    }
                    if let mood = capture.noteMood {
                        GiftPageStamp(mood: mood)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: Self.column, alignment: .leading)
                .padding(.top, 19)
            }
        }
    }

    // MARK: First

    private var firstPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            pinnedField(capture.firstLabel ?? "A First", height: 64)
                .padding(.top, 38)

            if let date = capture.firstDate {
                Text(date, format: .dateTime.month(.wide).day().year())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PreludePalette.promptBrown)
                    .padding(.top, 10)
                    .padding(.leading, 2)
            }

            if hasPhoto {
                GiftPagePolaroid(capture: capture, width: 128)
                    .frame(width: Self.column)
                    .padding(.top, 18)
            }
        }
    }

    // MARK: Shared field

    /// The flat `#DCD0C3` text field with the paperclip over its top-left
    /// corner, as on the Reason and Note pages.
    private func pinnedField(_ text: String, height: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(PreludePalette.bodyText)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.7)
            // The paperclip overhangs the field's first ~12pt; start the
            // text clear of it.
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.vertical, 12)
            .frame(width: Self.column, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(PreludePalette.textAreaFill)
            )
            .overlay(alignment: .topLeading) {
                PreludePaperclip()
                    .offset(x: -7, y: -9)
            }
    }
}

// MARK: - Polaroid (read only)

/// The `note_polaroid_frame` art with the capture's photo set into its window.
/// Same window metrics as `PolaroidPhotoWell` (113×113 at 6, 9 in 125×152).
struct GiftPagePolaroid: View {
    let capture: PreludeCapture
    var width: CGFloat = 112

    @State private var image: UIImage?

    var body: some View {
        let s = width / 125
        Image("note_polaroid_frame")
            .resizable()
            .interpolation(.high)
            .frame(width: 125 * s, height: 152 * s)
            .overlay(alignment: .topLeading) {
                Color(white: 0.88)
                    .frame(width: 113 * s, height: 113 * s)
                    .overlay {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .clipped()
                    .padding(.leading, 6 * s)
                    .padding(.top, 9 * s)
            }
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            .task(id: capture.id) {
                image = await PreludePhotoLoader.loadImage(for: capture)
            }
            .accessibilityLabel("Photo")
    }
}

// MARK: - Mood stamp

struct GiftPageStamp: View {
    let mood: ProfileNoteMood

    private var assetName: String { "stamp_\(mood.rawValue)_sel" }

    var body: some View {
        VStack(spacing: 6) {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(mood.tintColor)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: mood.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                    }
            }
            Text(mood.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Audio

/// Owns the preview's two players so they outlive page re-renders: the voice
/// memo on the current page, and the looping gift song underneath.
final class GiftPreviewAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingCaptureId: UUID?

    private var memoPlayer: AVAudioPlayer?
    private var songPlayer: AVAudioPlayer?
    private var durations: [UUID: TimeInterval] = [:]

    private static let songVolume: Float = 0.55
    private static let duckedVolume: Float = 0.12

    var elapsed: TimeInterval { memoPlayer?.currentTime ?? 0 }

    func isPlaying(_ capture: PreludeCapture) -> Bool {
        playingCaptureId == capture.id
    }

    func duration(of capture: PreludeCapture) -> TimeInterval {
        if let cached = durations[capture.id] { return cached }
        guard let url = Self.voiceMemoURL(for: capture),
              let probe = try? AVAudioPlayer(contentsOf: url) else { return 0 }
        durations[capture.id] = probe.duration
        return probe.duration
    }

    func toggle(_ capture: PreludeCapture) {
        isPlaying(capture) ? stopMemo() : play(capture)
    }

    func play(_ capture: PreludeCapture) {
        stopMemo()
        guard let url = Self.voiceMemoURL(for: capture) else { return }
        do {
            try Self.activateSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            memoPlayer = player
            playingCaptureId = capture.id
            songPlayer?.setVolume(Self.duckedVolume, fadeDuration: 0.4)
        } catch {
            print("[GiftPageFlipPreview] voice memo failed to play: \(error)")
        }
    }

    func stopMemo() {
        memoPlayer?.stop()
        memoPlayer = nil
        if playingCaptureId != nil {
            playingCaptureId = nil
            songPlayer?.setVolume(Self.songVolume, fadeDuration: 0.6)
        }
    }

    func startSong(_ song: PreludeGiftSong?) {
        guard song != nil, songPlayer == nil else { return }
        let url = DataPersistenceManager.shared.preludeGiftSongAudioURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try Self.activateSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Self.songVolume
            player.play()
            songPlayer = player
        } catch {
            print("[GiftPageFlipPreview] gift song failed to play: \(error)")
        }
    }

    func stopAll() {
        stopMemo()
        songPlayer?.stop()
        songPlayer = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finished = ObjectIdentifier(player)
        Task { @MainActor in
            guard let current = self.memoPlayer, ObjectIdentifier(current) == finished else { return }
            self.stopMemo()
        }
    }

    private static func voiceMemoURL(for capture: PreludeCapture) -> URL? {
        guard capture.type == .voiceMemo, let fileId = capture.voiceMemoFileId else { return nil }
        let url = DataPersistenceManager.shared.preludeVoiceMemoFileURL(fileId: fileId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func activateSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    }
}

#Preview {
    GiftPageFlipPreview(
        captures: [
            PreludeCapture(type: .reason, reasonText: "You are so kind and thoughtful"),
            PreludeCapture(type: .voiceMemo),
            PreludeCapture(
                type: .note,
                noteText: "The more time I spend with you the dreamier you seem to me, I still want to learn more about you...",
                noteMood: .dreamy
            )
        ],
        onDone: {}
    )
}
