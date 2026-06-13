# Breakup & Archive System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full breakup/archive lifecycle — BreakupInitiationView → ScrapbookHomeView (read-only archive with retention countdown, reconnect banner, frozen garden/pet, export) → StepOutConfirmationView → ReconnectInviteView — all routing through ContentView based on `RelationshipStage.archivedCouple`.

**Architecture:** All "server" operations (media upload, ZIP export, push notifications) are simulated locally using `ArchiveService`, which saves an `ArchiveBundle` snapshot to disk and schedules local `UNUserNotificationCenter` notifications for retention warnings. No real network calls are made; the backend contract is satisfied by the local stub so the UI is fully functional and ready for a real backend layer later. Tasks are ordered so each builds successfully before the next begins.

**Tech Stack:** SwiftUI, `UNUserNotificationCenter`, `UIActivityViewController`, `@MainActor ObservableObject` pattern, `DataPersistenceManager` JSON file persistence, `BabyTownTheme` for all colors.

**Build command (every task):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

## Existing code you must understand before starting

- **`BabyTown/Models/CoupleProfile.swift`** — tolerant Codable pattern with `decodeIfPresent`; `RelationshipStage` is already a stored property. Add new fields following the same pattern.
- **`BabyTown/Services/DataPersistenceManager.swift`** — `@MainActor` singleton; load/save pattern for every model file; `clearAllData()` must be updated with new file URLs.
- **`BabyTown/ContentView.swift`** — `Screen` enum switches in body; `init()` does stage-aware routing (prelude routing established there); add `archivedCouple` case following the same pattern.
- **`BabyTown/Theme/BabyTownTheme.swift`** — use `BabyTownTheme.accent`, `.accentDeep`, `.accentGradient`, `.accentSoft`, `.cardBackground`, `.textPrimary`, `.textSecondary`, `.background` for all colors.
- **`BabyTown/Views/Prelude/ArchiveFlowView.swift`** and **`ReconnectFlowView.swift`** — these exist as Prelude-stage stubs. Do NOT modify them. New views go in `BabyTown/Views/Breakup/`.
- **`RelationshipStage`** — already defined with `.prelude`, `.officialCouple`, `.archivedCouple`. No changes needed.

---

## File Map

### New files
| File | Purpose |
|---|---|
| `BabyTown/Models/ArchiveBundle.swift` | Local snapshot of all shared state captured at breakup time |
| `BabyTown/Models/BreakupReconnectInvite.swift` | Reconnect invite model |
| `BabyTown/Services/ArchiveService.swift` | `@MainActor` singleton: breakup simulation, extend, step-out, reconnect, local notification scheduling |
| `BabyTown/Views/Breakup/ScrapbookGardenView.swift` | Frozen garden display (read-only sticker list) |
| `BabyTown/Views/Breakup/ScrapbookPetView.swift` | Frozen pet state display |
| `BabyTown/Views/Breakup/BreakupInitiationView.swift` | "End Relationship" confirm + simulated upload progress screen |
| `BabyTown/Views/Breakup/StepOutConfirmationView.swift` | "Start Fresh" destructive confirm |
| `BabyTown/Views/Breakup/ExportProgressView.swift` | Simulated export progress + share sheet |
| `BabyTown/Views/Breakup/ReconnectInviteView.swift` | Send reconnect invite + receive/accept modal |
| `BabyTown/Views/Breakup/ScrapbookHomeView.swift` | Full archive home: retention bar, reconnect banner, read-only Moments feed, TabView for garden/pet |

### Modified files
| File | Change |
|---|---|
| `BabyTown/Models/CoupleProfile.swift` | Add `breakupDate`, `archiveExpiryDate`, `hasSteppedOut` with tolerant decode |
| `BabyTown/Services/DataPersistenceManager.swift` | Add archive bundle + reconnect invite persistence; update `clearAllData()` |
| `BabyTown/ContentView.swift` | Add `case archivedCouple` to `Screen` enum; route to `ScrapbookHomeView` |
| `BabyTown/AppDelegate.swift` | Handle archive notification tap identifiers |

---

## Task 1: CoupleProfile new fields

**Files:**
- Modify: `BabyTown/Models/CoupleProfile.swift`

- [ ] **Step 1: Add three new stored properties**

In `BabyTown/Models/CoupleProfile.swift`, after `var inviteSent: Bool` (line 25), add:

```swift
    var breakupDate: Date?
    var archiveExpiryDate: Date?
    var hasSteppedOut: Bool
```

- [ ] **Step 2: Add to init parameters with defaults**

In `init(...)`, after `inviteSent: Bool = false`, add:

```swift
        breakupDate: Date? = nil,
        archiveExpiryDate: Date? = nil,
        hasSteppedOut: Bool = false
```

- [ ] **Step 3: Assign in init body**

