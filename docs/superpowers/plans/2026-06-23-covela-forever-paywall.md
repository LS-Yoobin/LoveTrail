# Covela Forever Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the partner-invite paywall with Covela Forever — a content-access subscription that gates moments (sliding 50-item window), letters (30-day), important dates (10 cap), and pinned moments (10 cap).

**Architecture:** Rename the entitlement property throughout, retire three old components, build a new paywall screen and two gating components, wire vault logic into the home feed and map, gate the letters list by date, and add hard-cap checks at add-time for dates and pins.

**Tech Stack:** Swift, SwiftUI, StoreKit 2 (existing `StoreManager`), `DataPersistenceManager` (UserDefaults + JSON on-disk), `BabyTown.xcodeproj`.

## Global Constraints

- UserDefaults key `"isPartnerUnlocked"` must NOT be renamed — changing it logs out existing paying users.
- Free tier limits: 50 most recently added moments visible; letters older than 30 days vaulted; max 10 important dates; max 10 pinned moments.
- `StoreManager.shared.isForeverUnlocked == true` lifts all restrictions everywhere — no partial gates.
- No new Swift packages or third-party dependencies.
- Reuse `BabyTownTheme`, `LoopingVideoPlayer`, and the `AllPlansSheet`-style bottom sheet pattern from the old paywall.
- Subscription copy: tier name = "Covela Forever", tagline = "Keep every memory, forever".
- Pricing unchanged: Yearly $29.99 (7-day free trial), Monthly $5.99, Lifetime $79. One purchase covers both partners.
- StoreKit product IDs (raw values of `ForeverPlan`) must not change.

---

## File Map

**New files:**
- `BabyTown/Views/CovelaForeverPaywallView.swift` — full paywall screen (replaces `InvitePartnerPaywallView`)
- `BabyTown/Components/VaultedMomentPrompt.swift` — bottom sheet shown when a vaulted moment/marker is tapped
- `BabyTown/Components/VaultedLetterRow.swift` — frosted locked row for letters older than 30 days

**Modified files:**
- `BabyTown/Models/Moment.swift` — add `dateAddedToApp: Date?`
- `BabyTown/Services/DataPersistenceManager.swift` — rename unlock methods to `isForeverUnlocked()` / `setForeverUnlocked(_:)`
- `BabyTown/Services/StoreManager.swift` — rename `PartnerPlan` → `ForeverPlan`, `isPartnerUnlocked` → `isForeverUnlocked`
- `BabyTown/ViewModels/HomeViewModel.swift` — add `vaultedMomentIDs(isForeverUnlocked:) -> Set<UUID>`
- `BabyTown/Components/DayClusterCard.swift` — accept `isVaulted: Bool`, render frosted overlay
- `BabyTown/Components/MemoryMapAnnotation.swift` — add `isVaulted: Bool`
- `BabyTown/Views/MapView.swift` — blur vaulted map markers, show `VaultedMomentPrompt` on tap
- `BabyTown/Views/NotificationCenterView.swift` — 30-day letter gate, remove old unlock state
- `BabyTown/Views/HomeView.swift` — remove `InvitePartnerBanner`, add vaulted prompt + paywall
- `BabyTown/Components/SettingsSheet.swift` — "Covela Forever" upgrade row
- `BabyTown/Views/CoupleProfile/CoupleProfileView.swift` — free invite, "Upgrade to Forever" button, date/pin hard caps
- `BabyTown/Views/SubscriptionDetailView.swift` — update `isPartnerUnlocked` → `isForeverUnlocked`

**Deleted files:**
- `BabyTown/Views/InvitePartnerPaywallView.swift`
- `BabyTown/Components/InvitePartnerBanner.swift`
- `BabyTown/Components/PartnerPerksList.swift`

---

### Task 1: Rename entitlement throughout the codebase

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`
- Modify: `BabyTown/Services/StoreManager.swift`
- Modify: `BabyTown/Views/NotificationCenterView.swift`
- Modify: `BabyTown/Views/SubscriptionDetailView.swift`
- Modify: `BabyTown/Views/HomeView.swift`
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`
- Modify: `BabyTown/Components/SettingsSheet.swift`

**Interfaces:**
- Produces: `StoreManager.shared.isForeverUnlocked: Bool`, `StoreManager.shared.activePlan: ForeverPlan?`, `DataPersistenceManager.shared.isForeverUnlocked() -> Bool`, `DataPersistenceManager.shared.setForeverUnlocked(_:)`
- All later tasks use `store.isForeverUnlocked` — nothing else.

- [ ] **Step 1: Update DataPersistenceManager — rename methods, keep UserDefaults key**

In `BabyTown/Services/DataPersistenceManager.swift`, find the two methods and the reset line. The UserDefaults key string `"isPartnerUnlocked"` stays unchanged.

Replace:
```swift
func setPartnerUnlocked(_ unlocked: Bool) {
    userDefaults.set(unlocked, forKey: isPartnerUnlockedKey)
}

func isPartnerUnlocked() -> Bool {
    return userDefaults.bool(forKey: isPartnerUnlockedKey)
}
```
With:
```swift
func setForeverUnlocked(_ unlocked: Bool) {
    userDefaults.set(unlocked, forKey: isPartnerUnlockedKey)
}

func isForeverUnlocked() -> Bool {
    return userDefaults.bool(forKey: isPartnerUnlockedKey)
}
```

- [ ] **Step 2: Update StoreManager — rename enum and property**

In `BabyTown/Services/StoreManager.swift`:

