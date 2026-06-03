# BabyTown Push Notifications — Design Spec

**Date:** 2026-06-03
**Status:** Approved (design), pending implementation plan
**Branch context:** `secretgarden`

## Goal

Expand BabyTown's local notifications from the two existing daily ones (8 AM
"Good morning", 9 PM "Daily polaroids") into a richer set that re-engages users
around their pet, their saved moments, and their important dates — while laying
dormant, clearly-marked hooks for the partner-driven notifications that need a
backend BabyTown does not yet have.

## Constraints & current reality

- **The app is 100% local.** No backend, no APNs registration
  (`registerForRemoteNotifications` is absent), no remote push. `PartnerInvite.swift`
  states the partner-join backend is a placeholder.
- All notifications in scope this round are **local** (`UNUserNotificationCenter`,
  `UNCalendarNotificationTrigger` / `UNTimeIntervalNotificationTrigger`).
- iOS local notifications **fire on a fixed schedule and cannot inspect app state
  at fire time.** Any state-conditional notification must be (re)scheduled while the
  app runs.
- No new entitlements. We do **not** use `BGTaskScheduler`.

## Architecture: reschedule-on-lifecycle (chosen approach A)

A single entry point on `NotificationManager`:

```swift
func refresh(_ snapshot: NotificationSnapshot)
```

`NotificationSnapshot` is a lightweight value type the caller assembles from
existing state — it keeps `NotificationManager` decoupled from view models:

```swift
struct NotificationSnapshot {
    var userNickname: String?          // DataPersistenceManager.loadUserNickname()
    var isPetAdopted: Bool             // PetViewModel.isAdopted
    var petName: String?               // PetViewModel.displayName(for: adoptedSkin)
    var lastPetInteractionAt: Date?    // NEW timestamp (see below)
    var litterIsDirty: Bool            // PetViewModel.isLitterBoxDirty
    var litterIsSelfCleaning: Bool     // existing auto-box check
    var hungerLevel: Double            // current hunger 0–100
    var thirstLevel: Double            // current thirst 0–100
    var hungerDecayPerHour: Double     // PetEconomy.hungerDecayPerHour
    var thirstDecayPerHour: Double     // PetEconomy.thirstDecayPerHour
    var momentCount: Int               // HomeViewModel.moments.count
    var specialDates: [SpecialDate]    // CoupleProfile.specialDates
}
```

`refresh` removes the pending requests it owns (by stable identifier prefix) and
re-creates them from the snapshot. The two existing daily notifications stay on
their own identifiers and are untouched by `refresh`.

### When `refresh` is called

- App launch (after state loads).
- App enters background — add a `scenePhase` observer in `BabyTownApp` /
  `ContentView` (none exists today) that calls `refresh` on `.background`.
- After relevant in-app actions, so the schedule stays current without waiting
  for a background event: clean litter, any pet interaction, feed/water,
  moment(s) saved, special date added/edited/removed.

### Notification identifier scheme

| Identifier | Type |
|---|---|
| `daily_morning_notification` | existing, untouched |
| `daily_evening_polaroids` | existing, untouched |
| `pet_misses_you` | rolling, refresh-managed |
| `litter_box_noon` | conditional daily, refresh-managed |
| `pet_needs` | conditional, refresh-managed |
| `special_date_<uuid>` | annual, refresh-managed (one per date) |
| `milestone_<n>` | event-fired, fire-once |
| `partner_*` (stubs) | event-fired via debug only |

## Notifications — build now

### 1. "Pet misses you"

- **Copy:** title `"{petName} misses you"`, body
  `"Hi {userNickname}, {petName} misses you 🐾"` (fallbacks: `"Someone misses you"`
  / drop the name if nickname is empty).