In the init body, after `self.inviteSent = inviteSent`, add:

```swift
        self.breakupDate = breakupDate
        self.archiveExpiryDate = archiveExpiryDate
        self.hasSteppedOut = hasSteppedOut
```

- [ ] **Step 4: Add to CodingKeys**

In `enum CodingKeys`, after `case relationshipStage, inviteSent`, add:

```swift
        case breakupDate, archiveExpiryDate, hasSteppedOut
```

- [ ] **Step 5: Add to tolerant decode**

In `init(from decoder:)`, after the `inviteSent` decode line, add:

```swift
        breakupDate = try c.decodeIfPresent(Date.self, forKey: .breakupDate)
        archiveExpiryDate = try c.decodeIfPresent(Date.self, forKey: .archiveExpiryDate)
        hasSteppedOut = try c.decodeIfPresent(Bool.self, forKey: .hasSteppedOut) ?? false
```

- [ ] **Step 6: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Models/CoupleProfile.swift && git commit -m "feat: add breakupDate, archiveExpiryDate, hasSteppedOut to CoupleProfile"
```

---

## Task 2: ArchiveBundle + BreakupReconnectInvite models

**Files:**
- Create: `BabyTown/Models/ArchiveBundle.swift`
- Create: `BabyTown/Models/BreakupReconnectInvite.swift`

- [ ] **Step 1: Create ArchiveBundle**

Create `BabyTown/Models/ArchiveBundle.swift`:

```swift
import Foundation

struct ArchiveBundle: Codable {
    let coupleId: String
    let breakupDate: Date
    var expiryDate: Date
    var userAHasSteppedOut: Bool
    var userBHasSteppedOut: Bool
    var moments: [Moment]
    var coupleProfile: CoupleProfile
    var petState: PetState
    var preludeChapter: PreludeChapter?
    var preludeCaptures: [PreludeCapture]

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0)
    }

    var bothSteppedOut: Bool {
        userAHasSteppedOut && userBHasSteppedOut
    }
}
```

- [ ] **Step 2: Create BreakupReconnectInvite**

Create `BabyTown/Models/BreakupReconnectInvite.swift`:

```swift
import Foundation

struct BreakupReconnectInvite: Codable {
    let id: UUID
    let senderUserId: String
    let recipientUserId: String
    let sentAt: Date
    var status: InviteStatus

    enum InviteStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Models/ArchiveBundle.swift BabyTown/Models/BreakupReconnectInvite.swift && git commit -m "feat: add ArchiveBundle and BreakupReconnectInvite models"
```

---

## Task 3: DataPersistenceManager archive persistence

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

- [ ] **Step 1: Add file URL properties**

In `DataPersistenceManager.swift`, after the `preludeVoiceMemosDirectory` URL property, add:

```swift
    private var archiveBundleFileURL: URL {
        documentsDirectory.appendingPathComponent("archive_bundle.json")
    }

