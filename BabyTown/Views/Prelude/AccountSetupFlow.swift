import SwiftUI

struct AccountSetupResult {
    let email: String
    let avatarImage: UIImage?
}

struct AccountSetupFlow: View {
    var onComplete: (AccountSetupResult) -> Void
    var onCancel: () -> Void

    private enum Step { case email, photo }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var avatarImage: UIImage?

    var body: some View {
        ZStack {
            switch step {
            case .email:
                AccountEmailStep(
                    email: $email,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.35)) { step = .photo }
                    },
                    onCancel: onCancel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case .photo:
                AccountPhotoStep(
                    avatarImage: $avatarImage,
                    onComplete: {
                        onComplete(AccountSetupResult(email: email, avatarImage: avatarImage))
                    },
                    onCancel: onCancel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    AccountSetupFlow(
        onComplete: { result in
            print("Complete: email=\(result.email), photo=\(result.avatarImage != nil)")
        },
        onCancel: { print("Cancelled") }
    )
}
