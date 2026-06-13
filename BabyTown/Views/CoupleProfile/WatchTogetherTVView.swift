import SwiftUI

/// The four visual states the Watch Together TV can be in.
enum WatchTogetherTVState: Equatable {
    /// Idle — shows "Click to watch together" paw graphic (Variant 1).
    case idle
    /// Powering on — static/noise frame (Variant 2). Plays once then advances.
    case turningOn
    /// Input active — "Paste a YouTube link…" (Variant 3).
    case input
    /// Black screen — zoom-transition trigger (Variant 4).
    case black
}

/// Tappable retro TV prop placed on the Secret Garden canvas.
/// In the garden it always renders in `.idle` state; the full 4-state machine
/// activates when the Watch Together entry sheet is presented.
struct WatchTogetherTVView: View {
    var state: WatchTogetherTVState = .idle
    var scale: CGFloat = 1
    var onTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    static let gardenMinScale: CGFloat = 0.8
    static let gardenDefaultScale: CGFloat = 1.3
    static let gardenMaxScale: CGFloat = 2.5
    /// Intrinsic render size at scale 1 — TV is wider than the vinyl disc.
    static let gardenBaseSide: CGFloat = 100

    private var size: CGFloat { Self.gardenBaseSide * scale }

    private var imageName: String {
        switch state {
        case .idle:      return "watch_together_tv_default"
        case .turningOn: return "watch_together_tv_static"
        case .input:     return "watch_together_tv_input"
        case .black:     return "watch_together_tv_black"
        }
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { tvArt }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Watch Together")
            } else {
                tvArt
            }
        }
        .simultaneousGesture(
            onLongPress.map { action in
                LongPressGesture(minimumDuration: 1.5)
                    .onEnded { _ in action() }
            }
        )
        .accessibilityLabel("Watch Together TV")
    }

    private var tvArt: some View {
        Group {
            if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallbackTV
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.20), radius: 5, y: 2)
    }

    private var fallbackTV: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.15))
            Image(systemName: "tv.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}
