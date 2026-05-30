import SwiftUI

struct NicknameView: View {

    var onContinue: (String) -> Void

    @State private var nickname = ""
    @State private var contentOpacity: Double = 0
    @FocusState private var isFieldFocused: Bool

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        !trimmedNickname.isEmpty
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("What should we call you?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("So we know how to address you")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                TextField("Your nickname", text: $nickname)
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .focused($isFieldFocused)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray6))
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    )
                    .padding(.horizontal, 40)
                    .onSubmit {
                        if canContinue {
                            continueTapped()
                        }
                    }

                Spacer()

                continueButton
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                contentOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFieldFocused = true
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [.white, Color.pink.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var continueButton: some View {
        Button(action: continueTapped) {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            canContinue
                                ? LinearGradient(
                                    colors: [.pink, .pink.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color(.systemGray4),
                                        Color(.systemGray4).opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .shadow(
                            color: canContinue ? .pink.opacity(0.3) : .clear,
                            radius: 12, y: 6
                        )
                )
        }
        .disabled(!canContinue)
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
        .animation(.easeInOut(duration: 0.3), value: canContinue)
    }

    private func continueTapped() {
        guard canContinue else { return }
        onContinue(trimmedNickname)
    }
}

#Preview {
    NicknameView { nickname in
        print("Nickname: \(nickname)")
    }
}
