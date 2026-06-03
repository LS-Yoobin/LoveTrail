# Couples Profile Page (Slice 1) Implementation Plan

> **Status (2026-06-02):** Slice 1 implemented — all 13 tasks complete; `swift test` (20 tests) and `xcodebuild` green. Temp `.loveGarden` route shows `CoupleProfileView`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the temporary garden screen into the Couples Profile Page: a full-screen living-garden background with a floating header (back button + your editable avatar + a partner invite/pending slot), an Important Dates card (read-only foundational dates + full CRUD special dates, chronologically merged), and a Visit Pet button.

**Architecture:** Pure date merge/sort logic goes in the existing `GardenCore` Swift package (unit-tested via `swift test`). New app models (`SpecialDate`, `CoupleProfile`) persist through `DataPersistenceManager` (tolerant JSON + image files), mirroring existing patterns. The garden becomes a reusable ambient `GardenBackgroundView`; `CoupleProfileView` is a `ZStack` of that background plus a floating header and a `ScrollView` of translucent cards (only the cards scroll, avoiding SpriteKit-inside-ScrollView perf issues). The temporary `ContentView` route is repointed from `LoveGardenView` to `CoupleProfileView`.

**Tech Stack:** Swift, SwiftUI (`PhotosPicker`, `ShareLink`), SpriteKit (`SpriteView`), Swift Package Manager (`GardenCore`), JSON `Codable` + image-file persistence.

**Context for the engineer:**
- iOS app, single Xcode target `BabyTown`, scheme `BabyTown`. App source under `BabyTown/` is auto-compiled (file-system synced group) — creating a `.swift` file there needs no `pbxproj` edit.
- The `GardenCore` local package is already linked. Add new pure types to it; tests run via `swift test`.
- **No XCTest target in the app** — pure logic is tested in `GardenCore`; UI is verified by `xcodebuild build` + the simulator. Trust `xcodebuild`/`swift test` over the editor's SourceKit diagnostics (they show false "No such module" for package imports).
- **Build command:** `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Package test command:** `swift test --package-path GardenCore`
- Existing APIs this plan calls (do not change them):
  - `DataPersistenceManager.shared` (`@MainActor` singleton): `loadUserNickname() -> String?`; `loadFoundingPhotoDate(promptText: String) -> Date?`; `loadPinnedFirstMet() -> UIImage?`; `loadPinnedOfficial() -> UIImage?`; `loadMoments()`, `loadUserLetters()`, `loadGardenState()`. Founding prompt strings are exactly `"When we first met"` and `"When we became official"`.
  - `loadPetState().adoptedSkin -> CatSkin?`; `CatSkin.profileSitAsset` (asset names `profile_calico_sit` / `profile_cowcat_sit`, which exist in the catalog).
  - `PartnerInvite.current()` → has `.link: String` and `.messageText: String`.
  - Visit Pet overlay pattern (from `HomeView`): `NavigationStack { AdoptAPetRootView(onDismiss: { ... }) }`. `AdoptAPetRootView` takes a trailing `onDismiss: () -> Void`.
  - Garden building (from `LoveGardenView`): `GardenActMapper.acts(moments:letters:)` → `GardenComposer().compose(acts:)` → `LoveGardenScene(size:elements:season:)`; season via `loadGardenState().season(now:)`.

---

## File Structure

**GardenCore package (pure, tested):**
- Create: `GardenCore/Sources/GardenCore/ImportantDates.swift` — `SpecialDateInput`, `ImportantDateItem`, `ImportantDatesComposer`.
- Create: `GardenCore/Tests/GardenCoreTests/ImportantDatesComposerTests.swift`.

**App models (synced group):**
- Create: `BabyTown/Models/SpecialDate.swift` — one user-authored special date.
- Create: `BabyTown/Models/CoupleProfile.swift` — local user's profile (name + special dates).

**App persistence:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift` — couple-profile JSON, user-avatar image, special-date images.