    private var reconnectInviteFileURL: URL {
        documentsDirectory.appendingPathComponent("reconnect_invite.json")
    }
```

- [ ] **Step 2: Add six new methods in an Archive section**

After the `deletePreludeVoiceMemo` method (end of the `// MARK: - Prelude` section), add:

```swift
    // MARK: - Archive

    func saveArchiveBundle(_ bundle: ArchiveBundle) {
        guard let data = try? encoder.encode(bundle) else { return }
        try? data.write(to: archiveBundleFileURL)
    }

    func loadArchiveBundle() -> ArchiveBundle? {
        guard fileManager.fileExists(atPath: archiveBundleFileURL.path),
              let data = try? Data(contentsOf: archiveBundleFileURL),
              let bundle = try? decoder.decode(ArchiveBundle.self, from: data) else {
            return nil
        }
        return bundle
    }

    func clearArchiveBundle() {
        try? fileManager.removeItem(at: archiveBundleFileURL)
    }

    func saveReconnectInvite(_ invite: BreakupReconnectInvite) {
        guard let data = try? encoder.encode(invite) else { return }
        try? data.write(to: reconnectInviteFileURL)
    }

    func loadReconnectInvite() -> BreakupReconnectInvite? {
        guard fileManager.fileExists(atPath: reconnectInviteFileURL.path),
              let data = try? Data(contentsOf: reconnectInviteFileURL),
              let invite = try? decoder.decode(BreakupReconnectInvite.self, from: data) else {
            return nil
        }
        return invite
    }

    func clearReconnectInvite() {
        try? fileManager.removeItem(at: reconnectInviteFileURL)
    }
```

- [ ] **Step 3: Update clearAllData()**

In `clearAllData()`, after `try? fileManager.removeItem(at: preludeVoiceMemosDirectory)`, add:

```swift
        try? fileManager.removeItem(at: archiveBundleFileURL)
        try? fileManager.removeItem(at: reconnectInviteFileURL)
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Services/DataPersistenceManager.swift && git commit -m "feat: add archive bundle and reconnect invite persistence to DataPersistenceManager"
```

---

## Task 4: ArchiveService

**Files:**
- Create: `BabyTown/Services/ArchiveService.swift`

- [ ] **Step 1: Create the file**

Create `BabyTown/Services/ArchiveService.swift`:

```swift
import Foundation
import UserNotifications

@MainActor
final class ArchiveService: ObservableObject {

    static let shared = ArchiveService()

    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0

    private let dpm = DataPersistenceManager.shared

    private init() {}

    // MARK: - Breakup

    /// Creates a local ArchiveBundle snapshot from current device state and simulates an upload.
    /// Updates CoupleProfile to .archivedCouple on completion.
    func beginBreakup() async {
        isUploading = true
        uploadProgress = 0

        let profile = dpm.loadCoupleProfile()
        let moments = dpm.loadMoments()
        let petState = dpm.loadPetState()
        let preludeCaptures = dpm.loadPreludeCaptures()
        let preludeChapter = dpm.loadPreludeChapter()
        let breakupDate = Date()
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: breakupDate)!

        let bundle = ArchiveBundle(
            coupleId: "local-\(profile.displayName ?? "couple")-\(Int(breakupDate.timeIntervalSince1970))",
            breakupDate: breakupDate,
            expiryDate: expiryDate,
            userAHasSteppedOut: false,
            userBHasSteppedOut: false,
            moments: moments,
            coupleProfile: profile,
            petState: petState,
            preludeChapter: preludeChapter,
            preludeCaptures: preludeCaptures.filter { $0.isIncludedInGift }
        )

        // Simulate upload: 10 steps × 0.2s = 2s total
        for step in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            uploadProgress = Double(step) / 10.0
        }

        dpm.saveArchiveBundle(bundle)

        var updated = profile
        updated.relationshipStage = .archivedCouple
        updated.breakupDate = breakupDate
        updated.archiveExpiryDate = expiryDate
        updated.hasSteppedOut = false
        dpm.saveCoupleProfile(updated)

        scheduleRetentionNotifications(expiryDate: expiryDate)

        isUploading = false
    }

    // MARK: - Retention

    func extendRetention() {
        let newExpiry = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        var profile = dpm.loadCoupleProfile()
        profile.archiveExpiryDate = newExpiry
        dpm.saveCoupleProfile(profile)

        if var bundle = dpm.loadArchiveBundle() {
            bundle.expiryDate = newExpiry
            dpm.saveArchiveBundle(bundle)
        }

        scheduleRetentionNotifications(expiryDate: newExpiry)
    }

    // MARK: - Step Out

    func stepOut() {
        var profile = dpm.loadCoupleProfile()
        profile.hasSteppedOut = true
        profile.relationshipStage = .prelude
        profile.breakupDate = nil
        profile.archiveExpiryDate = nil
        dpm.saveCoupleProfile(profile)
        dpm.clearArchiveBundle()
        dpm.clearReconnectInvite()
        cancelRetentionNotifications()
    }

    // MARK: - Reconnect

    func sendReconnectInvite(fromUserId: String = "local-user", toUserId: String = "partner") {
        let invite = BreakupReconnectInvite(
            id: UUID(),
            senderUserId: fromUserId,
            recipientUserId: toUserId,
            sentAt: Date(),
            status: .pending
        )
        dpm.saveReconnectInvite(invite)
    }

    func acceptReconnect() {
        var profile = dpm.loadCoupleProfile()
        profile.relationshipStage = .officialCouple
        profile.breakupDate = nil
        profile.archiveExpiryDate = nil
        profile.hasSteppedOut = false
        dpm.saveCoupleProfile(profile)
        dpm.clearReconnectInvite()
        cancelRetentionNotifications()
    }

    func declineReconnect() {
        guard var invite = dpm.loadReconnectInvite() else { return }
        invite.status = .declined
        dpm.saveReconnectInvite(invite)
    }

    // MARK: - Export

    /// Returns a plain-text export of the archive bundle for sharing.
    func generateExportText() -> String {
        guard let bundle = dpm.loadArchiveBundle() else {
            return "No archive found."
        }

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        var lines: [String] = []

        let name = bundle.coupleProfile.displayName ?? "Our Story"
        lines.append("=== \(name) — Archive ===")
        lines.append("Archived: \(fmt.string(from: bundle.breakupDate))")
        lines.append("")

        lines.append("MEMORIES (\(bundle.moments.count))")
        lines.append(String(repeating: "-", count: 32))
        for moment in bundle.moments.sorted(by: { $0.dateTaken < $1.dateTaken }) {
            var entry = "[\(fmt.string(from: moment.dateTaken))]"
            if let caption = moment.caption { entry += " \(caption)" }
            if let place = moment.placeName { entry += " @ \(place)" }
            lines.append(entry)
        }

        let dates = bundle.coupleProfile.specialDates
        if !dates.isEmpty {
            lines.append("")
            lines.append("SPECIAL DATES")
            lines.append(String(repeating: "-", count: 32))
            for d in dates { lines.append("• \(d.title): \(fmt.string(from: d.date))") }
        }

        if let chapter = bundle.preludeChapter {
            lines.append("")
            lines.append("PRELUDE CHAPTER")
            lines.append(String(repeating: "-", count: 32))
            lines.append("Started: \(fmt.string(from: chapter.startDate))")
            lines.append("Became official: \(fmt.string(from: chapter.officialDate))")
            let giftIds = Set(chapter.giftCaptureIds)
            for capture in bundle.preludeCaptures where giftIds.contains(capture.id) {
                lines.append("[\(capture.typeLabel)] \(capture.displayTitle)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Local Notifications

    func scheduleRetentionNotifications(expiryDate: Date) {
        cancelRetentionNotifications()
        let center = UNUserNotificationCenter.current()
        let sevenDay = expiryDate.addingTimeInterval(-7 * 24 * 3600)
        let threeDay = expiryDate.addingTimeInterval(-3 * 24 * 3600)

        scheduleArchiveNotification(
            center: center,
            identifier: "archive_7_day",
            title: "Your shared memories expire soon",
            body: "Your shared memories expire in 7 days. Export or extend to keep them.",
            fireDate: sevenDay
        )
        scheduleArchiveNotification(
            center: center,
            identifier: "archive_3_day",
            title: "Last chance to export",
            body: "Your shared memories expire in 3 days.",
            fireDate: threeDay
        )
        scheduleArchiveNotification(
            center: center,
            identifier: "archive_expired",
            title: "Your memories have been deleted.",
            body: "Your shared archive has expired and can no longer be recovered.",
            fireDate: expiryDate
        )
    }

    private func scheduleArchiveNotification(
        center: UNUserNotificationCenter,
        identifier: String,
        title: String,
        body: String,
        fireDate: Date
    ) {
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancelRetentionNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["archive_7_day", "archive_3_day", "archive_expired"]
        )
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Services/ArchiveService.swift && git commit -m "feat: add ArchiveService with local breakup simulation, retention extensions, and notification scheduling"
```

---

## Task 5: ScrapbookGardenView + ScrapbookPetView

**Files:**
- Create: `BabyTown/Views/Breakup/ScrapbookGardenView.swift`
- Create: `BabyTown/Views/Breakup/ScrapbookPetView.swift`

Created before ScrapbookHomeView so the home view can reference them without build errors.

- [ ] **Step 1: Inspect ProfileSticker to find the display label property**

```bash
grep -n "var " /Users/ybstudio/Desktop/Projects/Covela/BabyTown/Models/ProfileSticker.swift | head -20
```

Note which property holds the sticker's display name (e.g. `label`, `name`, `displayName`). Use that property in `StickerSnapshotRow` in Step 3 below.

- [ ] **Step 2: Inspect PetState to find the name/identity property**

```bash
grep -rn "var cat\|var name\|var displayName\|var petName" /Users/ybstudio/Desktop/Projects/Covela/BabyTown --include="*.swift" | grep -i "pet\|cat" | head -10
```

Note which property holds the pet's display name or identity. Use that property in `ScrapbookPetView` in Step 4 below.

- [ ] **Step 3: Create ScrapbookGardenView**

Create `BabyTown/Views/Breakup/ScrapbookGardenView.swift`. Replace `stickerLabelProperty` with the real property name found in Step 1 (e.g. `sticker.label`; if no label property exists, use `"Sticker \(sticker.id.uuidString.prefix(6))"` as fallback):

```swift
import SwiftUI

struct ScrapbookGardenView: View {
    let bundle: ArchiveBundle?

    private var stickers: [ProfileSticker] {
        bundle?.coupleProfile.stickers ?? []
    }

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                frozenBadge(label: "Garden snapshot — frozen at archive")
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let note = bundle?.coupleProfile.profileNote, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(BabyTownTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 12)
                        }

                        if stickers.isEmpty {
                            Text("Garden was empty")
                                .font(.system(size: 14))
                                .foregroundStyle(BabyTownTheme.textSecondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(stickers) { sticker in
                                StickerSnapshotRow(sticker: sticker)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func frozenBadge(label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "snowflake")
                .font(.system(size: 12))
                .foregroundStyle(BabyTownTheme.textSecondary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(BabyTownTheme.cardBackground.opacity(0.7)))
    }
}

private struct StickerSnapshotRow: View {
    let sticker: ProfileSticker

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(BabyTownTheme.accent)
                )

            // Replace stickerDisplayText with the real label property found in Step 1
            Text(stickerDisplayText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
    }

    // Replace with the real label property, e.g.: sticker.label ?? "Sticker"
    private var stickerDisplayText: String {
        "Sticker \(sticker.id.uuidString.prefix(6))"
    }
}

#Preview {
    ScrapbookGardenView(bundle: nil)
}
```

- [ ] **Step 4: Create ScrapbookPetView**

Create `BabyTown/Views/Breakup/ScrapbookPetView.swift`. Replace the pet name access with the real property found in Step 2:

```swift
import SwiftUI

struct ScrapbookPetView: View {
    let bundle: ArchiveBundle?

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                frozenBadge(label: "Pet frozen — healthy, no decay in archive")
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                VStack(spacing: 28) {
                    Spacer()

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.5))

                    VStack(spacing: 10) {
                        Text(petDisplayName)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary)

                        Text("Frozen — healthy and waiting for you")
                            .font(.system(size: 14))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // Replace with the real name property found in Step 2, e.g. bundle?.petState.catName
    private var petDisplayName: String {
        "Your pet"
    }

    private func frozenBadge(label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "snowflake")
                .font(.system(size: 12))
                .foregroundStyle(BabyTownTheme.textSecondary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(BabyTownTheme.cardBackground.opacity(0.7)))
    }
}

#Preview {
    ScrapbookPetView(bundle: nil)
}
```

- [ ] **Step 5: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Views/Breakup/ScrapbookGardenView.swift BabyTown/Views/Breakup/ScrapbookPetView.swift && git commit -m "feat: add ScrapbookGardenView and ScrapbookPetView frozen state displays"
```

---

## Task 6: BreakupInitiationView

**Files:**
- Create: `BabyTown/Views/Breakup/BreakupInitiationView.swift`

Shown from relationship settings. Two states: confirmation screen and simulated upload progress. `onComplete()` is called when upload finishes; caller re-routes to ScrapbookHomeView.

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/Breakup/BreakupInitiationView.swift`:

```swift
import SwiftUI

struct BreakupInitiationView: View {

    var onComplete: () -> Void
    var onCancel: () -> Void

    @StateObject private var service = ArchiveService.shared
    @State private var showConfirmAlert = false

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            if service.isUploading {
                uploadingView
            } else {
                confirmationView
            }
        }
        .alert("End this relationship?", isPresented: $showConfirmAlert) {
            Button("End Relationship", role: .destructive) {
                Task { await beginBreakup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will archive your story. You'll both have 30 days to export your memories or reconnect.")
        }
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BabyTownTheme.textSecondary)

                VStack(spacing: 10) {
                    Text("End Relationship")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Text("This will archive your story.\nYou'll both have 30 days to export your\nmemories or reconnect.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    showConfirmAlert = true
                } label: {
                    Text("End Relationship")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.gray))
                }
                .buttonStyle(.plain)

                Button("Cancel", action: onCancel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
    }

    // MARK: - Uploading

    private var uploadingView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 52))
                .foregroundStyle(BabyTownTheme.accent)

            VStack(spacing: 10) {
                Text("Archiving your story…")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Preserving your memories")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

            ProgressView(value: service.uploadProgress)
                .progressViewStyle(.linear)
                .tint(BabyTownTheme.accent)
                .padding(.horizontal, 48)

            Spacer()
        }
    }

    private func beginBreakup() async {
        await service.beginBreakup()
        onComplete()
    }
}

#Preview {
    BreakupInitiationView(onComplete: {}, onCancel: {})
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Views/Breakup/BreakupInitiationView.swift && git commit -m "feat: add BreakupInitiationView with confirmation and simulated upload progress"
```

---

## Task 7: StepOutConfirmationView + ExportProgressView

**Files:**
- Create: `BabyTown/Views/Breakup/StepOutConfirmationView.swift`
- Create: `BabyTown/Views/Breakup/ExportProgressView.swift`

- [ ] **Step 1: Create StepOutConfirmationView**

Create `BabyTown/Views/Breakup/StepOutConfirmationView.swift`:

```swift
import SwiftUI

struct StepOutConfirmationView: View {

    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var showAlert = false

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "figure.walk.departure")
                        .font(.system(size: 52))
                        .foregroundStyle(BabyTownTheme.textSecondary)

                    VStack(spacing: 10) {
                        Text("Start Fresh")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary)

                        Text("You'll lose access to your shared\nmemories. This can't be undone.")
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showAlert = true
                    } label: {
                        Text("Leave my memories behind")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.red.opacity(0.75)))
                    }
                    .buttonStyle(.plain)

                    Button("Keep browsing", action: onCancel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BabyTownTheme.accent)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .alert("Are you sure?", isPresented: $showAlert) {
            Button("Start Fresh", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll lose access to your shared memories. This cannot be undone.")
        }
    }
}

#Preview {
    StepOutConfirmationView(onConfirm: {}, onCancel: {})
}
```

- [ ] **Step 2: Create ExportProgressView**

Create `BabyTown/Views/Breakup/ExportProgressView.swift`:

```swift
import SwiftUI

struct ExportProgressView: View {

    var onDone: () -> Void

    @StateObject private var service = ArchiveService.shared
    @State private var progress: Double = 0
    @State private var exportText: String = ""
    @State private var done = false
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "doc.zipper")
                    .font(.system(size: 52))
                    .foregroundStyle(BabyTownTheme.accent)

                VStack(spacing: 10) {
                    Text(done ? "Export ready" : "Preparing export…")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Text(done
                        ? "All memories, dates, and captures included."
                        : "Gathering your memories and captures")
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }

                if !done {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(BabyTownTheme.accent)
                        .padding(.horizontal, 48)
                } else {
                    VStack(spacing: 14) {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(BabyTownTheme.accentGradient))
                        }
                        .buttonStyle(.plain)

                        Button("Done", action: onDone)
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
        .task { await generateExport() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(text: exportText)
        }
    }

    private func generateExport() async {
        for step in 1...8 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            progress = Double(step) / 8.0
        }
        exportText = service.generateExportText()
        done = true
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportProgressView(onDone: {})
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Views/Breakup/StepOutConfirmationView.swift BabyTown/Views/Breakup/ExportProgressView.swift && git commit -m "feat: add StepOutConfirmationView and ExportProgressView"
```

---

## Task 8: ReconnectInviteView

**Files:**
- Create: `BabyTown/Views/Breakup/ReconnectInviteView.swift`

Handles both sending and receiving a reconnect invite. The `existingInvite` parameter determines which state to show:
- `nil` or `declined`/`expired` status → send-invite screen
- `pending` with `senderUserId == "local-user"` → waiting-for-response screen
- `pending` with `senderUserId != "local-user"` → incoming invite (accept/decline)

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/Breakup/ReconnectInviteView.swift`:

```swift
import SwiftUI

struct ReconnectInviteView: View {

