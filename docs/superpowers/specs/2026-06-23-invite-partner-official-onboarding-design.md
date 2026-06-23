# Invite Partner — Official Onboarding Flow Design Spec

**Date:** 2026-06-23
**Status:** Approved

---

## Overview

When a user selects "Already Official" at the path selector, they currently flow through FirstMemories → HowItWorks → PhotoAccess → home. This spec inserts a partner connection step after FirstMemories and adds a post-acceptance reveal sequence, along with a locked home state for users whose partner has not yet joined.

---

## Revised Official Path

```
PathSelector → Official → FirstMemories → InvitePartnerView
                                               │
                  ┌────────────────────────────┼──────────────────────┐
           "Invite partner"             "I have a code"         (no skip at start)
                  │                           │
          POST /create-invite         POST /accept-invite
          → pending state              → joined immediately
          │        │
        wait   "Continue to your space"
                   │
             officialPending (PendingHomeView)
             pet only, all else dimmed
             polling in background
                   │
           partner accepts (Change Stream or poll)
                   │
     ┌─────────────┘
     │
     if partner_had_prelude: true → partnerGiftReveal
     if partner_had_prelude: false → skip to justPickPhotos
                   │
           justPickPhotos
                   │
           HowItWorks → PhotoAccess → home (full)
```

"Skip for now" (labelled "Continue to your space") is only available **after the invite has been sent** — it is not present on the initial card state. Users who skip land in `officialPending`, not the full home.

---

## New ContentView Screen Cases

Four cases added to the `Screen` enum:

| Case | Description |
|---|---|
| `.invitePartner` | Invite/referral screen, inserted after `.firstMemories` |
| `.officialPending` | PendingHomeView — locked home while waiting for partner |
| `.partnerGiftReveal` | Shows partner's Prelude scrapbook after acceptance |
| `.justPickPhotos` | Celebration bridge before HowItWorks |

### Navigation wiring

- `.firstMemories` `onFinished` callback navigates to `.invitePartner` (currently navigates to `.howItWorks` — this changes)
- `.invitePartner` `onSkip` navigates to `.officialPending`
- `.invitePartner` `onPartnerJoined(hadPrelude:)` navigates to `.partnerGiftReveal` or `.justPickPhotos`
- `.officialPending` transitions to `.partnerGiftReveal` or `.justPickPhotos` when polling detects acceptance
- `.partnerGiftReveal` `onContinue` navigates to `.justPickPhotos`
- `.justPickPhotos` `onContinue` navigates to `.howItWorks`

### App relaunch

`DataPersistenceManager` gets a new persisted flag: `pendingPartnerInvite: Bool`. When true and onboarding is complete, `loadLastActiveScreen` returns `officialPending` so the user lands back in `PendingHomeView` on relaunch rather than the full home.

---

## Screen 1 — InvitePartnerView

### State A: Choose action

Two tappable cards in the same rounded rect + shadow style as the rest of onboarding.

**Card A — Invite your partner**
- Icon: envelope with heart (SF Symbol: `envelope.heart.fill`)
- Label: "Invite your partner"
- Subtext: "Send them a link. They tap it and you are connected."
- Action: calls `POST /create-invite`, transitions screen to State B

**Card B — I have a code**
- Icon: key (SF Symbol: `key.fill`)
- Label: "I have a code"
- Subtext: "Enter the code from the email your partner sent you."
- Action: expands inline to show the code entry field (see below)

Back button at bottom returns to `.firstMemories`. No skip option at this state.

### State B: Pending (after invite sent)

The card area cross-fades out. Replaced by:

- **Pulsing rings animation:** three soft concentric rings expanding outward from a central heart icon, looping continuously. Built with SwiftUI Canvas or `withAnimation` repeating. Ring color: `BabyTownTheme.accent` at decreasing opacity (0.4 → 0.2 → 0.08).
- **Headline:** "Invitation sent" (serif, bold, 32pt)
- **Subtext:** "We will let you know the moment they join." (regular, muted)
- **"Copy code" action:** small text button below subtext, copies the 6-char code to clipboard. Label: "Copy invite code"
- **"Continue to your space" button:** muted, below the copy action. Tapping navigates to `.officialPending`. This is the only skip path.

The screen also begins polling for partner acceptance from this state (see Polling section).

### State C: Code entry (I have a code path)

An inline text field expands below Card B:

- Placeholder: "Enter your 6-character code"
- Character limit: 6, auto-uppercased
- "Join" button: enabled only when 6 chars are entered
- On tap: calls `GET /invite/:code` to validate, then `POST /accept-invite`
- On success: navigates to `.partnerGiftReveal` (if `partner_had_prelude: true`) or `.justPickPhotos`
- On error: inline error label below the field — "That code is not valid or has expired."

---

## Screen 2 — PendingHomeView

A dedicated view (separate file, not HomeView) that mirrors HomeView's visual shell. Navigation, tab bar, and overall layout are identical. Locked state is baked in — no conditionals in HomeView.

### Available features

- Pet adoption and pet room — fully functional
- Profile and settings

### Locked features (dimmed, non-interactive)

