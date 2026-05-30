import SwiftUI
import UIKit

/// Presents the system share sheet from the topmost view controller.
///
/// Avoids wrapping `UIActivityViewController` in a SwiftUI `.sheet`, which breaks
/// destination apps (e.g. Instagram) that need a stable presenter after the user
/// picks an activity.
enum ActivitySharePresenter {

    @MainActor
    static func present(
        image: UIImage,
        applicationActivities: [UIActivity]? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        guard let fileURL = writeTemporaryJPEG(from: image) else {
            onComplete?()
            return
        }
        guard let presenter = topViewController() else {
            try? FileManager.default.removeItem(at: fileURL)
            onComplete?()
            return
        }

        let activity = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: applicationActivities
        )

        activity.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
            onComplete?()
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activity, animated: true)
    }

    /// Presents the system share sheet for plain text (used as a fallback when
    /// the device can't send SMS).
    @MainActor
    static func present(text: String, onComplete: (() -> Void)? = nil) {
        guard let presenter = topViewController() else {
            onComplete?()
            return
        }

        let activity = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        activity.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activity, animated: true)
    }

    private static func writeTemporaryJPEG(from image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabyTown-share-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            return nil
        }
        return topMostViewController(from: root)
    }

    private static func topMostViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return viewController
    }
}
