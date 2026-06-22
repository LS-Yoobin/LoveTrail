# Personal Place Vault — Design Spec

**Date:** 2026-06-22  
**Branch:** watch  
**Status:** Approved

---

## Overview

When a user steps out of a breakup archive and later invites a new partner, location metadata from their past relationship moments is automatically extracted into a personal, private vault. Photos and all couple-tied context are discarded. Only coordinates, place names, countries, and dates are kept. The new partner never sees this data. It lives in a dedicated "My Travels" screen accessible from the user's profile.

---

## Goals

- Extract location metadata silently on step-out before the archive is cleared
- Confirm the save with a brief transitional moment (not a decision screen)
- Reassure the user before they send a new partner invite that their past travel data is private
- Provide a personal "My Travels" screen that is entirely outside the couple-facing UI

---

## Non-Goals

- No manual selection of which places to keep
- No map rendering in My Travels (MVP is list only)
- No sharing of vault data with any partner
- No syncing vault to the server (local only)

---

## Data Model

### `VaultedPlace`

New file: `BabyTown/Models/VaultedPlace.swift`

```swift
struct VaultedPlace: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let placeName: String?
    let country: String?
    let dateTaken: Date
}
```

No reference to any `coupleId`, partner `userId`, `assetIdentifier`, caption, or voice note. Pure location metadata.

### Deduplication rule

At extraction time, moments are filtered to those with both `latitude`/`longitude` and a non-nil, non-empty `placeName`. They are then grouped by `placeName`. One `VaultedPlace` is created per unique place name, keeping the earliest `dateTaken`. Moments without a `placeName` are skipped — an unlabeled coordinate has no value in My Travels.

---

## DataPersistenceManager

Three new methods added to `DataPersistenceManager`, following the existing JSON-to-disk pattern:

```swift
func saveVaultedPlaces(_ places: [VaultedPlace])
func loadVaultedPlaces() -> [VaultedPlace]
func clearVaultedPlaces()
```

File key: `vaulted_places.json` in the app's Documents directory.

---

## ArchiveService — stepOut() changes

Before any existing clear logic runs, `stepOut()` performs a silent extraction:

1. Load archive bundle — if nil, skip extraction entirely
2. Filter `bundle.moments` to those with non-nil `latitude`, `longitude`, and non-empty `placeName`
3. Deduplicate by `placeName` — one `VaultedPlace` per unique name, earliest `dateTaken`
4. `dpm.saveVaultedPlaces(vaultedPlaces)`

The existing logic then runs unchanged:
- Clear profile fields (`relationshipStage`, `breakupDate`, etc.)
- `dpm.deleteArchiveBundle()`
- `dpm.clearReconnectInvite()`
- `cancelRetentionNotifications()`

The extraction is synchronous (no async needed — it mirrors the existing sync pattern of `stepOut()`). If the archive has zero qualifying moments, the vault is saved as an empty array and the confirmation step handles the zero-count case gracefully.

---

## StepOutConfirmationView — changes

Currently `performStepOut()` calls `stepOut()` then immediately calls `onConfirmed()`.

New behavior:

1. `performStepOut()` calls `ArchiveService.shared.stepOut()`
2. Reads count: `let count = DataPersistenceManager.shared.loadVaultedPlaces().count`
3. View transitions to a new `.travelsSaved(count: Int)` state

The `.travelsSaved` state shows:
- `mappin.circle.fill` system icon (large, secondary tint)
- If count > 0: `"[X] travel spots saved to My Travels"`
- If count == 0: auto-skips after 0.5s without showing the state
- A single "Continue" button that calls `onConfirmed()`
- Auto-dismisses after 2.5 seconds if the user does not tap

The existing alert and "Leave my memories behind" / "Keep browsing" buttons are unchanged.

---

## TravelsPrivateGateView

New file: `BabyTown/Views/MyTravels/TravelsPrivateGateView.swift`

A full-screen sheet shown once per invite session when the user opens `InvitePartnerFlowView` and has a non-empty vault.

Content:
- Lock or footprints icon (`figure.walk` or `lock.fill`)
- "[X] places saved in My Travels"
- "These are yours. Your new partner won't see them."
- A single "Got it" button that dismisses the sheet

---

## InvitePartnerFlowView — gate injection

On `.onAppear`, the view checks:

```swift
let vault = DataPersistenceManager.shared.loadVaultedPlaces()
if !vault.isEmpty && !hasShownTravelsGate {
    showTravelsGate = true
}
```

- `@State private var showTravelsGate = false`
- `@State private var hasShownTravelsGate = false`

`TravelsPrivateGateView` is presented as `.fullScreenCover(isPresented: $showTravelsGate)`. On dismiss, `hasShownTravelsGate = true`. The gate only fires once per instance of `InvitePartnerFlowView`.

---

## MyTravelsView

New file: `BabyTown/Views/MyTravels/MyTravelsView.swift`

A simple list of `VaultedPlace` entries sorted by `dateTaken` descending, grouped by year. Each row shows:
- Place name (primary)
- Country (secondary, if available)
- Date (tertiary)

Empty state: "Places from your past chapters will appear here."

No map rendering in this view for MVP. Coordinates are stored and ready for a future map layer.

---

## Navigation — Entry Point

A "My Travels" row is added to the user's existing profile or settings sheet. It presents `MyTravelsView` as a sheet or pushed view. It is not surfaced anywhere in the couple-facing screens (garden, map, timeline, prelude).

---

## File Summary

| File | Change |
|---|---|
| `BabyTown/Models/VaultedPlace.swift` | New |
| `BabyTown/Services/DataPersistenceManager.swift` | Add 3 vault methods |
| `BabyTown/Services/ArchiveService.swift` | Extend `stepOut()` with pre-clear extraction |
| `BabyTown/Views/Breakup/StepOutConfirmationView.swift` | Add `.travelsSaved` state |
| `BabyTown/Views/MyTravels/TravelsPrivateGateView.swift` | New |
| `BabyTown/Views/InvitePartnerFlowView.swift` | Gate on appear |
| `BabyTown/Views/MyTravels/MyTravelsView.swift` | New |
| Profile/settings nav | Add My Travels entry point |

---

## Acceptance Criteria

- [ ] `VaultedPlace` stores only lat, lon, placeName, country, dateTaken — no couple or partner identifiers
- [ ] `stepOut()` extracts and saves vault before clearing archive; if archive is nil, extraction is skipped silently
- [ ] Deduplication: one `VaultedPlace` per unique `placeName`, earliest date wins
- [ ] Moments without `placeName` are not vaulted
- [ ] `StepOutConfirmationView` shows travel count confirmation after step-out fires; zero count auto-skips
- [ ] `InvitePartnerFlowView` shows gate once per session when vault is non-empty
- [ ] Gate copy contains no reference to "ex", "breakup", or relationship
- [ ] `MyTravelsView` is inaccessible from any couple-facing screen
- [ ] Vault data persists across app restarts
- [ ] `clearVaultedPlaces()` is available for full account reset (wire into `clearAllData()`)
