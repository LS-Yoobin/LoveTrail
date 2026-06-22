# Partner Invite and Pairing Backend — Design Spec

**Date:** 2026-06-22
**Status:** Approved
**Backend:** Supabase (PostgreSQL + Auth + Realtime + Storage + Edge Functions)

---

## Overview

When a Prelude user invites their partner, the backend must handle two distinct scenarios:

- **New user partner:** Partner has never used the app. Downloads via invite link, completes full onboarding, then accepts the invite.
- **Existing Prelude partner:** Partner already has the app and their own Prelude. Skips identity setup, goes straight to the gift reveal. Both users exchange their scrapbooks mutually.

The invite code is the handshake. One Edge Function creates it, one validates it, one pairs the accounts and snapshots both gifts into a permanent Prelude chapter.

---

## Jira Structure

**Epic:** Partner Invite and Pairing Backend

| Ticket | Title | Gates |
|---|---|---|
| SUB-1 | DB schema and row-level security setup | Unblocked |
| SUB-2 | Invite creation API (inviter side) | Requires SUB-1 |
| SUB-3 | Invite acceptance and account pairing API (partner side) | Requires SUB-1, SUB-2 |

---

## Database Schema

### `users`
One row per account. Created on first sign-in via Supabase Auth trigger.

```sql
CREATE TABLE users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id),
  email       TEXT UNIQUE NOT NULL,
  username    TEXT NOT NULL,
  avatar_url  TEXT,
  apple_sub   TEXT UNIQUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

### `couples`
One row per relationship. Created when the inviter finishes onboarding. `partner_id` is NULL until invite is accepted.

```sql
CREATE TABLE couples (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id           UUID NOT NULL REFERENCES users(id),
  partner_id           UUID REFERENCES users(id),
  relationship_stage   TEXT NOT NULL DEFAULT 'prelude'
                         CHECK (relationship_stage IN ('prelude', 'official', 'archived')),
  invite_sent          BOOLEAN NOT NULL DEFAULT FALSE,
  prelude_started_at   TIMESTAMPTZ,
  official_at          TIMESTAMPTZ,
  archived_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);
```

---

### `invites`
One row per invite sent. Resending cancels the previous row and creates a new one.

```sql
CREATE TABLE invites (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code             TEXT UNIQUE NOT NULL,
  couple_id        UUID NOT NULL REFERENCES couples(id),
  inviter_id       UUID NOT NULL REFERENCES users(id),
  inviter_name     TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled')),
  gift_capture_ids UUID[] NOT NULL DEFAULT '{}',
  expires_at       TIMESTAMPTZ NOT NULL,
  accepted_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
```

---

### `prelude_captures`
One row per capture. All captures private by default until `is_included_in_gift = true`.

```sql
CREATE TABLE prelude_captures (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id               UUID NOT NULL REFERENCES couples(id),
  created_by              UUID NOT NULL REFERENCES users(id),
  type                    TEXT NOT NULL
                            CHECK (type IN ('note', 'first', 'voice_memo', 'reason')),
  is_included_in_gift     BOOLEAN NOT NULL DEFAULT FALSE,
  is_partner_retroactive  BOOLEAN NOT NULL DEFAULT FALSE,
  note_text               TEXT,
  note_photo_url          TEXT,
  first_label             TEXT,
  voice_memo_url          TEXT,
  reason_text             TEXT,
  created_at              TIMESTAMPTZ DEFAULT NOW()
);
```

Privacy guarantee: captures with `is_included_in_gift = false` are never returned by any Edge Function or query. Edge Functions filter explicitly before returning gift data.

---

### `prelude_chapters`
Created once when the invite is accepted. Immutable snapshot of both users' gifts.

```sql
CREATE TABLE prelude_chapters (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id             UUID NOT NULL UNIQUE REFERENCES couples(id),
  start_date            TIMESTAMPTZ NOT NULL,
  official_date         TIMESTAMPTZ NOT NULL,
  inviter_capture_ids   UUID[] NOT NULL DEFAULT '{}',
  partner_capture_ids   UUID[] NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ DEFAULT NOW()
);
```

`partner_capture_ids` is an empty array if the partner was a new user with no prior Prelude.

---

## Row-Level Security

### `users`
```sql
-- Users read and update their own row only
CREATE POLICY "users_select_own" ON users FOR SELECT USING (id = auth.uid());
CREATE POLICY "users_update_own" ON users FOR UPDATE USING (id = auth.uid());
```

### `couples`
```sql
-- Both partners can read and update their shared couple row
CREATE POLICY "couples_select_member" ON couples FOR SELECT
  USING (inviter_id = auth.uid() OR partner_id = auth.uid());

CREATE POLICY "couples_update_member" ON couples FOR UPDATE
  USING (inviter_id = auth.uid() OR partner_id = auth.uid());

-- Edge functions handle INSERT via service role
```

### `invites`
```sql
-- Inviter sees their own rows
CREATE POLICY "invites_select_own" ON invites FOR SELECT
  USING (inviter_id = auth.uid());

-- INSERT and UPDATE via Edge Functions (service role) only
-- GET /invite/:code uses service role to look up by code — no public SELECT policy needed
```

### `prelude_captures`
```sql
-- Only members of the couple can read captures
CREATE POLICY "captures_select_member" ON prelude_captures FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM couples
      WHERE couples.id = prelude_captures.couple_id
      AND (couples.inviter_id = auth.uid() OR couples.partner_id = auth.uid())
    )
  );

