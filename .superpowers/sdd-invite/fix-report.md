# Fix Report — Invite Partner Onboarding Code Review

**Status:** All 4 fixes applied and committed.

**Commit:** `67c7034`

## Fix 1 (Critical): `setOnboardingCompleted(true)` before officialPending
**Applied.** In `BabyTown/ContentView.swift`, added `DataPersistenceManager.shared.setOnboardingCompleted(true)` immediately before `screen = .officialPending` inside the `.invitePartner` case's `onSkip` closure. App relaunch after invite send now correctly resumes at `.officialPending`.

## Fix 2 (Important): Read name before clear
**Applied in both files.**
- `BabyTown/Views/OnboardingInviteView.swift` (`checkForAcceptance`): `revealerName` is now read from persistence before `clearPendingInviteState()` is called.
- `BabyTown/Views/PendingHomeView.swift` (`checkAcceptance`): `name` is now read from persistence before `clearPendingInviteState()` is called.

## Fix 3 (Important): Remove wrong `savePendingInvitePartnerName` call
**Applied.** Removed `DataPersistenceManager.shared.savePendingInvitePartnerName(inviterName)` from `sendInvite()` in `BabyTown/Views/OnboardingInviteView.swift`. The fallback of `"your partner"` will be used as intended. `PendingHomeView.partnerName` confirmed correct: it uses `loadPendingInvitePartnerName() ?? "your partner"`.

## Fix 4 (Important): Remove hyphens from user-facing strings
**Applied.** In `BabyTown/Views/OnboardingInviteView.swift`:
- `"Enter the 6-character code from the invite email."` → `"Enter the 6 character code from the invite email."`
- `"Enter your 6-character code"` (placeholder) → `"Enter your 6 character code"`