    let existingInvite: BreakupReconnectInvite?
    var onInviteSent: () -> Void
    var onAccepted: () -> Void
    var onDeclined: () -> Void
    var onDismiss: () -> Void

    private enum ViewState {
        case sendInvite, waitingForResponse, incomingInvite
    }

    private var viewState: ViewState {
        guard let invite = existingInvite, invite.status == .pending else {
            return .sendInvite
        }
        return invite.senderUserId == "local-user" ? .waitingForResponse : .incomingInvite
    }

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            switch viewState {
            case .sendInvite:    sendView
            case .waitingForResponse: waitingView
            case .incomingInvite: incomingView
            }
        }
    }

    // MARK: - Send Invite

    private var sendView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(BabyTownTheme.accent)
                VStack(spacing: 10) {
                    Text("Invite them back")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text("Send a reconnect invite. They'll be notified\nand can choose to accept or decline.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            Spacer()
            VStack(spacing: 14) {
                Button(action: onInviteSent) {
                    Text("Send Reconnect Invite")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(BabyTownTheme.accentGradient))
                }
                .buttonStyle(.plain)
                Button("Not yet", action: onDismiss)
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
    }

    // MARK: - Waiting

    private var waitingView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "ellipsis.message")
                    .font(.system(size: 64))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.6))
                VStack(spacing: 10) {
                    Text("Invite sent")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text("Waiting for them to respond.\nYou'll be notified when they do.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            Spacer()
            Button("Close", action: onDismiss)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BabyTownTheme.accent)
                .padding(.bottom, 44)
        }
    }

    // MARK: - Incoming

    private var incomingView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(BabyTownTheme.accent)
                VStack(spacing: 10) {
                    Text("They want to continue your story")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Accept to return to your shared archive.\nYour garden and pet resume where they left off.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 14) {
                Button(action: onAccepted) {
                    Text("Accept")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(BabyTownTheme.accentGradient))
                }
                .buttonStyle(.plain)
                Button("Decline", action: onDeclined)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
    }
}

