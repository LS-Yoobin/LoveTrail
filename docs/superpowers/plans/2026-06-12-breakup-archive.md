# Breakup & Archive System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full breakup lifecycle — server-first archive bundle, 30-day retention timer with manual extension, photo export, deliberate step-out, and reconnect invite flow.

**Architecture:** At breakup, all media is uploaded to a server-side archive bundle and both users enter a read-only `archivedCouple` scrapbook. The iOS client caches the bundle locally for browsing. All state transitions (extend, step-out, reconnect) are server-authoritative. `ArchiveAPIClient` is a protocol — the stub calls are the integration seam; fill in real endpoints when the backend is ready.

**Tech Stack:** Swift 5.9, SwiftUI, UIKit, GardenCore, URLSession, XCTest, UNUserNotificationCenter

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `BabyTown/Models/CoupleProfile.swift` | Add `breakupDate`, `archiveExpiryDate`, `hasSteppedOut`, `coupleId` |
| Create | `BabyTown/Models/ArchiveBundle.swift` | Archive bundle model + tolerant decode |
| Create | `BabyTown/Models/BreakupReconnectInvite.swift` | Reconnect invite model |
| Modify | `BabyTown/Services/DataPersistenceManager.swift` | Add archive bundle save/load/delete |
| Create | `BabyTown/Services/ArchiveAPIClient.swift` | Network protocol + stub implementation |
| Create | `BabyTown/Services/ArchiveService.swift` | Orchestrates all archive operations |
| Create | `BabyTown/Views/Breakup/BreakupInitiationView.swift` | Confirmation + upload progress screen |
| Create | `BabyTown/Views/Breakup/ScrapbookHomeView.swift` | Read-only home — feed, retention bar, reconnect banner |
| Create | `BabyTown/Views/Breakup/ScrapbookGardenView.swift` | Frozen garden view |
| Create | `BabyTown/Views/Breakup/ScrapbookPetView.swift` | Frozen pet view (no decay) |
| Create | `BabyTown/Views/Breakup/StepOutConfirmationView.swift` | "Start Fresh" confirmation |
| Create | `BabyTown/Views/Breakup/ExportProgressView.swift` | ZIP generation + share sheet |
| Create | `BabyTown/Views/Breakup/ReconnectInviteView.swift` | Send and receive reconnect invite |
| Modify | `BabyTown/Views/HomeView.swift` | Gate on `relationshipStage` for `archivedCouple` |
| Modify | `BabyTown/Services/NotificationManager.swift` | Schedule archive expiry and reconnect push notifications |
| Modify | `BabyTown/AppDelegate.swift` | Handle archive notification taps |

---

## Task 1: CoupleProfile — Add Breakup Fields

**Files:**
- Modify: `BabyTown/Models/CoupleProfile.swift`

- [ ] **Step 1: Add four new properties to `CoupleProfile`**

  Open `BabyTown/Models/CoupleProfile.swift`. Add these four properties after `watchTogetherTVScale`:

  ```swift
  /// Stable backend couple identifier, set when partner accepts invite.
  var coupleId: String?
  /// Set to the confirmation date when entering archivedCouple.
  var breakupDate: Date?
  /// Expiry date of the server-side archive bundle; reset on each extension.
  var archiveExpiryDate: Date?
  /// True once this user has explicitly stepped out of the scrapbook permanently.
  var hasSteppedOut: Bool
  ```

- [ ] **Step 2: Update `CodingKeys`**

  Replace the existing `CodingKeys` enum:

  ```swift
  enum CodingKeys: String, CodingKey {
      case displayName, specialDates, stickers, profileNote, profileNotePosition
      case recordPlayerPosition, recordPlayerScale
      case watchTogetherTVPosition, watchTogetherTVScale
      case coupleId, breakupDate, archiveExpiryDate, hasSteppedOut
  }
  ```

- [ ] **Step 3: Update `init(displayName:...)`**

  Add the four new parameters with defaults after `watchTogetherTVScale`:

  ```swift
  init(
      displayName: String? = nil,
      specialDates: [SpecialDate] = [],
      stickers: [ProfileSticker] = [],
      profileNote: String? = nil,
      profileNotePosition: NormalizedPoint? = nil,
      recordPlayerPosition: NormalizedPoint? = nil,
      recordPlayerScale: CGFloat? = nil,
      watchTogetherTVPosition: NormalizedPoint? = nil,
      watchTogetherTVScale: CGFloat? = nil,
      coupleId: String? = nil,
      breakupDate: Date? = nil,
      archiveExpiryDate: Date? = nil,
      hasSteppedOut: Bool = false
  ) {
      self.displayName = displayName
      self.specialDates = specialDates
      self.stickers = stickers
      self.profileNote = profileNote
      self.profileNotePosition = profileNotePosition
      self.recordPlayerPosition = recordPlayerPosition
      self.recordPlayerScale = recordPlayerScale
      self.watchTogetherTVPosition = watchTogetherTVPosition
      self.watchTogetherTVScale = watchTogetherTVScale
      self.coupleId = coupleId
      self.breakupDate = breakupDate
      self.archiveExpiryDate = archiveExpiryDate
      self.hasSteppedOut = hasSteppedOut
  }
  ```

- [ ] **Step 4: Update `init(from decoder:)`**

  Add these four lines inside the existing tolerant decode init, after the `watchTogetherTVScale` decode:

  ```swift
  coupleId = try c.decodeIfPresent(String.self, forKey: .coupleId)
  breakupDate = try c.decodeIfPresent(Date.self, forKey: .breakupDate)
  archiveExpiryDate = try c.decodeIfPresent(Date.self, forKey: .archiveExpiryDate)
  hasSteppedOut = try c.decodeIfPresent(Bool.self, forKey: .hasSteppedOut) ?? false
  ```

