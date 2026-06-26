# Home Garden Patch Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a decorative-but-interactive grass patch scene (pet house + mailbox) into the Home feed between CoupleSpaceCard and OnThisDaySection.

**Architecture:** A new `HomeGardenPatchView` component encapsulates the 160pt ZStack scene and takes pure callbacks; `HomeView` owns the `hasUnreadMail` state and wires both tap actions. `DataPersistenceManager` gets a single UserDefaults-backed read method as a placeholder for the future inbox backend.

**Tech Stack:** SwiftUI, UserDefaults (DataPersistenceManager), xcassets imageset scaffolding

## Global Constraints

- Never use ` - ` (space dash space) in any user-facing string
- Always use `BabyTownTheme.*` tokens for colors; never hardcode hex/RGB
- Both Pink and Blue themes must be supported
- Swift file naming: PascalCase; asset naming: snake_case
- No animations on mailbox state change (static image swap only)
- Mailbox tap is a no-op in this phase — no navigation wired
- The four PNG assets must be dragged into Xcode by the developer after the imageset folders are created; the plan only creates the `Contents.json` scaffolding
- No BabyTown test target exists — verification is done by building in Xcode and running in the simulator

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `BabyTown/Components/HomeGardenPatchView.swift` | Create | ZStack widget: grass oval, pet house button, mailbox button |
| `BabyTown/Services/DataPersistenceManager.swift` | Modify (lines 132–134, 670–673) | Add `hasUnreadMailKey` constant and `loadHasUnreadMail()` method |
| `BabyTown/Views/HomeView.swift` | Modify (lines 29–82, 224–226, 670–673) | Add state, load on appear, insert widget in scroll VStack |
| `BabyTown/Assets.xcassets/home_grass_patch.imageset/Contents.json` | Create | 1x imageset placeholder |
| `BabyTown/Assets.xcassets/home_pet_house.imageset/Contents.json` | Create | 1x imageset placeholder |
| `BabyTown/Assets.xcassets/home_mailbox_empty.imageset/Contents.json` | Create | 1x imageset placeholder |
| `BabyTown/Assets.xcassets/home_mailbox_full.imageset/Contents.json` | Create | 1x imageset placeholder |

---

### Task 1: DataPersistenceManager — `loadHasUnreadMail()`

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

**Interfaces:**
- Produces: `func loadHasUnreadMail() -> Bool` on `DataPersistenceManager`

- [ ] **Step 1: Add the UserDefaults key constant**

In `DataPersistenceManager.swift`, find the block of private key constants around line 132 (`private let pendingInvitePartnerNameKey = "pendingInvitePartnerName"`). Add directly after it:

```swift
    private let hasUnreadMailKey = "hasUnreadMail"
```

- [ ] **Step 2: Add the load method**

After `func loadInviterName() -> String?` (ends around line 721), add:

```swift
    func loadHasUnreadMail() -> Bool {
        userDefaults.bool(forKey: hasUnreadMailKey)
    }
```

`UserDefaults.bool(forKey:)` returns `false` by default when the key is absent, so no explicit default needed.

- [ ] **Step 3: Build to verify no compile errors**

In Xcode: `Cmd+B`. Expected: build succeeds with no new errors.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat: add loadHasUnreadMail placeholder to DataPersistenceManager"
```

---

### Task 2: Asset Imageset Scaffolding

**Files:**
- Create: `BabyTown/Assets.xcassets/home_grass_patch.imageset/Contents.json`
- Create: `BabyTown/Assets.xcassets/home_pet_house.imageset/Contents.json`
- Create: `BabyTown/Assets.xcassets/home_mailbox_empty.imageset/Contents.json`
- Create: `BabyTown/Assets.xcassets/home_mailbox_full.imageset/Contents.json`

**Interfaces:**
- Produces: four named imagesets accessible via `Image("home_grass_patch")` etc. in SwiftUI
- The PNG files themselves are not created here — the developer drags them into Xcode after this task

- [ ] **Step 1: Create the four imageset directories and their Contents.json**

Each file has identical content (1x universal slot, no filename yet):

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Create this file at all four paths:
- `BabyTown/Assets.xcassets/home_grass_patch.imageset/Contents.json`
- `BabyTown/Assets.xcassets/home_pet_house.imageset/Contents.json`
- `BabyTown/Assets.xcassets/home_mailbox_empty.imageset/Contents.json`
- `BabyTown/Assets.xcassets/home_mailbox_full.imageset/Contents.json`

- [ ] **Step 2: Build to verify Xcode picks up the new imagesets**

In Xcode: `Cmd+B`. Expected: build succeeds. The imagesets appear in the Assets catalog browser (they will show empty image slots until PNGs are dragged in).

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Assets.xcassets/home_grass_patch.imageset/Contents.json
git add BabyTown/Assets.xcassets/home_pet_house.imageset/Contents.json
git add BabyTown/Assets.xcassets/home_mailbox_empty.imageset/Contents.json
git add BabyTown/Assets.xcassets/home_mailbox_full.imageset/Contents.json
git commit -m "feat: scaffold asset imagesets for home garden patch widget"
```

---

### Task 3: `HomeGardenPatchView` Component

**Files:**
- Create: `BabyTown/Components/HomeGardenPatchView.swift`