#Preview {
    ReconnectInviteView(
        existingInvite: nil,
        onInviteSent: {},
        onAccepted: {},
        onDeclined: {},
        onDismiss: {}
    )
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Views/Breakup/ReconnectInviteView.swift && git commit -m "feat: add ReconnectInviteView (send, waiting, incoming states)"
```

---

## Task 9: ScrapbookHomeView

**Files:**
- Create: `BabyTown/Views/Breakup/ScrapbookHomeView.swift`

All dependencies (`ScrapbookGardenView`, `ScrapbookPetView`, `StepOutConfirmationView`, `ExportProgressView`, `ReconnectInviteView`) now exist from Tasks 5–8.

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/Breakup/ScrapbookHomeView.swift`:

```swift
import SwiftUI

struct ScrapbookHomeView: View {

    @StateObject private var service = ArchiveService.shared
    @State private var bundle: ArchiveBundle? = nil
    @State private var profile: CoupleProfile = CoupleProfile()
    @State private var reconnectInvite: BreakupReconnectInvite? = nil
    @State private var selectedTab: Int = 0
    @State private var showStepOut = false
    @State private var showReconnect = false
    @State private var showExport = false
    @State private var showExtendConfirm = false
    @State private var showExtendedToast = false
    /// Called when the user steps out (step-out or reconnect accepted) — re-routes ContentView.
    var onSteppedOut: () -> Void = {}

    private let dpm = DataPersistenceManager.shared

    private var daysRemaining: Int {
        bundle?.daysRemaining ?? (profile.archiveExpiryDate.map {
            max(0, Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0)
        } ?? 30)
    }

    private var reconnectBannerText: String {
        if let invite = reconnectInvite, invite.status == .pending {
            return invite.senderUserId == "local-user"
                ? "Reconnect invite sent. Waiting for their response…"
                : "They want to continue your story. Tap to respond."
        }
        return "Changed your mind? Invite them back"
    }

    var body: some View {
        ZStack {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                retentionBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                reconnectBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                TabView(selection: $selectedTab) {
                    momentsTab
                        .tabItem { Label("Memories", systemImage: "photo.on.rectangle") }
                        .tag(0)

                    ScrapbookGardenView(bundle: bundle)
                        .tabItem { Label("Garden", systemImage: "leaf.fill") }
                        .tag(1)

                    ScrapbookPetView(bundle: bundle)
                        .tabItem { Label("Pet", systemImage: "pawprint.fill") }
                        .tag(2)
                }
            }

            if showExtendedToast {
                VStack {
                    Spacer()
                    Text("Extended by 30 days")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(BabyTownTheme.accentDeep))
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showStepOut = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showStepOut) {
            StepOutConfirmationView(
                onConfirm: {
                    service.stepOut()
                    onSteppedOut()
                },
                onCancel: { showStepOut = false }
            )
        }
        .sheet(isPresented: $showExport) {
            ExportProgressView(onDone: { showExport = false })
        }
        .fullScreenCover(isPresented: $showReconnect) {
            ReconnectInviteView(
                existingInvite: reconnectInvite,
                onInviteSent: {
                    service.sendReconnectInvite()
                    reconnectInvite = dpm.loadReconnectInvite()
                    showReconnect = false
                },
                onAccepted: {
                    service.acceptReconnect()
                    onSteppedOut()
                },
                onDeclined: {
                    service.declineReconnect()
                    reconnectInvite = dpm.loadReconnectInvite()
                    showReconnect = false
                },
                onDismiss: { showReconnect = false }
            )
        }
        .onAppear {
            bundle = dpm.loadArchiveBundle()
            profile = dpm.loadCoupleProfile()
            reconnectInvite = dpm.loadReconnectInvite()
        }
    }

    // MARK: - Retention Bar

    private var retentionBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)

            Text("Memories available for \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.textSecondary)

            Spacer()

            Button("Extend") { showExtendConfirm = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)

            Button {
                showExport = true
            } label: {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.accent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BabyTownTheme.cardBackground.opacity(0.6))
        )
        .alert("Extend by 30 days?", isPresented: $showExtendConfirm) {
            Button("Extend") {
                service.extendRetention()
                bundle = dpm.loadArchiveBundle()
                profile = dpm.loadCoupleProfile()
                withAnimation { showExtendedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showExtendedToast = false }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset the expiry timer to 30 days from today.")
        }
    }

    // MARK: - Reconnect Banner

    private var reconnectBanner: some View {
        Button { showReconnect = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.accent)
                Text(reconnectBannerText)
                    .font(.system(size: 13))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BabyTownTheme.accentSoft)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Moments Tab

    private var momentsTab: some View {
        Group {
            if let moments = bundle?.moments, !moments.isEmpty {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(moments.sorted(by: { $0.dateTaken > $1.dateTaken })) { moment in
                            ReadOnlyMomentRow(moment: moment)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.5))
                    Text("Your memories are preserved here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - ReadOnlyMomentRow

private struct ReadOnlyMomentRow: View {
    let moment: Moment

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                if let caption = moment.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .lineLimit(2)
                }
                Text(fmt.string(from: moment.dateTaken))
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                if let place = moment.placeName {
                    Text(place)
                        .font(.system(size: 12))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
    }
}

#Preview {
    ScrapbookHomeView()
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/Views/Breakup/ScrapbookHomeView.swift && git commit -m "feat: add ScrapbookHomeView with retention bar, reconnect banner, read-only Moments feed and frozen tabs"
```

