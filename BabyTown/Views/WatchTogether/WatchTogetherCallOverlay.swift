import SwiftUI

struct WatchTogetherCallOverlay: View {
    @ObservedObject var callController: WatchTogetherCallController
    let partnerName: String
    let selfInitial: String
    var isDimmedForVideoControls = false
    var sizeScale: CGFloat = 1
    var onToggleMic: () -> Void
    var onToggleCamera: () -> Void

    private var mainWidth: CGFloat { 140 * sizeScale }
    private var mainHeight: CGFloat { 186 * sizeScale }
    private var insetWidth: CGFloat { 56 * sizeScale }
    private var insetHeight: CGFloat { 74 * sizeScale }
    private var mainCornerRadius: CGFloat { 16 * sizeScale }
    private var insetCornerRadius: CGFloat { 10 * sizeScale }
    private var cardCornerRadius: CGFloat { 20 * sizeScale }
    private var cardPadding: CGFloat { 12 * sizeScale }
    private var controlButtonSize: CGFloat { 34 * sizeScale }
    private var controlIconSize: CGFloat { 14 * sizeScale }
    private var controlSpacing: CGFloat { 8 * sizeScale }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                mainVideoArea
                    .frame(width: mainWidth, height: mainHeight)
                    .clipShape(RoundedRectangle(cornerRadius: mainCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: mainCornerRadius)
                            .stroke(BabyTownTheme.accent.opacity(0.3), lineWidth: 1)
                    )

                if callController.isConnected {
                    selfInset
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }

            if !isDimmedForVideoControls {
                HStack(spacing: controlSpacing) {
                    compactControlButton(
                        systemName: callController.isMicMuted ? "mic.slash.fill" : "mic.fill",
                        label: callController.isMicMuted ? "Unmute microphone" : "Mute microphone",
                        action: onToggleMic
                    )
                    compactControlButton(
                        systemName: callController.isCameraOff ? "video.slash.fill" : "video.fill",
                        label: callController.isCameraOff ? "Turn on camera" : "Turn off camera",
                        action: onToggleCamera
                    )
                }
                .padding(controlSpacing)
            }
        }
        .padding(cardPadding)
        .background(.black.opacity(isDimmedForVideoControls ? 0.12 : 0.35), in: RoundedRectangle(cornerRadius: cardCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .opacity(isDimmedForVideoControls ? 0.12 : 1)
        .scaleEffect(isDimmedForVideoControls ? 0.94 : 1, anchor: .bottomLeading)
        .animation(.easeInOut(duration: 0.35), value: callController.isConnected)
        .animation(.easeInOut(duration: 0.22), value: isDimmedForVideoControls)
        .animation(.easeInOut(duration: 0.22), value: sizeScale)
    }

    @ViewBuilder
    private var mainVideoArea: some View {
        ZStack {
            if callController.isConnected {
                RTCVideoView(track: callController.remoteVideoTrack)
            } else if callController.isCameraOff {
                selfAvatarFull
            } else {
                RTCVideoView(track: callController.localVideoTrack, mirroredHorizontally: true)
            }

            if !callController.isConnected {
                waitingOverlay
            }
        }
    }

    @ViewBuilder
    private var selfInset: some View {
        Group {
            if callController.isCameraOff {
                selfAvatarInset
            } else {
                RTCVideoView(track: callController.localVideoTrack, mirroredHorizontally: true)
                    .frame(width: insetWidth, height: insetHeight)
                    .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
            }
        }
        .padding(controlSpacing)
    }

    private var waitingOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                ProgressView()
                    .tint(BabyTownTheme.accent)
                    .scaleEffect(0.85)
                Text("Waiting for \(partnerName)…")
                    .font(.system(size: 12 * sizeScale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 10 * sizeScale)
            .padding(.vertical, 8 * sizeScale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: insetCornerRadius))
            .padding(controlSpacing)
        }
    }

    private var selfAvatarFull: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mainCornerRadius)
                .fill(BabyTownTheme.accent.opacity(0.2))
            Text(selfInitial.prefix(1).uppercased())
                .font(.system(size: 34 * sizeScale, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
        }
    }

    private var selfAvatarInset: some View {
        ZStack {
            RoundedRectangle(cornerRadius: insetCornerRadius)
                .fill(BabyTownTheme.accent.opacity(0.25))
            Text(selfInitial.prefix(1).uppercased())
                .font(.system(size: 17 * sizeScale, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
        }
        .frame(width: insetWidth, height: insetHeight)
    }

    private func compactControlButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: controlIconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: controlButtonSize, height: controlButtonSize)
                .background(.black.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(label)
    }
}