-- Only the creator can insert, update, or delete their captures
CREATE POLICY "captures_insert_own" ON prelude_captures FOR INSERT
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "captures_update_own" ON prelude_captures FOR UPDATE
  USING (created_by = auth.uid());

CREATE POLICY "captures_delete_own" ON prelude_captures FOR DELETE
  USING (created_by = auth.uid());
```

### `prelude_chapters`
```sql
-- Only couple members can read; only Edge Functions can write (immutable after creation)
CREATE POLICY "chapters_select_member" ON prelude_chapters FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM couples
      WHERE couples.id = prelude_chapters.couple_id
      AND (couples.inviter_id = auth.uid() OR couples.partner_id = auth.uid())
    )
  );
-- INSERT via Edge Functions (service role) only; no UPDATE policy
```

---

## API Surface — Edge Functions

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
1. Verify caller has a `couples` row as `inviter_id`
2. Cancel any existing `pending` invite for this couple (set status = `cancelled`)
3. Generate a unique 6-char code (alphabet excludes 0, O, 1, I)
4. Insert `invites` row with status `pending`, expires in 30 days
5. Set `couples.invite_sent = true`

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
3. Check if a `users` row exists for the requesting device (via optional auth header)

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
3. Check if partner has an existing `couples` row as `inviter_id`
   - If yes: archive it (`relationship_stage = 'archived'`, `archived_at = now()`)
   - Collect partner's `is_included_in_gift = true` captures from the archived couple
4. Set `couples.partner_id = auth.uid()`
5. Set `couples.relationship_stage = 'official'`, `couples.official_at = now()`
6. Set `invites.status = 'accepted'`, `invites.accepted_at = now()`
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

**Realtime:** Both users are subscribed to their `couples` row. When `relationship_stage` flips to `official`, both apps receive the update simultaneously and transition to Official home without polling.

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

Realtime fires ◄────────────────────────────────────────────────────►

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
                                               → Archive Sarah's old couples row
                                               → Collect Sarah's is_included_in_gift captures
                                               → UPDATE couples.partner_id = Sarah
                                               → UPDATE stage = official
                                               → INSERT prelude_chapters
                                                  (inviter_capture_ids: Justin's gift,
                                                   partner_capture_ids: Sarah's gift)
                                               ← { inviter_gift_captures, partner_had_prelude: true,
                                                   partner_gift_captures }

                                               Sarah sees Justin's gift reveal

Realtime fires ◄────────────────────────────────────────────────────►

Justin: sees Sarah's gift reveal             Sarah: transitions to Official home
Justin: transitions to Official home
```

---

## Out of Scope

- Email verification flow
- Push notifications on invite acceptance (separate ticket)
- Invite expiry cron job (mark expired rows automatically)
- Partner retroactive entries post-pairing (adding "before I knew" captures after going official)
- Breakup archive and reconnect flows
- Editing email or avatar post-setup
- Gift capture order customization on the partner side