---

## Task 10: ContentView routing for archivedCouple

**Files:**
- Modify: `BabyTown/ContentView.swift`

Follow the exact same pattern used for `.prelude` routing.

- [ ] **Step 1: Add case to Screen enum**

In `enum Screen`, after `case prelude`, add:

```swift
        case archivedCouple
```

- [ ] **Step 2: Add routing in init()**

In `init()`, in the `if hasCompletedOnboarding` block, after the `} else if stage == .prelude {` block and before the `} else {` fallback, add:

```swift
            } else if stage == .archivedCouple {
                _targetScreen = State(initialValue: .archivedCouple)
```

The complete routing chain should now be:
```swift
            if lastScreen == "selectPhotos" {
                _targetScreen = State(initialValue: .selectPhotos)
            } else if stage == .prelude {
                _targetScreen = State(initialValue: .prelude)
            } else if stage == .archivedCouple {
                _targetScreen = State(initialValue: .archivedCouple)
            } else {
                _targetScreen = State(initialValue: .home)
            }
```

- [ ] **Step 3: Add case in body switch**

In the body `switch screen`, after the `case .prelude:` block, add:

```swift
            case .archivedCouple:
                ScrapbookHomeView(onSteppedOut: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screen = .prelude
                    }
                })
                .transition(.opacity)
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/ContentView.swift && git commit -m "feat: add archivedCouple routing to ContentView — routes to ScrapbookHomeView"
```

