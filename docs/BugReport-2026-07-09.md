# Covela Bug Analysis — 2026-07-09

Scope: full-codebase audit focused on recently shipped areas (pairing, Apple sign-in, watch together, photo selection) plus persistence and date logic. Findings ranked by severity, each with repro steps.

**Re-verified against `9ff089c`** (pull brought `a3bba82` + `9ff089c`: real email auth, per-account scoped storage, prelude media upload/import, invite flow rework). Finding 1 is fixed; the rest were re-confirmed against current code with updated line references. The ~1,700 new lines in the pairing/media-upload path have not had their own dedicated audit yet.

---

## HIGH

### 1. ~~Email sign-up is a stub that strands users~~ — FIXED in `9ff089c`
`createAccount` and `signIn` now call the real endpoints (`AuthService.swift:139-174` → `registerWithEmail`/`loginWithEmail` in `CovelaAPIClient.swift:56-65`) and persist the session via `persistSession`, so `isSignedIn` holds and survives relaunch. Verified the views are wired to it (`EmailSignUpView.swift:176`, `EmailLoginView.swift:154`).

---

### 2. Invite deep link pairs the device locally without redeeming any code
**Where:** `BabyTown/ContentView.swift:692-702` (onOpenURL) → `ContentView.swift:567-580` (partnerOnboarding onComplete)

**Problem:** Any `babytown://invite?from=Name` URL immediately routes to `PartnerOnboardingFlow`, regardless of current state (mid-prelude, already paired, mid-onboarding). On completion the app sets `relationshipStage = .officialCouple`, `setPartnerAccount(true)`, and marks onboarding complete — **without ever calling `accept-invite`**. The URL carries no code, so it can't redeem one. Consequences:
- Joiner's device believes it's paired; no couple exists on the backend.
- Inviter's poll (`PendingHomeView.swift:600-613`) never sees `accepted` and waits forever.
- Any app/website can flip an existing user's state by opening this URL.

The new server-side checks added in `9ff089c` (`resolveAlreadyPaired`, `routeAfterAuthentication` at `ContentView.swift:64-76,128`) only run on sign-in, not on the deep-link path, so they don't mitigate this.

**Repro:**
1. Device A: create an invite, sit on the pending screen.
2. Device B (any state): open Safari → `babytown://invite?from=Alex` → complete the partner flow.
3. Device B shows Home as an official couple; Device A polls forever; backend has no couple.

**Fix direction:** Deep link should carry the code and funnel into `InviteJoinFlow.join(code:)` (same path as `JoinWithCodeView`), and should be ignored or confirmed when the user is already paired.

---

### 3. All day-boundary logic is hardcoded to America/Los_Angeles
**Where:** `HomeViewModel.swift:1005,1061,1107` · `PetViewModel.swift:42,357` · `DaySection.swift:26,54,64` · `PotentialMemoryCard.swift:44` · `MemorySharePayload.swift:138` — 36 occurrences across 22 files as of `9ff089c` (unchanged by the pull).

**Problem:** Polaroid release ("9pm"), the polaroid release timer, daily check-in streaks, litter schedule, On This Day matching, and day-section labels all use LA time. For anyone outside US Pacific:
- Polaroids "release at 9pm" at midnight (US East), 5-6am (Europe), or midday the next day (Asia).
- Daily check-in: a user can check in twice in one local day and be paid twice (e.g. Berlin 8am = LA 11pm yesterday, Berlin 8pm = LA 11am today → two "days"), and `checkedInToday` reads false when it should be true.
- On This Day matches the wrong calendar day for photos taken near local midnight.

**Repro:** Set device timezone to Europe/Berlin. Check in at 8:00, again at 20:00 same day → second check-in awards coins again. Take a polaroid → unlock time shows 6:00 next morning instead of 21:00.