**Interfaces:**
- Consumes: `loadHasUnreadMail()` (Task 1); imagesets `home_grass_patch`, `home_pet_house`, `home_mailbox_empty`, `home_mailbox_full` (Task 2)
- Produces: `struct HomeGardenPatchView: View` with init `(hasUnreadMail: Bool, onPetHouseTap: () -> Void, onMailboxTap: () -> Void)`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct HomeGardenPatchView: View {
    let hasUnreadMail: Bool
    let onPetHouseTap: () -> Void
    let onMailboxTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("home_grass_patch")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 0) {
                Button(action: onPetHouseTap) {
                    Image("home_pet_house")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 90)
                }
                .buttonStyle(.plain)
                .padding(.leading, 28)

                Spacer()

                Button(action: onMailboxTap) {
                    Image(hasUnreadMail ? "home_mailbox_full" : "home_mailbox_empty")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 36)
            }
            .offset(y: 14)
        }
        .frame(height: 160)
        .clipped()
    }
}
```

**Notes for the developer:**
- `.offset(y: 14)` pushes the objects so they partially overlap the grass bottom edge. Adjust this value after real assets are in place.
- `frame(height: 90)` for the pet house and `frame(height: 70)` for the mailbox are starting sizes; tune after assets are added.
- `.clipped()` prevents the offset objects from painting outside the 160pt frame during layout.

- [ ] **Step 2: Build to verify no compile errors**

In Xcode: `Cmd+B`. Expected: build succeeds.

- [ ] **Step 3: Add a preview for visual verification**

Append at the bottom of `HomeGardenPatchView.swift`:

```swift
#Preview {
    VStack {
        HomeGardenPatchView(
            hasUnreadMail: false,
            onPetHouseTap: {},
            onMailboxTap: {}
        )
        HomeGardenPatchView(
            hasUnreadMail: true,
            onPetHouseTap: {},
            onMailboxTap: {}
        )
    }
    .padding()
    .background(Color(red: 0.94, green: 0.97, blue: 1.0))
}
```

Open the Xcode Canvas (`Cmd+Option+Return`) and confirm the widget renders in both `hasUnreadMail` states. With placeholder (missing) assets the images will be empty; that is expected until PNGs are added.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Components/HomeGardenPatchView.swift
git commit -m "feat: add HomeGardenPatchView component"
```

---

### Task 4: Wire Widget into HomeView

**Files:**
- Modify: `BabyTown/Views/HomeView.swift`

**Interfaces:**
- Consumes: `HomeGardenPatchView(hasUnreadMail:onPetHouseTap:onMailboxTap:)` (Task 3); `DataPersistenceManager.shared.loadHasUnreadMail()` (Task 1)
- Uses existing state: `showVisitPet: Bool` (already declared at line 28)

- [ ] **Step 1: Add `hasUnreadMail` state**

In `HomeView`, find the block of `@State` declarations. After line 64:
```swift
    @State private var hasUnreadNotifications = AppNotification.hasUnread()
```
Add:
```swift
    @State private var hasUnreadMail = false
```

- [ ] **Step 2: Load `hasUnreadMail` on appear**

Find the `.onAppear` block at line 670:
```swift
            .onAppear {
                viewModel.onPinCapReached = { showPinCapSheet = true }
                refreshCoupleSpaceCardMetadata()
            }
```
Replace it with:
```swift
            .onAppear {
                viewModel.onPinCapReached = { showPinCapSheet = true }
                refreshCoupleSpaceCardMetadata()
                hasUnreadMail = DataPersistenceManager.shared.loadHasUnreadMail()
            }
```

- [ ] **Step 3: Insert the widget into the scroll VStack**

In `HomeView`'s scroll `VStack`, find the `CoupleSpaceCard(...)` call (around line 212). It ends with a closing `)` before the comment `// On This Day section`. Insert `HomeGardenPatchView` immediately after that closing `)`:

Before:
```swift
                    CoupleSpaceCard(
                        avatar: coupleSpaceAvatar,
                        partnerAvatar: coupleSpacePartnerAvatar,
                        gardenThumbnail: coupleSpaceGardenThumbnail,
                        bloomCount: coupleSpaceBloomCount,
                        isReadyToInvite: store.isForeverUnlocked,
                        onTap: {
                            dismissMemorySearchKeyboard()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCoupleProfile = true
                            }
                        }
                    )

                    // On This Day section (cached; never computed in body)
```

After:
```swift
                    CoupleSpaceCard(
                        avatar: coupleSpaceAvatar,
                        partnerAvatar: coupleSpacePartnerAvatar,
                        gardenThumbnail: coupleSpaceGardenThumbnail,
                        bloomCount: coupleSpaceBloomCount,
                        isReadyToInvite: store.isForeverUnlocked,
                        onTap: {
                            dismissMemorySearchKeyboard()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCoupleProfile = true
                            }
                        }
                    )

                    HomeGardenPatchView(
                        hasUnreadMail: hasUnreadMail,
                        onPetHouseTap: { showVisitPet = true },
                        onMailboxTap: {}
                    )

                    // On This Day section (cached; never computed in body)
```

- [ ] **Step 4: Build and run in simulator**

In Xcode: `Cmd+R`. Navigate to the Home tab. Confirm:
- The 160pt widget area appears between the "Our Garden" card and the "On This Day" section
- Tapping the pet house (left side) opens the pet room overlay
- Tapping the mailbox (right side) does nothing
- The widget does not appear when memory search is active (it is inside the `else` branch that hides when `isMemorySearchActive`)

With placeholder (missing) assets the images will be blank; that is expected until PNGs are dragged in.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Views/HomeView.swift
git commit -m "feat: wire HomeGardenPatchView into Home feed between CoupleSpaceCard and OnThisDay"
```

---

## Post-Implementation: Add Real Assets

After a designer provides the four PNG files, the developer must:

1. Open `BabyTown/Assets.xcassets` in Xcode
2. Locate each imageset (`home_grass_patch`, `home_pet_house`, `home_mailbox_empty`, `home_mailbox_full`)
3. Drag the corresponding PNG into the **1x** slot of each imageset
4. Build and run in simulator; adjust `frame(height:)` and `.offset(y:)` values in `HomeGardenPatchView` if the visual layout needs tuning against the real artwork
