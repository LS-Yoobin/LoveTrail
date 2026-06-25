import SwiftUI

struct EmailLoginView: View {
    var onAuthenticated: () -> Void

    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            // Background — matches WelcomeView
            LinearGradient(
                colors: [Color.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Headline
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        Text("Log in to your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Fields
                    VStack(spacing: 14) {
                        TextField("", text: $email, prompt: Text("Email").foregroundColor(Color(white: 0.4)))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($emailFocused)
                            .submitLabel(.next)
                            .onSubmit { passwordFocused = true }
                            .foregroundStyle(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        emailFocused
                                            ? BabyTownTheme.accent.opacity(0.5)
                                            : Color(.separator),
                                        lineWidth: 1
                                    )
                            )

                        SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color(white: 0.4)))
                            .textContentType(.password)
                            .focused($passwordFocused)
                            .submitLabel(.go)
                            .onSubmit { if canSubmit { submit() } }
                            .foregroundStyle(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        passwordFocused
                                            ? BabyTownTheme.accent.opacity(0.5)
                                            : Color(.separator),
                                        lineWidth: 1
                                    )
                            )
                    }

                    // Auth service error (from real API once wired)
                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // CTA
                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            }
                            Text("Log In")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(canSubmit ? BabyTownTheme.accentGradient : LinearGradient(colors: [Color(.systemGray3)], startPoint: .leading, endPoint: .trailing))
                                .shadow(color: canSubmit ? BabyTownTheme.accent.opacity(0.35) : .clear, radius: 14, y: 6)
                        )
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .animation(.easeOut(duration: 0.2), value: canSubmit)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
        }
        .onAppear { emailFocused = true }
    }

    // MARK: - Logic

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await authService.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                onAuthenticated()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        EmailLoginView(onAuthenticated: { print("logged in") })
            .environmentObject(AuthService.shared)
    }
}
