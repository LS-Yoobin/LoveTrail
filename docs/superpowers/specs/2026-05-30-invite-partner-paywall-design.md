# Invite Partner Paywall — Design

**Date:** 2026-05-30
**Status:** Approved (design phase), purchase mechanics deferred

## Goal

Add an "Invite Partner to Town" entry point and a paywall screen that sells a
paid couples tier. This session builds the **UI flow and a stubbed unlock**;
real StoreKit billing and the actual partner-sync backend are separate future
projects.

## Scope (this session)

- A promo **banner card** in the Home timeline ("Invite your partner to Town").
- A **paywall screen** (Direction A — benefit-forward) presented when the banner
  is tapped.
- A **stubbed purchase**: tapping a plan flips a locally-persisted
  `isPartnerUnlocked` flag and dismisses the paywall; the banner then hides.

Out of scope: real StoreKit/App Store products, receipts, accounts/auth, cloud
backup, real-time sync, shared letters/places backend.

## Pricing (display only)

One purchase covers **both** partners.

| Plan | Price | Note |
|------|-------|------|
| Yearly (hero) | **$29.99/yr** | $2.50/mo · ~58% off · 7-day free trial |
| Monthly | **$5.99/mo** | |
| Lifetime | **$79** | one payment |

## Benefits shown

1. ☁️ Private cloud backup — every memory safe forever
2. 🔒 Just the two of you — a private vault no one else can see
3. 📸 Add moments together — both upload to the same timeline in real time
4. 💌 Unlimited history — letters you write each other never expire
5. 📍 Places you've been — your shared map of memories grows

## Components

1. **`DataPersistenceManager`** — add `isPartnerUnlockedKey`,
   `setPartnerUnlocked(_:)`, `isPartnerUnlocked()` following the existing
   `hasCompletedOnboarding` pattern.

2. **`InvitePartnerBanner`** (Components/) — a tappable gradient card for the
   feed. Inputs: `onTap: () -> Void`. Pink/red Baby Town styling, 💞 icon,
   title + one-line subtitle + chevron.

3. **`InvitePartnerPaywallView`** (Views/) — the full paywall screen matching
   approved Direction A v3. Inputs: `onUnlock: () -> Void`, `onDismiss: () ->
   Void`. Internal `selectedPlan` state (defaults to yearly). The CTA calls
   `onUnlock`; the ✕ calls `onDismiss`.

4. **`HomeView`** — owns `showPartnerPaywall` and `isPartnerUnlocked` state.
   Renders `InvitePartnerBanner` at the top of the non-search feed branch only
   when `!isPartnerUnlocked`. Presents the paywall via `.fullScreenCover`.
   `onUnlock` persists the flag, sets `isPartnerUnlocked = true`, and dismisses.

## Data flow

```
Banner tap → showPartnerPaywall = true
Paywall plan/CTA tap → onUnlock → DataPersistenceManager.setPartnerUnlocked(true)
                                 → isPartnerUnlocked = true → dismiss → banner hides
Paywall ✕ → onDismiss → dismiss (banner stays)
```

## Out-of-scope follow-ups (future specs)

- Real StoreKit 2 products + entitlement validation.
- Partner accounts / auth and invite link.
- Cloud backup + real-time shared timeline, letters, places sync.
- Free-tier "letters expire after 1 week" timer (the thing "Unlimited history"
  removes).