---

## Task 11: Retention notifications + AppDelegate handling

**Files:**
- Modify: `BabyTown/AppDelegate.swift`
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Add notification name constant to AppDelegate**

In `BabyTown/AppDelegate.swift`, inside the `AppDelegate` class definition, add a static constant before `func application(...)`:

```swift
    static let openScrapbookNotificationName = Notification.Name("OpenScrapbookNotification")
```

- [ ] **Step 2: Handle archive notification identifiers in didReceive**

In `userNotificationCenter(_:didReceive:withCompletionHandler:)`, after the existing
`if identifier == "daily_morning_notification" { ... }` block, add:

```swift
        if identifier == "archive_7_day" || identifier == "archive_3_day" || identifier == "archive_expired" {
            NotificationCenter.default.post(name: AppDelegate.openScrapbookNotificationName, object: nil)
        }
```

- [ ] **Step 3: Listen in ContentView**

In `ContentView.swift`, after the existing `.onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCameraNotificationName))` modifier, add:

```swift
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openScrapbookNotificationName)) { _ in
            let stage = DataPersistenceManager.shared.loadCoupleProfile().relationshipStage
            if stage == .archivedCouple {
                withAnimation(.easeInOut(duration: 0.4)) {
                    screen = .archivedCouple
                }
            }
        }
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/ybstudio/Desktop/Projects/Covela && git add BabyTown/AppDelegate.swift BabyTown/ContentView.swift && git commit -m "feat: handle archive retention notification taps in AppDelegate and ContentView"
```

