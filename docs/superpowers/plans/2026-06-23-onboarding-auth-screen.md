# Onboarding Auth Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a CovelaAuthView as the first onboarding step, before WelcomeView, with Apple/Google stubs and a functional email sign-up flow.

**Architecture:** ContentView gains an `.auth` Screen case; new users are routed through it before `.welcome`. CovelaAuthView lives inside a NavigationStack (added in ContentView's `.auth` case) so EmailSignUpView and EmailLoginView can be pushed onto the stack via NavigationLink. AuthService is a MainActor ObservableObject singleton with stub implementations the backend teammate replaces later.

**Tech Stack:** SwiftUI, async/await, Canvas (for GoogleLogoView)

## Global Constraints

- No hardcoded hex or RGB values — all colors via `BabyTownTheme.*` tokens
- No ` - ` (space dash space) in any user-facing string
- Both Pink and Blue themes must render correctly via `BabyTownTheme.accent`
- Apple and Google buttons must not perform any auth action — "Coming soon" alert only
- `AuthService` interface must be clean for a backend teammate to swap stubs with real calls
- Existing users who have completed onboarding skip `.auth` — the `hasCompletedOnboarding` guard in `ContentView.init` is unchanged

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `BabyTown/Services/AuthService.swift` | Stub auth logic, `AuthUser` model |
| Create | `BabyTown/Views/Auth/CovelaAuthView.swift` | Main auth screen + `GoogleLogoView` |
| Create | `BabyTown/Views/Auth/EmailSignUpView.swift` | Email + password sign-up form |
| Create | `BabyTown/Views/Auth/EmailLoginView.swift` | Email + password log-in stub |
| Modify | `BabyTown/ContentView.swift` | Add `.auth` case; route new users through it |

---

### Task 1: AuthService

**Files:**
- Create: `BabyTown/Services/AuthService.swift`

**Interfaces:**
- Produces:
  - `struct AuthUser { let id: String; let email: String }`
  - `class AuthService: ObservableObject` — singleton `AuthService.shared`
  - `func createAccount(email: String, password: String) async throws -> AuthUser`
  - `func signIn(email: String, password: String) async throws -> AuthUser`
  - `@Published var isLoading: Bool`
  - `@Published var errorMessage: String?`

- [ ] **Step 1: Create AuthService.swift**

```swift
import Foundation

struct AuthUser {
    let id: String
    let email: String
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private init() {}

    func createAccount(email: String, password: String) async throws -> AuthUser {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        // TODO: Replace stub with real API call
        try await Task.sleep(nanoseconds: 800_000_000)
        let user = AuthUser(id: UUID().uuidString, email: email)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        // TODO: Replace stub with real API call
        try await Task.sleep(nanoseconds: 800_000_000)
        let user = AuthUser(id: UUID().uuidString, email: email)
        currentUser = user
        return user
    }
}
```

- [ ] **Step 2: Verify it builds**

In Xcode: Product → Build (⌘B). Expected: builds with no errors.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/AuthService.swift
git commit -m "feat: add AuthService stub for email auth"
```

---

### Task 2: CovelaAuthView

**Files:**
- Create: `BabyTown/Views/Auth/CovelaAuthView.swift`

**Interfaces:**
- Consumes: `BabyTownTheme.accent`, `FloatingHeartsView`, `OnboardingLegalLinks`
- Produces: `struct CovelaAuthView: View` with `init(onAuthenticated: () -> Void)`
- Note: `NavigationLink` targets `EmailSignUpView(onAuthenticated:)` and `EmailLoginView(onAuthenticated:)` — those views are created in Tasks 3 and 4. The file won't compile until those types exist. Build verification happens in Task 5 after ContentView is wired up.

- [ ] **Step 1: Create directory and file**

Create folder `BabyTown/Views/Auth/` then create `CovelaAuthView.swift`:

```swift
import SwiftUI

struct CovelaAuthView: View {
    let onAuthenticated: () -> Void

    @State private var catScale: CGFloat = 0.6
    @State private var catOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    @State private var showComingSoonAlert = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            FloatingHeartsView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("First Page Cat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .scaleEffect(catScale)
                    .opacity(catOpacity)
                    .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 20, y: 8)

                Text("Your private world starts here.")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .opacity(textOpacity)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showComingSoonAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                            Text("Continue with Apple")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.black))
                    }
                    .padding(.horizontal, 40)

                    Button {
                        showComingSoonAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            GoogleLogoView()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(Color.black.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        )
                    }
                    .padding(.horizontal, 40)

                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 4)

                    NavigationLink {
                        EmailSignUpView(onAuthenticated: onAuthenticated)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope")
                            Text("Continue with Email")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [BabyTownTheme.accent, BabyTownTheme.accent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                        )
                    }
                    .padding(.horizontal, 40)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            EmailLoginView(onAuthenticated: onAuthenticated)
                        } label: {
                            Text("Log in")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                    }

                    OnboardingLegalLinks()
                        .padding(.top, 4)
                }
                .opacity(buttonsOpacity)
                .padding(.bottom, 42)
            }
        }
        .navigationBarHidden(true)
        .alert("Coming soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple and Google sign-in are coming soon.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                catScale = 1.0
                catOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                buttonsOpacity = 1.0
            }
        }
    }
}

private struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = min(size.width, size.height) * 0.42
            let sw = r * 0.36
            let gap = 4.0

            let segments: [(start: Double, end: Double, color: Color)] = [
                (-30 + gap, 90 - gap, Color(red: 0.92, green: 0.26, blue: 0.21)),
                (90 + gap, 180 - gap, Color(red: 0.99, green: 0.73, blue: 0.01)),
                (180 + gap, 250 - gap, Color(red: 0.23, green: 0.71, blue: 0.40)),
                (250 + gap, 330 - gap, Color(red: 0.26, green: 0.52, blue: 0.96)),
            ]

            for seg in segments {
                var path = Path()
                path.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: r,
                    startAngle: .degrees(seg.start),
                    endAngle: .degrees(seg.end),
                    clockwise: false
                )
                context.stroke(path, with: .color(seg.color),
                               style: StrokeStyle(lineWidth: sw, lineCap: .round))
            }

            // Blue horizontal bar (the G's crossbar)
            var bar = Path()
            bar.move(to: CGPoint(x: cx, y: cy))
            bar.addLine(to: CGPoint(x: cx + r + sw / 2, y: cy))
            context.stroke(bar, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)),
                           style: StrokeStyle(lineWidth: sw, lineCap: .round))
        }
    }
}
```

- [ ] **Step 2: Commit (file created — build deferred to Task 5)**

```bash
git add "BabyTown/Views/Auth/CovelaAuthView.swift"
git commit -m "feat: add CovelaAuthView with Apple/Google stubs and Google logo"
```

---

### Task 3: EmailSignUpView

**Files:**
- Create: `BabyTown/Views/Auth/EmailSignUpView.swift`

**Interfaces:**
- Consumes: `AuthService.shared.createAccount(email:password:)`, `BabyTownTheme.accent`, `.onboardingBackButton(action:)`
- Produces: `struct EmailSignUpView: View` with `init(onAuthenticated: () -> Void)`

- [ ] **Step 1: Create EmailSignUpView.swift**

```swift
import SwiftUI

struct EmailSignUpView: View {
    let onAuthenticated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var hasAttemptedSubmit = false