Replace `enum PartnerPlan` with `enum ForeverPlan` everywhere in this file (the raw values — product IDs — stay identical). Replace `isPartnerUnlocked` with `isForeverUnlocked`. Replace `DataPersistenceManager.shared.isPartnerUnlocked()` with `DataPersistenceManager.shared.isForeverUnlocked()`. Replace `DataPersistenceManager.shared.setPartnerUnlocked` with `DataPersistenceManager.shared.setForeverUnlocked`.

Key lines to update (show complete updated signatures):
```swift
// Line ~5
enum ForeverPlan: String, CaseIterable { ... }   // was PartnerPlan

// Line ~51-52
@Published private(set) var isForeverUnlocked: Bool   // was isPartnerUnlocked
@Published private(set) var activePlan: ForeverPlan?  // was PartnerPlan?

// Line ~62
self.isForeverUnlocked = DataPersistenceManager.shared.isForeverUnlocked()

// Line ~78
func product(for plan: ForeverPlan) -> Product? { ... }

// Line ~84
func displayPrice(for plan: ForeverPlan) -> String { ... }

// Line ~90
let loaded = try await Product.products(for: ForeverPlan.allCases.map(\.rawValue))
// Sort closure: ForeverPlan(rawValue:...) in both places

// Line ~103
func purchase(_ plan: ForeverPlan) async -> Bool { ... }

// Line ~119
return isForeverUnlocked

// Lines ~143-157
var plan: ForeverPlan?
guard let matched = ForeverPlan(rawValue: transaction.productID) else { continue }
self.isForeverUnlocked = unlocked
self.activePlan = plan

// Line ~165
isForeverUnlocked = false
```

- [ ] **Step 3: Update all call sites**

In each file below, replace every occurrence of `isPartnerUnlocked` with `isForeverUnlocked`, `PartnerPlan` with `ForeverPlan`, and `store.isPartnerUnlocked` with `store.isForeverUnlocked`:

- `BabyTown/Views/NotificationCenterView.swift` — `@State private var isPartnerUnlocked` → `isForeverUnlocked`, `DataPersistenceManager.shared.isPartnerUnlocked()` → `.isForeverUnlocked()`
- `BabyTown/Views/SubscriptionDetailView.swift` — `store.isPartnerUnlocked` → `store.isForeverUnlocked`
- `BabyTown/Views/HomeView.swift` — `store.isPartnerUnlocked` → `store.isForeverUnlocked`
- `BabyTown/Views/CoupleProfile/CoupleProfileView.swift` — all occurrences of `isPartnerUnlocked`
- `BabyTown/Components/SettingsSheet.swift` — `store.isPartnerUnlocked` → `store.isForeverUnlocked`
- `BabyTown/Views/InvitePartnerPaywallView.swift` — `store.isPartnerUnlocked` → `store.isForeverUnlocked` (this file is deleted in Task 3 but must compile until then)

- [ ] **Step 4: Build to confirm zero errors**

Open `BabyTown.xcodeproj` in Xcode, press ⌘B. Expected: build succeeds with no errors. Fix any remaining `isPartnerUnlocked` or `PartnerPlan` references if found.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift \
        BabyTown/Services/StoreManager.swift \
        BabyTown/Views/NotificationCenterView.swift \
        BabyTown/Views/SubscriptionDetailView.swift \
        BabyTown/Views/HomeView.swift \
        BabyTown/Views/CoupleProfile/CoupleProfileView.swift \
        BabyTown/Components/SettingsSheet.swift \
        BabyTown/Views/InvitePartnerPaywallView.swift
