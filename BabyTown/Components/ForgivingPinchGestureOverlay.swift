import SwiftUI
import UIKit

/// A pinch target on the canvas; the second finger may sit outside the artwork bounds.
struct ForgivingPinchTarget: Equatable {
    enum Kind: Equatable {
        case sticker(UUID)
        case recordPlayer
    }

    let kind: Kind
    let frame: CGRect
    let baseScale: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
}

/// Pinch-to-scale where only one finger must start on a target frame; the other may be anywhere on the canvas.
struct ForgivingPinchGestureOverlay: UIViewRepresentable {
    let isEnabled: Bool
    let targets: [ForgivingPinchTarget]
    let selectedStickerID: UUID?
    let onPreviewScale: (ForgivingPinchTarget.Kind, CGFloat?) -> Void
    let onCommitScale: (ForgivingPinchTarget.Kind, CGFloat) -> Void

    /// Matches `ProfileStickerView` / vinyl pinch damping.
    static let pinchSensitivity: CGFloat = 0.22

    func makeUIView(context: Context) -> PassThroughPinchView {
        let view = PassThroughPinchView()
        view.isUserInteractionEnabled = isEnabled
        view.backgroundColor = .clear
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: PassThroughPinchView, context: Context) {
        uiView.isUserInteractionEnabled = isEnabled
        context.coordinator.targets = targets
        context.coordinator.selectedStickerID = selectedStickerID
        context.coordinator.onPreviewScale = onPreviewScale
        context.coordinator.onCommitScale = onCommitScale
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var targets: [ForgivingPinchTarget] = []
        var selectedStickerID: UUID?
        var onPreviewScale: ((ForgivingPinchTarget.Kind, CGFloat?) -> Void)?
        var onCommitScale: ((ForgivingPinchTarget.Kind, CGFloat) -> Void)?

        private weak var hostView: PassThroughPinchView?
        private var pinchRecognizer: UIPinchGestureRecognizer?
        private var activeTarget: ForgivingPinchTarget?
        private var pinchStartScale: CGFloat = 1

        func attach(to view: PassThroughPinchView) {
            hostView = view
            guard pinchRecognizer == nil else { return }
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            pinch.cancelsTouchesInView = false
            view.addGestureRecognizer(pinch)
            pinchRecognizer = pinch
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = hostView else { return false }
            let touchCount = gestureRecognizer.numberOfTouches
            for touchIndex in 0..<touchCount {
                let point = gestureRecognizer.location(ofTouch: touchIndex, in: view)
                if target(at: point) != nil { return true }
            }
            return false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                guard let view = hostView else { return }
                let point = recognizer.location(ofTouch: 0, in: view)
                guard let target = target(at: point) else { return }
                activeTarget = target
                pinchStartScale = target.baseScale
                publishPreview(for: target, scale: target.baseScale)

            case .changed:
                guard let target = activeTarget else { return }
                let damped = 1 + (recognizer.scale - 1) * ForgivingPinchGestureOverlay.pinchSensitivity
                let proposed = pinchStartScale * damped
                let clamped = min(max(proposed, target.minScale), target.maxScale)
                publishPreview(for: target, scale: clamped)

            case .ended, .cancelled:
                guard let target = activeTarget else { return }
                let damped = 1 + (recognizer.scale - 1) * ForgivingPinchGestureOverlay.pinchSensitivity
                let proposed = pinchStartScale * damped
                let final = min(max(proposed, target.minScale), target.maxScale)
                onCommitScale?(target.kind, final)
                publishPreview(for: target, scale: nil)
                activeTarget = nil
                recognizer.scale = 1

            default:
                break
            }
        }

        private func publishPreview(for target: ForgivingPinchTarget, scale: CGFloat?) {
            onPreviewScale?(target.kind, scale)
        }

        private func target(at point: CGPoint) -> ForgivingPinchTarget? {
            if let selectedStickerID,
               let selected = targets.first(where: {
                   if case .sticker(let id) = $0.kind { return id == selectedStickerID }
                   return false
               }),
               selected.frame.insetBy(dx: -8, dy: -8).contains(point) {
                return selected
            }

            let hitSlop: CGFloat = 8
            return targets.first { $0.frame.insetBy(dx: -hitSlop, dy: -hitSlop).contains(point) }
        }
    }
}

/// Forwards single-finger touches to views below; captures multi-touch for canvas-wide pinch.
final class PassThroughPinchView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }
        guard let event else { return nil }
        let touchCount = event.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 0
        if touchCount >= 2 {
            return self
        }
        return nil
    }
}

enum ForgivingPinchGeometry {
    static func stickerFrame(
        sticker: ProfileSticker,
        canvasSize: CGSize,
        previewScale: CGFloat?,
        includesLabel: Bool
    ) -> CGRect {
        let scale = previewScale ?? sticker.scale
        let side = ProfileSticker.renderedSize(scale: scale)
        let center = CGPoint(
            x: sticker.position.x * canvasSize.width,
            y: sticker.position.y * canvasSize.height
        )
        var height = side
        if includesLabel {
            height += 8 + 34
        }
        return CGRect(
            x: center.x - side / 2,
            y: center.y - side / 2,
            width: side,
            height: height
        )
    }

    static func recordPlayerFrame(
        position: NormalizedPoint,
        scale: CGFloat,
        canvasSize: CGSize
    ) -> CGRect {
        let side = VinylRecordPlayerView.gardenBaseSide * scale
        let center = CGPoint(
            x: position.x * canvasSize.width,
            y: position.y * canvasSize.height
        )
        return CGRect(
            x: center.x - side / 2,
            y: center.y - side / 2,
            width: side,
            height: side
        )
    }
}
