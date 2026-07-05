import SwiftUI

/// Shows a generated partner invite code with copy/share actions.
/// Used right after `create-invite` succeeds, and any time the inviter
/// wants to re-share the code for a still-pending invite.
struct InviteCodeSheet: View {
    let code: String
    var onDone: () -> Void

    @State private var codeCopied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Your invite code is ready")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BabyTownTheme.accentDeep)

                    Text("Share this code with your partner however you like. We will let you know the moment they join.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.72))
                        .multilineTextAlignment(.center)
                }

                Text(code)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .tracking(4)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BabyTownTheme.cardTintLight)
                    )

                Button {
                    ActivitySharePresenter.present(text: "Join me on Covela! Use my invite code: \(code)")
                } label: {
                    Text("Share code")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(BabyTownTheme.accentGradient))
                }

                Button {
                    UIPasteboard.general.string = code
                    withAnimation { codeCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { codeCopied = false }
                    }
                } label: {
                    Text(codeCopied ? "Copied!" : "Copy invite code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .background(BabyTownTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDone()
                    }
                }
            }
        }
    }
}

#Preview {
    InviteCodeSheet(code: "X7KP4Q", onDone: {})
}
