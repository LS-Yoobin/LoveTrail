# Partner Invite and Pairing Backend — Design Spec

**Date:** 2026-06-22
**Status:** Approved
**Backend:** MongoDB Atlas (Database + JWT Auth + Change Streams + GridFS Storage)

---

## Overview

When a Prelude user invites their partner, the backend must handle two distinct scenarios:

- **New user partner:** Partner has never used the app. Downloads via invite link, completes full onboarding, then accepts the invite.
- **Existing Prelude partner:** Partner already has the app and their own Prelude. Skips identity setup, goes straight to the gift reveal. Both users exchange their scrapbooks mutually.

The invite code is the handshake. One API endpoint creates it, one validates it, one pairs the accounts and snapshots both gifts into a permanent Prelude chapter.

---

## Jira Structure

**Epic:** Partner Invite and Pairing Backend

| Ticket | Title | Gates |
|---|---|---|
| SUB-1 | MongoDB collection schemas and access control setup | Unblocked |
| SUB-2 | Invite creation API (inviter side) | Requires SUB-1 |
| SUB-3 | Invite acceptance and account pairing API (partner side) | Requires SUB-1, SUB-2 |

---

## Collections

### `users`
One document per account. Created on first sign-in.

```json
{
  "_id": "uuid",
  "email": "string (unique, indexed)",
  "username": "string",
  "avatar_url": "string | null",
  "apple_sub": "string | null (unique, sparse index)",
  "created_at": "ISODate"
}
```

---

### `couples`
One document per relationship. Created when the inviter finishes onboarding. `partner_id` is null until invite is accepted.

```json
{
  "_id": "uuid",
  "inviter_id": "ref: users._id (indexed)",
  "partner_id": "ref: users._id | null (indexed)",
  "relationship_stage": "enum: prelude | official | archived",
  "invite_sent": "boolean (default: false)",
  "prelude_started_at": "ISODate | null",
  "official_at": "ISODate | null",
  "archived_at": "ISODate | null",
  "created_at": "ISODate"
}
```

---

### `invites`
One document per invite sent. Resending cancels the previous document and creates a new one.

```json
{
  "_id": "uuid",
  "code": "string (unique, indexed)",
  "couple_id": "ref: couples._id",
  "inviter_id": "ref: users._id",
  "inviter_name": "string",
  "status": "enum: pending | accepted | expired | cancelled",
  "gift_capture_ids": ["ref: prelude_captures._id"],
  "expires_at": "ISODate",
  "accepted_at": "ISODate | null",
  "created_at": "ISODate"
}
```

---

### `prelude_captures`
One document per capture. All captures private by default until `is_included_in_gift: true`.

```json
{
  "_id": "uuid",
  "couple_id": "ref: couples._id (indexed)",
  "created_by": "ref: users._id (indexed)",
  "type": "enum: note | first | voice_memo | reason",
  "is_included_in_gift": "boolean (default: false)",
  "is_partner_retroactive": "boolean (default: false)",
  "note_text": "string | null",
  "note_photo_url": "string | null",
  "first_label": "string | null",
  "voice_memo_url": "string | null",
  "reason_text": "string | null",
  "created_at": "ISODate"
}
```

Privacy guarantee: captures with `is_included_in_gift: false` are never returned by any endpoint or query. All API handlers filter explicitly before returning gift data.

---

### `prelude_chapters`
Created once when the invite is accepted. Immutable snapshot of both users' gifts.

```json
{
  "_id": "uuid",
  "couple_id": "ref: couples._id (unique, indexed)",
  "start_date": "ISODate",
  "official_date": "ISODate",
  "inviter_capture_ids": ["ref: prelude_captures._id"],
  "partner_capture_ids": ["ref: prelude_captures._id"],
  "created_at": "ISODate"
}
```

`partner_capture_ids` is an empty array if the partner was a new user with no prior Prelude.

---

## Access Control

Access control is enforced at the API middleware layer. All routes except `GET /invite/:code` require a valid JWT. Each handler verifies document ownership before any read or write. No direct client database access.

### `users`
- **Read / Update:** caller's `_id` must match the document `_id`

### `couples`
- **Read / Update:** caller's `_id` must equal `inviter_id` or `partner_id`
- **Insert:** API layer only

### `invites`
- **Read:** caller's `_id` must equal `inviter_id`
- **Insert / Update:** API layer only
- `GET /invite/:code` uses a service credential to look up by code without user auth

### `prelude_captures`
- **Read:** caller must be a member of the document's `couple_id`
- **Insert:** `created_by` must equal caller's `_id`
- **Update / Delete:** caller's `_id` must equal `created_by`

### `prelude_chapters`
- **Read:** caller must be a member of the document's `couple_id`
- **Insert:** API layer only; no update path (immutable after creation)

---

## API Surface

### `POST /create-invite`
Called when the inviter taps "Send Invite" in `GiftCurationView` (after account setup).

**Auth:** Required

**Request body:**
```json
{
  "inviter_name": "Justin",
  "gift_capture_ids": ["uuid1", "uuid2", "uuid3"]
}
```

**Logic:**
1. Verify caller has a `couples` document as `inviter_id`
2. Cancel any existing `pending` invite for this couple (set status: `cancelled`)
3. Generate a unique 6-char code (alphabet excludes 0, O, 1, I)
4. Insert `invites` document with status `pending`, expires in 30 days
5. Set `couples.invite_sent: true`