git commit -m "refactor: rename isPartnerUnlocked → isForeverUnlocked, PartnerPlan → ForeverPlan"
```

---

### Task 2: Add dateAddedToApp to Moment

**Files:**
- Modify: `BabyTown/Models/Moment.swift`

**Interfaces:**
- Produces: `Moment.dateAddedToApp: Date?` — nil on existing decoded moments (backward compat), set to `Date()` on all new Moment creation sites.

- [ ] **Step 1: Add the property and CodingKey**

In `BabyTown/Models/Moment.swift`, add `var dateAddedToApp: Date?` after `var videoFileName: String?`:

```swift
var videoFileName: String?
var dateAddedToApp: Date?
```

In the `CodingKeys` enum, append `dateAddedToApp` to the case list:

```swift
enum CodingKeys: String, CodingKey {
    case id, dateTaken, assetIdentifier, thumbnailData, placeName, caption,
         voiceNotePath, promptText, isPinned, pinnedAt, isLocked, unlockTime,
         latitude, longitude, isAddedFromOnThisDay, isPlaceNameUserSet,
         country, videoFileName, dateAddedToApp
}
```

Because `dateAddedToApp` is `Date?`, the synthesised Codable decoder uses `decodeIfPresent` — existing stored Moments without this key decode successfully with `nil`.

- [ ] **Step 2: Set dateAddedToApp on every Moment creation site**

Search the project for `Moment(id:` or `Moment(` to find all callsites that construct a `Moment` struct. In each one, pass `dateAddedToApp: Date()`:

```bash
grep -rn "Moment(" BabyTown --include="*.swift" | grep -v "\.git"
```

For each found site, add `dateAddedToApp: Date()` to the initialiser. If the site is constructing a historical/scanned moment (where you know the actual add date doesn't matter), `Date()` is still correct — the vault window is about when it entered the app.

- [ ] **Step 3: Build and confirm**

Press ⌘B in Xcode. Expected: build succeeds. If any `Moment(` call sites have a missing-argument error, add `dateAddedToApp: Date()` there.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Models/Moment.swift
# Add any modified view/viewmodel files that now pass dateAddedToApp
git commit -m "feat(model): add dateAddedToApp to Moment for vault ordering"
```

---

### Task 3: Retire old paywall components and free the partner invite

**Files:**
- Delete: `BabyTown/Views/InvitePartnerPaywallView.swift`
- Delete: `BabyTown/Components/InvitePartnerBanner.swift`
- Delete: `BabyTown/Components/PartnerPerksList.swift`
- Modify: `BabyTown/Views/HomeView.swift`
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`
- Modify: `BabyTown/Views/NotificationCenterView.swift`

**Interfaces:**
- Consumes: `store.isForeverUnlocked` (from Task 1)
- Produces: Partner invite flow is free — no payment gate. `showPartnerPaywall` state is removed from HomeView and CoupleProfileView.

- [ ] **Step 1: Delete the three retired files**

```bash
rm BabyTown/Views/InvitePartnerPaywallView.swift
rm BabyTown/Components/InvitePartnerBanner.swift
rm BabyTown/Components/PartnerPerksList.swift
```

Then in Xcode, delete the file references from the project navigator (Move to Trash is already done; just remove the red references). Or use: select each in Xcode navigator → Delete → Remove Reference.

- [ ] **Step 2: Clean HomeView of old paywall state**

In `BabyTown/Views/HomeView.swift`:

Remove `@State private var showPartnerPaywall = false`.

Remove the `InvitePartnerBanner` from the feed body (the component no longer exists).

Remove the `.fullScreenCover(isPresented: $showPartnerPaywall)` block that presented `InvitePartnerPaywallView`.

In `onPartnerTap:` callback (line ~574), change the action from `showPartnerPaywall = true` to `showInviteFlow = true` (partner invite is now free — go straight to flow).

Update the invite button label logic (line ~91). Since partner invite is free, the label can simplify to always show "Invite partner" when no partner is paired, and "Send invite" once paired — remove the `store.isForeverUnlocked` condition from the label string if it was gated:
```swift
// Old
return store.isForeverUnlocked ? "Send invite" : "Invite partner"
// New — label depends on whether invite has been sent, not on subscription
return store.activePlan != nil ? "Send invite" : "Invite partner"
// Or just: return "Invite partner" if simpler for your flow
```

- [ ] **Step 3: Clean CoupleProfileView of old paywall gate**

In `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`:

Remove the two `.fullScreenCover` blocks that presented `InvitePartnerPaywallView` (lines ~345 and ~467). Both are replaced in Task 10 with a single `CovelaForeverPaywallView` cover.

On the invite button tap (line ~802 area — `showInviteFlow = true` path), remove any paywall interception. The tap should go directly to `InvitePartnerFlowView` regardless of `isForeverUnlocked`.

Remove the `return store.isForeverUnlocked ? "Send invite" : "Invite partner"` computed label (line ~105). Replace with a simple string that doesn't depend on subscription state.

- [ ] **Step 4: Clean NotificationCenterView**

In `BabyTown/Views/NotificationCenterView.swift`:

Remove `@State private var showPartnerPaywall = false` and `@State private var isForeverUnlocked = ...` (the locally-held copy). This view will get its unlock state from `StoreManager.shared` directly in Task 8.

Remove any paywall `.fullScreenCover` or `.sheet` block that presented the old paywall from this view.

- [ ] **Step 5: Build**

Press ⌘B. Expected: build succeeds with no references to deleted types. Fix any stray `InvitePartnerPaywallView`, `InvitePartnerBanner`, or `PartnerPerksList` references.

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Views/HomeView.swift \
        BabyTown/Views/CoupleProfile/CoupleProfileView.swift \
        BabyTown/Views/NotificationCenterView.swift
git commit -m "feat: free the partner invite, retire old paywall components"
```

---

### Task 4: Build CovelaForeverPaywallView

**Files:**
- Create: `BabyTown/Views/CovelaForeverPaywallView.swift`

**Interfaces:**
- Consumes: `StoreManager` (via `@ObservedObject var store: StoreManager`), `ForeverPlan` enum (Task 1)
- Produces: `CovelaForeverPaywallView(store:onUnlock:onDismiss:)` — a full-screen paywall view, callable from any entry point with the same signature.

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/CovelaForeverPaywallView.swift` with the following content. This mirrors the structure of the old `InvitePartnerPaywallView` with new copy, a new benefits list, and `ForeverPlan` in place of `PartnerPlan`:

```swift
import SwiftUI

struct CovelaForeverPaywallView: View {

    @ObservedObject var store: StoreManager
    var onUnlock: () -> Void
    var onDismiss: () -> Void

    @State private var showAllPlans = false
    @State private var appear = false
    @State private var showError = false

    private var accent: Color { BabyTownTheme.accentDeep }
    private var heroGradient: [Color] { [BabyTownTheme.accent, BabyTownTheme.accentDeep] }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, accent.opacity(0.10)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            LoopingVideoPlayer(videoName: "transparent_flowers")
                .frame(height: 300)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .blendMode(.screen)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                closeRow
                hero
                benefitsList
                    .padding(.top, 18)
                bothBanner
                    .padding(.top, 18)
                yearlyHeroCard
                    .padding(.top, 18)
                cta
                    .padding(.top, 16)
                seeAllPlansButton
                    .padding(.top, 12)
                finePrint
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)

            if store.isPurchasing {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(accent)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appear = true }
        }
        .sheet(isPresented: $showAllPlans) {
            ForeverAllPlansSheet(
                accent: accent,
                store: store,
                onPurchase: { plan in buy(plan) }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationBackground(BabyTownTheme.cardBackground)
        }
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { store.purchaseError = nil }
        } message: {
            Text(store.purchaseError ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Purchase

    private func buy(_ plan: ForeverPlan) {
        Task {
            let unlocked = await store.purchase(plan)
            if unlocked {
                onUnlock()
            } else if store.purchaseError != nil {
                showError = true
            }
        }
    }

    private func restore() {
        Task {
            await store.restore()
            if store.isForeverUnlocked { onUnlock() }
        }
    }

    // MARK: - Sections

    private var closeRow: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
                    .frame(width: 32, height: 32)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            Image("BabyTownFullIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 15.75, style: .continuous))
                .shadow(color: accent.opacity(0.38), radius: 12, y: 6)
                .padding(.bottom, 16)

            Text("Keep every memory,\nforever")
                .font(.system(size: 25, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.85))

            Text("Your full story, always within reach")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "photo.on.rectangle.angled", text: "Every moment, always — your full timeline with no limits")
            benefitRow(icon: "envelope.open.fill",       text: "Letters that last — read and write beyond 30 days")
            benefitRow(icon: "calendar.badge.plus",      text: "Unlimited important dates — every milestone, saved forever")
            benefitRow(icon: "pin.fill",                 text: "Unlimited pinned moments — keep what matters most")
            benefitRow(icon: "heart.fill",               text: "One purchase for both of you — covers you and your partner")
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bothBanner: some View {
        (Text("One purchase unlocks Forever for ")
            + Text("both").fontWeight(.bold)
            + Text(" of you"))
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing))
            )
    }

    private var yearlyHeroCard: some View {
        Button { buy(.yearly) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yearly")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.85))
                    Text("$2.50/mo · save ~58%")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.black.opacity(0.5))
                }
                Spacer()
                Text(store.displayPrice(for: .yearly))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.85))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.white, accent.opacity(0.06)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent, lineWidth: 2)
            )
            .overlay(alignment: .topLeading) {
                Text("7-DAY FREE TRIAL")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent))
                    .offset(x: 14, y: -10)
            }
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        Button { buy(.yearly) } label: {
            Text("Start 7-day free trial")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing))
                        .shadow(color: accent.opacity(0.34), radius: 14, y: 6)
                )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    private var seeAllPlansButton: some View {
        Button { showAllPlans = true } label: {
            Text("See all Plans")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var finePrint: some View {
        VStack(spacing: 6) {
            Text("Then \(store.displayPrice(for: .yearly))/year · Cancel anytime")
            Button(action: restore) {
                Text("Restore purchase")
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 10))
        .foregroundStyle(.black.opacity(0.35))
        .multilineTextAlignment(.center)
    }
}

// MARK: - All Plans sheet

private struct ForeverAllPlansSheet: View {

    let accent: Color
    @ObservedObject var store: StoreManager
    var onPurchase: (ForeverPlan) -> Void

    private let cardHeight: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            Text("CHOOSE A PLAN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.black.opacity(0.45))
                .padding(.top, 20)
                .padding(.bottom, 16)

            planCard(.yearly,  title: "Yearly + 7-day free trial",
                     primary: "\(store.displayPrice(for: .yearly))/year for 2 users",
                     secondary: "$1.25 per user/month", badge: "BEST DEAL", highlighted: true)
                .padding(.bottom, 10)

            planCard(.monthly, title: "Monthly",
                     primary: "\(store.displayPrice(for: .monthly))/month for 2 users",
                     secondary: "$3.00 per user/month", badge: nil, highlighted: false)
                .padding(.bottom, 10)

            planCard(.lifetime, title: "Lifetime",
                     primary: "\(store.displayPrice(for: .lifetime)) once for 2 users",
                     secondary: "One payment, forever", badge: nil, highlighted: false)

            Text("Cancel anytime in the App Store")
                .font(.system(size: 11.5))
                .foregroundStyle(.black.opacity(0.42))
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(BabyTownTheme.cardBackground)
    }

    private func planCard(
        _ plan: ForeverPlan,
        title: String,
        primary: String,
        secondary: String,
        badge: String?,
        highlighted: Bool
    ) -> some View {
        Button { onPurchase(plan) } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.88))
                        .lineLimit(2).minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(primary)
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.55))
                    Text(secondary)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.42))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, badge == nil ? 0 : 72)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(accent))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(highlighted ? 1 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(highlighted ? accent.opacity(0.85) : Color.black.opacity(0.12),
                            lineWidth: highlighted ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }
}

