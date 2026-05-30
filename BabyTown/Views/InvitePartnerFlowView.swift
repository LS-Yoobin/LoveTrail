import SwiftUI
import MessageUI

/// Shown after a verified purchase (and from Settings ▸ Subscription): lets the
/// user copy their invite link or text it to their partner.
struct InvitePartnerFlowView: View {

    /// Called when the user finishes or skips the invite step.
    var onDone: () -> Void

    @State private var invite = PartnerInvite.current()
    @State private var phoneNumber = ""
    @State private var copied = false
    @State private var showMessageComposer = false
    @FocusState private var phoneFocused: Bool

    private let accent = Color(red: 0.88, green: 0.22, blue: 0.38)
    private var heroGradient: [Color] {
        [Color(red: 1.0, green: 0.48, blue: 0.63), accent]
    }

    private var canSendText: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, accent.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    linkSection
                        .padding(.top, 28)
                    orDivider
                        .padding(.top, 24)
                    textSection
                        .padding(.top, 16)
                    laterButton
                        .padding(.top, 22)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 26)
            }
        }
        .sheet(isPresented: $showMessageComposer) {
            MessageComposeView(
                recipients: [phoneNumber],
                body: invite.messageText
            ) { _ in
                showMessageComposer = false
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(colors: heroGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 70, height: 70)
                .overlay(Text("💞").font(.system(size: 34)))
                .shadow(color: accent.opacity(0.38), radius: 12, y: 6)
                .padding(.top, 40)
                .padding(.bottom, 16)

            Text("Invite your partner")
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(.black.opacity(0.85))

            Text("Send them the link to join your private Town.")
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 12)
        }
    }

    private var linkSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(invite.link)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGray6))
            )

            Button(action: copyLink) {
                Text(copied ? "Copied!" : "Copy link")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: accent.opacity(0.3), radius: 12, y: 5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            line
            Text("or text it")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.4))
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(.black.opacity(0.10))
            .frame(height: 1)
    }

    private var textSection: some View {
        VStack(spacing: 12) {
            TextField("Partner's phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($phoneFocused)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            Button(action: sendText) {
                Text("Send via text")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(canSendText ? .white : .black.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule().fill(
                            canSendText
                                ? AnyShapeStyle(LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color(.systemGray5))
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSendText)
        }
    }

    private var laterButton: some View {
        Button(action: onDone) {
            Text("I'll do this later")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func copyLink() {
        UIPasteboard.general.string = invite.link
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { copied = false }
        }
    }

    private func sendText() {
        phoneFocused = false
        guard canSendText else { return }
        if MessageComposeView.canSend {
            showMessageComposer = true
        } else {
            // Simulator / device without SMS: fall back to the share sheet.
            ActivitySharePresenter.present(text: invite.messageText)
        }
    }
}

#Preview {
    InvitePartnerFlowView(onDone: {})
}
