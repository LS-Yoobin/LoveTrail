# Partner Invite — Email + Code Redemption Design Spec

**Date:** 2026-06-23
**Status:** Approved
**Extends:** `2026-06-22-partner-invite-pairing-backend-design.md`

---

## Overview

When a Prelude user sends an invite, Covela emails the partner a branded invite with a link to the App Store and a visible 6-char code. The partner redeems it by typing the code in the app. No deep link service is required — the code is always visible in the email.

Two partner paths are supported:

- **New user:** Downloads the app, completes full onboarding, enters code at the end.
- **Existing Prelude user:** Opens the app, enters code from home or settings, skips identity setup, goes straight to gift reveal.

---

## End-to-End Flow

### Path 1 — New user partner

```
Inviter (Justin)                          Sarah (New user)
────────────────────────────────────────────────────────
Justin finishes curating his gift
Taps "Send Invite"
  → Account setup: own email + photo (if not done)
  → Enters Sarah's email address
  → POST /create-invite → code X7KP4Q
  → POST /send-invite-email
      Resend delivers branded email to Sarah

                                          Sarah receives email:
                                          "Justin wants to share something with you"
                                          [Open Covela] → App Store link
                                          "Or enter code: X7KP4Q"

                                          Downloads Covela → full onboarding:
                                          welcome → username → email
                                          → photo → color theme
                                          → "Have an invite code?" screen
                                          → Types X7KP4Q
                                          → POST /accept-invite
                                          → Gift reveal: sees Justin's Prelude

Change stream fires ◄───────────────────────────────────►
Justin: "Sarah accepted" notification    Sarah: transitions to shared home
Justin: transitions to shared home
```

### Path 2 — Existing Prelude user partner

```
Inviter (Justin)                          Sarah (Existing Prelude user)
────────────────────────────────────────────────────────────────────────
[Same invite + email send as above]

                                          Sarah receives email
                                          Opens Covela (already installed)
                                          Taps "Enter invite code"
                                          on PreludeHomeView or settings
                                          Types X7KP4Q
                                          → GET /invite/:code
                                            ← existing_user: true
                                          → Skips identity setup
                                          → Gift reveal: sees Justin's Prelude
                                          → POST /accept-invite
                                          → Both see each other's gifts

Change stream fires ◄───────────────────────────────────►
Both transition to shared home simultaneously
```

---

## UI Changes

### 1. `PartnerEmailStep` (new screen in `AccountSetupFlow`)

Added as Step 3 in `AccountSetupFlow`, after the inviter's own email and photo steps.

```
AccountSetupFlow
  Step 1: AccountEmailStep     ← inviter's own email (existing)
  Step 2: AccountPhotoStep     ← inviter's photo (existing)
  Step 3: PartnerEmailStep     ← NEW: partner's email
        ↓
  POST /create-invite + POST /send-invite-email
  → "Invite sent to sarah@email.com" confirmation
```

**Layout:**
- Title: `"Where should we send the invite?"`
- Subtitle: `"Your partner will get an email with a link to download Covela"`
- Email text field — `.keyboardType(.emailAddress)`, autocorrect off, placeholder `"partner@email.com"`
- "Continue" button — disabled until valid email format (`contains("@")` with `.` after)
- Footer: `"We only use this to send the invite. Nothing else."`

If the inviter has sent an invite before, the field is pre-filled with the stored `partnerEmail` and editable.

Persisted via `DataPersistenceManager.savePartnerEmail(_:)` under key `"partnerEmail"` — separate from the inviter's own email key `"userEmail"`.

### 2. Code entry — new user path

A new screen inserted at the end of `PartnerOnboardingFlow`, between color theme and gift reveal:

```
"Have an invite code?"

[  X7KP4Q        ]   ← 6-char field, auto-caps, no spaces, monospace font

[Connect]

─────────────────────
"No code yet"        ← plain text link → skips to solo Prelude home
```

On submit: calls `GET /invite/:code`. If valid, calls `POST /accept-invite`, then shows gift reveal. If invalid, shows inline error: `"That code doesn't look right. Check the email and try again."`

### 3. Code entry — existing user path