#Preview {
    CovelaForeverPaywallView(store: .shared, onUnlock: {}, onDismiss: {})
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode's navigator, right-click `BabyTown/Views/` → Add Files → select `CovelaForeverPaywallView.swift`. Ensure it's added to the `BabyTown` target.

- [ ] **Step 3: Build**

Press ⌘B. Expected: builds cleanly. If `ForeverPlan` cases (`.yearly`, `.monthly`, `.lifetime`) are not found, confirm Task 1 completed and the enum was renamed.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/CovelaForeverPaywallView.swift
git commit -m "feat: add CovelaForeverPaywallView with new copy and benefits"
```

---

### Task 5: Vault logic in HomeViewModel + DayClusterCard vaulted state

**Files:**
- Modify: `BabyTown/ViewModels/HomeViewModel.swift`
- Modify: `BabyTown/Components/DayClusterCard.swift`

**Interfaces:**
- Produces: `HomeViewModel.vaultedMomentIDs(isForeverUnlocked: Bool) -> Set<UUID>` — pure function, no side effects, safe to call on every render.
- Produces: `DayClusterCard(section:isVaulted:onTap:)` — adds optional `isVaulted: Bool = false` parameter; when true renders a frosted overlay with a lock icon instead of the normal tap action.

- [ ] **Step 1: Add vaultedMomentIDs to HomeViewModel**

In `BabyTown/ViewModels/HomeViewModel.swift`, add this method after the existing `pinnedMoments` computed property:

```swift
/// Returns the IDs of moments that are hidden behind the Forever paywall.
/// The 50 most recently added moments are always visible; everything beyond
/// that is vaulted. Returns an empty set when the user is subscribed.
func vaultedMomentIDs(isForeverUnlocked: Bool) -> Set<UUID> {
    guard !isForeverUnlocked else { return [] }
    let freeLimit = 50
    guard moments.count > freeLimit else { return [] }
    let sorted = moments.sorted {
        ($0.dateAddedToApp ?? $0.dateTaken) > ($1.dateAddedToApp ?? $1.dateTaken)
    }
    return Set(sorted.dropFirst(freeLimit).map(\.id))
}
```

- [ ] **Step 2: Add vaulted rendering to DayClusterCard**

In `BabyTown/Components/DayClusterCard.swift`, add `var isVaulted: Bool = false` to the struct's stored properties (near the top with the other inputs).

In the card body, wrap the existing content in a `ZStack` so the frosted overlay can sit above it. After the existing content, add:

```swift
if isVaulted {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                Text("This memory is in your vault")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        )
        .allowsHitTesting(false)
}
```

Also disable the card's tap action when vaulted — wherever the `onTap` / `Button` action fires in DayClusterCard, guard it:

```swift
// Find the existing tap gesture or Button. Wrap the action:
.onTapGesture {
    guard !isVaulted else { return }
    // ... existing tap action
}
// OR if it's a Button:
.disabled(isVaulted)
```

The card itself remains tappable (the HomeView layer above will handle the vaulted tap to show VaultedMomentPrompt in Task 6).

- [ ] **Step 3: Build**

Press ⌘B. Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/ViewModels/HomeViewModel.swift \
        BabyTown/Components/DayClusterCard.swift
git commit -m "feat: add vault logic to HomeViewModel and frosted state to DayClusterCard"
```

