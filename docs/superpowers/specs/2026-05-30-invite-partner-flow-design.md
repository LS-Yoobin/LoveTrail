# Post-Purchase Invite Partner Flow — Design

**Date:** 2026-05-30
**Status:** Approved
**Follows:** 2026-05-30-partner-billing-storekit-design.md

## Goal

After a verified purchase, send the buyer into an Invite Partner screen where
they can **copy an invite link** or **text it** to their partner. Also reachable
from Settings ▸ Subscription.

## Decisions

- **Texting** uses the native iOS Messages compose sheet
  (`MFMessageComposeViewController`), pre-filled with the number + message; the
  user sends from their own number. Apps can't send SMS silently. If the device
  can't send text (e.g. simulator), fall back to the system share sheet.
- **Invite link** is a locally-generated placeholder: a stable 6-char code →
  `https://babytown.app/invite/<code>`. Copy/text work now; the link won't
  resolve (open app / pair accounts) until the partner-join backend exists.
- **Entry points:** auto-shown after purchase (centralized inside the paywall so
  every purchase path triggers it) + an "Invite your partner" button in
  Settings ▸ Subscription.

## Components

1. **`PartnerInvite`** (Services/) — value type holding `code`; computes `link`
   and `messageText`. `static current()` loads-or-creates the code via
   `DataPersistenceManager`. `static generateCode()` → 6 chars from an
   unambiguous alphabet (no 0/O/1/I).

2. **`DataPersistenceManager`** — `partnerInviteCodeKey` +
   `loadOrCreatePartnerInviteCode()`; cleared in `clearAllData()`.

3. **`MessageComposeView`** (Components/) — `UIViewControllerRepresentable` over
   `MFMessageComposeViewController` (recipients, body, finish callback). Exposes
   `canSend`.

4. **`ActivitySharePresenter.present(text:)`** — text variant of the existing
   image share presenter, for the SMS-unavailable fallback.

5. **`InvitePartnerFlowView`** (Views/) — 💞 hero, the link in a read-only pill
   with a **Copy link** button (shows "Copied!"), a gray phone-number field with
   **Send via text**, and **I'll do this later**. Inputs: `onDone`.

6. **Wiring:**
   - `InvitePartnerPaywallView.buy()` — on a verified purchase, present
     `InvitePartnerFlowView` (dismissing the All-Plans sheet first if open);
     calling `onDone` then triggers the existing `onUnlock` (dismiss paywall).
   - `SubscriptionDetailView` — add an "Invite your partner" button (unlocked
     users) that presents `InvitePartnerFlowView`.

## Data flow

```
Purchase verified → showInviteFlow
Copy link  → UIPasteboard = invite.link → "Copied!"
Send text  → canSend ? Messages sheet(number, message) : share sheet(message)
Done / later → onDone → onUnlock → dismiss paywall
```

## Reset / Testing

`clearAllData()` removes the invite code so Reset App yields a fresh code on the
next invite.

## Out of scope (future sync project)

Link resolution / universal-link routing, partner account pairing, validating
that the partner actually joined.
