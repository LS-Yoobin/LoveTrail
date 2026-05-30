import SwiftUI
import MessageUI

/// SwiftUI wrapper around the native Messages compose sheet, pre-filled with a
/// recipient and body. The user sends from their own number — apps cannot send
/// SMS silently.
struct MessageComposeView: UIViewControllerRepresentable {

    let recipients: [String]
    let body: String
    var onFinish: (MessageComposeResult) -> Void

    /// Whether this device can send text messages (false on most simulators).
    static var canSend: Bool { MFMessageComposeViewController.canSendText() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void

        init(onFinish: @escaping (MessageComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onFinish(result)
        }
    }
}
