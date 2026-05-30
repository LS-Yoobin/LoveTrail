# Partner Billing (StoreKit 2) — Design

**Date:** 2026-05-30
**Status:** Approved
**Follows:** 2026-05-30-invite-partner-paywall-design.md (replaces the stubbed unlock)

## Goal

Make the Invite Partner paywall actually charge users via **raw StoreKit 2**,
and add a Subscription section in Settings.

## Products (bundle `LS.BabyTown`)

| Plan | Product ID | Type | Price | Offer |
|------|-----------|------|-------|-------|
| Yearly | `LS.BabyTown.partner.yearly` | Auto-renewable | $29.99/yr | 7-day free trial |
| Monthly | `LS.BabyTown.partner.monthly` | Auto-renewable | $5.99/mo | — |
| Lifetime | `LS.BabyTown.partner.lifetime` | Non-consumable | $79 | — |

Yearly + Monthly share subscription group "Partner Access". Lifetime standalone.

## Components

1. **`StoreManager`** (Services/, `@MainActor` `ObservableObject` singleton
   `StoreManager.shared`). Publishes `products`, `isPartnerUnlocked`,
   `activePlan`, `isPurchasing`, `purchaseError`.
   - `start()` — load products + begin `Transaction.updates` listener +
     `refreshEntitlements()`. Called once at app launch.
   - `purchase(_ plan:)` — `product.purchase()`, verify signed transaction,
     `finish()`, refresh entitlements. Ignores user-cancel; sets `purchaseError`
     on real failures.
   - `restore()` — `AppStore.sync()` then refresh.
   - `refreshEntitlements()` — derive unlock + active plan from
     `Transaction.currentEntitlements`; mirror to
     `DataPersistenceManager.setPartnerUnlocked(...)`.
   - `resetForTesting()` — clear unlock state so the banner/paywall return after
     Reset App (see Testing).
   - Entitlement truth = StoreKit; the persisted flag is only a fast/offline
     mirror seeded at init.

2. **`PartnerPlan`** enum — the three product IDs + display metadata.

3. **`Products.storekit`** — local StoreKit test config (3 products + trial) so
   the purchase sheet is testable in the simulator. Enabled via the Run scheme.

4. **`PartnerPerksList`** (Components/) — the 5-benefit list extracted from the
   paywall so the paywall and Subscription screen share one source of truth.

5. **`InvitePartnerPaywallView`** — takes the `StoreManager`. Plan buttons call
   `store.purchase(...)`; prices come from `Product.displayPrice` (fallback to
   hardcoded). Lifetime re-added as a 3rd modal row. Spinner while purchasing,
   alert on error, working Restore. Verified purchase → `onUnlock()`.

6. **`SubscriptionDetailView`** (Views/) — perks list, current status (active
   plan or "Not subscribed"), **Manage Subscription** (auto-renewing plans only,
   via `.manageSubscriptionsSheet`), **Restore Purchases**, and an "Invite your
   partner" button (opens paywall) when not subscribed.

7. **`SettingsSheet`** — new "Subscription" section → `NavigationLink` to
   `SubscriptionDetailView`, with a trailing status label.

8. **`HomeView`** — banner visibility observes `StoreManager.shared`.

9. **App launch** (`ContentView`) — `StoreManager.shared.start()`.

## Cancellation

No in-app "Cancel" button (Apple disallows app-driven cancellation). "Manage
Subscription" opens Apple's system sheet, where the user cancels. Lifetime has
nothing to cancel.

## Reset / Testing

- **Reset App** calls `StoreManager.shared.resetForTesting()` + clears the
  persisted flag, so the Invite-Partner banner + paywall reappear immediately
  for continued testing within the session.
- To fully re-test a *purchase* across launches, clear the test transaction in
  Xcode: **Debug ▸ StoreKit ▸ Manage Transactions**.

## Manual steps (outside code)

- Enable the StoreKit config once: **Edit Scheme ▸ Run ▸ Options ▸ StoreKit
  Configuration ▸ Products.storekit**.
- App Store Connect: create the 3 products with the exact IDs above, set prices
  + the 7-day trial, sign Paid Apps agreement. Real charges only occur in
  sandbox / TestFlight / App Store builds.

## Error handling

Verification failure / network error → alert. User-cancel → silent. Entitlement
always re-derived from StoreKit, never trusted from the local flag alone.
