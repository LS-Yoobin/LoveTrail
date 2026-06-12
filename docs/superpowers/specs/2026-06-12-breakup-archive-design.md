# Covela — Breakup & Archive System Design (PDR)

## Context

Covela's Prelude system design (2026-06-11) defined three relationship stages — `prelude`, `officialCouple`, `archivedCouple` — and sketched a high-level archive + reconnect flow, deferring its full design. This document is the full PDR for that deferred system.

**Core product promise:** When a couple breaks up, their shared story doesn't vanish overnight. Both users enter a shared "scrapbook" — a read-only archive of everything they built together. They have time to export their memories, reflect, and potentially reconnect. When they're ready to move on, they step out deliberately. The moment they do, the door closes.

---

## Relationship Lifecycle

```
prelude
   ↓ (partner accepts invite)
officialCouple
   ↓ (either user initiates breakup + confirms)
archivedCouple  ←────────────────────────────────────────────┐
   ├─ [scrapbook active — both browsing]                      │
   │     ↓ (either sends reconnect invite + other accepts)    │
   │  officialCouple  ← archive chapter preserved in timeline │
   │                                                          │
   ├─ [one or both step out explicitly]                       │
   │     ↓                                                    │
   │  prelude (solo)  — no archive access                     │
   │  (partner still in scrapbook can still invite back ──────┘)
   │
   └─ [retention timer expires, no extension]
         ↓
      archive bundle permanently wiped — both auto-exit to prelude
```

### Key Rules

- Breakup can be initiated by either user; requires explicit confirmation
- Both users enter `archivedCouple` simultaneously
- Retention timer starts at breakup confirmation: **30-day default**
- Either user can silently extend by 30 days, unlimited times
- "Stepping out" is always a deliberate, explicit action — it is permanent and immediate
- App deletion + 30 days of no server activity is treated as a step-out signal; the other user's timer continues normally
- Reconnect is possible as long as at least one user remains in `archivedCouple` — even if their partner has already stepped out into Prelude
- Timer expiry with no extension: server wipes the archive bundle and both users are auto-exited to Prelude

---

## Data Categories

### Preserved in Archive Bundle (server-side, read-only for both users)

| Category | What's kept |
|---|---|
| Moments | All metadata: captions, voice notes, location, date, pinned status |
| Photos & Videos | Actual image/video bytes, uploaded to server at breakup (see Upload Note) |
| Couple Profile | Display names, special dates, profile note, sticker layout |
| Garden | Full layout snapshot — sticker positions, vinyl player, Watch Together TV |
| Pet | Full state snapshot — cat identity, room décor, trick training, coins. Pet does not decay in the archive. |
| Playlist | All shared tracks |
| Prelude Chapter | Full origin story (gift captures only — private captures stay with their creator forever) |

### Personal Data — Never Touched by Breakup

| Category | Why |
|---|---|
| Each user's camera roll photos | Not Covela's data — the app only referenced them |
| Private Prelude captures (not in gift) | Always belonged to the creator alone |
| Each user's account and login | Required for scrapbook access and eventual Prelude restart |

### Wiped at Expiry or When Both Have Stepped Out

The full archive bundle: photos, videos, voice notes, all metadata, garden snapshot, pet snapshot, couple profile, playlist, Prelude chapter.

---

### Upload Note

Moments today store `assetIdentifier` — a reference to the user's camera roll, not actual bytes. For the server-side archive to work, the app must upload all photo and video data at breakup confirmation. This is a meaningful upload operation. The UX must account for it with a progress screen during the "archiving" step. Upload failure should be retryable; breakup state is not committed until the upload succeeds.

---

## Retention Timer

- **Default:** 30 days from breakup confirmation date
- **Extension:** Either user can tap "Extend" to add 30 days. Silent — no notification to the other user. Resets clock from current date (not from original breakup date). Unlimited extensions allowed.
- **Notifications** (push, to both users still in scrapbook):
  - 7 days before expiry: *"Your shared memories expire in 7 days. Export or extend to keep them."*
  - 3 days before expiry: final warning
  - Day of expiry: *"Your memories have been deleted."*
- Users who have already stepped out receive no notifications.

### Early Wipe Triggers

| Trigger | Outcome |
|---|---|
| Both users step out | Server wipes immediately — no need to wait for timer |
| One steps out, other's timer expires | Server wipes at timer expiry |
| App deleted + 30 days no server activity | Treated as step-out signal; other user's timer continues |

---

## Export

Available to both users at any point during the scrapbook state, before stepping out.

### Export Package Contents

- All photos and videos (full resolution, organized by date)
- Captions alongside their photos
- Voice notes as audio files alongside their Moments
- Special dates as a plain list
- Prelude chapter captures (text notes, voice memos, firsts, reasons)
- Cover page: *"[Name] & [Name] — [relationship start date] to [breakup date]"*

