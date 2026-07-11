import SwiftUI
import AuthenticationServices

struct CovelaAuthView: View {
    var onAuthenticated: () -> Void

    @ObservedObject private var authService = AuthService.shared

    @State private var showEmailSignUp = false
    @State private var showEmailLogin = false
    @State private var showComingSoon = false
    @State private var showAuthError = false

    @State private var bookScale: CGFloat = 0.6
    @State private var bookOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var sparkleShift: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingWelcomeBackground()

                FloatingHeartsView()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    authHeroMark
                        .scaleEffect(bookScale)
                        .opacity(bookOpacity)

                    // Headline
                    Text("Your private world starts here.")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .opacity(contentOpacity)

                    Spacer(minLength: 36)

                    // Auth buttons
                    VStack(spacing: 12) {
                        appleButton
                        googleButton
                        orDivider
                        emailButton
                    }
                    .padding(.horizontal, 32)
                    .opacity(contentOpacity)

                    // Footer
                    VStack(spacing: 12) {
                        logInFooter
                        OnboardingLegalLinks()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 52)
                    .opacity(contentOpacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Coming Soon", isPresented: $showComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Google sign-in is coming soon. Use Apple or email for now.")
            }
            .alert("Sign In Failed", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authService.errorMessage ?? "Something went wrong. Please try again.")
            }
            .navigationDestination(isPresented: $showEmailSignUp) {
                EmailSignUpView(onAuthenticated: {
                    showEmailSignUp = false
                    onAuthenticated()
                })
                .environmentObject(authService)
            }
            .navigationDestination(isPresented: $showEmailLogin) {
                EmailLoginView(onAuthenticated: {
                    showEmailLogin = false
                    onAuthenticated()
                })
                .environmentObject(authService)
            }
        }
        .onChange(of: authService.errorMessage) { _, message in
            showAuthError = message != nil
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                sparkleShift = 8
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                bookScale = 1.0
                bookOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                contentOpacity = 1.0
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            let success = await authService.handleAppleSignIn(result: result)
            if success {
                onAuthenticated()
            }
        }
    }

    // MARK: - Auth Buttons

    private var authHeroMark: some View {
        ZStack {
            Image("BabyTownFullIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 136, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.78), lineWidth: 3)
                )
                .shadow(color: BabyTownTheme.accentDeep.opacity(0.18), radius: 18, y: 10)

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("for two")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(BabyTownTheme.accentDeep)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .shadow(color: BabyTownTheme.accent.opacity(0.16), radius: 10, y: 4)
                )
                .offset(y: 12)
            }
            .frame(width: 136, height: 136)

            Image(systemName: "sparkle")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.22))
                .offset(x: -60, y: -61 - sparkleShift)

            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.22).opacity(0.85))
                .offset(x: 63, y: -52 + sparkleShift)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handleAppleSignIn(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
        .clipShape(Capsule())
        .disabled(authService.isLoading)
        .opacity(authService.isLoading ? 0.6 : 1)
    }

    private var googleButton: some View {
        Button {
            showComingSoon = true
        } label: {
            HStack(spacing: 10) {
                GoogleGLogo()
                    .frame(width: 20, height: 20)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private var orDivider: some View {
        HStack {
            dividerLine
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
            dividerLine
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }

    private var emailButton: some View {
        Button {
            showEmailSignUp = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16))
                Text("Continue with Email")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule()
                    .fill(BabyTownTheme.accentGradient)
                    .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 14, y: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private var logInFooter: some View {
        Button {
            showEmailLogin = true
        } label: {
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(.secondary)
                Text("Log in")
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Google G Logo

private struct GoogleGLogo: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                ArcShape(startAngle: -30, endAngle: 90, clockwise: false)
                    .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: s * 0.18)
                ArcShape(startAngle: 90, endAngle: 210, clockwise: false)
                    .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: s * 0.18)
                ArcShape(startAngle: 210, endAngle: 330, clockwise: false)
                    .stroke(Color(red: 0.98, green: 0.74, blue: 0.01), lineWidth: s * 0.18)
                ArcShape(startAngle: 330, endAngle: 360, clockwise: false)
                    .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), lineWidth: s * 0.18)
                Rectangle()
                    .fill(.white)
                    .frame(width: s * 0.5, height: s * 0.18)
                    .offset(x: s * 0.12)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct ArcShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2 * 0.72,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: clockwise
        )
        return p
    }
}

// MARK: - Preview

#Preview {
    CovelaAuthView(onAuthenticated: { print("authenticated") })
}
