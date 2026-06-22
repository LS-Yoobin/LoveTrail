# Covela Forever Paywall — Design

**Date:** 2026-06-22
**Status:** Approved

## Goal

Replace the existing partner-invite paywall with a new subscription product, **Covela Forever**, built around content access rather than feature unlocking. Partner connection becomes free. Premium is now about preserving your full shared history — moments, letters, dates, and pinned memories — with no limits.

## Competitive Context

- **Cozy Couples** hides content older than 2 weeks. User sentiment is mixed — the cutoff feels arbitrary and punishing.
- **Sumone** uses a messy hybrid of ads, in-app currency, and premium. Conversion suffers from confusion.
- **Paired** ($800K/month) gates structured content while leaving creation free. Strong because habit formation happens before the paywall.
- **Our positioning:** More generous than Cozy Couples (50-moment sliding window vs. 2-week hard cut). Cleaner than Sumone. Focused on emotional loss aversion — "your memories are safely stored away" — rather than feature denial.

## Subscription Product

**Name:** Covela Forever
**Tagline:** Keep every memory, forever
**Audience:** Female-primary; "forever" and "memory" language tested strongest for this demographic in the couples app category.

**Plans (unchanged from prior pricing):**

| Plan | Price | Note |
|---|---|---|
| Yearly (hero) | $29.99/yr | $2.50/mo · ~58% off · 7-day free trial |
| Monthly | $5.99/mo | |
| Lifetime | $79 | One payment |

One purchase covers both partners.

## Free Tier Rules

| Content | Free Limit | Logic |
|---|---|---|
| Moments / Home feed | 50 most recent visible | Sliding window — vault activates above 50 |
| Letters | Last 30 days visible | Time-based — older letters vaulted |
| Important dates | Up to 10 | Hard cap — 11th attempt triggers upgrade prompt |
| Pinned moments | Up to 10 | Hard cap — 11th attempt triggers upgrade prompt |
| Scrapbook | Always fully visible | No restriction |
| Secret Garden | Always accessible | Upgrade CTA lives here |

**Why sliding window for moments, time-based for letters:**
Moments can be imported from any point in the past (scan feature, photo library). A time-based rule would immediately vault historical imports for established couples. The sliding window is fair regardless of relationship stage — under 50 moments means no restrictions at all. Letters are chronological communications by nature, so 30-day time gating aligns with how users think about them.

**Premium (Covela Forever) unlocks:**
- Full moment timeline — all moments, no limit
- Full letter history — all letters beyond 30 days
- Unlimited important dates
- Unlimited pinned moments

## Paywall Page

Single screen, shown identically from all three entry points.

**Structure (top to bottom):**

1. Close button (top left)
2. Looping flowers video (reuse `transparent_flowers` asset)
3. Headline: "Keep every memory, forever"
4. Subheadline: "Your full story, always within reach"
5. Benefits list (5 items):
   - Every moment, always — your full timeline with no limits
   - Letters that last — read and write beyond 30 days
   - Unlimited important dates — every milestone, saved forever
   - Unlimited pinned moments — keep what matters most
   - One purchase for both of you — covers you and your partner
6. Yearly hero card — "$29.99/yr · 7-day free trial" with BEST DEAL badge
7. Primary CTA — "Start 7-day free trial"
8. "See all plans" → bottom sheet with Yearly / Monthly / Lifetime plan cards
9. Fine print — "Then $29.99/year · Cancel anytime · Restore purchase"

**What changes from `InvitePartnerPaywallView`:**
- Hero copy and benefits list (partner-focused → memory/history-focused)
- Plan card copy ("for 2 users" language stays, pricing is identical)
- Everything else (layout, plan card structure, CTA style, flower video, StoreKit wiring) is preserved

## Entry Points

### 1. Vaulted Content Tap

Vaulted items remain visible in the feed as locked cards — they do not disappear. This is intentional: users should know their history exists and is safely stored, not feel like it was deleted.