### Export Format

ZIP file, generated server-side on demand. Delivered via iOS share sheet — user can save to Files, AirDrop, iCloud Drive, etc.

### Excluded from Export

Garden layout, pet state, playlist. These are interactive states, not memory artifacts. Users who want their shared playlist already have it in Apple Music / Spotify.

---

## UX Flows

### Breakup Initiation

1. Either user: Relationship Settings → *"End Relationship"*
2. Confirmation screen: *"This will archive your story. You'll both have 30 days to export your memories or reconnect."* — neutral, no guilt, no dramatic framing
3. On confirm: progress screen while uploading all photos and videos to server archive bundle
4. On upload complete: both users simultaneously enter `archivedCouple`
5. Other user receives push notification: *"Your shared story has been archived."* — no name, no blame

### Scrapbook Home Screen

Replaces the normal home screen. Soft, muted visual treatment — still, not actively sad.

- **Top bar:** Retention countdown — *"Memories available for 23 more days"* + **Extend** button + **Export** button
- **Reconnect banner** (subtle, below top bar): *"Changed your mind? Invite [Name] back"* — always visible, never pressuring
- **Feed:** Read-only Moments in reverse chronological order — same visual layout as active home, no editing or pinning
- **Bottom tabs:** Garden (frozen), Pet (frozen, alive, no decay), Profile (read-only)

### Stepping Out

1. User taps *"Start Fresh"* in settings
2. Confirmation: *"You'll lose access to your shared memories. This can't be undone."*
3. On confirm: server immediately revokes their access; local couple data cleared; user lands on Prelude home
4. If the other user is still in scrapbook, their reconnect banner updates: *"[Name] has moved on. You can still invite them back."*

### Reconnect Flow

1. User in scrapbook (or ex-partner who stepped out into Prelude — see below) taps reconnect banner → sends invite
2. Other user receives push notification — even if they've stepped out into Prelude
3. Other user sees a modal: *"[Name] wants to continue your story. Accept to return to your shared archive."*
4. If accepted: both return to `officialCouple`. The archive period becomes a labeled chapter in the shared timeline — *"[Breakup date] – [Reconnect date]: A chapter apart."* Garden and pet resume from their frozen states.
5. If declined: invite expires, scrapbook continues for the sender

**Reconnect eligibility:**
- At least one user must still be in `archivedCouple` (not stepped out) to send an invite
- A user who has stepped out into Prelude can *receive and accept* a reconnect invite from their ex
- If both have stepped out, reconnect is not possible through the app

### Support Recovery

Users who have stepped out, or whose data has expired, may contact support at the app's support email. Business logic for support-side recovery:

- Within the 30-day timer: data is intact on the server; support can re-grant access manually
- After expiry: data is wiped; support cannot recover it
- Support team should be briefed that recovery is only possible within the active retention window

---

## Data Models

### Additions to `CoupleProfile`

```swift
// Already defined in Prelude spec:
var relationshipStage: RelationshipStage

// New fields:
var breakupDate: Date?          // set when entering archivedCouple
var archiveExpiryDate: Date?    // breakupDate + 30 days, reset on each extension
var hasSteppedOut: Bool         // true once this user exits permanently
```

### New: `ArchiveBundle` (server-side; local read-only cache for scrapbook browsing)

```swift
struct ArchiveBundle: Codable {
    let coupleId: String
    let breakupDate: Date
    var expiryDate: Date
    var userASteppedOut: Bool
    var userBSteppedOut: Bool

    // Snapshots of all shared state captured at breakup time
    var moments: [Moment]
    var coupleProfile: CoupleProfile   // includes garden layout: stickers, positions, scales
    var petState: PetState             // frozen snapshot — StoredNeed values not re-evaluated; no decay in scrapbook
    var playlist: [CouplePlaylistTrack]
    var preludeChapter: PreludeChapter?

    // Photo and video asset bytes stored server-side, keyed by Moment.id
    // Local cache: ThumbnailStore populated from server on scrapbook load
}
```

### New: `BreakupReconnectInvite`

```swift
struct BreakupReconnectInvite: Codable {
    let id: UUID
    let senderUserId: String
    let recipientUserId: String
    let sentAt: Date
    var status: InviteStatus

    enum InviteStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired     // sender stepped out before recipient responded
    }
}
```

### `RelationshipStage` (unchanged from Prelude spec, reproduced for clarity)

```swift
enum RelationshipStage: String, Codable {
    case prelude
    case officialCouple
    case archivedCouple
}
```

`hasSteppedOut: Bool` on `CoupleProfile` distinguishes a user still browsing the scrapbook from one who has moved on. Both technically remain in `archivedCouple` on the server until the bundle is wiped, but access is revoked the moment `hasSteppedOut` becomes `true`.