---

### Task 6: VaultedMomentPrompt + wire HomeView

**Files:**
- Create: `BabyTown/Components/VaultedMomentPrompt.swift`
- Modify: `BabyTown/Views/HomeView.swift`

**Interfaces:**
- Consumes: `CovelaForeverPaywallView` (Task 4), `HomeViewModel.vaultedMomentIDs(isForeverUnlocked:)` (Task 5), `DayClusterCard(isVaulted:)` (Task 5)
- Produces: `VaultedMomentPrompt(isPresented:onUnlockForever:)` — a `.sheet` component; when `onUnlockForever` is called, the caller presents the full paywall.

- [ ] **Step 1: Create VaultedMomentPrompt**

Create `BabyTown/Components/VaultedMomentPrompt.swift`:

```swift
import SwiftUI

struct VaultedMomentPrompt: View {

    @Binding var isPresented: Bool
    var onUnlockForever: () -> Void

    private var accent: Color { BabyTownTheme.accentDeep }

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(accent)

            VStack(spacing: 6) {
                Text("This moment has been safely stored away")
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.85))

                Text("Upgrade to Covela Forever to unlock your full timeline")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.horizontal, 24)

            Button {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onUnlockForever()
                }
            } label: {
                Text("Unlock Forever")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [BabyTownTheme.accent, accent],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button {
                isPresented = false
            } label: {
                Text("Maybe later")
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(BabyTownTheme.cardBackground)
    }
}
```

- [ ] **Step 2: Wire into HomeView**

In `BabyTown/Views/HomeView.swift`, add two state variables:

```swift
@State private var showVaultedPrompt = false
@State private var showForeverPaywall = false
```

Compute vaulted IDs in the view body (HomeView already observes both `viewModel` and `store`):

```swift
private var vaultedIDs: Set<UUID> {
    viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)
}
```

Where `DayClusterCard` is rendered in the feed, pass `isVaulted`:

```swift
DayClusterCard(
    section: section,
    isVaulted: vaultedIDs.contains(section.moments.first?.id ?? UUID()),
    onTap: { moment, all in
        if vaultedIDs.contains(moment.id) {
            showVaultedPrompt = true
        } else {
            // existing open-memory logic
        }
    }
)
```

Add the sheet and paywall cover at the end of the view body:

```swift
.sheet(isPresented: $showVaultedPrompt) {
    VaultedMomentPrompt(
        isPresented: $showVaultedPrompt,
        onUnlockForever: { showForeverPaywall = true }
    )
    .presentationDetents([.height(340)])
    .presentationDragIndicator(.visible)
    .presentationBackground(BabyTownTheme.cardBackground)
}
.fullScreenCover(isPresented: $showForeverPaywall) {
    CovelaForeverPaywallView(
        store: store,
        onUnlock: { showForeverPaywall = false },
        onDismiss: { showForeverPaywall = false }
    )
}
```

- [ ] **Step 3: Add VaultedMomentPrompt to Xcode project**

In Xcode navigator, add `BabyTown/Components/VaultedMomentPrompt.swift` to the BabyTown target.

- [ ] **Step 4: Build and manually test**