A persistent `"Enter invite code"` button added to `PreludeHomeView` (or `PreludeSettingsSheet` testing section during development). Tapping presents a modal with the same 6-char field.

On submit: same `GET /invite/:code` → `POST /accept-invite` flow.

### 4. Invite sent confirmation update

After `POST /send-invite-email` succeeds, the existing alert updates:

- Before: `"Invite sent!"`
- After: `"Invite sent to [sarah@email.com]"`

If `POST /send-invite-email` fails (Resend error or bad email), the app shows:
`"Couldn't send the email. Share the code directly: X7KP4Q"` — inviter can copy and send manually.

---

## Email Template

Sent via Resend from `no-reply@covela.app`.

**Subject:** `"[InviterName] wants to share something with you"`

**Body:**

```
[Covela wordmark]

[InviterName] made you something private.
A Prelude — just for you.

[Open Covela]           ← App Store link for Covela

Already have Covela? Enter your code:

    X7KP4Q

────────────────────────
You received this because [InviterName] invited you.
```

The `[Open Covela]` CTA links to the Covela App Store URL. The code is always printed in the email body — no deep link dependency. If the email client strips links, the partner still has the code.

---

## Backend

### Email Service: Resend

- Account at resend.com
- Sending domain: `no-reply@covela.app` (DNS verification, ~10 min setup)
- API key stored as `RESEND_API_KEY` environment variable on the backend
- **Cost:** $0 up to 3,000 emails/month, $20/month for up to 50,000

### New Endpoint: `POST /send-invite-email`

Called immediately after `POST /create-invite` succeeds.

**Auth:** Required

**Request:**
```json
{
  "partner_email": "sarah@email.com",
  "inviter_name": "Justin",
  "code": "X7KP4Q"
}
```

**Logic:**
1. Validate `partner_email` is valid email format
2. Confirm `code` belongs to the authenticated inviter (prevents spoofing)
3. Call Resend API with the email template
4. Write `partner_email` to `invites.partner_email` (for resend support)

**Response:**
```json
{ "sent": true }
```

**Errors:**
- `400` — invalid email format
- `500` — Resend API failure (app shows copy-code fallback)

### `invites` collection — one field added

All fields from the June 22 spec are unchanged. One field added:

```json
"partner_email": "string | null"
```

Stored when the invite is sent. Used if the inviter resends later.

### Full API surface

| Endpoint | Source |
|---|---|
| `POST /create-invite` | June 22 spec — unchanged |
| `GET /invite/:code` | June 22 spec — unchanged |
| `POST /accept-invite` | June 22 spec — unchanged |
| `POST /send-invite-email` | This spec — new |

---

## `DataPersistenceManager` Changes

| Method | Key | Notes |
|---|---|---|
| `savePartnerEmail(_ email: String)` | `"partnerEmail"` | New — partner's email, not inviter's |
| `loadPartnerEmail() -> String?` | `"partnerEmail"` | New — pre-fills `PartnerEmailStep` on resend |

`clearAllData()` must clear `"partnerEmail"` alongside existing keys.

---

## Complete Change Surface

| File | Change |
|---|---|
| `DataPersistenceManager.swift` | Add `savePartnerEmail` / `loadPartnerEmail`, clear in `clearAllData` |
| `AccountSetupFlow.swift` | Add `Step.partnerEmail` case, wire to `PartnerEmailStep` |
| `PartnerEmailStep.swift` | New file — partner email entry screen |
| `GiftCurationView.swift` / `AccountSetupFlow` | After account setup: call `POST /create-invite` then `POST /send-invite-email`, show updated confirmation |
| `PartnerOnboardingFlow.swift` | Add code entry screen before gift reveal |
| `PreludeHomeView.swift` | Add "Enter invite code" button |
| Backend | Add `POST /send-invite-email` endpoint, Resend integration, `partner_email` field on `invites` |

---

## Out of Scope

- Deep link / Universal Links (replaced by typed code)
- Branch.io or any deferred deep link service
- Covela sending the email on behalf of the inviter without a partner email (inviter must provide it)
- Email verification for the partner's email address
- Resending the email from within the app (future: resend button in invite status screen)
- Push notification on invite acceptance (separate spec)
- Invite expiry cron job (separate ticket)