---

## Verification Checklist

After all tasks complete and build succeeds:

1. **Breakup flow:** Navigate to `BreakupInitiationView` in a Preview or from settings. Tap "End Relationship" → confirm → progress bar advances over ~2 seconds. After completion, `couple_profile.json` should have `"relationshipStage": "archivedCouple"` and `archive_bundle.json` should exist in Documents.

2. **Scrapbook routing:** Force-quit and relaunch with stage=archivedCouple stored → ContentView should route to `ScrapbookHomeView`, not Prelude or Home.

3. **Retention bar:** Shows "Memories available for 30 more days." The Extend button alert appears, and after confirming, `archiveExpiryDate` in `couple_profile.json` resets to 30 days from now, and the toast appears.

4. **Export:** Tap export icon → progress bar fills over ~1.2 seconds → Share button appears → tapping opens `UIActivityViewController` with the text export.

5. **Step out:** Gear icon → StepOutConfirmationView → "Leave my memories behind" → confirm destructive → `archive_bundle.json` deleted, stage = `.prelude`, ContentView transitions to PreludeHomeView.

6. **Reconnect send:** Reconnect banner → `ReconnectInviteView` in send state → "Send Reconnect Invite" → banner text updates to "Reconnect invite sent."

7. **Reconnect receive (simulate):** Manually write `{"id":"...","senderUserId":"partner","recipientUserId":"local-user","sentAt":...,"status":"pending"}` to `Documents/reconnect_invite.json` using Xcode device file browser, then re-open the reconnect sheet → should show incoming-invite screen with Accept/Decline.

8. **Reconnect accept:** Accept from incoming screen → stage transitions to `.officialCouple`, ContentView routes to home on next launch.

9. **Garden/Pet tabs:** In ScrapbookHomeView, tap Garden and Pet tabs → both show frozen badge and read-only content without any edit controls.

10. **Notification tap routing:** While in archivedCouple state, simulate an archive notification tap in the debugger → app routes to `ScrapbookHomeView`.
