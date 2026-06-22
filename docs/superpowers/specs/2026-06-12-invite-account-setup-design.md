# Invite Account Setup Flow

**Date:** 2026-06-12
**Branch:** watch
**Status:** Approved — ready for implementation planning

---

## Overview

When a Prelude user taps "Send Invite" for the first time, they are gated through a two-step account setup flow before the invite is dispatched: email entry, then an optional profile photo. On subsequent sends (resend), setup is already complete and the invite fires immediately.

---

## Flow

```
GiftCurationView
  └── "Send Invite" tapped
        ├── [account complete] → viewModel.sendInvite() → success alert (existing)
        └── [account not set up] → AccountSetupFlow (fullScreenCover)
              ├── Step 1: AccountEmailStep   (required)
              └── Step 2: AccountPhotoStep  (optional — skippable)
                    └── onComplete(result) → save email + avatar → sendInvite() → success alert
```

Account setup is considered complete when `DataPersistenceManager.shared.loadUserEmail() != nil`. No separate flag — derived from data presence.

---

## Data Model Changes

### `DataPersistenceManager`

Add two methods, mirroring the existing `saveUserNickname`/`loadUserNickname` pattern:

```swift
func saveUserEmail(_ email: String)
func loadUserEmail() -> String?
```

Stored in `UserDefaults` under a dedicated key (e.g. `"userEmail"`). Email is a user-account credential, not couple data — it lives alongside nickname in UserDefaults, not inside `CoupleProfile`.

No new persistence for the profile photo — `saveUserAvatar(_:)` and `loadUserAvatar()` already exist and are wired into the secret garden's `ProfileSticker.Kind.userAvatar`.

---

## Architecture

### New Files — `BabyTown/Views/Prelude/`

| File | Role |
|---|---|
| `AccountSetupFlow.swift` | Coordinator. Owns `Step` enum, drives transitions, surfaces single `onComplete`/`onCancel` callbacks. |
| `AccountEmailStep.swift` | Email entry screen. Stateless beyond the field binding passed from coordinator. |
| `AccountPhotoStep.swift` | Profile photo screen. Handles camera (`UIImagePickerController`) + library (`PHPickerViewController`) via SwiftUI representables. |

### `AccountSetupResult`

Defined in `AccountSetupFlow.swift`:

```swift
struct AccountSetupResult {
    let email: String
    let avatarImage: UIImage?  // nil if user skipped
}
```

The coordinator passes this to `GiftCurationView` via `onComplete`. The caller is responsible for persisting before calling `viewModel.sendInvite()`.

### Step Transition

`AccountSetupFlow` uses a `ZStack` with:

```swift
.transition(.asymmetric(
    insertion: .move(edge: .trailing),
    removal:   .move(edge: .leading)
))
```

Forward-only progression — no back navigation between steps.

---

## `AccountSetupFlow` (Coordinator)

```
AccountSetupFlow
  @State step: Step = .email
  @State email: String = ""
  @State avatarImage: UIImage? = nil
  var onComplete: (AccountSetupResult) -> Void
  var onCancel: () -> Void

  body:
    switch step {
    case .email:  AccountEmailStep(email: $email, onContinue: { step = .photo })
    case .photo:  AccountPhotoStep(avatarImage: $avatarImage, onComplete: { … })
    }
```

---

## Email Step (`AccountEmailStep`)

**Layout (top to bottom):**

1. `✕` cancel button — top-left, dismisses entire flow without sending
2. Progress indicator — 2-dot or `HeartProgressIndicator`, showing step 1 of 2
3. `envelope.fill` icon in `BabyTownTheme.accent` on a soft circle background
4. Title: "Create your account"
5. Subtitle: "Your username is already set. Just add your email."
6. Read-only username chip — pill showing `@{nickname}`, `BabyTownTheme.accentSoft` fill
7. Email text field — `.keyboardType(.emailAddress)`, `.textContentType(.emailAddress)`, `.autocorrectionDisabled()`, placeholder "you@example.com", auto-focused on appear
8. Inline validation hint — appears below field only after first blur if invalid. Soft gray: "Enter a valid email to continue." Hidden once valid.
9. `PrimaryCTAButton` "Continue" — disabled until email passes format check (`contains("@")` with a `.` after the `@`). Fires `.soft` haptic on tap.
10. Footer note — small `BabyTownTheme.textSecondary` text: "Used to connect with your partner. We'll never share it."

---

## Photo Step (`AccountPhotoStep`)

**Layout (top to bottom):**

1. `✕` cancel button — top-left, dismisses entire flow without sending
2. Progress indicator — step 2 of 2
3. Avatar circle (120pt) — empty: `BabyTownTheme.accentGradient` fill + `person.fill` SF Symbol. With photo: image clipped to circle. Tapping triggers source picker.
4. Camera badge — `camera.fill` pinned bottom-right of circle, alternative tap target for source picker
5. Title: "Add your photo"
6. Subtitle: "This will appear in your shared garden when your partner connects."
7. Source picker — `confirmationDialog` with "Take Photo", "Choose from Library", "Cancel"
8. `PrimaryCTAButton` — label "Continue" (no photo) / "Looks good" (photo set). Always enabled.
9. "Skip for now" plain text button — `BabyTownTheme.textSecondary`, below CTA. Sets `avatarImage = nil`, fires completion.

**Photo is not persisted on selection** — only on `onComplete`. A mid-step cancel leaves the existing avatar unchanged.

---

## `GiftCurationView` Changes

Minimal diff:

- Add `@State private var showAccountSetup = false`
- Replace send button action:
  ```swift
  if DataPersistenceManager.shared.loadUserEmail() != nil {
      viewModel.sendInvite()
      showInviteSent = true
  } else {
      showAccountSetup = true
  }
  ```
- Add `.fullScreenCover(isPresented: $showAccountSetup)`:
  ```swift
  AccountSetupFlow(
      onCancel: { showAccountSetup = false },
      onComplete: { result in
          DataPersistenceManager.shared.saveUserEmail(result.email)
          if let img = result.avatarImage {
              DataPersistenceManager.shared.saveUserAvatar(img)
          }
          showAccountSetup = false
          viewModel.sendInvite()
          showInviteSent = true
      }
  )
  ```
- Everything else in `GiftCurationView` unchanged.

---

## Complete Change Surface

| File | Change |
|---|---|
| `BabyTown/Services/DataPersistenceManager.swift` | Add `saveUserEmail` / `loadUserEmail` |
| `BabyTown/Views/Prelude/GiftCurationView.swift` | ~15-line send button change + one `fullScreenCover` |
| `BabyTown/Views/Prelude/AccountSetupFlow.swift` | New file — coordinator |
| `BabyTown/Views/Prelude/AccountEmailStep.swift` | New file — email screen |
| `BabyTown/Views/Prelude/AccountPhotoStep.swift` | New file — photo screen |

---

## Out of Scope

- Backend account creation / API calls (wired later)
- Email verification flow
- Editing email or photo post-setup (future settings screen)
- Subject lift / background removal on avatar photo