**Fix direction:** Replace the LA calendars with `Calendar.current` (user's local timezone). If LA was intentional for testing, gate it behind DEBUG.

---

### 4. `clearAllData()` leaves partner content and the auth session behind
**Where:** `BabyTown/Services/DataPersistenceManager.swift:1061-1098`, called from `ContentView.swift:39-57` (resetAppToWelcome)

**Context change in `9ff089c`:** storage is now per-account scoped (files under `CovelaUserData/<userId>/`, defaults in a `com.covela.userdata.<userId>` suite), so leftovers no longer bleed into a *different* account. The reset path still leaves them inside the current scope, and since the reset doesn't sign out, that scope stays active:
- `letter_photos/`, `letter_stickers/`, `letter_voice_memos/` directories (letter JSON is deleted, its media is not; prelude media dirs *are* deleted)
- special-date photos and profile-sticker images inside `pinned_photos/` (only first_met/official/avatars are removed by name)
- UserDefaults: `celebratedMomentMilestones`, `petNeedsNotifiedWhileLow`, `petMissesYouNotifiedForInteractionAt`, `hasUnreadMail`, `SelectPhotos_SelectedYear/Month`
- The Keychain auth session (`KeychainTokenStore`) — after a "full reset" the user is still signed in as the previous account.

For a privacy-first couples app, an ex-partner's letter photos and voice memos surviving a reset is the serious part.

**Repro:** Write a letter with a photo and voice memo → reset app from Home settings → inspect `CovelaUserData/<scope>/`: `letter_photos/*.jpg` and `letter_voice_memos/*` are still there; relaunch skips auth because the Keychain session survived.

**Fix direction:** Enumerate and delete the three letter media directories and `pinned_photos/` wholesale (then recreate), remove the missing keys, and call `AuthService.shared.signOut()` from the reset path.

---

## MEDIUM

### 5. Prelude user who creates a gift invite gets hijacked to the couple pending screen on relaunch
**Where:** `GiftCurationView.swift:115` sets the pending invite flag; `ContentView.swift:93` routes any pending invite to `.officialPending` before the `.prelude` check at `ContentView.swift:99`.

A user in the Prelude phase who generates an invite code stays in Prelude for the session, but on next launch `hasPendingPartnerInvite()` wins over `relationshipStage == .prelude` and they land on `PendingHomeView` (Together-phase pending home). Prelude home becomes unreachable until the invite resolves.

**Repro:** Prelude path → create invite code → force-quit → relaunch → couple pending screen instead of Prelude home.

### 6. Session token and API responses printed to console in Release
**Where:** `CovelaAPIClient.swift:161,169`. Request logging improved in `9ff089c` (only key names and value lengths now), but line 169 still prints the **full response body** — including the session token returned by the auth endpoints. `AuthService.swift:101-108` still logs identityToken prefix/lengths, and the new prelude sync path (`PreludeAPIClient.swift:55-85,112,132`) logs capture ids and media paths on every operation. None of it is compiled out in Release. Wrap in `#if DEBUG` or use a logger with redaction.

### 7. Joiner's gift to the inviter is dropped; inviter never sees any reveal
**Where:** `InviteAPIClient.swift:242,249` — `acceptInvite` decodes `partnerGiftCaptures` and `partnerHadPrelude` but only maps `inviterGiftCaptures` (`InviteAPIClient.swift:309`). Both inviter-side polls still hard-code empty captures (`PendingHomeView.swift:612`, `OnboardingInviteView.swift:453` — now with an explicit comment acknowledging the poll never receives captures). Net effect: when the joining partner had their own Prelude gift, it is silently discarded — nobody ever displays it.

Note: the *joiner's* side of the exchange is now solid — `PartnerGiftCaptureImporter` (new in `9ff089c`) downloads and persists the inviter's gift media locally. Only the inviter-side reveal is missing.

### 8. Watch Together camera fails silently
**Where:** `WatchTogetherViewModel.swift:90-92`. Errors from `startHosting`/`join` are only printed; `isCameraModeEnabled` stays false and the UI gives no feedback — the button just appears dead. Surface an error state (per voice rules: specific, no "Something went wrong").

### 9. `isPartnerAccount()` heuristic can invert who's who
**Where:** `DataPersistenceManager.swift:565-568` — falls back to "partnerEmail set AND userEmail unset". Partially mitigated in `9ff089c`: `AccountSetupFlow` now saves `userEmail` on the prelude invite path (`GiftCurationView.swift:84`) and profile settings does too (`ProfileSettingsView.swift:260`). But an Apple-sign-in inviter on the onboarding invite path still never gets `userEmail` saved, and `OnboardingInviteView` still persists the partner's email — once that runs, the inviter is misclassified as the invited partner: avatars swap (`ProfileStickerSync.swift:66`), greeting/partner names invert. Latent while email invites are disabled; will activate the day they go live.

### 10. Prelude backend sync: inconsistent key + wrong response type
**Where:** `PreludeAPIClient.swift:98` sends `milestoneDate` (camelCase) among otherwise snake_case keys — verify the backend actually reads it; likely silently dropped. `updateCapture` and `updateGiftInclusion` (lines 133, 143) decode `CaptureIdResponse` from a PATCH (an `OKResponse` struct exists at line 30 but is unused there); if the server answers `{ok:true}` the decode throws and the fire-and-forget sync fails silently on every edit.

---

## LOW

- **Swift 6 races flagged by the compiler:** `WatchTogetherSessionService.swift:16-19` builds `@MainActor` singletons from nonisolated default-argument context; `GardenActMapper.swift:144` ("error in Swift 6 mode"); `AuthService.swift:46`; `WatchTogetherCallController.swift:210`. Build passes today; will break on the language-mode bump.
- **Missing asset:** image set `scanning_cats` references `scanning_cats.png` which doesn't exist (build warning) → renders blank wherever used.
- **`StoreManager.shared.resetForTesting()`** is called in the production reset path (`ContentView.swift:42`).
- **Apple sign-in never captures the user's email into local profile** — improved in `9ff089c`: `displayName` is now sent to the backend (`AuthService.swift:114-117`), but the session is still persisted with `email: nil` (`AuthService.swift:119`); `currentUser.email` is always `""`. Apple only provides these on first authorization, so the local copy is lost permanently unless saved then.
- **Email invite feature is a visible dead end:** `LiveInviteAPIClient.sendInviteEmail` unconditionally throws "Email invites aren't available yet" (`InviteAPIClient.swift:184-186`) while `OnboardingInviteView` still offers the email field.
- **No TURN server** in `WatchTogetherCallController.swift:26-28` (STUN only) — calls will fail to connect across symmetric NATs (common on cellular). Expected at this stage, noting for launch.

---

## Verified-clean areas
- `HomeViewModel.swift:1155 sortedMoments.first!` — safe (Dictionary(grouping:) guarantees non-empty groups).
- `loadCoupleProfile` → `saveCoupleProfile` → `NotificationManager.refresh()` re-entrancy — bounded, terminates after migration/prune settle.
- `SelectPhotosViewModel.loadFullSizeImage` continuation — single-callback delivery mode + `hasResumed` guard; no leak.
- `PendingHomeView` poll timer lifecycle — started/stopped correctly on appear/disappear (`PendingHomeView.swift:595-598`).
- Email auth wiring (re-checked after `9ff089c`) — real endpoints, Keychain persistence, error surfacing in both views.