Press ⌘B. Run on simulator. Add more than 50 moments (or temporarily lower the `freeLimit` to 3 in `vaultedMomentIDs` to test). Verify:
- First 50 (most recent by `dateAddedToApp`) show normally.
- Older ones show the frosted lock card.
- Tapping a locked card shows the bottom sheet with "This moment has been safely stored away".
- Tapping "Unlock Forever" dismisses the sheet then opens the full paywall.
- Tapping "Maybe later" dismisses with no paywall.

Restore `freeLimit = 50` before committing.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Components/VaultedMomentPrompt.swift \
        BabyTown/Views/HomeView.swift
git commit -m "feat: add VaultedMomentPrompt and wire vault gate into home feed"
```

---

### Task 7: Vaulted map markers

**Files:**
- Modify: `BabyTown/Components/MemoryMapAnnotation.swift`
- Modify: `BabyTown/Views/MapView.swift`

**Interfaces:**
- Consumes: `HomeViewModel.vaultedMomentIDs(isForeverUnlocked:)` (Task 5), `VaultedMomentPrompt` (Task 6), `CovelaForeverPaywallView` (Task 4)
- Produces: Vaulted moment map markers are visually blurred; tapping one shows `VaultedMomentPrompt`.

- [ ] **Step 1: Add isVaulted to MemoryMapAnnotation**

In `BabyTown/Components/MemoryMapAnnotation.swift`, add `let isVaulted: Bool` to the class properties and update `init(section:showsPhotoThumbnail:)`:

```swift
let isVaulted: Bool

init(section: DaySection, showsPhotoThumbnail: Bool = true, isVaulted: Bool = false) {
    self.isVaulted = isVaulted
    // ... rest of existing init unchanged
}
```

- [ ] **Step 2: Pass vaultedIDs when building annotations in MapView**

In `BabyTown/Views/MapView.swift`, add state:

```swift
@State private var showVaultedPrompt = false
@State private var showForeverPaywall = false
```

In the `buildAnnotations` / `updateAnnotations` methods (around line ~418 and ~443 in the file), pass `isVaulted` when constructing `MemoryMapAnnotation`. MapView already has access to `viewModel`; add `store` as a parameter or use `StoreManager.shared`:

```swift
// At top of MapView, after existing @ObservedObject var viewModel:
@ObservedObject private var store: StoreManager = .shared
```

Then when building annotations:

```swift
let vaulted = viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)

// In the MemoryMapAnnotation(section:...) construction:
MemoryMapAnnotation(
    section: section,
    showsPhotoThumbnail: showsPhotoThumbnails,
    isVaulted: section.moments.contains { vaulted.contains($0.id) }
)
```

- [ ] **Step 3: Blur vaulted markers and intercept their tap**

Find where the map annotation view is rendered (the `MKAnnotationView` or SwiftUI `Annotation` / `MapAnnotation` — wherever the thumbnail is shown). When `annotation.isVaulted`:

- Apply `.blur(radius: 8)` to the marker's image/view.
- Overlay a `Image(systemName: "lock.fill")` centered over the blurred thumbnail.

In the existing `onOpenMemory` tap handler (line ~390), guard against vaulted:

```swift
private func handleAnnotationTap(_ section: DaySection) {
    let vaulted = viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)
    if section.moments.contains(where: { vaulted.contains($0.id) }) {
        showVaultedPrompt = true
    } else {
        onOpenMemory(section)
    }
}
```

Replace the `onOpenMemory(section)` call at line ~390 with `handleAnnotationTap(section)`.

Attach the prompt and paywall to the MapView body:

```swift
.sheet(isPresented: $showVaultedPrompt) {
    VaultedMomentPrompt(
        isPresented: $showVaultedPrompt,
        onUnlockForever: { showForeverPaywall = true }
    )
    .presentationDetents([.height(340)])
    .presentationDragIndicator(.visible)
    .presentationBackground(BabyTownTheme.cardBackground)
}
.fullScreenCover(isPresented: $showForeverPaywall) {
    CovelaForeverPaywallView(
        store: store,
        onUnlock: { showForeverPaywall = false },
        onDismiss: { showForeverPaywall = false }
    )
}
```

- [ ] **Step 4: Build and manually test**

Press ⌘B. Run on simulator. With vaulted moments in place, open the map. Verify:
- Vaulted moment markers appear blurred with a lock icon.
- Tapping a vaulted marker shows `VaultedMomentPrompt`.
- Non-vaulted markers tap through to the memory card as before.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Components/MemoryMapAnnotation.swift \
        BabyTown/Views/MapView.swift
git commit -m "feat: blur vaulted moment markers on map, show vault prompt on tap"
```

---

### Task 8: Letters 30-day gating

**Files:**
- Create: `BabyTown/Components/VaultedLetterRow.swift`
- Modify: `BabyTown/Views/NotificationCenterView.swift`

**Interfaces:**
- Consumes: `UserLetter.createdAt: Date` (already on model), `CovelaForeverPaywallView` (Task 4)
- Produces: Letters with `createdAt` older than 30 days show `VaultedLetterRow` instead of `UserLetterRow`; tapping opens the paywall.

- [ ] **Step 1: Create VaultedLetterRow**

Create `BabyTown/Components/VaultedLetterRow.swift`:

```swift
import SwiftUI

struct VaultedLetterRow: View {

    let letter: UserLetter
    var onUnlockForever: () -> Void

    private var accent: Color { BabyTownTheme.accentDeep }

    var body: some View {
        Button(action: onUnlockForever) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accent.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(letter.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.35))
                        .redacted(reason: .placeholder)
                    Text("Unlock Forever to read this letter")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.35))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Update NotificationCenterView**

In `BabyTown/Views/NotificationCenterView.swift`, add state:

```swift
@ObservedObject private var store: StoreManager = .shared
@State private var showForeverPaywall = false
```

Replace the `ForEach(userLetters...)` loop with a version that checks each letter's age:

```swift
private var thirtyDaysAgo: Date {
    Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
}