---

## Backend Business Logic

| Event | Server Action |
|---|---|
| Breakup confirmed | Create `ArchiveBundle`; upload photos/videos; set `expiryDate = now + 30 days`; notify both users |
| Extend tapped | Reset `expiryDate = now + 30 days`; no notification to other user |
| 7-day warning | Push to all users with `hasSteppedOut == false` |
| 3-day warning | Push to all users with `hasSteppedOut == false` |
| `expiryDate` reached | Wipe `ArchiveBundle`; set both users to `prelude`; push expiry notification |
| User steps out | Set `hasSteppedOut = true`; revoke access token; clear local data; if both stepped out → wipe immediately |
| App deleted + 30-day inactivity | Treat as step-out; other user's timer continues |
| Both stepped out | Wipe `ArchiveBundle` immediately |
| Reconnect accepted | Restore `officialCouple`; restore garden + pet from frozen snapshots; write archive chapter to timeline |

---

## Files to Create / Modify

### New Files

| File | Purpose |
|---|---|
| `BabyTown/Models/ArchiveBundle.swift` | Archive bundle model |
| `BabyTown/Models/BreakupReconnectInvite.swift` | Reconnect invite model |
| `BabyTown/Views/Breakup/BreakupInitiationView.swift` | Confirmation flow + upload progress |
| `BabyTown/Views/Breakup/ScrapbookHomeView.swift` | Read-only archive home screen |
| `BabyTown/Views/Breakup/ScrapbookGardenView.swift` | Frozen garden in scrapbook |
| `BabyTown/Views/Breakup/ScrapbookPetView.swift` | Frozen pet in scrapbook |
| `BabyTown/Views/Breakup/StepOutConfirmationView.swift` | "Start Fresh" confirmation |
| `BabyTown/Views/Breakup/ReconnectInviteView.swift` | Send / receive reconnect invite |
| `BabyTown/Views/Breakup/ExportProgressView.swift` | Export ZIP generation + share sheet |
| `BabyTown/Services/ArchiveService.swift` | Upload, extend, export, wipe orchestration |

### Modified Files

| File | Change |
|---|---|
| `BabyTown/Models/CoupleProfile.swift` | Add `breakupDate`, `archiveExpiryDate`, `hasSteppedOut` |
| `BabyTown/Views/HomeView.swift` | Gate on `relationshipStage`; route to `ScrapbookHomeView` for `archivedCouple` |
| `BabyTown/Services/DataPersistenceManager.swift` | Add persistence for `ArchiveBundle` local cache |
| `BabyTown/AppDelegate.swift` | Handle push notifications for expiry warnings and reconnect invites |

---

## Implementation Order

1. `CoupleProfile` new fields + `RelationshipStage.archivedCouple` persistence
2. `ArchiveBundle` model + `DataPersistenceManager` local cache
3. `ArchiveService` — upload, extend, export, wipe, step-out
4. `BreakupInitiationView` — confirmation + upload progress
5. `ScrapbookHomeView` — read-only feed + retention bar + reconnect banner
6. `ScrapbookGardenView` + `ScrapbookPetView` — frozen states
7. `StepOutConfirmationView` — "Start Fresh" flow
8. `ExportProgressView` — ZIP generation + share sheet
9. `BreakupReconnectInvite` model + `ReconnectInviteView` — send + receive
10. `HomeView` gating for `archivedCouple`
11. Push notification handling for expiry warnings and reconnect invites
12. Backend: archive bundle storage, retention timer cron, wipe job, reconnect invite API

---

## Verification

1. Initiate breakup → confirm upload progress screen appears and completes. Verify both users enter `archivedCouple`.
2. Verify scrapbook home shows all Moments, frozen garden, frozen pet, retention countdown.
3. Verify no editing or pinning is possible in scrapbook.
4. Tap Extend → verify `archiveExpiryDate` resets to `now + 30 days`. Verify no notification sent to other user.
5. Tap Export → verify ZIP is generated with photos, voice notes, captions, special dates, Prelude chapter. Verify share sheet appears.
6. One user steps out → verify they land on Prelude home. Verify the other user's scrapbook shows updated reconnect banner.
7. User still in scrapbook sends reconnect invite → verify other user (now in Prelude) receives push notification and sees the accept/decline modal.
8. Reconnect accepted → verify both return to `officialCouple`, archive chapter appears in timeline, garden and pet resume from frozen state.
9. Reconnect declined → verify scrapbook continues normally for sender.
10. Both users step out → verify server wipes `ArchiveBundle` immediately (confirm via support-side data check).
11. Simulate timer expiry → verify push notifications at 7 days and 3 days. Verify bundle is wiped on day 30. Verify both users auto-transition to Prelude.
12. App deletion simulation (no server activity for 30+ days) → verify treated as step-out; other user's timer continues.