**Response:**
```json
{
  "code": "X7KP4Q",
  "link": "https://covela.app/invite/X7KP4Q"
}
```

---

### `GET /invite/:code`
Called when the partner taps the deep link, before onboarding begins. Validates the code and tells the app whether this is a new or existing user.

**Auth:** None required

**Logic:**
1. Look up invite by code
2. Check status is `pending` and not expired
3. Check if a `users` document exists for the requesting device (via optional auth header)

**Response:**
```json
{
  "valid": true,
  "inviter_name": "Justin",
  "status": "pending",
  "existing_user": false
}
```

Returns `valid: false` if code is expired, accepted, or cancelled.

---

### `POST /accept-invite`
Called when the partner taps "Open our space" at the end of onboarding.

**Auth:** Required (partner must have created their account)

**Request body:**
```json
{
  "code": "X7KP4Q"
}
```

**Logic:**
1. Validate code is `pending` and not expired
2. Confirm caller is not the inviter (cannot accept own invite)
3. Check if partner has an existing `couples` document as `inviter_id`
   - If yes: archive it (`relationship_stage: 'archived'`, `archived_at: now()`)
   - Collect partner's `is_included_in_gift: true` captures from the archived couple
4. Set `couples.partner_id: auth.uid()`
5. Set `couples.relationship_stage: 'official'`, `couples.official_at: now()`
6. Set `invites.status: 'accepted'`, `invites.accepted_at: now()`
7. Insert `prelude_chapters`:
   - `inviter_capture_ids`: from `invites.gift_capture_ids`
   - `partner_capture_ids`: partner's curated captures (empty array if new user)
   - `start_date`: earliest capture `created_at` across both sets
   - `official_date`: now()
8. Return both gift payloads

**Response:**
```json
{
  "couple_id": "uuid",
  "inviter_name": "Justin",
  "partner_had_prelude": true,
  "inviter_gift_captures": [
    { "id": "uuid1", "type": "note", "note_text": "I keep thinking about you." },
    { "id": "uuid2", "type": "voice_memo", "voice_memo_url": "storage/path" }
  ],
  "partner_gift_captures": [
    { "id": "uuid3", "type": "reason", "reason_text": "The way you always laugh first." }
  ]
}
```

**Realtime:** Both clients open a MongoDB Change Stream (or WebSocket backed by one) watching their `couples` document. When `relationship_stage` flips to `official`, both apps receive the update simultaneously and transition to Official home without polling.

---

## Full User Flow

### New user partner path

```
Justin (Inviter)                            Sarah (New User Partner)
────────────────────────────────────────────────────────────────────

Sign in → INSERT users, INSERT couples
          (inviter_id = Justin, stage = prelude)

[Capture notes, firsts, voice memos, reasons]
→ INSERT prelude_captures

[Curate gift]
→ UPDATE prelude_captures.is_included_in_gift

[Account setup: email + photo]
→ UPDATE users

[Send Invite]
→ POST /create-invite
→ INSERT invites (pending, 30d)
→ UPDATE couples.invite_sent = true
← { code, link }

Justin shares link ─────────────────────────→ Sarah receives link

                                               Sarah taps link
                                               → GET /invite/CODE
                                               ← { valid, existing_user: false }

                                               Full PartnerOnboardingFlow:
                                               welcome → username → email
                                               → photo → color theme

                                               [Sarah taps "Open our space"]
                                               → POST /accept-invite { code }
                                               → Archive: nothing to archive
                                               → UPDATE couples.partner_id = Sarah
                                               → UPDATE stage = official
                                               → INSERT prelude_chapters
                                                  (partner_capture_ids: [])
                                               ← { inviter_gift_captures, partner_had_prelude: false }

                                               Sarah sees Justin's gift reveal

Change Stream fires ◄───────────────────────────────────────────────►

Justin: "Sarah accepted" notification        Sarah: transitions to Official home
Justin: transitions to Official home
```

---

### Existing Prelude partner path

```
Justin (Inviter)                            Sarah (Existing Prelude User)
────────────────────────────────────────────────────────────────────────

[Same invite creation flow as above]

Justin shares link ─────────────────────────→ Sarah receives link

                                               Sarah taps link
                                               → GET /invite/CODE
                                               ← { valid, existing_user: true }

                                               Trimmed onboarding:
                                               Skip username/email/photo/theme
                                               → Show Justin's gift reveal directly

                                               [Sarah taps "Open our space"]
                                               → POST /accept-invite { code }
                                               → Archive Sarah's old couples document
                                               → Collect Sarah's is_included_in_gift captures
                                               → UPDATE couples.partner_id = Sarah
                                               → UPDATE stage = official
                                               → INSERT prelude_chapters
                                                  (inviter_capture_ids: Justin's gift,
                                                   partner_capture_ids: Sarah's gift)
                                               ← { inviter_gift_captures, partner_had_prelude: true,
                                                   partner_gift_captures }

                                               Sarah sees Justin's gift reveal

Change Stream fires ◄───────────────────────────────────────────────►

Justin: sees Sarah's gift reveal             Sarah: transitions to Official home
Justin: transitions to Official home
```

---

## Out of Scope

- Email verification flow
- Push notifications on invite acceptance (separate ticket)
- Invite expiry cron job (mark expired documents automatically)
- Partner retroactive entries post-pairing (adding "before I knew" captures after going official)
- Breakup archive and reconnect flows
- Editing email or avatar post-setup
- Gift capture order customization on the partner side