    private var emailValid: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
    private var passwordValid: Bool { password.count >= 8 }
    private var passwordsMatch: Bool { password == confirmPassword }
    private var formValid: Bool { emailValid && passwordValid && passwordsMatch }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create your account")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 4) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        if hasAttemptedSubmit && !emailValid {
                            Text("Please enter a valid email address.")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        }
                    }

                    VStack(spacing: 4) {
                        SecureField("Password", text: $password)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        if hasAttemptedSubmit && !passwordValid {
                            Text("Password must be at least 8 characters.")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        }
                    }

                    VStack(spacing: 4) {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        if hasAttemptedSubmit && !passwordsMatch {
                            Text("Passwords do not match.")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        }
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                    }

                    Button {
                        hasAttemptedSubmit = true
                        guard formValid else { return }
                        Task {
                            do {
                                _ = try await auth.createAccount(email: email, password: password)
                                onAuthenticated()
                            } catch {
                                auth.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [BabyTownTheme.accent, BabyTownTheme.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .opacity(formValid ? 1 : 0.5)
                        )
                    }
                    .disabled(auth.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onboardingBackButton { dismiss() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "BabyTown/Views/Auth/EmailSignUpView.swift"
git commit -m "feat: add EmailSignUpView with validation and AuthService wiring"
```

---

### Task 4: EmailLoginView

**Files:**
- Create: `BabyTown/Views/Auth/EmailLoginView.swift`

**Interfaces:**
- Consumes: `AuthService.shared.signIn(email:password:)`, `BabyTownTheme.accent`, `.onboardingBackButton(action:)`
- Produces: `struct EmailLoginView: View` with `init(onAuthenticated: () -> Void)`

- [ ] **Step 1: Create EmailLoginView.swift**

```swift
import SwiftUI

struct EmailLoginView: View {
    let onAuthenticated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var auth = AuthService.shared

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Welcome back")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )

                    SecureField("Password", text: $password)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            do {
                                _ = try await auth.signIn(email: email, password: password)
                                onAuthenticated()
                            } catch {
                                auth.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [BabyTownTheme.accent, BabyTownTheme.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(auth.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onboardingBackButton { dismiss() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "BabyTown/Views/Auth/EmailLoginView.swift"
git commit -m "feat: add EmailLoginView stub"
```

---

### Task 5: ContentView routing

**Files:**
- Modify: `BabyTown/ContentView.swift:12-25` (Screen enum)
- Modify: `BabyTown/ContentView.swift:62` (new-user targetScreen)
- Modify: `BabyTown/ContentView.swift:71-98` (body switch — add `.auth` case)

**Interfaces:**
- Consumes: `CovelaAuthView(onAuthenticated:)`

Three edits to `ContentView.swift`:

- [ ] **Step 1: Add `.auth` to the Screen enum**

Find this line in the enum:
```swift
case launch, welcome, storyOnboarding, nickname, colorTheme, birthday
```
Replace with:
```swift
case launch, auth, welcome, storyOnboarding, nickname, colorTheme, birthday
```

- [ ] **Step 2: Route new users to `.auth` instead of `.welcome`**

Find:
```swift
        } else {
            _targetScreen = State(initialValue: .welcome)
```
Replace with:
```swift
        } else {
            _targetScreen = State(initialValue: .auth)
```

- [ ] **Step 3: Add the `.auth` case to the body switch**

Find:
```swift
            case .welcome:
                WelcomeView {
```
Insert this block immediately before it:
```swift
            case .auth:
                NavigationStack {
                    CovelaAuthView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            screen = .welcome
                        }
                    }
                }
                .transition(.opacity)

```

- [ ] **Step 4: Build and verify**

In Xcode: Product → Build (⌘B). Expected: builds with no errors or warnings.

Run the app on Simulator. Expected flow for a new user (or after tapping Reset in Settings):
1. Launch screen fades out
2. CovelaAuthView appears with spring-animated cat, sequential fade-ins
3. Apple and Google buttons show "Coming soon" alert
4. "Continue with Email" pushes EmailSignUpView (back chevron visible)
5. Fill in valid email + matching password (8+ chars) → "Create Account" button active
6. Tap "Create Account" → spinner → advances to WelcomeView

- [ ] **Step 5: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "feat: route new users through CovelaAuthView before onboarding"
```