Dimming: opacity 0.35. Tapping any locked element shows a transient toast at the bottom of the screen:

> "Available once your partner joins"

Locked elements:
- Camera capture button
- Scan
- Prompt cards
- Letters tab

### Secret Garden tab

The "The Beginning..." typing effect is replaced with:

> Waiting for your partner...

Same character-by-character typing animation — same speed, same loop, never stops. The text restarts from the beginning each time it completes, identical to the existing "The Beginning..." behaviour.

### Nav area banner

A pill-shaped banner immediately below the nav bar. Soft `BabyTownTheme.accent` fill at 0.12 opacity, `BabyTownTheme.accent` text.

Copy: "Waiting for [partnerName]..." — where `partnerName` is the name stored from `POST /create-invite`. Falls back to "Waiting for your partner..." if name is unavailable.

The banner disappears (fades out) the moment the polling callback fires with an accepted invite.

### Polling

`PendingHomeView` starts a polling timer on `.onAppear` and cancels it on `.onDisappear`. Poll interval: 10 seconds. Each tick calls `GET /invite/:code` using the stored `pendingInviteCode` and checks whether `status === "accepted"`.

When acceptance is detected:
1. Cancel the timer
2. Clear the `pendingPartnerInvite` persistence flag
3. Navigate to `.partnerGiftReveal` if `partner_had_prelude: true`, otherwise `.justPickPhotos`

---

## Screen 3 — PartnerGiftRevealView

A parameterized view that works in both directions:
- **Inviter path:** shows the partner's Prelude captures. Only reached when `partner_had_prelude: true`.
- **Code-entry path (user is the partner):** shows the inviter's captures. Only reached when `inviter_gift_captures` is non-empty in the `POST /accept-invite` response.

`ContentView` passes `captures: [CaptureCard]` and `revealerName: String` when navigating to `.partnerGiftReveal`. These are held as temporary `@State` vars on `ContentView` and populated from the acceptance response before navigation.

### Layout

Full-screen scroll. Dark plum gradient background (matching the existing gift section in PreludeOnboardingView: `#4a1942 → #8b3d5c`).

**Header (pinned, not scrollable):**
- Title (serif, white): "[revealerName]'s Prelude"
- Subtext (small, white at 0.65 opacity): "This is how they felt before you were ever official."

**Scrollable body:**
Each capture rendered as a card — same visual style as existing capture cards in the scrapbook. Card types: note, first, voice memo, reason.

**Footer CTA (pinned):**
- Button: "Continue"
- Enabled only after the user has scrolled past the first capture card (first card fully out of the top of the viewport)
- Tapping navigates to `.justPickPhotos`

If the reveal captures array is empty, this screen is skipped entirely.

---

## Screen 4 — JustPickPhotosView

A warm, minimal celebration screen. No scroll needed.

### Layout (top to bottom, centered)

- **Photo collage:** the two founding moment images from FirstMemories, displayed as overlapping polaroid cards at slight rotation offsets. If only one photo was added (official photo only), show it as a single centered polaroid.
- **Title (serif, bold, 38pt):** "Just pick photos of us."
- **Subtext (regular, muted):** "Covela does the rest."
- **CTA button:** "Let's go" — full-width capsule, `BabyTownTheme.accentGradient`, navigates to `.howItWorks`

Background: same soft gradient as WelcomeView (white → `BabyTownTheme.accent` at 0.06 opacity).

---

## Data Persistence

New flags added to `DataPersistenceManager`:

| Key | Type | Purpose |
|---|---|---|
| `pendingPartnerInvite` | `Bool` | True while invite is sent and partner has not yet joined |
| `pendingInviteCode` | `String?` | The 6-char code, stored so it can be displayed/copied after relaunch |
| `pendingInvitePartnerName` | `String?` | Partner name for the banner copy |

These flags are cleared when acceptance is detected.

---

## Copy Rules

- No dash characters anywhere in user-facing strings
- All copy uses sentence case
- "Waiting for your partner..." uses an ellipsis character (`…`), not three dots

---

## Files Affected

| File | Change |
|---|---|
| `ContentView.swift` | Add `.invitePartner`, `.officialPending`, `.partnerGiftReveal`, `.justPickPhotos` Screen cases; wire navigation callbacks; update `firstMemories` `onFinished` to route to `.invitePartner`; update relaunch logic to check `pendingPartnerInvite` flag |
| `Views/Onboarding/InvitePartnerView.swift` | New file |
| `Views/Onboarding/PendingHomeView.swift` | New file |
| `Views/Onboarding/PartnerGiftRevealView.swift` | New file |
| `Views/Onboarding/JustPickPhotosView.swift` | New file |
| `Services/DataPersistenceManager.swift` | Add `pendingPartnerInvite`, `pendingInviteCode`, `pendingInvitePartnerName` persistence methods |

---

## Out of Scope

- Push notification when partner accepts (separate ticket)
- Resend invite flow
- Invite expiry UI (30-day expiry handled by backend)
- Real-time Change Stream / WebSocket (polling covers MVP; Change Stream is a backend upgrade path)
- Partner retroactive entries post-pairing