// In the body, replace:
ForEach(userLetters.sorted { $0.sortDate > $1.sortDate }) { letter in
    UserLetterRow(letter: letter)
}

// With:
ForEach(userLetters.sorted { $0.sortDate > $1.sortDate }) { letter in
    if store.isForeverUnlocked || letter.createdAt >= thirtyDaysAgo {
        UserLetterRow(letter: letter)
    } else {
        VaultedLetterRow(letter: letter) {
            showForeverPaywall = true
        }
    }
}
```

Add the paywall cover:

```swift
.fullScreenCover(isPresented: $showForeverPaywall) {
    CovelaForeverPaywallView(
        store: store,
        onUnlock: { showForeverPaywall = false },
        onDismiss: { showForeverPaywall = false }
    )
}
```

- [ ] **Step 3: Add VaultedLetterRow to Xcode project**

Add `BabyTown/Components/VaultedLetterRow.swift` to the BabyTown target.

- [ ] **Step 4: Build and manually test**

Press ⌘B. Run on simulator. Navigate to Letters. Verify:
- Letters less than 30 days old show normally.
- Letters older than 30 days show `VaultedLetterRow` with redacted title and lock icon.
- Tapping a vaulted letter row opens the full paywall.
- With `store.isForeverUnlocked = true`, all letters show normally.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Components/VaultedLetterRow.swift \
        BabyTown/Views/NotificationCenterView.swift
git commit -m "feat: gate letters older than 30 days behind Covela Forever"
```

---

### Task 9: Hard caps for Important Dates and Pinned Moments

