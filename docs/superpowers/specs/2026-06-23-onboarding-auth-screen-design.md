# Onboarding Auth Screen Design

**Date:** 2026-06-23  
**Status:** Approved

## Overview

Insert an authentication screen as the first onboarding step, before the existing "Welcome to your Covela" screen. Users choose to sign in via Apple (stub), Google (stub), or Email (functional). This mirrors the pattern established in the Bloggo project's `AuthView`.

## Screen Flow

```
Launch → Auth (NEW) → Welcome → Nickname → ColorTheme → Birthday → PathSelector → ...
```

- Existing users who have completed onboarding skip `.auth` entirely — the `hasCompletedOnboarding` check in `ContentView.init` is unchanged.
- "Continue with Email" pushes `EmailSignUpView`; on success the onboarding advances to `.welcome`.
- "Already have an account? Log in" pushes `EmailLoginView` (stub).
- Apple and Google buttons show a "Coming soon" alert on tap.

## New Files

| File | Purpose |
|---|---|
| `BabyTown/Views/Auth/CovelaAuthView.swift` | Main auth screen |
| `BabyTown/Views/Auth/EmailSignUpView.swift` | Email + password sign-up form |
| `BabyTown/Views/Auth/EmailLoginView.swift` | Email + password log-in form (stub) |
| `BabyTown/Services/AuthService.swift` | Auth service with stub implementations |

## Modified Files

| File | Change |
|---|---|
| `BabyTown/ContentView.swift` | Add `.auth` case to Screen enum; route launch → auth for new users |

## CovelaAuthView

**Background:** Same warm white-to-`BabyTownTheme.accent.opacity(0.06)` gradient as `WelcomeView`. `FloatingHeartsView` overlay included. Both Pink and Blue themes work automatically via `BabyTownTheme` tokens — no hardcoded colors.

**Animations:** "First Page Cat" image spring-animates in on appear (mirrors `WelcomeView`). Text and buttons fade in sequentially.

**Layout (top to bottom):**
1. "First Page Cat" image — 100pt centered, spring scale + opacity on appear
2. Headline: `"Your private world starts here."` — serif, ~30pt bold
3. Auth buttons stacked with 12pt spacing:
   - **Continue with Apple** — black capsule, SF Symbol `apple.logo`, "Coming soon" alert on tap
   - **Continue with Google** — white capsule, programmatic G logo (4-color arc, same as Bloggo), "Coming soon" alert on tap
   - `"or"` divider — thin lines flanking centered text
   - **Continue with Email** — `BabyTownTheme.accent` gradient capsule (matches "Let's go." button), envelope icon, navigates to `EmailSignUpView`
4. Footer: `"Already have an account?"` + bold `"Log in"` — pushes `EmailLoginView`
5. `OnboardingLegalLinks()` — reuses existing component

## EmailSignUpView

**Background:** Same warm gradient. Back chevron top-left using existing `OnboardingBackButton` pattern.

**Layout:**
1. Headline: `"Create your account"` — serif, ~28pt bold
2. Form fields:
   - Email — `.emailAddress` keyboard, autocapitalization off
   - Password — `SecureField`
   - Confirm Password — `SecureField`
3. Inline validation (shown below fields, before first submit attempt):
   - Invalid email format
   - Password fewer than 8 characters
   - Passwords do not match
4. `"Create Account"` CTA — `BabyTownTheme.accent` capsule, disabled until all fields are valid; shows `ProgressView` spinner while the auth call is in flight
5. On success → calls `onAuthenticated()` → `ContentView` advances to `.welcome`

## EmailLoginView (stub)

Same layout as `EmailSignUpView` but with only Email + Password fields and a `"Log In"` CTA. Calls `AuthService.signIn`. Stub succeeds after a simulated delay.

## AuthService

`BabyTown/Services/AuthService.swift` — `ObservableObject`, singleton via `static let shared`.

```swift
struct AuthUser {
    let id: String
    let email: String
}

@Published var currentUser: AuthUser?
@Published var isLoading: Bool
@Published var errorMessage: String?

func createAccount(email: String, password: String) async throws -> AuthUser
func signIn(email: String, password: String) async throws -> AuthUser
```

**Stub behavior:** Both methods simulate an 0.8s network delay (`Task.sleep`) then return a mock `AuthUser`. Each has a `// TODO: Replace stub with real API call` comment marking the exact lines the backend teammate will replace.

`isLoading` and `errorMessage` are already wired into the views so error states display automatically once real errors come back from the API.

## Constraints

- No hardcoded hex or RGB — all colors via `BabyTownTheme.*` tokens
- No ` - ` (space dash space) in any user-facing string
- Both Pink and Blue themes must render correctly
- Apple and Google buttons must not perform any auth action (UI stubs only)
- `AuthService` interface must be clean for backend teammate to drop real implementation in with minimal changes