**App views (synced group, all new under `BabyTown/Views/CoupleProfile/`):**
- Create: `BabyTown/Views/CoupleProfile/GardenBackgroundView.swift` — ambient garden backdrop (reusable).
- Create: `BabyTown/Views/CoupleProfile/ProfileEditorSheet.swift` — edit your name + photo.
- Create: `BabyTown/Views/CoupleProfile/ProfileAvatarSlot.swift` — one circular avatar (you / invite variants).
- Create: `BabyTown/Views/CoupleProfile/CoupleHeaderView.swift` — back button + the two avatar slots.
- Create: `BabyTown/Views/CoupleProfile/SpecialDateEditorSheet.swift` — add/edit a special date.
- Create: `BabyTown/Views/CoupleProfile/ImportantDatesCard.swift` — merged foundational + special list.
- Create: `BabyTown/Views/CoupleProfile/VisitPetCard.swift` — cat-portrait button.
- Create: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift` — the assembled page.

**App routing:**
- Modify: `BabyTown/ContentView.swift` — repoint the temporary `.loveGarden` route to `CoupleProfileView`.

---

## Task 1: Pure date merge/sort logic (GardenCore)

**Files:**
- Create: `GardenCore/Sources/GardenCore/ImportantDates.swift`
- Create: `GardenCore/Tests/GardenCoreTests/ImportantDatesComposerTests.swift`

- [ ] **Step 1: Write the failing tests**

`GardenCore/Tests/GardenCoreTests/ImportantDatesComposerTests.swift`:
```swift
import XCTest
@testable import GardenCore

final class ImportantDatesComposerTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .init(identifier: .gregorian),
                       year: y, month: m, day: d).date!
    }

    func testFoundationalAndSpecialAreMergedAndSortedAscending() {
        let special = [
            SpecialDateInput(id: UUID(), title: "Anniversary", date: date(2025, 6, 1)),
            SpecialDateInput(id: UUID(), title: "Trip", date: date(2024, 1, 1)),
        ]
        let items = ImportantDatesComposer().compose(
            firstMet: date(2024, 2, 14),
            official: date(2024, 6, 1),
            special: special
        )
        XCTAssertEqual(items.map(\.title),
                       ["Trip", "When we first met", "When we became official", "Anniversary"])
    }

    func testMissingFoundationalDatesAreOmitted() {
        let items = ImportantDatesComposer().compose(
            firstMet: nil, official: date(2024, 6, 1), special: [])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].kind, .official)
    }

    func testEmptyInputsProduceEmptyList() {
        XCTAssertTrue(ImportantDatesComposer().compose(
            firstMet: nil, official: nil, special: []).isEmpty)
    }

    func testFoundationalItemsCarryFixedIdsAndKinds() {
        let items = ImportantDatesComposer().compose(
            firstMet: date(2024, 2, 14), official: date(2024, 6, 1), special: [])
        XCTAssertEqual(items.first { $0.kind == .firstMet }?.id, "firstMet")
        XCTAssertEqual(items.first { $0.kind == .official }?.id, "official")
    }

    func testSpecialItemKeepsItsUUIDStringAsId() {
        let uid = UUID()
        let items = ImportantDatesComposer().compose(
            firstMet: nil, official: nil,
            special: [SpecialDateInput(id: uid, title: "X", date: date(2025, 1, 1))])
        XCTAssertEqual(items[0].id, uid.uuidString)
        XCTAssertEqual(items[0].kind, .special)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path GardenCore`
Expected: FAIL — `SpecialDateInput` / `ImportantDateItem` / `ImportantDatesComposer` not found.

- [ ] **Step 3: Implement**

`GardenCore/Sources/GardenCore/ImportantDates.swift`:
```swift
import Foundation

/// A UI-free description of one user-authored special date. The app maps its
/// `SpecialDate` model into this so GardenCore stays Foundation-only.
public struct SpecialDateInput: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let date: Date
    public init(id: UUID, title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }
}

