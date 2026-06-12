import SwiftUI

struct ReconnectInviteView: View {
    var onReconnected: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inviteSent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                VStack(spacing: 10) {
                    Text(inviteSent ? "Invite sent" : "Invite them back")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    Text(inviteSent
                         ? "Waiting for them to respond. You'll be notified when they do."
                         : "Send a reconnect invite. They'll be notified and can choose to accept or decline.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 14) {
                if !inviteSent {
                    Button {
                        sendInvite()
                    } label: {
                        Text("Send Reconnect Invite")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }
                Button(inviteSent ? "Close" : "Not yet") {
                    if inviteSent { onReconnected() }
                    dismiss()
                }
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
    }

    private func sendInvite() {
        ArchiveService.shared.sendReconnectInvite()
        inviteSent = true
    }
}