- [ ] **Step 5: Verify encode round-trip in a unit test**

  In your test target (create `BabyTownTests/CoupleProfileTests.swift` if it doesn't exist):

  ```swift
  import XCTest
  @testable import BabyTown

  final class CoupleProfileTests: XCTestCase {
      func test_breakupFields_encodeDecodeRoundTrip() throws {
          var profile = CoupleProfile()
          profile.coupleId = "couple-abc-123"
          profile.breakupDate = Date(timeIntervalSince1970: 1_000_000)
          profile.archiveExpiryDate = Date(timeIntervalSince1970: 1_000_000 + 30 * 86_400)
          profile.hasSteppedOut = true

          let data = try JSONEncoder().encode(profile)
          let decoded = try JSONDecoder().decode(CoupleProfile.self, from: data)

          XCTAssertEqual(decoded.coupleId, "couple-abc-123")
          XCTAssertEqual(decoded.breakupDate?.timeIntervalSince1970,
                         profile.breakupDate?.timeIntervalSince1970)
          XCTAssertEqual(decoded.archiveExpiryDate?.timeIntervalSince1970,
                         profile.archiveExpiryDate?.timeIntervalSince1970)
          XCTAssertTrue(decoded.hasSteppedOut)
      }

      func test_missingBreakupFields_defaultToNilAndFalse() throws {
          let json = #"{"specialDates":[],"stickers":[]}"#.data(using: .utf8)!
          let profile = try JSONDecoder().decode(CoupleProfile.self, from: json)
          XCTAssertNil(profile.coupleId)
          XCTAssertNil(profile.breakupDate)
          XCTAssertNil(profile.archiveExpiryDate)
          XCTAssertFalse(profile.hasSteppedOut)
      }
  }
  ```

  Run: `Cmd+U` in Xcode  
  Expected: both tests pass

- [ ] **Step 6: Commit**

  ```bash
  git add BabyTown/Models/CoupleProfile.swift
  git commit -m "feat(archive): add breakup fields to CoupleProfile"
  ```

---

## Task 2: ArchiveBundle Model

**Files:**
- Create: `BabyTown/Models/ArchiveBundle.swift`
- Create: `BabyTownTests/ArchiveBundleTests.swift`

- [ ] **Step 1: Write a failing encode/decode test**

  Create `BabyTownTests/ArchiveBundleTests.swift`:

  ```swift
  import XCTest
  @testable import BabyTown

  final class ArchiveBundleTests: XCTestCase {
      func test_archiveBundle_encodeDecodeRoundTrip() throws {
          let bundle = ArchiveBundle(
              coupleId: "couple-xyz",
              breakupDate: Date(timeIntervalSince1970: 1_000_000),
              expiryDate: Date(timeIntervalSince1970: 1_000_000 + 30 * 86_400),
              userASteppedOut: false,
              userBSteppedOut: false,
              moments: [],
              coupleProfile: CoupleProfile(),
              petState: PetState(),
              gardenState: GardenState(),
              playlist: [],
              preludeChapter: nil
          )
          let data = try JSONEncoder().encode(bundle)
          let decoded = try JSONDecoder().decode(ArchiveBundle.self, from: data)
          XCTAssertEqual(decoded.coupleId, "couple-xyz")
          XCTAssertFalse(decoded.userASteppedOut)
          XCTAssertNil(decoded.preludeChapter)
      }
  }
  ```

  Run: `Cmd+U`  
  Expected: FAIL — `ArchiveBundle` not defined

- [ ] **Step 2: Create `BabyTown/Models/ArchiveBundle.swift`**

  ```swift
  import Foundation
  import GardenCore

  struct ArchiveBundle: Codable {
      let coupleId: String
      let breakupDate: Date
      var expiryDate: Date
      var userASteppedOut: Bool
      var userBSteppedOut: Bool
      var moments: [Moment]
      var coupleProfile: CoupleProfile
      var petState: PetState
      var gardenState: GardenState
      var playlist: [CouplePlaylistTrack]
      var preludeChapter: PreludeChapter?

      init(
          coupleId: String,
          breakupDate: Date,
          expiryDate: Date,
          userASteppedOut: Bool = false,
          userBSteppedOut: Bool = false,
          moments: [Moment] = [],
          coupleProfile: CoupleProfile = CoupleProfile(),
          petState: PetState = PetState(),
          gardenState: GardenState = GardenState(),
          playlist: [CouplePlaylistTrack] = [],
          preludeChapter: PreludeChapter? = nil
      ) {
          self.coupleId = coupleId
          self.breakupDate = breakupDate
          self.expiryDate = expiryDate
          self.userASteppedOut = userASteppedOut
          self.userBSteppedOut = userBSteppedOut
          self.moments = moments
          self.coupleProfile = coupleProfile
          self.petState = petState
          self.gardenState = gardenState
          self.playlist = playlist
          self.preludeChapter = preludeChapter
      }

      enum CodingKeys: String, CodingKey {
          case coupleId, breakupDate, expiryDate
          case userASteppedOut, userBSteppedOut
          case moments, coupleProfile, petState, gardenState, playlist, preludeChapter
      }

      init(from decoder: Decoder) throws {
          let c = try decoder.container(keyedBy: CodingKeys.self)
          coupleId = try c.decode(String.self, forKey: .coupleId)
          breakupDate = try c.decode(Date.self, forKey: .breakupDate)
          expiryDate = try c.decode(Date.self, forKey: .expiryDate)
          userASteppedOut = try c.decodeIfPresent(Bool.self, forKey: .userASteppedOut) ?? false
          userBSteppedOut = try c.decodeIfPresent(Bool.self, forKey: .userBSteppedOut) ?? false
          moments = try c.decodeIfPresent([Moment].self, forKey: .moments) ?? []
          coupleProfile = try c.decodeIfPresent(CoupleProfile.self, forKey: .coupleProfile) ?? CoupleProfile()
          petState = try c.decodeIfPresent(PetState.self, forKey: .petState) ?? PetState()
          gardenState = try c.decodeIfPresent(GardenState.self, forKey: .gardenState) ?? GardenState()
          playlist = try c.decodeIfPresent([CouplePlaylistTrack].self, forKey: .playlist) ?? []
          preludeChapter = try c.decodeIfPresent(PreludeChapter.self, forKey: .preludeChapter)
      }
  }
  ```

- [ ] **Step 3: Run test to verify it passes**

  Run: `Cmd+U`  
  Expected: PASS

- [ ] **Step 4: Commit**

  ```bash
  git add BabyTown/Models/ArchiveBundle.swift BabyTownTests/ArchiveBundleTests.swift
  git commit -m "feat(archive): add ArchiveBundle model"
  ```

---

## Task 3: BreakupReconnectInvite Model

**Files:**
- Create: `BabyTown/Models/BreakupReconnectInvite.swift`
- Create: `BabyTownTests/BreakupReconnectInviteTests.swift`

- [ ] **Step 1: Write a failing test**

  Create `BabyTownTests/BreakupReconnectInviteTests.swift`:

  ```swift
  import XCTest
  @testable import BabyTown

  final class BreakupReconnectInviteTests: XCTestCase {
      func test_invite_encodeDecodeRoundTrip() throws {
          let invite = BreakupReconnectInvite(
              id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
              senderUserId: "user-a",
              recipientUserId: "user-b",
              sentAt: Date(timeIntervalSince1970: 1_000_000),
              status: .pending
          )
          let data = try JSONEncoder().encode(invite)
          let decoded = try JSONDecoder().decode(BreakupReconnectInvite.self, from: data)
          XCTAssertEqual(decoded.senderUserId, "user-a")
          XCTAssertEqual(decoded.status, .pending)
      }

      func test_missingStatus_defaultsToPending() throws {
          let json = """
          {"id":"12345678-1234-1234-1234-123456789012",
           "senderUserId":"u1","recipientUserId":"u2",
           "sentAt":1000000}
          """.data(using: .utf8)!
          let decoded = try JSONDecoder().decode(BreakupReconnectInvite.self, from: json)
          XCTAssertEqual(decoded.status, .pending)
      }
  }
  ```

  Run: `Cmd+U`  
  Expected: FAIL — `BreakupReconnectInvite` not defined

- [ ] **Step 2: Create `BabyTown/Models/BreakupReconnectInvite.swift`**

  ```swift
  import Foundation

  struct BreakupReconnectInvite: Codable, Identifiable, Equatable {
      let id: UUID
      let senderUserId: String
      let recipientUserId: String
      let sentAt: Date
      var status: InviteStatus

      enum InviteStatus: String, Codable, Equatable {
          case pending
          case accepted
          case declined
          case expired
      }

      enum CodingKeys: String, CodingKey {
          case id, senderUserId, recipientUserId, sentAt, status
      }

      init(
          id: UUID = UUID(),
          senderUserId: String,
          recipientUserId: String,
          sentAt: Date = Date(),
          status: InviteStatus = .pending
      ) {
          self.id = id
          self.senderUserId = senderUserId
          self.recipientUserId = recipientUserId
          self.sentAt = sentAt
          self.status = status
      }

      init(from decoder: Decoder) throws {
          let c = try decoder.container(keyedBy: CodingKeys.self)
          id = try c.decode(UUID.self, forKey: .id)
          senderUserId = try c.decode(String.self, forKey: .senderUserId)
          recipientUserId = try c.decode(String.self, forKey: .recipientUserId)
          sentAt = try c.decode(Date.self, forKey: .sentAt)
          status = try c.decodeIfPresent(InviteStatus.self, forKey: .status) ?? .pending
      }
  }
  ```

- [ ] **Step 3: Run test to verify it passes**

  Run: `Cmd+U`  
  Expected: PASS

- [ ] **Step 4: Commit**

  ```bash
  git add BabyTown/Models/BreakupReconnectInvite.swift BabyTownTests/BreakupReconnectInviteTests.swift
  git commit -m "feat(archive): add BreakupReconnectInvite model"
  ```

---

## Task 4: DataPersistenceManager — Archive Bundle Persistence

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

- [ ] **Step 1: Add the file URL property**

  In `DataPersistenceManager`, alongside the other `private var *FileURL` properties, add:

  ```swift
  private var archiveBundleFileURL: URL {
      documentsDirectory.appendingPathComponent("archive_bundle.json")
  }
  ```

- [ ] **Step 2: Add save/load/delete methods**

  In the `// MARK: - Pet` section area, add a new `// MARK: - Archive` section:

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

  func deleteArchiveBundle() {
      try? fileManager.removeItem(at: archiveBundleFileURL)
  }
  ```

- [ ] **Step 3: Add `deleteArchiveBundle` to `clearAllData()`**

  Inside `clearAllData()`, add alongside the other `removeItem` calls:

  ```swift
  try? fileManager.removeItem(at: archiveBundleFileURL)
  ```

- [ ] **Step 4: Verify save/load round-trip manually**

  In a simulator debug session, call:
  ```swift
  let bundle = ArchiveBundle(coupleId: "test", breakupDate: Date(), expiryDate: Date())
  DataPersistenceManager.shared.saveArchiveBundle(bundle)
  let loaded = DataPersistenceManager.shared.loadArchiveBundle()
  assert(loaded?.coupleId == "test")
  ```
  Expected: assertion passes, no crash.

- [ ] **Step 5: Commit**

  ```bash
  git add BabyTown/Services/DataPersistenceManager.swift
  git commit -m "feat(archive): add archive bundle persistence to DataPersistenceManager"
  ```

---

## Task 5: ArchiveAPIClient — Network Protocol + Stub

**Files:**
- Create: `BabyTown/Services/ArchiveAPIClient.swift`

This task defines the integration seam between the iOS client and the backend. The `StubArchiveAPIClient` simulates success locally — replace each method body with real `URLSession` calls once the backend endpoints are live.

- [ ] **Step 1: Create `BabyTown/Services/ArchiveAPIClient.swift`**

  ```swift
  import Foundation

  // MARK: - Protocol

  protocol ArchiveAPIClientProtocol {
      /// Uploads photo/video data for a single moment. Called once per moment during breakup initiation.
      func uploadMomentMedia(_ moment: Moment) async throws
      /// Creates the archive bundle on the server. Called after all media is uploaded.
      func createArchiveBundle(_ bundle: ArchiveBundle) async throws
      /// Resets the archive expiry date to `newExpiry` on the server.
      func extendRetention(coupleId: String, newExpiry: Date) async throws
      /// Marks this user as stepped out on the server and revokes their access.
      func stepOut(coupleId: String) async throws
      /// Requests a server-generated ZIP export. Returns a download URL.
      func generateExportZip(coupleId: String) async throws -> URL
      /// Creates a reconnect invite on the server and returns it.
      func sendReconnectInvite(coupleId: String) async throws -> BreakupReconnectInvite
      /// Accepts a reconnect invite; server transitions both users back to officialCouple.
      func acceptReconnectInvite(inviteId: UUID, coupleId: String) async throws
  }

  // MARK: - Stub (replace with real URLSession calls when backend is ready)

  final class StubArchiveAPIClient: ArchiveAPIClientProtocol {
      static let shared = StubArchiveAPIClient()
      private init() {}

      func uploadMomentMedia(_ moment: Moment) async throws {
          // TODO: POST media bytes to /archive/media/{moment.id}
          try await Task.sleep(nanoseconds: 10_000_000) // simulate 10ms per photo
      }

      func createArchiveBundle(_ bundle: ArchiveBundle) async throws {
          // TODO: POST encoded bundle to /archive/couples/{bundle.coupleId}
      }

      func extendRetention(coupleId: String, newExpiry: Date) async throws {
          // TODO: PATCH /archive/couples/{coupleId}/expiry with newExpiry
      }

      func stepOut(coupleId: String) async throws {
          // TODO: POST /archive/couples/{coupleId}/step-out
      }

      func generateExportZip(coupleId: String) async throws -> URL {
          // TODO: POST /archive/couples/{coupleId}/export -> returns presigned ZIP URL
          // Returning a placeholder local URL for stub testing
          return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("export.zip")
      }

      func sendReconnectInvite(coupleId: String) async throws -> BreakupReconnectInvite {
          // TODO: POST /archive/couples/{coupleId}/reconnect-invite -> returns invite JSON
          return BreakupReconnectInvite(
              senderUserId: "stub-sender",
              recipientUserId: "stub-recipient"
          )
      }

      func acceptReconnectInvite(inviteId: UUID, coupleId: String) async throws {
          // TODO: POST /archive/reconnect-invites/{inviteId}/accept
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add BabyTown/Services/ArchiveAPIClient.swift
  git commit -m "feat(archive): add ArchiveAPIClient protocol and stub"
  ```

---

## Task 6: ArchiveService — Orchestration

**Files:**
- Create: `BabyTown/Services/ArchiveService.swift`

- [ ] **Step 1: Create `BabyTown/Services/ArchiveService.swift`**

  ```swift
  import Foundation
  import GardenCore

  @MainActor
  final class ArchiveService {
      static let shared = ArchiveService()

      private let persistence = DataPersistenceManager.shared
      private let api: ArchiveAPIClientProtocol = StubArchiveAPIClient.shared

      private init() {}

      // MARK: - Breakup Initiation

      /// Uploads all media, creates the server-side archive bundle, and transitions the
      /// local profile to `archivedCouple`. `progress` is called with 0.0–1.0 as
      /// each moment is uploaded.
      func initiateBreakup(progress: @escaping @Sendable (Double) -> Void) async throws {
          let moments = persistence.loadMoments()
          let profile = persistence.loadCoupleProfile()
          let petState = persistence.loadPetState()
          let gardenState = persistence.loadGardenState()
          let playlist = persistence.loadPlaylist()
          let preludeChapter = persistence.loadPreludeChapter()

          let total = max(moments.count, 1)
          for (index, moment) in moments.enumerated() {
              try await api.uploadMomentMedia(moment)
              let fraction = Double(index + 1) / Double(total)
              progress(fraction)
          }

          let breakupDate = Date()
          let expiryDate = breakupDate.addingTimeInterval(30 * 24 * 60 * 60)

          let bundle = ArchiveBundle(
              coupleId: profile.coupleId ?? "",
              breakupDate: breakupDate,
              expiryDate: expiryDate,
              moments: moments,
              coupleProfile: profile,
              petState: petState,
              gardenState: gardenState,
              playlist: playlist,
              preludeChapter: preludeChapter
          )
          try await api.createArchiveBundle(bundle)
          persistence.saveArchiveBundle(bundle)

          var updated = profile
          updated.relationshipStage = .archivedCouple
          updated.breakupDate = breakupDate
          updated.archiveExpiryDate = expiryDate
          updated.hasSteppedOut = false
          persistence.saveCoupleProfile(updated)
      }

      // MARK: - Extend Retention

      /// Silently resets the retention clock to `now + 30 days`.
      func extendRetention() async throws {
          guard var bundle = persistence.loadArchiveBundle() else { return }
          let newExpiry = Date().addingTimeInterval(30 * 24 * 60 * 60)
          try await api.extendRetention(coupleId: bundle.coupleId, newExpiry: newExpiry)
          bundle.expiryDate = newExpiry
          persistence.saveArchiveBundle(bundle)

          var profile = persistence.loadCoupleProfile()
          profile.archiveExpiryDate = newExpiry
          persistence.saveCoupleProfile(profile)
      }

      // MARK: - Step Out

      /// Revokes server access, clears local archive, and transitions the profile to `.prelude`.
      func stepOut() async throws {
          let profile = persistence.loadCoupleProfile()
          try await api.stepOut(coupleId: profile.coupleId ?? "")
          persistence.deleteArchiveBundle()

          var updated = profile
          updated.relationshipStage = .prelude
          updated.hasSteppedOut = true
          updated.breakupDate = nil
          updated.archiveExpiryDate = nil
          persistence.saveCoupleProfile(updated)
      }

      // MARK: - Export

      /// Requests a server-generated ZIP and returns the download URL for the share sheet.
      func requestExportURL() async throws -> URL {
          let profile = persistence.loadCoupleProfile()
          return try await api.generateExportZip(coupleId: profile.coupleId ?? "")
      }

      // MARK: - Reconnect

      func sendReconnectInvite() async throws -> BreakupReconnectInvite {
          let profile = persistence.loadCoupleProfile()
          return try await api.sendReconnectInvite(coupleId: profile.coupleId ?? "")
      }

      /// Accepts an incoming reconnect invite and restores the couple to `officialCouple`.
      /// Garden and pet resume from their frozen archive snapshots.
      func acceptReconnectInvite(inviteId: UUID) async throws {
          let profile = persistence.loadCoupleProfile()
          try await api.acceptReconnectInvite(inviteId: inviteId, coupleId: profile.coupleId ?? "")

          if let bundle = persistence.loadArchiveBundle() {
              persistence.savePetState(bundle.petState)
              persistence.saveGardenState(bundle.gardenState)
          }
          persistence.deleteArchiveBundle()

          var updated = profile
          updated.relationshipStage = .officialCouple
          updated.hasSteppedOut = false
          updated.breakupDate = nil
          updated.archiveExpiryDate = nil
          persistence.saveCoupleProfile(updated)
      }
  }
  ```

  > **Note:** `persistence.loadPlaylist()` follows the same pattern as `loadMoments()`. Add it to `DataPersistenceManager` if it doesn't exist, following the established save/load pair pattern.

- [ ] **Step 2: Build the project — confirm it compiles**

  Press `Cmd+B` in Xcode.  
  Expected: builds cleanly, no errors.

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Services/ArchiveService.swift
  git commit -m "feat(archive): add ArchiveService orchestration layer"
  ```

---

## Task 7: BreakupInitiationView

**Files:**
- Create: `BabyTown/Views/Breakup/BreakupInitiationView.swift`

- [ ] **Step 1: Create `BabyTown/Views/Breakup/BreakupInitiationView.swift`**

  ```swift
  import SwiftUI

  struct BreakupInitiationView: View {
      var onComplete: () -> Void
      var onCancel: () -> Void

      @State private var stage: Stage = .confirmation
      @State private var uploadProgress: Double = 0
      @State private var errorMessage: String?

      enum Stage { case confirmation, uploading, failed }

      var body: some View {
          switch stage {
          case .confirmation:
              confirmationView
          case .uploading:
              uploadingView
          case .failed:
              failedView
          }
      }

      private var confirmationView: some View {
          VStack(spacing: 24) {
              Spacer()
              Text("Archive Your Story")
                  .font(.title2.bold())
              Text("This will archive your story. You'll both have 30 days to export your memories or reconnect.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 32)
              Spacer()
              Button(role: .destructive) {
                  Task { await startBreakup() }
              } label: {
                  Text("End Relationship")
                      .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.red)
              .padding(.horizontal, 32)
              Button("Cancel", action: onCancel)
                  .padding(.bottom, 32)
          }
      }

      private var uploadingView: some View {
          VStack(spacing: 24) {
              Spacer()
              ProgressView("Archiving your memories…", value: uploadProgress)
                  .padding(.horizontal, 40)
              Text("This may take a moment for large photo libraries.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              Spacer()
          }
      }

      private var failedView: some View {
          VStack(spacing: 24) {
              Spacer()
              Text("Something went wrong")
                  .font(.title3.bold())
              Text(errorMessage ?? "Please check your connection and try again.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 32)
              Button("Try Again") {
                  Task { await startBreakup() }
              }
              .buttonStyle(.borderedProminent)
              Button("Cancel", action: onCancel)
              Spacer()
          }
      }

      private func startBreakup() async {
          stage = .uploading
          uploadProgress = 0
          do {
              try await ArchiveService.shared.initiateBreakup { fraction in
                  Task { @MainActor in uploadProgress = fraction }
              }
              onComplete()
          } catch {
              errorMessage = error.localizedDescription
              stage = .failed
          }
      }
  }
  ```

- [ ] **Step 2: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Views/Breakup/BreakupInitiationView.swift
  git commit -m "feat(archive): add BreakupInitiationView with upload progress"
  ```

---

## Task 8: ScrapbookHomeView

**Files:**
- Create: `BabyTown/Views/Breakup/ScrapbookHomeView.swift`

- [ ] **Step 1: Create `BabyTown/Views/Breakup/ScrapbookHomeView.swift`**

  ```swift
  import SwiftUI

  struct ScrapbookHomeView: View {
      var bundle: ArchiveBundle
      var onStepOut: () -> Void
      var onReconnect: () -> Void

      @State private var showExport = false
      @State private var showStepOutConfirmation = false
      @State private var showReconnect = false
      @State private var showGarden = false
      @State private var showPet = false
      @State private var selectedTab: Tab = .memories

      enum Tab { case memories, garden, pet }

      var body: some View {
          VStack(spacing: 0) {
              retentionBar
              reconnectBanner
              tabContent
              tabBar
          }
          .sheet(isPresented: $showExport) {
              ExportProgressView()
          }
          .sheet(isPresented: $showStepOutConfirmation) {
              StepOutConfirmationView(onConfirmed: onStepOut)
          }
          .sheet(isPresented: $showReconnect) {
              ReconnectInviteView(onReconnected: onReconnect)
          }
      }

      private var retentionBar: some View {
          HStack {
              if let expiry = bundle.expiryDate as Date? {
                  Text(expiryLabel(expiry))
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }
              Spacer()
              Button("Export") { showExport = true }
                  .font(.caption.bold())
              Button("Extend") {
                  Task {
                      try? await ArchiveService.shared.extendRetention()
                  }
              }
              .font(.caption.bold())
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(.ultraThinMaterial)
      }

      private var reconnectBanner: some View {
          Button {
              showReconnect = true
          } label: {
              HStack {
                  Image(systemName: "heart")
                  Text("Changed your mind? Invite \(bundle.coupleProfile.displayName ?? "them") back")
                      .font(.subheadline)
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 16)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          .background(Color(.secondarySystemBackground))
      }

      @ViewBuilder
      private var tabContent: some View {
          switch selectedTab {
          case .memories:
              ScrollView {
                  LazyVStack(spacing: 16) {
                      ForEach(bundle.moments.sorted { $0.dateTaken > $1.dateTaken }) { moment in
                          ScrapbookMomentRow(moment: moment)
                      }
                  }
                  .padding(16)
              }
          case .garden:
              ScrapbookGardenView(bundle: bundle)
          case .pet:
              ScrapbookPetView(bundle: bundle)
          }
      }

      private var tabBar: some View {
          HStack {
              tabButton("Memories", systemImage: "photo.stack", tab: .memories)
              tabButton("Garden", systemImage: "leaf", tab: .garden)
              tabButton("Pet", systemImage: "pawprint", tab: .pet)
              Spacer()
              Button {
                  showStepOutConfirmation = true
              } label: {
                  Text("Start Fresh")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }
              .padding(.trailing, 16)
          }
          .padding(.vertical, 8)
          .background(.ultraThinMaterial)
      }

      private func tabButton(_ label: String, systemImage: String, tab: Tab) -> some View {
          Button {
              selectedTab = tab
          } label: {
              VStack(spacing: 4) {
                  Image(systemName: systemImage)
                  Text(label).font(.caption2)
              }
              .foregroundStyle(selectedTab == tab ? .primary : .secondary)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
      }

      private func expiryLabel(_ expiry: Date) -> String {
          let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
          return "Memories available for \(max(days, 0)) more day\(days == 1 ? "" : "s")"
      }
  }

  // MARK: - Moment Row (read-only)

  private struct ScrapbookMomentRow: View {
      let moment: Moment
      var body: some View {
          HStack(alignment: .top, spacing: 12) {
              Image(uiImage: moment.thumbnail)
                  .resizable()
                  .scaledToFill()
                  .frame(width: 72, height: 72)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              VStack(alignment: .leading, spacing: 4) {
                  if let caption = moment.caption {
                      Text(caption).font(.subheadline)
                  }
                  if let place = moment.placeName {
                      Text(place).font(.caption).foregroundStyle(.secondary)
                  }
                  Text(moment.dateTaken, style: .date)
                      .font(.caption2)
                      .foregroundStyle(.tertiary)
              }
              Spacer()
          }
      }
  }
  ```

- [ ] **Step 2: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Views/Breakup/ScrapbookHomeView.swift
  git commit -m "feat(archive): add ScrapbookHomeView"
  ```

---

## Task 9: ScrapbookGardenView + ScrapbookPetView

**Files:**
- Create: `BabyTown/Views/Breakup/ScrapbookGardenView.swift`
- Create: `BabyTown/Views/Breakup/ScrapbookPetView.swift`

- [ ] **Step 1: Create `BabyTown/Views/Breakup/ScrapbookGardenView.swift`**

  ```swift
  import SwiftUI
  import GardenCore

  struct ScrapbookGardenView: View {
      let bundle: ArchiveBundle

      var body: some View {
          ZStack {
              // Render the frozen garden state — same visual as the live garden
              // but wrapped in a non-interactive overlay.
              GardenView(state: bundle.gardenState)
                  .disabled(true)
                  .allowsHitTesting(false)

              frozenOverlay
          }
      }

      private var frozenOverlay: some View {
          VStack {
              Spacer()
              Label("Garden is frozen", systemImage: "snowflake")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .padding(.bottom, 16)
          }
      }
  }
  ```

  > **Note:** Replace `GardenView(state:)` with whatever the actual garden rendering view is in your codebase — check `BabyTown/Views/CoupleProfile/ProfileGardenLayout.swift` for the correct initializer and pass `bundle.gardenState` and `bundle.coupleProfile` as needed.

- [ ] **Step 2: Create `BabyTown/Views/Breakup/ScrapbookPetView.swift`**

  ```swift
  import SwiftUI

  struct ScrapbookPetView: View {
      let bundle: ArchiveBundle

      var body: some View {
          // The pet is displayed from the frozen PetState snapshot.
          // StoredNeed values are NOT re-evaluated — no decay in the scrapbook.
          VStack(spacing: 24) {
              Spacer()
              if let skin = bundle.petState.adoptedSkin {
                  Image(skin.portraitAsset)
                      .resizable()
                      .scaledToFit()
                      .frame(height: 200)
                  Text(bundle.petState.customPetNames[skin.rawValue] ?? skin.petName)
                      .font(.title3.bold())
                  Text("Resting peacefully")
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
              } else {
                  Text("No pet adopted yet")
                      .foregroundStyle(.secondary)
              }
              Spacer()
          }
      }
  }
  ```

- [ ] **Step 3: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 4: Commit**

  ```bash
  git add BabyTown/Views/Breakup/ScrapbookGardenView.swift BabyTown/Views/Breakup/ScrapbookPetView.swift
  git commit -m "feat(archive): add frozen garden and pet scrapbook views"
  ```

---

## Task 10: StepOutConfirmationView

**Files:**
- Create: `BabyTown/Views/Breakup/StepOutConfirmationView.swift`

- [ ] **Step 1: Create `BabyTown/Views/Breakup/StepOutConfirmationView.swift`**

  ```swift
  import SwiftUI

  struct StepOutConfirmationView: View {
      var onConfirmed: () -> Void
      @Environment(\.dismiss) private var dismiss
      @State private var isProcessing = false
      @State private var errorMessage: String?

      var body: some View {
          NavigationStack {
              VStack(spacing: 24) {
                  Spacer()
                  Image(systemName: "door.left.hand.open")
                      .font(.system(size: 56))
                      .foregroundStyle(.secondary)
                  Text("Start Fresh?")
                      .font(.title2.bold())
                  Text("You'll lose access to your shared memories. This can't be undone.")
                      .multilineTextAlignment(.center)
                      .foregroundStyle(.secondary)
                      .padding(.horizontal, 32)
                  if let error = errorMessage {
                      Text(error)
                          .font(.caption)
                          .foregroundStyle(.red)
                  }
                  Spacer()
                  if isProcessing {
                      ProgressView()
                  } else {
                      Button(role: .destructive) {
                          Task { await confirmStepOut() }
                      } label: {
                          Text("Move On")
                              .frame(maxWidth: .infinity)
                      }
                      .buttonStyle(.borderedProminent)
                      .tint(.red)
                      .padding(.horizontal, 32)
                  }
                  Button("Keep My Memories") { dismiss() }
                      .padding(.bottom, 32)
              }
              .navigationBarHidden(true)
          }
      }

      private func confirmStepOut() async {
          isProcessing = true
          do {
              try await ArchiveService.shared.stepOut()
              onConfirmed()
          } catch {
              errorMessage = error.localizedDescription
              isProcessing = false
          }
      }
  }
  ```

- [ ] **Step 2: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Views/Breakup/StepOutConfirmationView.swift
  git commit -m "feat(archive): add StepOutConfirmationView"
  ```

---

## Task 11: ExportProgressView

**Files:**
- Create: `BabyTown/Views/Breakup/ExportProgressView.swift`

- [ ] **Step 1: Create `BabyTown/Views/Breakup/ExportProgressView.swift`**

  ```swift
  import SwiftUI

  struct ExportProgressView: View {
      @Environment(\.dismiss) private var dismiss
      @State private var stage: Stage = .preparing

      enum Stage {
          case preparing
          case ready(URL)
          case failed(String)
      }

      var body: some View {
          NavigationStack {
              VStack(spacing: 24) {
                  Spacer()
                  switch stage {
                  case .preparing:
                      ProgressView("Preparing your memories…")
                  case .ready(let url):
                      Image(systemName: "checkmark.circle")
                          .font(.system(size: 56))
                          .foregroundStyle(.green)
                      Text("Export Ready")
                          .font(.title3.bold())
                      ShareLink(item: url) {
                          Label("Save Memories", systemImage: "square.and.arrow.up")
                              .frame(maxWidth: .infinity)
                      }
                      .buttonStyle(.borderedProminent)
                      .padding(.horizontal, 32)
                  case .failed(let message):
                      Image(systemName: "exclamationmark.triangle")
                          .font(.system(size: 56))
                          .foregroundStyle(.orange)
                      Text("Export Failed")
                          .font(.title3.bold())
                      Text(message)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                          .multilineTextAlignment(.center)
                          .padding(.horizontal, 32)
                      Button("Try Again") {
                          Task { await requestExport() }
                      }
                      .buttonStyle(.borderedProminent)
                  }
                  Spacer()
              }
              .navigationTitle("Export Memories")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .topBarLeading) {
                      Button("Close") { dismiss() }
                  }
              }
              .task { await requestExport() }
          }
      }

      private func requestExport() async {
          stage = .preparing
          do {
              let url = try await ArchiveService.shared.requestExportURL()
              stage = .ready(url)
          } catch {
              stage = .failed(error.localizedDescription)
          }
      }
  }
  ```

- [ ] **Step 2: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Views/Breakup/ExportProgressView.swift
  git commit -m "feat(archive): add ExportProgressView with ShareLink"
  ```

---

## Task 12: ReconnectInviteView

**Files:**
- Create: `BabyTown/Views/Breakup/ReconnectInviteView.swift`

- [ ] **Step 1: Create `BabyTown/Views/Breakup/ReconnectInviteView.swift`**

  ```swift
  import SwiftUI

  /// Shown when a user taps the reconnect banner. Handles both the "send" path
  /// (user is in scrapbook) and the "receive" path (user gets a push notification
  /// carrying an invite, decoded and passed in as `incomingInvite`).
  struct ReconnectInviteView: View {
      var incomingInvite: BreakupReconnectInvite? = nil
      var onReconnected: () -> Void
      @Environment(\.dismiss) private var dismiss

      @State private var stage: Stage = .idle
      @State private var sentInvite: BreakupReconnectInvite?
      @State private var errorMessage: String?

      enum Stage { case idle, sending, waitingForAccept, accepting, done, failed }

      var body: some View {
          NavigationStack {
              Group {
                  if let incoming = incomingInvite {
                      incomingView(incoming)
                  } else {
                      sendView
                  }
              }
              .navigationTitle("Reconnect")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .topBarLeading) {
                      Button("Cancel") { dismiss() }
                  }
              }
          }
      }

      // MARK: - Send path

      private var sendView: some View {
          VStack(spacing: 24) {
              Spacer()
              switch stage {
              case .idle, .failed:
                  Image(systemName: "heart.circle")
                      .font(.system(size: 56))
                      .foregroundStyle(.pink)
                  Text("Invite Them Back")
                      .font(.title3.bold())
                  Text("We'll send them an invitation to reconnect. They can accept even if they've already moved on.")
                      .multilineTextAlignment(.center)
                      .foregroundStyle(.secondary)
                      .padding(.horizontal, 32)
                  if let error = errorMessage {
                      Text(error).font(.caption).foregroundStyle(.red)
                  }
                  Button("Send Invite") {
                      Task { await sendInvite() }
                  }
                  .buttonStyle(.borderedProminent)
                  .padding(.horizontal, 32)

              case .sending:
                  ProgressView("Sending…")

              case .waitingForAccept:
                  Image(systemName: "envelope.open.fill")
                      .font(.system(size: 56))
                      .foregroundStyle(.secondary)
                  Text("Invite Sent")
                      .font(.title3.bold())
                  Text("We've notified them. You'll hear back in the app.")
                      .multilineTextAlignment(.center)
                      .foregroundStyle(.secondary)
                      .padding(.horizontal, 32)
                  Button("Done") { dismiss() }
                      .buttonStyle(.borderedProminent)

              default:
                  EmptyView()
              }
              Spacer()
          }
      }

      // MARK: - Receive path

      private func incomingView(_ invite: BreakupReconnectInvite) -> some View {
          VStack(spacing: 24) {
              Spacer()
              switch stage {
              case .idle, .failed:
                  Image(systemName: "heart.fill")
                      .font(.system(size: 56))
                      .foregroundStyle(.pink)
                  Text("They want to continue your story")
                      .font(.title3.bold())
                  Text("Accept to return to your shared archive and pick up where you left off.")
                      .multilineTextAlignment(.center)
                      .foregroundStyle(.secondary)
                      .padding(.horizontal, 32)
                  if let error = errorMessage {
                      Text(error).font(.caption).foregroundStyle(.red)
                  }
                  Button("Accept") {
                      Task { await acceptInvite(invite) }
                  }
                  .buttonStyle(.borderedProminent)
                  .padding(.horizontal, 32)
                  Button("Decline", role: .cancel) { dismiss() }

              case .accepting:
                  ProgressView("Reconnecting…")

              default:
                  EmptyView()
              }
              Spacer()
          }
      }

      // MARK: - Actions

      private func sendInvite() async {
          stage = .sending
          do {
              sentInvite = try await ArchiveService.shared.sendReconnectInvite()
              stage = .waitingForAccept
          } catch {
              errorMessage = error.localizedDescription
              stage = .failed
          }
      }

      private func acceptInvite(_ invite: BreakupReconnectInvite) async {
          stage = .accepting
          do {
              try await ArchiveService.shared.acceptReconnectInvite(inviteId: invite.id)
              stage = .done
              onReconnected()
          } catch {
              errorMessage = error.localizedDescription
              stage = .failed
          }
      }
  }
  ```

- [ ] **Step 2: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Views/Breakup/ReconnectInviteView.swift
  git commit -m "feat(archive): add ReconnectInviteView (send + receive paths)"
  ```

---

## Task 13: HomeView — Gate on `archivedCouple`

**Files:**
- Modify: `BabyTown/Views/HomeView.swift`
- Modify: `BabyTown/ContentView.swift` (or wherever HomeView is instantiated at the root)

- [ ] **Step 1: Find where `HomeView` is conditionally shown**

  Open `BabyTown/ContentView.swift`. Locate the root view switch — it likely checks `hasCompletedOnboarding` or a relationship stage. Identify exactly where `HomeView` is presented.

- [ ] **Step 2: Add the `archivedCouple` branch**

  In the root content switch (in `ContentView.swift` or wherever the top-level routing lives), add a branch before the `HomeView` case:

  ```swift
  let profile = DataPersistenceManager.shared.loadCoupleProfile()

  switch profile.relationshipStage {
  case .archivedCouple:
      if let bundle = DataPersistenceManager.shared.loadArchiveBundle() {
          ScrapbookHomeView(
              bundle: bundle,
              onStepOut: {
                  // Re-read profile and route to Prelude
                  // (the view hierarchy will update because relationshipStage changed)
              },
              onReconnect: {
                  // Re-read profile and route to officialCouple
              }
          )
      } else {
          // Bundle missing (expired or cleared) — push back to Prelude
          // Set profile to .prelude defensively
      }
  case .officialCouple:
      HomeView(/* existing args */)
  case .prelude:
      // Prelude home (existing or future)
      HomeView(/* existing args */)
  }
  ```

  Match the exact routing pattern already in use in `ContentView.swift`. The point is to route `archivedCouple` to `ScrapbookHomeView` before reaching the live `HomeView`.

- [ ] **Step 3: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 4: Manual verification**

  In the simulator:
  1. Set `profile.relationshipStage = .archivedCouple` in a debug launch and save a stub `ArchiveBundle`
  2. Relaunch the app
  3. Confirm `ScrapbookHomeView` loads, not the live `HomeView`

- [ ] **Step 5: Commit**

  ```bash
  git add BabyTown/Views/HomeView.swift BabyTown/ContentView.swift
  git commit -m "feat(archive): gate HomeView routing on archivedCouple → ScrapbookHomeView"
  ```

---

## Task 14: NotificationManager — Archive Expiry Notifications

**Files:**
- Modify: `BabyTown/Services/NotificationManager.swift`
- Modify: `BabyTown/AppDelegate.swift`

- [ ] **Step 1: Add archive notification identifiers**

  In `NotificationManager.swift`, add these static constants alongside the existing `openCameraNotificationName`:

  ```swift
  static let archiveExpiry7DayIdentifier = "archive_expiry_7day"
  static let archiveExpiry3DayIdentifier = "archive_expiry_3day"
  static let archiveExpiredIdentifier = "archive_expired"
  static let reconnectInviteIdentifier = "reconnect_invite"
  ```

- [ ] **Step 2: Add `scheduleArchiveExpiryNotifications(expiryDate:)`**

  In `NotificationManager.swift`:

  ```swift
  @MainActor
  func scheduleArchiveExpiryNotifications(expiryDate: Date) {
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: [
          Self.archiveExpiry7DayIdentifier,
          Self.archiveExpiry3DayIdentifier,
          Self.archiveExpiredIdentifier
      ])

      func schedule(identifier: String, body: String, fireDate: Date) {
          guard fireDate > Date() else { return }
          let content = UNMutableNotificationContent()
          content.title = "Covela"
          content.body = body
          content.sound = .default
          let comps = Calendar.current.dateComponents(
              [.year, .month, .day, .hour, .minute], from: fireDate)
          let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
          let request = UNNotificationRequest(
              identifier: identifier, content: content, trigger: trigger)
          center.add(request)
      }

      let sevenDayWarning = expiryDate.addingTimeInterval(-7 * 24 * 60 * 60)
      let threeDayWarning = expiryDate.addingTimeInterval(-3 * 24 * 60 * 60)

      schedule(
          identifier: Self.archiveExpiry7DayIdentifier,
          body: "Your shared memories expire in 7 days. Export or extend to keep them.",
          fireDate: sevenDayWarning
      )
      schedule(
          identifier: Self.archiveExpiry3DayIdentifier,
          body: "Your shared memories expire in 3 days. Export or extend to keep them.",
          fireDate: threeDayWarning
      )
      schedule(
          identifier: Self.archiveExpiredIdentifier,
          body: "Your memories have been deleted.",
          fireDate: expiryDate
      )
  }

  @MainActor
  func cancelArchiveExpiryNotifications() {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
          Self.archiveExpiry7DayIdentifier,
          Self.archiveExpiry3DayIdentifier,
          Self.archiveExpiredIdentifier
      ])
  }
  ```

- [ ] **Step 3: Call `scheduleArchiveExpiryNotifications` from `ArchiveService`**

  In `ArchiveService.initiateBreakup()`, after `persistence.saveCoupleProfile(updated)`, add:

  ```swift
  NotificationManager.shared.scheduleArchiveExpiryNotifications(expiryDate: expiryDate)
  ```

  In `ArchiveService.extendRetention()`, after `persistence.saveCoupleProfile(profile)`, add:

  ```swift
  NotificationManager.shared.scheduleArchiveExpiryNotifications(expiryDate: newExpiry)
  ```

  In `ArchiveService.stepOut()`, after `persistence.saveCoupleProfile(updated)`, add:

  ```swift
  NotificationManager.shared.cancelArchiveExpiryNotifications()
  ```

  In `ArchiveService.acceptReconnectInvite(inviteId:)`, after `persistence.saveCoupleProfile(updated)`, add:

  ```swift
  NotificationManager.shared.cancelArchiveExpiryNotifications()
  ```

- [ ] **Step 4: Handle archive notification taps in `AppDelegate`**

  In `AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)`, add handling for archive identifiers alongside the existing `daily_morning_notification` case:

  ```swift
  let identifier = response.notification.request.identifier
  Task { @MainActor in
      NotificationManager.shared.acknowledgeNotification(identifier: identifier)
  }

  switch identifier {
  case "daily_morning_notification":
      NotificationCenter.default.post(
          name: NotificationManager.openCameraNotificationName, object: nil)
  case NotificationManager.archiveExpiry7DayIdentifier,
       NotificationManager.archiveExpiry3DayIdentifier:
      // Route user to scrapbook — no additional action needed;
      // HomeView routing will show ScrapbookHomeView automatically.
      break
  case NotificationManager.archiveExpiredIdentifier:
      // Archive is wiped server-side. Transition profile to .prelude defensively.
      Task { @MainActor in
          var profile = DataPersistenceManager.shared.loadCoupleProfile()
          if profile.relationshipStage == .archivedCouple {
              profile.relationshipStage = .prelude
              profile.breakupDate = nil
              profile.archiveExpiryDate = nil
              DataPersistenceManager.shared.saveCoupleProfile(profile)
              DataPersistenceManager.shared.deleteArchiveBundle()
          }
      }
  default:
      break
  }
  completionHandler()
  ```

- [ ] **Step 5: Build the project**

  Press `Cmd+B`.  
  Expected: clean build.

- [ ] **Step 6: Manual verification**

  Set `expiryDate` to `Date() + 15` seconds in a debug build. Run the app. Background it. Confirm the notification fires. Tap it — confirm the app opens to the scrapbook.

- [ ] **Step 7: Commit**

  ```bash
  git add BabyTown/Services/NotificationManager.swift BabyTown/Services/ArchiveService.swift BabyTown/AppDelegate.swift
  git commit -m "feat(archive): schedule and handle archive expiry notifications"
  ```

---

## Spec Verification Checklist

Run these manually in the simulator against a debug build once all tasks are complete:

- [ ] **1.** Initiate breakup → confirm upload progress screen appears. Verify both users enter `archivedCouple` (check `DataPersistenceManager.shared.loadCoupleProfile().relationshipStage`).
- [ ] **2.** Verify scrapbook home shows all Moments, frozen garden, frozen pet, retention countdown.
- [ ] **3.** Verify no editing or pinning is possible — all interactive controls absent.
- [ ] **4.** Tap Extend → verify `archiveExpiryDate` resets to `now + 30 days`. No notification fired.
- [ ] **5.** Tap Export → ZIP share sheet appears with photos, voice notes, captions.
- [ ] **6.** One user steps out → confirm they land on Prelude home. Confirm local archive bundle is deleted.
- [ ] **7.** User in scrapbook taps Reconnect → invite sent. Other user sees modal (simulate via `ReconnectInviteView(incomingInvite:)`).
- [ ] **8.** Reconnect accepted → both return to `officialCouple`. Archive bundle cleared. Garden and pet restored from snapshot.
- [ ] **9.** Reconnect declined → scrapbook continues for sender, invite dismissed.
- [ ] **10.** Both step out → archive bundle deleted locally on both devices.
- [ ] **11.** Set `expiryDate = Date() + 15s` → confirm 3 push notifications fire at correct times.
- [ ] **12.** `archiveExpired` notification tap → profile defensively transitions to `.prelude`, bundle deleted.

---

## Out-of-Scope Dependency

**Timeline archive chapter on reconnect:** The spec requires that when reconnect is accepted, the breakup period appears as a labeled chapter in the shared timeline — *"[Date] – [Date]: A chapter apart."* This feature depends on the timeline chapter system defined in the Prelude spec (`PreludeChapter`, `PreludeChapterView`). It is not implemented here. Once the Prelude timeline system is built, add a call in `ArchiveService.acceptReconnectInvite` to write an archive chapter spanning `bundle.breakupDate → Date()` to the timeline persistence layer.
