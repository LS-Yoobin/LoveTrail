# Settings: Log Out + Account Info

**Date:** 2026-06-25
**Status:** Approved

## Overview

Add two features to `SettingsSheet`:
1. A **Log Out** button that signs the user out and returns them to the auth screen, preserving local data.
2. An **Account Info** subpage that displays the user's email, username, and birthday in read-only form.

## SettingsSheet Changes

### Account section (new, near top)

Insert a new `Section` with header `"Account"` immediately after the Subscription section. It contains one row:

- **Account Info** — a `NavigationLink` that pushes `AccountInfoView` onto the existing `NavigationStack`.

### App section (existing, extended)

Add a **Log Out** button below the existing Reset App button inside the `"App"` section:

- Style: `Button(role: .destructive)`
- Icon: `rectangle.portrait.and.arrow.right` (system)
- Label: `"Log Out"`
- Tapping it shows a `confirmationDialog`: *"Log out of Covela?"* with message *"Your data stays on this device."*
- On confirm: calls `onLogOut()` then `dismiss()`
- On cancel: no action

### New closure parameter

```swift
var onLogOut: () -> Void
```

Added alongside existing `onResetApp`, `onReplayStory`, `onVisitPet`, `onOpenCoupleProfile`.

## AccountInfoView

A private `View` pushed via `NavigationLink` inside `SettingsSheet`'s `NavigationStack`. Not a separate file — lives at the bottom of `SettingsSheet.swift`.

**Navigation title:** `"Account Info"`
**Back button:** automatic from `NavigationStack` (no custom back button needed)

### Data sources

| Row | Source | Fallback |
|---|---|---|
| Email | `DataPersistenceManager.shared.loadUserEmail()` | `AuthService.shared.currentUser?.email` |
| Username | `DataPersistenceManager.shared.loadUserNickname()` | `"Not set"` |
| Birthday | `CoupleProfile.specialDates` where `id == SpecialDate.localUserBirthdayID`, formatted `MMM d, yyyy` | `"Not set"` |

All rows are read-only display. No editing in this iteration.

### Layout

Plain `List` with a single section. Each row is a standard `HStack`: label on the left (`Text`, `.foregroundStyle(.primary)`), value on the right (`Text`, `.foregroundStyle(.secondary)`).

## Callback Wiring

### HomeView

`SettingsSheet` call site gains:
```swift
onLogOut: { onLogOut?() }
```
`HomeView` already has an optional `var onLogOut: (() -> Void)?` parameter added to match the existing `onResetApp` pattern.

### PendingHomeView

Same treatment — `onLogOut: { onLogOut?() }` added to its `SettingsSheet` call site.

### ContentView

Both `HomeView` and `PendingHomeView` call sites pass:
```swift
onLogOut: {
    AuthService.shared.signOut()
    withAnimation(.easeInOut(duration: 0.4)) {
        screen = .auth
    }
}
```

## Out of Scope

- Editing account info fields
- Account deletion
- Apple/Google sign-in (already stubbed as "Coming Soon")