/// One row in the merged Important Dates list, ready to render.
public struct ImportantDateItem: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case firstMet   // foundational, read-only on the profile page
        case official   // foundational, read-only on the profile page
        case special    // user-authored, editable
    }
    /// Stable id: "firstMet"/"official" for the two foundational rows, or the
    /// special date's UUID string.
    public let id: String
    public let title: String
    public let date: Date
    public let kind: Kind

    public init(id: String, title: String, date: Date, kind: Kind) {
        self.id = id
        self.title = title
        self.date = date
        self.kind = kind
    }
}

/// Merges the two foundational dates (when present) with the user's special
/// dates into one chronologically ascending list. Pure and deterministic.
public struct ImportantDatesComposer {
    public init() {}

    public func compose(firstMet: Date?,
                        official: Date?,
                        special: [SpecialDateInput]) -> [ImportantDateItem] {
        var items: [ImportantDateItem] = []
        if let firstMet {
            items.append(ImportantDateItem(id: "firstMet",
                                           title: "When we first met",
                                           date: firstMet, kind: .firstMet))
        }
        if let official {
            items.append(ImportantDateItem(id: "official",
                                           title: "When we became official",
                                           date: official, kind: .official))
        }
        for s in special {
            items.append(ImportantDateItem(id: s.id.uuidString,
                                           title: s.title, date: s.date, kind: .special))
        }
        return items.sorted { $0.date < $1.date }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path GardenCore`
Expected: PASS — all ImportantDatesComposer tests plus the existing 15 tests green.

- [ ] **Step 5: Commit**

```bash
git add GardenCore
git commit -m "feat(couple): ImportantDatesComposer merge+sort in GardenCore"
```

---

## Task 2: `SpecialDate` model (app)

**Files:**
- Create: `BabyTown/Models/SpecialDate.swift`

- [ ] **Step 1: Implement the model**

`BabyTown/Models/SpecialDate.swift`:
```swift
import Foundation

/// One user-authored special date on the Couples Profile Page. The optional
/// photo is stored as a separate image file keyed by `id` (see
/// DataPersistenceManager), not embedded here.
struct SpecialDate: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var date: Date

    init(id: UUID = UUID(), title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/SpecialDate.swift
git commit -m "feat(couple): SpecialDate model"
```

---

## Task 3: `CoupleProfile` model (app)

**Files:**
- Create: `BabyTown/Models/CoupleProfile.swift`

- [ ] **Step 1: Implement the model (tolerant decode)**

`BabyTown/Models/CoupleProfile.swift`:
```swift
import Foundation

/// The local user's couple-profile state. Only the user's own identity and their
/// special dates are stored; the partner's identity is backend-authored later and
/// is intentionally absent. Tolerant decode (default-on-missing) mirrors PetState
/// / GardenState so the format can grow safely. The user's avatar image is stored
/// as a separate file (see DataPersistenceManager), not embedded here.
struct CoupleProfile: Codable, Equatable {
    var displayName: String?
    var specialDates: [SpecialDate]

    init(displayName: String? = nil, specialDates: [SpecialDate] = []) {
        self.displayName = displayName
        self.specialDates = specialDates
    }

    enum CodingKeys: String, CodingKey {
        case displayName, specialDates
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        specialDates = try c.decodeIfPresent([SpecialDate].self, forKey: .specialDates) ?? []
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/CoupleProfile.swift
git commit -m "feat(couple): CoupleProfile model with tolerant decode"
```

---

## Task 4: Persistence in `DataPersistenceManager`

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

Add couple-profile JSON, the user-avatar image, and special-date images, following the existing file/JSON patterns. Images live in the existing `pinnedPhotosDirectory`.

- [ ] **Step 1: Add file URLs**

In `DataPersistenceManager.swift`, next to the other `…FileURL` computed properties (e.g. after `gardenStateFileURL`), add:
```swift
    private var coupleProfileFileURL: URL {
        documentsDirectory.appendingPathComponent("couple_profile.json")
    }

    private var userAvatarURL: URL {
        pinnedPhotosDirectory.appendingPathComponent("couple_user_avatar.jpg")
    }

    private func specialDatePhotoURL(id: UUID) -> URL {
        pinnedPhotosDirectory.appendingPathComponent("special_date_\(id.uuidString).jpg")
    }
```

- [ ] **Step 2: Add couple-profile load/save**

Add near the garden-state methods:
```swift
    func saveCoupleProfile(_ profile: CoupleProfile) {
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: coupleProfileFileURL)
    }

    /// Tolerant load — returns an empty profile when nothing is stored.
    func loadCoupleProfile() -> CoupleProfile {
        guard fileManager.fileExists(atPath: coupleProfileFileURL.path),
              let data = try? Data(contentsOf: coupleProfileFileURL),
              let profile = try? decoder.decode(CoupleProfile.self, from: data) else {
            return CoupleProfile()
        }
        return profile
    }
```

- [ ] **Step 3: Add user-avatar image load/save**

```swift
    func saveUserAvatar(_ image: UIImage?) {
        guard let image, let jpeg = image.jpegData(compressionQuality: 0.85) else {
            try? fileManager.removeItem(at: userAvatarURL)
            return
        }
        try? jpeg.write(to: userAvatarURL)
    }

    func loadUserAvatar() -> UIImage? {
        guard fileManager.fileExists(atPath: userAvatarURL.path),
              let data = try? Data(contentsOf: userAvatarURL) else { return nil }
        return UIImage(data: data)
    }
```

- [ ] **Step 4: Add special-date image load/save/delete**

```swift
    func saveSpecialDatePhoto(_ image: UIImage?, id: UUID) {
        let url = specialDatePhotoURL(id: id)
        guard let image, let jpeg = image.jpegData(compressionQuality: 0.85) else {
            try? fileManager.removeItem(at: url)
            return
        }
        try? jpeg.write(to: url)
    }

    func loadSpecialDatePhoto(id: UUID) -> UIImage? {
        let url = specialDatePhotoURL(id: id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteSpecialDatePhoto(id: UUID) {
        try? fileManager.removeItem(at: specialDatePhotoURL(id: id))
    }
```

- [ ] **Step 5: Wipe couple data on reset**

Find `clearAllData()` and add, next to the other `removeItem` calls:
```swift
        try? fileManager.removeItem(at: coupleProfileFileURL)
        try? fileManager.removeItem(at: userAvatarURL)
```
(Special-date photos are keyed by UUID; they live in `pinnedPhotosDirectory` and are acceptable to leave for Slice 1 — they are orphaned without the profile that references them. Do not over-engineer a sweep here.)

- [ ] **Step 6: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat(couple): persist CoupleProfile, user avatar, special-date photos"
```

---

## Task 5: `GardenBackgroundView` (ambient backdrop)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/GardenBackgroundView.swift`

A reusable, ambient version of the garden (no revival banner, no memory sheet) for use as the profile-page background. It reuses the same compose→scene pipeline as `LoveGardenView` but does not register/persist a visit.

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/GardenBackgroundView.swift`:
```swift
import SwiftUI
import SpriteKit
import GardenCore

/// The living garden rendered purely as an ambient backdrop (no banners, no
/// memory cards). Built once on appear. Used behind the Couples Profile Page.
struct GardenBackgroundView: View {
    @State private var scene: LoveGardenScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Color(red: 0.78, green: 0.90, blue: 0.98).ignoresSafeArea()
                }
            }
            .onAppear { build(size: geo.size) }
        }
    }

    private func build(size: CGSize) {
        guard scene == nil else { return }
        let dpm = DataPersistenceManager.shared
        let acts = GardenActMapper.acts(moments: dpm.loadMoments(),
                                        letters: dpm.loadUserLetters())
        let elements = GardenComposer().compose(acts: acts)
        let season = dpm.loadGardenState().season(now: Date())
        scene = LoveGardenScene(size: size, elements: elements, season: season)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/GardenBackgroundView.swift
git commit -m "feat(couple): ambient GardenBackgroundView"
```

---

## Task 6: `ProfileEditorSheet` (edit your name + photo)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/ProfileEditorSheet.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/ProfileEditorSheet.swift`:
```swift
import SwiftUI
import PhotosUI

/// Sheet for editing YOUR own profile: a circular photo + a display name.
/// Calls `onSave` with the chosen image (nil = keep/clear) and name.
struct ProfileEditorSheet: View {
    let initialName: String
    let initialImage: UIImage?
    let onSave: (UIImage?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    init(initialName: String, initialImage: UIImage?,
         onSave: @escaping (UIImage?, String) -> Void) {
        self.initialName = initialName
        self.initialImage = initialImage
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _image = State(initialValue: initialImage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Circle().fill(.quaternary)
                            Image(systemName: "camera.fill").font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                }

                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(image, name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        image = ui
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/ProfileEditorSheet.swift
git commit -m "feat(couple): ProfileEditorSheet for editing your name + photo"
```

---

## Task 7: `ProfileAvatarSlot` (circular avatar, two variants)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/ProfileAvatarSlot.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/ProfileAvatarSlot.swift`:
```swift
import SwiftUI

/// One circular avatar in the couple header. Two variants:
/// - `.you`: shows your photo (or an "add" placeholder) + name; tappable to edit.
/// - `.invite`: a locked partner slot inviting them to create their own profile.
struct ProfileAvatarSlot: View {
    enum Variant {
        case you(image: UIImage?, name: String, onTap: () -> Void)
        case invite(onTap: () -> Void)
    }

    let variant: Variant
    private let size: CGFloat = 84

    var body: some View {
        switch variant {
        case let .you(image, name, onTap):
            Button(action: onTap) {
                VStack(spacing: 6) {
                    avatarCircle(image: image, placeholderSystemName: "person.crop.circle.badge.plus")
                    Text(name.isEmpty ? "You" : name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

        case let .invite(onTap):
            Button(action: onTap) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundStyle(.secondary)
                        Image(systemName: "heart.circle")
                            .font(.title).foregroundStyle(.secondary)
                    }
                    .frame(width: size, height: size)
                    Text("Invite partner")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func avatarCircle(image: UIImage?, placeholderSystemName: String) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(.quaternary)
                Image(systemName: placeholderSystemName)
                    .font(.title).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(radius: 4, y: 2)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/ProfileAvatarSlot.swift
git commit -m "feat(couple): ProfileAvatarSlot (you / invite variants)"
```

---

## Task 8: `CoupleHeaderView` (back + two slots)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/CoupleHeaderView.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/CoupleHeaderView.swift`:
```swift
import SwiftUI

/// The floating header over the garden: a back button, your editable avatar, and
/// the partner invite slot. Presents the profile editor (you) and a share sheet
/// (invite) on tap.
struct CoupleHeaderView: View {
    let userName: String
    let userImage: UIImage?
    let onBack: () -> Void
    let onEditYou: () -> Void

    private var invite: PartnerInvite { PartnerInvite.current() }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 40) {
                ProfileAvatarSlot(variant: .you(image: userImage, name: userName, onTap: onEditYou))
                ShareLink(item: URL(string: invite.link) ?? URL(string: "https://babytown.app")!,
                          message: Text(invite.messageText)) {
                    ProfileAvatarSlotInviteLabel()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// The invite slot rendered as a ShareLink label (ShareLink needs a plain label,
/// so we reuse the avatar-slot invite styling here).
private struct ProfileAvatarSlotInviteLabel: View {
    var body: some View {
        ProfileAvatarSlot(variant: .invite(onTap: {}))
            .allowsHitTesting(false)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/CoupleHeaderView.swift
git commit -m "feat(couple): CoupleHeaderView (back + avatar slots + invite share)"
```

---

## Task 9: `SpecialDateEditorSheet` (add/edit special date)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/SpecialDateEditorSheet.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/SpecialDateEditorSheet.swift`:
```swift
import SwiftUI
import PhotosUI

/// Add or edit a special date: title, date, optional photo. `onSave` receives the
/// edited `SpecialDate` and the chosen image (nil = no change requested by the
/// caller's convention: see CoupleProfileView). `onDelete` is nil when adding.
struct SpecialDateEditorSheet: View {
    let editing: SpecialDate?
    let initialImage: UIImage?
    let onSave: (SpecialDate, UIImage?) -> Void
    let onDelete: ((SpecialDate) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    init(editing: SpecialDate?,
         initialImage: UIImage?,
         onSave: @escaping (SpecialDate, UIImage?) -> Void,
         onDelete: ((SpecialDate) -> Void)?) {
        self.editing = editing
        self.initialImage = initialImage
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: editing?.title ?? "")
        _date = State(initialValue: editing?.date ?? Date())
        _image = State(initialValue: initialImage)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Anniversary)", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Photo (optional)") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(height: 160).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Label("Choose a photo", systemImage: "photo")
                        }
                    }
                }
                if let editing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete(editing)
                            dismiss()
                        } label: {
                            Label("Delete date", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Special Date" : "Edit Special Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = SpecialDate(
                            id: editing?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date)
                        onSave(result, image)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        image = ui
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/SpecialDateEditorSheet.swift
git commit -m "feat(couple): SpecialDateEditorSheet (add/edit/delete special date)"
```

---

## Task 10: `ImportantDatesCard` (merged list)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/ImportantDatesCard.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/ImportantDatesCard.swift`:
```swift
import SwiftUI
import GardenCore

/// The Important Dates glass card: foundational dates (read-only) + special dates
/// (tap to edit), merged chronologically by ImportantDatesComposer. Photo loading
/// is delegated to closures so this view stays presentation-only.
struct ImportantDatesCard: View {
    let items: [ImportantDateItem]
    let photoForItem: (ImportantDateItem) -> UIImage?
    let onTapSpecial: (String) -> Void   // special date's UUID string
    let onAdd: () -> Void

    private static let dateFormat: Date.FormatStyle =
        .dateTime.month(.abbreviated).day().year()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Important Dates")
                .font(.headline)

            ForEach(items) { item in
                row(item)
                if item.id != items.last?.id {
                    Divider()
                }
            }

            Button(action: onAdd) {
                Label("Add special date", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func row(_ item: ImportantDateItem) -> some View {
        let content = HStack(spacing: 12) {
            thumbnail(photoForItem(item))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold))
                Text(item.date, format: Self.dateFormat)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if item.kind == .special {
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }

        if item.kind == .special {
            Button { onTapSpecial(item.id) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func thumbnail(_ image: UIImage?) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                Image(systemName: "calendar").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/ImportantDatesCard.swift
git commit -m "feat(couple): ImportantDatesCard merged foundational + special list"
```

---

## Task 11: `VisitPetCard`

**Files:**
- Create: `BabyTown/Views/CoupleProfile/VisitPetCard.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/VisitPetCard.swift`:
```swift
import SwiftUI

/// A glass card button that opens the Visit Pet flow, illustrated with the
/// currently adopted cat's portrait (falls back to a paw icon if none adopted).
struct VisitPetCard: View {
    let skin: CatSkin?
    let onVisit: () -> Void

    var body: some View {
        Button(action: onVisit) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(skin?.placeholderColor.opacity(0.25) ?? Color.gray.opacity(0.2))
                    if let skin {
                        Image(skin.profileSitAsset).resizable().scaledToFit().padding(8)
                    } else {
                        Image(systemName: "pawprint.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Visit Pet").font(.subheadline.weight(.semibold))
                    Text(skin?.petName ?? "Your cat is waiting")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
```

(Note: `CatSkin.petName`, `.profileSitAsset`, and `.placeholderColor` all already exist on the enum.)

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/VisitPetCard.swift
git commit -m "feat(couple): VisitPetCard"
```

---

## Task 12: `CoupleProfileView` (assemble the page)

**Files:**
- Create: `BabyTown/Views/CoupleProfile/CoupleProfileView.swift`

- [ ] **Step 1: Implement**

`BabyTown/Views/CoupleProfile/CoupleProfileView.swift`:
```swift
import SwiftUI
import GardenCore

/// The Couples Profile Page: a full-screen living-garden background with a
/// floating header and scrolling glass cards (Important Dates, Visit Pet).
struct CoupleProfileView: View {
    var onBack: () -> Void = {}

    @State private var profile = CoupleProfile()
    @State private var userAvatar: UIImage?
    @State private var showEditProfile = false
    @State private var showVisitPet = false

    // Special-date editor state
    @State private var showDateEditor = false
    @State private var editingDate: SpecialDate?
    @State private var editingDateImage: UIImage?

    private var dpm: DataPersistenceManager { .shared }

    private var dateItems: [ImportantDateItem] {
        ImportantDatesComposer().compose(
            firstMet: dpm.loadFoundingPhotoDate(promptText: "When we first met"),
            official: dpm.loadFoundingPhotoDate(promptText: "When we became official"),
            special: profile.specialDates.map {
                SpecialDateInput(id: $0.id, title: $0.title, date: $0.date)
            })
    }

    private var displayName: String {
        profile.displayName ?? dpm.loadUserNickname() ?? "You"
    }

    var body: some View {
        ZStack {
            GardenBackgroundView()

            VStack(spacing: 0) {
                CoupleHeaderView(
                    userName: displayName,
                    userImage: userAvatar,
                    onBack: onBack,
                    onEditYou: { showEditProfile = true }
                )
                .padding(.top, 4)

                ScrollView {
                    VStack(spacing: 16) {
                        ImportantDatesCard(
                            items: dateItems,
                            photoForItem: photo(for:),
                            onTapSpecial: beginEditSpecial(id:),
                            onAdd: beginAddSpecial
                        )
                        VisitPetCard(
                            skin: dpm.loadPetState().adoptedSkin,
                            onVisit: { showVisitPet = true }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showEditProfile) {
            ProfileEditorSheet(initialName: displayName, initialImage: userAvatar) { image, name in
                dpm.saveUserAvatar(image)
                profile.displayName = name
                dpm.saveCoupleProfile(profile)
                userAvatar = image
            }
        }
        .sheet(isPresented: $showDateEditor) {
            SpecialDateEditorSheet(
                editing: editingDate,
                initialImage: editingDateImage,
                onSave: saveSpecial(_:image:),
                onDelete: editingDate == nil ? nil : deleteSpecial(_:)
            )
        }
        .fullScreenCover(isPresented: $showVisitPet) {
            NavigationStack {
                AdoptAPetRootView(onDismiss: { showVisitPet = false })
            }
        }
    }

    // MARK: Data

    private func load() {
        profile = dpm.loadCoupleProfile()
        userAvatar = dpm.loadUserAvatar()
    }

    private func photo(for item: ImportantDateItem) -> UIImage? {
        switch item.kind {
        case .firstMet: return dpm.loadPinnedFirstMet()
        case .official: return dpm.loadPinnedOfficial()
        case .special:
            guard let id = UUID(uuidString: item.id) else { return nil }
            return dpm.loadSpecialDatePhoto(id: id)
        }
    }

    private func beginAddSpecial() {
        editingDate = nil
        editingDateImage = nil
        showDateEditor = true
    }

    private func beginEditSpecial(id: String) {
        guard let uid = UUID(uuidString: id),
              let match = profile.specialDates.first(where: { $0.id == uid }) else { return }
        editingDate = match
        editingDateImage = dpm.loadSpecialDatePhoto(id: uid)
        showDateEditor = true
    }

    private func saveSpecial(_ date: SpecialDate, image: UIImage?) {
        if let idx = profile.specialDates.firstIndex(where: { $0.id == date.id }) {
            profile.specialDates[idx] = date
        } else {
            profile.specialDates.append(date)
        }
        dpm.saveSpecialDatePhoto(image, id: date.id)
        dpm.saveCoupleProfile(profile)
    }

    private func deleteSpecial(_ date: SpecialDate) {
        profile.specialDates.removeAll { $0.id == date.id }
        dpm.deleteSpecialDatePhoto(id: date.id)
        dpm.saveCoupleProfile(profile)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/CoupleProfile/CoupleProfileView.swift
git commit -m "feat(couple): assemble CoupleProfileView"
```

---

## Task 13: Repoint route + simulator verification

**Files:**
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Repoint the temporary route to the new page**

In `BabyTown/ContentView.swift`, find:
```swift
            case .loveGarden:
                LoveGardenView()
                    .transition(.opacity)
```
and replace it with:
```swift
            case .loveGarden:
                CoupleProfileView(onBack: {
                    withAnimation(.easeInOut(duration: 0.4)) { screen = .home }
                })
                .transition(.opacity)
```
(This keeps the existing TEMP `.loveGarden` route — now showing the Couples Profile Page — with the back button returning Home. The `.loveGarden` enum case and the temp `_targetScreen = .loveGarden` override from the Love Garden slice remain until the cat-room door slice replaces them.)

- [ ] **Step 2: Build**

Run: `xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Install, launch, and screenshot-verify**

Build for and boot the iPhone 17 Pro simulator, then:
```
xcrun simctl install booted "$(xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{print $2}' | head -1)/BabyTown.app"
xcrun simctl launch booted LS.BabyTown
```
Wait ~4s for the launch screen to transition, then:
```
xcrun simctl io booted screenshot /tmp/couple_profile.png
```
Open `/tmp/couple_profile.png` and confirm: the garden renders as the background; the floating header shows the back chevron, your avatar slot (placeholder or photo), and the partner "Invite partner" slot; the Important Dates glass card lists foundational dates (if any exist in this sim's data) plus an "Add special date" button; the Visit Pet card shows the cat portrait. Tapping your avatar opens the profile editor; "Add special date" opens the editor; Visit Pet opens the pet flow; back returns Home.

If the sim has no foundational dates/data, the dates card shows only the "Add special date" button — that is correct. (To see a fuller page, use a simulator that has existing app data, as in the Love Garden slice verification.)

- [ ] **Step 4: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "chore(couple): route temp entry to CoupleProfileView (Slice 1)"
```

---

## Self-Review (completed during planning)

**Spec coverage (couples-profile spec Slice 1, §5–§9):**
- Page = garden full-screen background + floating UI (§5.1) → Tasks 5, 12. ✓
- Back button → Home (§5.2) → Task 13. ✓
- Your editable avatar + name, pre-filled from nickname (§5.2) → Tasks 6, 7, 8, 12 (`displayName` falls back to `loadUserNickname()`). ✓
- Partner invite/pending slot with share CTA (§5.2) → Tasks 7, 8 (ShareLink with `PartnerInvite`). ✓
- No Customize button in Slice 1 (§4) → not present. ✓
- Foundational dates read-only with photo; special dates full CRUD; merged & sorted (§5.3) → Tasks 1, 9, 10, 12. ✓
- Visit Pet card with correct cat skin → existing flow (§5.4) → Tasks 11, 12. ✓
- Data model + tolerant persistence (§6) → Tasks 2, 3, 4. ✓
- Pure tested merge/sort logic (§7) → Task 1. ✓
- Focused subviews (§8) → Tasks 5–12 each one component. ✓
- Verify via temp route in simulator (§9) → Task 13. ✓
- Deferred items (stickers, customize, polish, real partner, door) → not present. ✓

**Placeholder scan:** No TBD/TODO-as-work; every code step has complete code; commands have expected output. ✓

**Type consistency:** `ImportantDatesComposer().compose(firstMet:official:special:)`, `SpecialDateInput(id:title:date:)`, `ImportantDateItem(id:title:date:kind:)` + `.kind` (`.firstMet/.official/.special`), `SpecialDate(id:title:date:)`, `CoupleProfile(displayName:specialDates:)`, DPM `saveCoupleProfile/loadCoupleProfile/saveUserAvatar/loadUserAvatar/saveSpecialDatePhoto/loadSpecialDatePhoto/deleteSpecialDatePhoto`, view inits (`ProfileEditorSheet(initialName:initialImage:onSave:)`, `ProfileAvatarSlot(variant:)`, `CoupleHeaderView(userName:userImage:onBack:onEditYou:)`, `SpecialDateEditorSheet(editing:initialImage:onSave:onDelete:)`, `ImportantDatesCard(items:photoForItem:onTapSpecial:onAdd:)`, `VisitPetCard(skin:onVisit:)`, `CoupleProfileView(onBack:)`) — names match across tasks. ✓