- **Trigger:** rolling. On every `refresh`, schedule a single
  `UNTimeIntervalNotificationTrigger` for **7 days after `lastPetInteractionAt`**
  (or 7 days from now if that point is already past and the pet is idle). Each new
  pet interaction pushes `lastPetInteractionAt` forward, so `refresh` keeps moving
  the fire date out — the user only gets it after a true 7-day gap.
- **Guard:** only scheduled when `isPetAdopted == true`. If no pet is adopted, the
  request is removed and never scheduled.
- **New state:** add `lastPetInteractionAt: Date?` to the pet state
  (`Pet.swift` codable struct, alongside `lastPetAt`/`lastPlayAt`). Updated when the
  pet room appears **and** on any care action (pet, feed, water, play, clean litter).
  This is the single "touched the pet/pet-room" signal the 7-day timer needs.

### 2. Litter-box reminder (12 PM)

- **Copy:** title `"Litter box needs you"`, body
  `"{petName}'s litter box could use a cleanup 🧹"`.
- **Trigger:** `UNCalendarNotificationTrigger` at **12:00 PM**. Scheduled by
  `refresh` **only when** `litterIsDirty == true` and `litterIsSelfCleaning == false`.
  Cleaning the litter calls `refresh`, which removes it. (Litter first dirties at the
  6 AM use event — see #3 — so by noon an uncleaned box is dirty.)
- Not repeating blindly: `refresh` re-evaluates each lifecycle/action, so it only
  exists while the box is actually dirty.

### 3. Litter schedule change → 6 AM / 6 PM

- One-line change in `PetViewModel.litterUseEventsSinceLastClean`:
  `let useHours = [8, 20]` → `let useHours = [6, 18]`.
- This shifts when the box becomes dirty; the noon reminder (#2) and existing
  litter mechanics follow automatically.

### 4. Milestone congrats

- **Thresholds:** 10, 50, 100, 250, 500, 1000 moments saved together.
- **Copy:** title `"Milestone unlocked! 🎉"`, body
  `"You've saved {n} moments together. Here's to many more 💞"`.
- **Trigger:** event-fired. When a moment-save raises `momentCount` across a
  threshold not yet celebrated, fire an immediate local notification
  (`UNTimeIntervalNotificationTrigger` ~1s) with identifier `milestone_<n>`.
- **Fire-once:** persist celebrated thresholds in `DataPersistenceManager`
  (e.g. `celebratedMomentMilestones: Set<Int>`). Never re-fire. Crossing multiple at
  once (bulk import) fires only the highest crossed threshold.
- Check runs wherever `momentCount` increases (the `moments` didSet path in
  `HomeViewModel`, line ~112) and is also reconciled in `refresh` as a safety net.

### 5. Pet needs (hungry / thirsty)

- **Copy:** hunger → `"{petName} is getting hungry 🍽️"`; thirst →
  `"{petName} is thirsty 💧"`. One combined notification if both are low.
- **Trigger:** computed one-shot. From current level + decay rate, compute when
  hunger crosses `feedThirstGate` (50) and thirst crosses `feedThirstGate` (50);
  schedule the earliest as a `UNTimeIntervalNotificationTrigger`. Feeding/watering
  calls `refresh`, recomputing.
- **Guard:** only when `isPetAdopted`. Suppress if it would fire inside quiet hours
  (before 9 AM / after 9 PM) by clamping the fire time into the next allowed window.

### 6. Anniversary / important-date reminders

- **Copy:** title `"{specialDate.title} 💞"`, body
  `"Today's the day — {specialDate.title}."` Fired the **morning of** (9 AM).
- **Trigger:** one annual `UNCalendarNotificationTrigger` per `SpecialDate`
  (month + day, hour 9), identifier `special_date_<uuid>`. `refresh` reconciles the
  set when dates are added/edited/removed.
- `SpecialDate` has `title` and `date`; no schema change needed.

## Notifications — dormant stubs (backend later)

These cannot fire as real cross-device pushes without a server. We build the
**content + a single dispatch function** so the future APNs path has one clear hook,
and so they're testable locally today.

```swift
enum PartnerEvent {
    case joined(partnerName: String?)
    case loveLetterReceived(title: String, sentAt: Date)
    case partnerAddedMoment
    case partnerAddedSpecialDate
}

func handlePartnerEvent(_ event: PartnerEvent)   // fires a local notification now
```

- **Partner joined:** `"{partnerName} just joined your BabyTown 💞"`.
- **Love letter received:** title = the letter's title; body =
  `"Sent {formatted sentAt}"` (e.g. `"Sent today at 3:42 PM"`).
- **Partner added a moment:** `"A new moment was saved — check it out!"`.
- **Partner added a special date:** `"A new important date was added — take a look!"`.

**Dormant means:** not wired to any real trigger (no backend exists to call them).
A debug-only action (e.g. in `SettingsSheet` under a debug section) invokes
`handlePartnerEvent(...)` so each can be verified locally. Code comments mark this as
the exact insertion point for the future server/APNs delivery path. The symmetry
("works the other way around") is inherent — the same function serves whichever
device receives the event once a backend drives it.

## Permissions & delegate

- Authorization is already requested (`requestAuthorization`, options
  `.alert/.badge/.sound`). On grant, call `refresh` with a fresh snapshot in addition
  to the existing daily scheduling.
- To show milestone/needs notifications while the app is foregrounded, implement
  `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:)` returning
  `[.banner, .sound]` (set the delegate in `AppDelegate`). Verify this doesn't make
  the existing daily notifications intrusive; if needed, gate foreground presentation
  to the event-fired categories only.

## Quiet hours

All scheduled notifications respect a 9 AM–9 PM window. Fixed-time ones (morning
8 AM is pre-existing; noon, 9 AM dates) are inside or intentionally at boundaries.
Computed ones (pet needs, pet-misses-you) clamp their fire time into the next
9 AM–9 PM window rather than buzzing overnight.

## Testing strategy

- **Unit-testable pure logic** (no `UNUserNotificationCenter` dependency): extract
  scheduling *decisions* into pure functions — given a `NotificationSnapshot` + `now`,
  return the set of `PlannedNotification` (id, content, fireDate). Test:
  - pet-misses-you fire date = lastInteraction + 7d; absent when not adopted.
  - litter noon present only when dirty & not self-cleaning.
  - pet-needs fire date matches decay crossing `feedThirstGate`; clamped out of quiet
    hours.
  - milestone crossing logic: each threshold once; bulk crossing fires highest only.
  - special-date triggers: one per date, correct month/day/hour.
- **Manual / simulator:** follow the repo's "verify UI in simulator" memory — route
  the entry point or use the debug actions to fire each notification; confirm copy and
  timing. Trust `xcodebuild` over SourceKit diagnostics.

## Out of scope

- Any real backend, APNs registration, or cross-device delivery.
- Notification preference toggles / per-category opt-out UI (could be a follow-up).
- The general "haven't opened the app in N days" come-back nudge (declined).
- Rewording the existing 8 AM / 9 PM notifications (left as-is).

## Files touched (anticipated)

- `Services/NotificationManager.swift` — `refresh`, snapshot, planners, stubs, delegate wiring.
- `Models/Pet.swift` — add `lastPetInteractionAt`.
- `ViewModels/PetViewModel.swift` — update `lastPetInteractionAt`; litter `useHours`→`[6,18]`; call `refresh` on care actions.
- `ViewModels/HomeViewModel.swift` — milestone check on moment count increase; call `refresh`.
- `Services/DataPersistenceManager.swift` — celebrated-milestones persistence.
- `BabyTownApp.swift` / `ContentView.swift` — `scenePhase` → `refresh` on background.
- `AppDelegate.swift` — `UNUserNotificationCenterDelegate` for foreground presentation.
- `Components/SettingsSheet.swift` — debug actions to fire partner-event stubs.
- New test target/file for the pure planner functions.
