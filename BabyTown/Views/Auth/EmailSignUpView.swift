import SwiftUI

struct EmailSignUpView: View {
    var onAuthenticated: () -> Void

    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    @FocusState private var emailFocused: Bool

    private enum PasswordFocus: Hashable { case primary, confirm }
    @FocusState private var passwordFocus: PasswordFocus?

    // Validation
    private var isEmailValid: Bool { authService.isValidEmail(email) }
    private var isPasswordLongEnough: Bool { password.count >= 8 }
    private var doPasswordsMatch: Bool { !password.isEmpty && password == confirmPassword }
    private var isFormValid: Bool { isEmailValid && isPasswordLongEnough && doPasswordsMatch }

    // Show inline hint only after user starts typing
    private var showEmailError: Bool { !email.isEmpty && !isEmailValid }
    private var showPasswordError: Bool { !password.isEmpty && !isPasswordLongEnough }
    private var showMatchError: Bool { !confirmPassword.isEmpty && !doPasswordsMatch }

    var body: some View {
        ZStack {
            OnboardingWelcomeBackground()

            FloatingHeartsView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Headline
                    Text("Create your account")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                        .padding(.top, 20)

                    // Fields
                    VStack(spacing: 6) {
                        inputField(
                            placeholder: "Email",
                            text: $email,
                            keyboard: .emailAddress,
                            contentType: .emailAddress,
                            focused: $emailFocused
                        )
                        if showEmailError {
                            validationMessage("Invalid email format")
                        }
                    }

                    VStack(spacing: 6) {
                        SecureField("", text: $password, prompt: Text("Password").foregroundColor(Color(white: 0.4)))
                            .textContentType(.newPassword)
                            .focused($passwordFocus, equals: .primary)
                            .foregroundStyle(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        passwordFocus == .primary
                                            ? BabyTownTheme.accent.opacity(0.5)
                                            : Color(.separator),
                                        lineWidth: 1
                                    )
                            )
                        if showPasswordError {
                            validationMessage("Password must be at least 8 characters")
                        }
                    }

                    VStack(spacing: 6) {
                        SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(Color(white: 0.4)))
                            .textContentType(.newPassword)
                            .focused($passwordFocus, equals: .confirm)
                            .foregroundStyle(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        passwordFocus == .confirm
                                            ? BabyTownTheme.accent.opacity(0.5)
                                            : (showMatchError ? Color.red.opacity(0.5) : Color(.separator)),
                                        lineWidth: 1
                                    )
                            )
                        if showMatchError {
                            validationMessage("Passwords do not match")
                        }
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
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                            }
                            Text("Create Account")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(isFormValid ? BabyTownTheme.accentGradient : LinearGradient(colors: [Color(.systemGray3)], startPoint: .leading, endPoint: .trailing))
                                .shadow(color: isFormValid ? BabyTownTheme.accent.opacity(0.35) : .clear, radius: 14, y: 6)
                        )
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .animation(.easeOut(duration: 0.2), value: isFormValid)
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
        guard isFormValid else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await authService.createAccount(
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

    // MARK: - Helpers

    private func inputField(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        contentType: UITextContentType,
        focused: FocusState<Bool>.Binding
    ) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(Color(white: 0.4)))
            .keyboardType(keyboard)
            .textContentType(contentType)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .focused(focused)
            .foregroundStyle(.black)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        focused.wrappedValue
                            ? BabyTownTheme.accent.opacity(0.5)
                            : Color(.separator),
                        lineWidth: 1
                    )
            )
    }

    private func validationMessage(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.red)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: text)
    }
}

#Preview {
    NavigationStack {
        EmailSignUpView(onAuthenticated: { print("signed up") })
            .environmentObject(AuthService.shared)
    }
}
