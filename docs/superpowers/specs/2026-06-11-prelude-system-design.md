# Covela — Three Relationship Stages: Prelude System Design

## Context

Covela is currently built around an assumed "already a couple" state — memories, garden, pet, and profile all presuppose an official relationship. The app has no explicit relationship lifecycle.

**Core insight:** Prelude is a solo experience. One person is quietly falling for someone. They capture that feeling in real time — notes, firsts, voice memos, reasons. When they're ready, they invite their partner. The invite is the reveal: the partner's first experience of the app is receiving the gift of your Prelude. Then the full app — garden, pet, shared timeline — unlocks for both.

Core promise from the product docs: *"Capture the story before it becomes a relationship."*

---

## Relationship State Machine

Three meaningful states. Everyone who opens Covela is in Prelude — that's the whole reason they're here.

```
prelude
   ↓ (partner accepts invite)
officialCouple
   ↓ (either user archives)
archivedCouple
   ↓ (either user reconnects, other confirms)
officialCouple  ← returns to active; archive chapter preserved in timeline
```

`RelationshipStage` enum:
```swift
enum RelationshipStage: String, Codable {
    case prelude           // building captures, partner not on the app yet
    case officialCouple    // partner accepted invite; full app unlocked
    case archivedCouple    // relationship archived
}
```

**Invite pending** is a boolean flag on `CoupleProfile` (`inviteSent: Bool`), not a separate stage. The app shows a *"Waiting for [name]…"* banner in Prelude once the invite is sent — the experience doesn't change meaningfully until they accept.

**Transitions:**
- `prelude → officialCouple`: partner accepts invite; gift reveal plays; full app unlocks
- `officialCouple → archivedCouple`: deliberate archive action with explicit confirmation
- `archivedCouple → officialCouple`: reconnect flow; archive chapter stays in timeline

---

## Feature Access by Stage

| Feature | Prelude | Official | Archived |
|---|---|---|---|
| Capture (Notes, Firsts, Voice, Reasons) | ✅ Core | ❌ | ❌ |
| Private captures (not in gift) | ✅ Always private | ✅ Still private | ✅ Read-only |
| Gift curation + invite | ✅ Available | ❌ | ❌ |
| Shared memory capture | ❌ | ✅ | ✅ Read-only |
| Home timeline | ❌ | ✅ Full timeline | Read-only archive |
| Garden | ❌ | ✅ | Frozen |
| Pet | ❌ | ✅ | Frozen |
| Prelude chapter (permanent) | ❌ | ✅ Readable | ✅ Read-only |

---

## Prelude Home

A personal capture feed. Chronological, intimate, built just for the person you're falling for.

**Top of screen:** Soft "Invite [Name]" banner — always accessible, never pressuring.

**Feed:** All captures in reverse chronological order. Each entry shows its type (Note, First, Voice, Reason), date, and preview.

**Quick capture bar (bottom):** Four capture types always one tap away.

**Reflection prompts:** When the user opens any capture type, the app offers a prompt to start from — never a blank page. These are suggestions only.

---

## Four Capture Types

All captures are private to the creator until they explicitly include them in the gift.

### Note
Short text reflection. Prompted by: *"What made you think about them today?"* Optional photo attachment. Reflection prompt examples:
- "What surprised you about them this week?"
- "What do you like about who you are when you're around them?"
- "What's something small they did that you keep thinking about?"

### First
A milestone moment tagged as a "first." User selects from a list or types their own:
- First text conversation
- First time they made you laugh
- First date
- First time you thought *"I'm in trouble"*
- First time you felt nervous around them
- First time you imagined a future with them

Each First has a date stamp and optional short note. Together they form an origin timeline.

### Voice Memo
Record up to 3 minutes. Captured in the moment — raw, unscripted. The recording is private and stored locally. When included in the gift, the partner hears your voice from before they were part of the story.

### Reason
One sentence: *"One reason I'm falling for you:"* Accumulates into a list. The smallest format — low friction, high emotional weight. Examples:
- "The way you always order the weirdest thing on the menu."
- "You remember everything I've told you."
- "You're genuinely kind to strangers."

---

## Gift Curation Flow

Triggered when the user taps "Invite [Name]."

1. **Select captures**: Review all captures. Toggle which Notes, Firsts, Voice Memos, and Reasons to include. Private captures stay private forever — they never see them unless included here.
2. **Preview**: See exactly what the partner will experience on their first launch. Swipeable card format. Can reorder.
3. **Add name + optional message**: *"I've been saving this for you."*
4. **Send invite**: Generates an invite link / code. Stage transitions to `invitePending`.

After invite is sent, the user can still add new captures and update the gift selection until the partner accepts.

---

## Partner's First Launch (Gift Reveal)

The partner downloads the app via invite link. Before their own onboarding:

**Cinematic reveal screen:**
- Full-screen experience, one card at a time
- Soft music (from couple's playlist if one exists)
- Each card shows a single capture: a Note, a First (with its date), a Voice Memo (playable inline), or a Reason
- Navigation: swipe to advance, tap to linger
- Final card: *"[Name] has been writing this since [first capture date]. Now you're here."*
- CTA: *"Start your story together →"*

After the reveal, the partner completes their own profile and onboarding. The full app unlocks for both users simultaneously.

**Partner's retroactive entries (optional):**
After the reveal, the partner is invited to add their own "before I knew" moments to the Prelude chapter — their side of the story from the same period. These live alongside the original captures in the permanent chapter, distinguished visually as the partner's perspective.

---

## Prelude Chapter (Permanent)

The gift becomes a permanent chapter in the shared timeline, always accessible.

- Labeled: *"Before We Were Official"* with the date range (first capture → invite accepted)
- Shows both the original creator's curated captures and any retroactive entries the partner added
- Private captures (not included in the gift) remain private forever — never surface here
- Readable from either user's account after going Official
- Becomes read-only after Archive but remains accessible to both

---

## Archive Flow *(designed now, implemented later)*

1. Either user taps Archive in relationship settings
2. Explicit confirmation: *"This will end your active relationship. Your memories are preserved forever."*
3. Garden and pet freeze in current state
4. Shared timeline and Prelude chapter become read-only
5. Both users' accounts persist independently as `soloPrelude`

---

## Reconnect Flow

1. From Archive view, either user taps "Reconnect"
2. Push notification to other user
3. Both confirm → transition back to `officialCouple`
4. Archive period becomes a labeled chapter in the timeline
5. Garden and pet resume from their frozen states

---

## Data Models

### `RelationshipStage` (added to `CoupleProfile`)
```swift
enum RelationshipStage: String, Codable {
    case prelude
    case officialCouple
    case archivedCouple
}
```

`CoupleProfile` also gains `inviteSent: Bool` — a flag set when the user sends their gift invite, cleared if the partner declines or the invite expires.

### `PreludeCapture` (polymorphic, stored in `prelude_captures.json`)
```swift
struct PreludeCapture: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let type: CaptureType
    var isIncludedInGift: Bool      // user-controlled curation flag
    var isPartnerRetroactive: Bool  // true for partner's "before I knew" entries

    // Type-specific payloads (only one non-nil at a time)
    var noteText: String?
    var notePhotoId: UUID?
    var firstLabel: String?         // "First time they made me laugh" etc.
    var voiceMemoFileId: String?    // local file path
    var reasonText: String?

    enum CaptureType: String, Codable {
        case note, first, voiceMemo, reason
    }
}
```

### `GiftPreview` (transient, not persisted)
Built from `PreludeCapture` items where `isIncludedInGift == true`, ordered by the user's curation sequence.

### `PreludeChapter` (stored in `prelude_chapter.json` after going Official)
```swift
struct PreludeChapter: Codable {
    let startDate: Date             // date of first capture
    let officialDate: Date          // date partner accepted invite
    let creatorUserId: String
    let partnerUserId: String
    var giftCaptureIds: [UUID]      // ordered list for the chapter
}
```

**Privacy guarantee:** Captures with `isIncludedInGift == false` never leave the device. They are excluded from any sync, export, or share operation.

---

## Files to Create / Modify

### New files
| File | Purpose |
|---|---|
| `BabyTown/Models/RelationshipStage.swift` | Stage enum |
| `BabyTown/Models/PreludeCapture.swift` | Polymorphic capture model |
| `BabyTown/Models/PreludeChapter.swift` | Permanent shared chapter |
| `BabyTown/ViewModels/PreludeViewModel.swift` | Capture CRUD, gift curation, stage transitions |
| `BabyTown/Views/PreludeHomeView.swift` | Solo capture feed + quick capture bar |
| `BabyTown/Views/CaptureEditorView.swift` | Create/edit any capture type |
| `BabyTown/Views/VoiceMemoRecorderView.swift` | In-app voice recording |
| `BabyTown/Views/GiftCurationView.swift` | Select + preview + send |
| `BabyTown/Views/GiftRevealView.swift` | Partner's cinematic first-launch experience |
| `BabyTown/Views/PreludeChapterView.swift` | Permanent chapter in shared timeline |
| `BabyTown/Views/ArchiveFlowView.swift` | Archive confirmation flow |
| `BabyTown/Views/ReconnectFlowView.swift` | Reconnect confirmation flow |

### Modified files
| File | Change |
|---|---|
| `BabyTown/Models/CoupleProfile.swift` | Add `relationshipStage: RelationshipStage` |
| `BabyTown/Services/DataPersistenceManager.swift` | Add persistence for `prelude_captures`, `prelude_chapter`; handle voice memo files |
| `BabyTown/Views/HomeView.swift` | Gate on `relationshipStage`; show `PreludeHomeView` for solo stages |
| `BabyTown/Views/InvitePartnerFlowView.swift` | Replace with `GiftCurationView` → send invite |

---

## Implementation Order

1. `RelationshipStage` enum + `CoupleProfile` field + persistence
2. `PreludeCapture` model + `DataPersistenceManager` persistence
3. `PreludeViewModel` (capture CRUD + stage transitions)
4. `PreludeHomeView` (capture feed + quick-add bar)
5. `CaptureEditorView` (all four types + reflection prompts)
6. `VoiceMemoRecorderView`
7. `GiftCurationView` (select + preview + send invite)
8. `GiftRevealView` (partner's cinematic first-launch)
9. `PreludeChapterView` (permanent chapter in timeline)
10. `HomeView` gating on `relationshipStage`
11. `ArchiveFlowView` + `ReconnectFlowView`

---

## Verification

1. Create all four capture types. Verify each persists correctly across app restarts.
2. Mark some captures for gift inclusion, leave others private. Verify private captures never appear in gift preview.
3. Send invite → verify stage transitions to `invitePending`. Verify captures still addable.
4. Simulate partner accepting invite → verify `GiftRevealView` plays, stage transitions to `officialCouple`, garden + pet unlock.
5. After going Official, open Prelude chapter in timeline. Verify only gift captures are visible.
6. Partner adds a retroactive entry. Verify it appears in the chapter distinguished from original captures.
7. Private captures (not in gift) — verify they remain accessible to the creator only, never visible in the chapter.
8. Archive → verify timeline + Prelude chapter read-only. Verify creator can still read their private captures.
9. Reconnect → verify archive chapter persists as a labeled section, not overwritten.