**Files:**
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`
- Modify: `BabyTown/ViewModels/HomeViewModel.swift`

**Interfaces:**
- Consumes: `CovelaForeverPaywallView` (Task 4), `store.isForeverUnlocked` (Task 1)
- Produces: Adding an 11th important date or pinning an 11th moment shows a bottom sheet with "Unlock Forever" CTA instead of proceeding.

- [ ] **Step 1: Gate saveSpecial in CoupleProfileView**

In `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`, add state:

```swift
@State private var showForeverPaywall = false
@State private var showDateCapSheet = false
```

The `saveSpecial(_:image:)` method (line ~1057) appends a new date when `firstIndex(where:)` returns `nil`. Guard that path:

```swift
private func saveSpecial(_ date: SpecialDate, image: UIImage?) {
    let isNew = profile.specialDates.firstIndex(where: { $0.id == date.id }) == nil
    if isNew && !store.isForeverUnlocked && profile.specialDates.count >= 10 {
        showDateCapSheet = true
        return
    }
    if let idx = profile.specialDates.firstIndex(where: { $0.id == date.id }) {
        profile.specialDates[idx] = date
    } else {
        profile.specialDates.append(date)
    }
    if let image { dpm.saveSpecialDatePhoto(image, id: date.id) }
    dpm.saveCoupleProfile(profile)
    refreshStickers()
}
```

Add a sheet for the cap prompt and the paywall cover to the view body:

```swift
.sheet(isPresented: $showDateCapSheet) {
    VStack(spacing: 20) {
        Capsule()
            .fill(Color.black.opacity(0.15))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
        Image(systemName: "calendar.badge.exclamationmark")
            .font(.system(size: 32))
            .foregroundStyle(BabyTownTheme.accentDeep)
        Text("You have reached your 10 important date limit")
            .font(.system(size: 16, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        Text("Upgrade to Covela Forever to save unlimited dates")
            .font(.system(size: 13))
            .foregroundStyle(.black.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        Button {
            showDateCapSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showForeverPaywall = true
            }
        } label: {
            Text("Unlock Forever")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(LinearGradient(
                    colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep],
                    startPoint: .leading, endPoint: .trailing
                )))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        Button { showDateCapSheet = false } label: {
            Text("Maybe later")
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }
    .frame(maxWidth: .infinity)
    .presentationDetents([.height(360)])
    .presentationDragIndicator(.visible)
    .presentationBackground(BabyTownTheme.cardBackground)
}
.fullScreenCover(isPresented: $showForeverPaywall) {
    CovelaForeverPaywallView(
        store: store,
        onUnlock: { showForeverPaywall = false },
        onDismiss: { showForeverPaywall = false }
    )
}
```

- [ ] **Step 2: Gate togglePin in HomeViewModel**

`togglePin(for:)` in `HomeViewModel` sets `shouldPin = true` when the section isn't already pinned. Add a callback mechanism so the caller (HomeView) can intercept the cap. Add a closure property:

```swift
/// Called when a pin attempt is blocked by the 10-pin free-tier limit.
var onPinCapReached: (() -> Void)?
```

In `togglePin(for:)`, before pinning:

```swift
func togglePin(for section: DaySection) {
    guard !section.moments.isEmpty else { return }
    let sectionMomentIds = Set(section.moments.map(\.id))
    let shouldPin = !section.moments.contains(where: \.isPinned)

    if shouldPin {
        let currentPinCount = moments.filter { $0.isPinned && !Self.isFoundingMoment($0) }.count
        if currentPinCount >= 10 {
            onPinCapReached?()
            return
        }
    }

    let pinTimestamp = Date()
    var newMoments = moments
    for index in newMoments.indices where sectionMomentIds.contains(newMoments[index].id) {
        newMoments[index].isPinned = shouldPin
        newMoments[index].pinnedAt = shouldPin ? pinTimestamp : nil
    }
    moments = newMoments
}
```

- [ ] **Step 3: Wire pin cap in HomeView**

In `BabyTown/Views/HomeView.swift`, add:

```swift
@State private var showPinCapSheet = false
```

On view appear (or in the initializer block where `viewModel` is configured), set the callback:

```swift
.onAppear {
    viewModel.onPinCapReached = { showPinCapSheet = true }
}
```

Add the pin cap sheet to the view body (same structure as the date cap sheet above, with "You have reached your 10 pinned moment limit" copy):

```swift
.sheet(isPresented: $showPinCapSheet) {
    VStack(spacing: 20) {
        Capsule()
            .fill(Color.black.opacity(0.15))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
        Image(systemName: "pin.fill")
            .font(.system(size: 32))
            .foregroundStyle(BabyTownTheme.accentDeep)
        Text("You have reached your 10 pinned moment limit")
            .font(.system(size: 16, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        Text("Upgrade to Covela Forever to pin unlimited moments")
            .font(.system(size: 13))
            .foregroundStyle(.black.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        Button {
            showPinCapSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showForeverPaywall = true
            }
        } label: {
            Text("Unlock Forever")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(LinearGradient(
                    colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep],
                    startPoint: .leading, endPoint: .trailing
                )))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        Button { showPinCapSheet = false } label: {
            Text("Maybe later")
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }
    .frame(maxWidth: .infinity)
    .presentationDetents([.height(360)])
    .presentationDragIndicator(.visible)
    .presentationBackground(BabyTownTheme.cardBackground)
}
```

- [ ] **Step 4: Build and manually test**

Press ⌘B. Run on simulator. Verify:
- Adding an 11th important date shows the cap sheet with "Unlock Forever".
- Tapping "Unlock Forever" dismisses the sheet then opens the full paywall.
- Pinning a moment when 10 are already pinned shows the pin cap sheet.
- With `store.isForeverUnlocked = true`, both caps are bypassed and add/pin works normally.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Views/CoupleProfile/CoupleProfileView.swift \
        BabyTown/ViewModels/HomeViewModel.swift \
        BabyTown/Views/HomeView.swift
git commit -m "feat: enforce 10-item hard cap on important dates and pinned moments"
```

---

### Task 10: Settings upgrade row + Secret Garden upgrade button

**Files:**
- Modify: `BabyTown/Components/SettingsSheet.swift`
- Modify: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`

**Interfaces:**
- Consumes: `CovelaForeverPaywallView` (Task 4), `store.isForeverUnlocked` (Task 1)
- Produces: Settings has a "Covela Forever" row that opens the paywall. The "Invite" button in Secret Garden becomes "Upgrade to Forever" for non-subscribers, and goes directly to the invite flow for subscribers.

- [ ] **Step 1: Update SettingsSheet**

In `BabyTown/Components/SettingsSheet.swift`, the existing row (line ~36) shows free/active status. Update it to use the new property name and label:

```swift
// Replace the existing subscription row label with:
Button {
    showPaywall = true
} label: {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text("Covela Forever")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
            Text(store.isForeverUnlocked
                 ? (store.activePlan?.displayName ?? "Active")
                 : "Free plan")
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.45))
        }
        Spacer()
        if !store.isForeverUnlocked {
            Text("Upgrade")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(BabyTownTheme.accentDeep))
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BabyTownTheme.accentDeep)
        }
    }
}
.buttonStyle(.plain)
```

Update the `.fullScreenCover(isPresented: $showPaywall)` to present `CovelaForeverPaywallView`:

```swift
.fullScreenCover(isPresented: $showPaywall) {
    CovelaForeverPaywallView(
        store: store,
        onUnlock: { showPaywall = false },
        onDismiss: { showPaywall = false }
    )
}
```

- [ ] **Step 2: Replace Invite button with Upgrade to Forever in CoupleProfileView**

In `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`, find the "Invite" button at line ~545. Replace it with a conditional:

```swift
// Old:
Text("Invite")

// New — show upgrade button for free users, keep invite for subscribers:
if store.isForeverUnlocked {
    Button {
        showInviteFlow = true
    } label: {
        Text("Send invite")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(BabyTownTheme.accentDeep))
    }
    .buttonStyle(.plain)
} else {
    Button {
        showForeverPaywall = true
    } label: {
        Text("Upgrade to Forever")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep],
                    startPoint: .leading, endPoint: .trailing
                ))
            )
    }
    .buttonStyle(.plain)
}
```

Ensure `showForeverPaywall` state and the corresponding `.fullScreenCover` are already added from Task 9. If not, add them here.

- [ ] **Step 3: Build**

Press ⌘B. Expected: clean build.

- [ ] **Step 4: Manually test all three entry points**

1. **Settings** — open settings sheet, tap the "Covela Forever" row, confirm paywall opens.
2. **Secret Garden** — open couple profile, tap "Upgrade to Forever" button (free user), confirm paywall opens. Set `isForeverUnlocked = true`, confirm button changes to "Send invite" and opens invite flow.
3. **Vaulted content** (from Tasks 6-7) — confirm vaulted moment prompt still opens paywall correctly.

- [ ] **Step 5: Final build and commit**

Press ⌘B one more time to confirm everything compiles cleanly end-to-end.

```bash
git add BabyTown/Components/SettingsSheet.swift \
        BabyTown/Views/CoupleProfile/CoupleProfileView.swift
git commit -m "feat: add Covela Forever row to Settings and upgrade button to Secret Garden"
```