**Surfaces where vaulted content appears:**
- Home feed (scrolling past the 50-moment threshold)
- Year filter results (vaulted moments in a filtered year show locked treatment)
- Map view (POI markers for vaulted moments appear blurred on the map)

**Visual treatment:** Frosted/blurred card or marker with a lock icon.

**Tap interaction (same across all surfaces):**
Tapping a vaulted item opens `VaultedMomentPrompt` — a bottom sheet, not the full paywall directly.

Prompt copy:
> "This moment has been safely stored away."

Two actions:
- **"Unlock Forever"** (accent button) → dismisses prompt, presents `CovelaForeverPaywallView`
- **"Maybe later"** (ghost/text button) → dismisses prompt, returns to feed

### 2. Settings

A "Covela Forever" row in `SettingsSheet` styled with the accent gradient. Shows current status ("Free" or active plan name). Tapping opens `CovelaForeverPaywallView` directly (no intermediate prompt).

### 3. Secret Garden

The "Invite" button is replaced with an "Upgrade to Forever" button using the same visual weight and accent styling. Tapping opens `CovelaForeverPaywallView` directly. No content inside the garden is locked.

### 4. Hard Cap Triggers (Important Dates + Pinned Moments)

When a free user tries to add an 11th important date or 11th pinned moment, a bottom sheet appears explaining the limit with a single "Unlock Forever" CTA that opens `CovelaForeverPaywallView`. Keeps the interruption proportional to the action.

## Component Changes

### Retired

- `InvitePartnerPaywallView` — deleted
- `InvitePartnerBanner` — removed from home feed (partner invite is now free)
- `PartnerPerksList` — deleted

### New

- `CovelaForeverPaywallView` — full paywall screen
- `VaultedMomentPrompt` — bottom sheet prompt for tapped vaulted content
- `VaultedLetterRow` — frosted locked treatment for letters older than 30 days

### Updated

| Component | Change |
|---|---|
| `StoreManager` | `isPartnerUnlocked` → `isForeverUnlocked` |
| `HomeViewModel` | Vaulting logic — sort moments by date added, mark index 51+ as vaulted |
| `DayClusterCard` | Locked/frosted variant when moment is vaulted |
| Map view POI markers | Blurred variant for vaulted moments |
| `SettingsSheet` | Replace partner row with "Covela Forever" upgrade row |
| Secret Garden | Replace Invite button with "Upgrade to Forever" button |
| Important dates | Hard cap at 10, bottom sheet on 11th attempt |
| Pinned moments | Hard cap at 10, bottom sheet on 11th attempt |

## Data Flow

```
StoreManager.isForeverUnlocked = false (default)

Home feed loads moments
→ HomeViewModel sorts by date added
→ Index 0–49: visible
→ Index 50+: .vaulted state
→ DayClusterCard renders locked variant for vaulted moments
→ User taps vaulted card → VaultedMomentPrompt
→ "Unlock Forever" → CovelaForeverPaywallView
→ Purchase verified → StoreManager.isForeverUnlocked = true
→ All gates lifted across the app

Letters feed loads letters
→ Filter: createdAt >= Date.now - 30 days → visible
→ createdAt < Date.now - 30 days → VaultedLetterRow

Important dates count >= 10
→ "Add" action shows hard-cap bottom sheet → CovelaForeverPaywallView

Pinned moments count >= 10
→ "Pin" action shows hard-cap bottom sheet → CovelaForeverPaywallView

Settings row tap → CovelaForeverPaywallView
Secret Garden upgrade button tap → CovelaForeverPaywallView
```

## Out of Scope

- Partner invite flow changes (separate spec — partner connection becomes free but the invite UX itself is not redesigned here)
- StoreKit receipt validation changes (existing StoreKit 2 plumbing in `StoreManager` is reused as-is)
- Breakup / archive mode paywall behaviour
- Prelude-specific paywall surfaces
