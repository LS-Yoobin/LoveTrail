# Prelude System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `prelude` relationship stage where a solo user captures notes, firsts, voice memos, and reasons privately, then invites their partner via a cinematic gift reveal that unlocks the full couple app.

**Architecture:** Three relationship stages (`prelude`, `officialCouple`, `archivedCouple`) stored on `CoupleProfile`. `PreludeViewModel` manages capture CRUD and stage transitions. `ContentView` gates post-onboarding routing based on stage — prelude users see `PreludeHomeView`, official couples see the existing `HomeView`. All capture data persists to `prelude_captures.json` via the existing `DataPersistenceManager` singleton pattern. Voice memo audio files live in a `PreludeVoiceMemos/` subdirectory under Documents.

**Tech Stack:** SwiftUI, AVFoundation (voice recording — wrap existing `VoiceRecorder.swift`), `Codable` JSON persistence, `@MainActor ObservableObject` ViewModels, `BabyTownTheme` for styling.

---

## File Map

### New Files
| File | Purpose |
|---|---|
| `BabyTown/Models/RelationshipStage.swift` | Stage enum |
| `BabyTown/Models/PreludeCapture.swift` | Polymorphic capture model |
| `BabyTown/Models/PreludeChapter.swift` | Permanent shared chapter model |
| `BabyTown/ViewModels/PreludeViewModel.swift` | Capture CRUD + stage transitions |
| `BabyTown/Views/Prelude/PreludeHomeView.swift` | Solo capture feed + quick-add bar |
| `BabyTown/Views/Prelude/CaptureEditorView.swift` | Note / First / Reason editors with prompts |
| `BabyTown/Views/Prelude/VoiceMemoRecorderView.swift` | In-app voice recording UI |
| `BabyTown/Views/Prelude/GiftCurationView.swift` | Select captures + preview + send invite |
| `BabyTown/Views/Prelude/GiftRevealView.swift` | Partner's cinematic first-launch |
| `BabyTown/Views/Prelude/PreludeChapterView.swift` | Permanent chapter in shared timeline |
| `BabyTown/Views/Prelude/ArchiveFlowView.swift` | Archive confirmation (stub) |
| `BabyTown/Views/Prelude/ReconnectFlowView.swift` | Reconnect confirmation (stub) |

### Modified Files
| File | Change |
|---|---|
| `BabyTown/Models/CoupleProfile.swift` | Add `relationshipStage: RelationshipStage`, `inviteSent: Bool` |
| `BabyTown/Services/DataPersistenceManager.swift` | Add prelude captures + chapter + voice memo persistence |
| `BabyTown/ContentView.swift` | Gate post-onboarding routing on `relationshipStage` |

---

## Task 1: RelationshipStage Enum + CoupleProfile Fields

**Files:**
- Create: `BabyTown/Models/RelationshipStage.swift`
- Modify: `BabyTown/Models/CoupleProfile.swift`

- [ ] **Step 1: Create RelationshipStage.swift**

```swift
// BabyTown/Models/RelationshipStage.swift
import Foundation

enum RelationshipStage: String, Codable {
    case prelude
    case officialCouple
    case archivedCouple
}
```

- [ ] **Step 2: Add fields to CoupleProfile**

Open `BabyTown/Models/CoupleProfile.swift`. Add two new stored properties after `watchTogetherTVScale`:

```swift
    var relationshipStage: RelationshipStage
    var inviteSent: Bool
```

Update `init` to include defaults:

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
        relationshipStage: RelationshipStage = .prelude,
        inviteSent: Bool = false
    ) {
        // ... existing assignments ...
        self.relationshipStage = relationshipStage
        self.inviteSent = inviteSent
    }
```

Add cases to `CodingKeys`:

```swift
    enum CodingKeys: String, CodingKey {
        case displayName, specialDates, stickers, profileNote, profileNotePosition
        case recordPlayerPosition, recordPlayerScale
        case watchTogetherTVPosition, watchTogetherTVScale
        case relationshipStage, inviteSent
    }
```

Add tolerant decode lines at the bottom of the `init(from:)` body:

```swift
        relationshipStage = try c.decodeIfPresent(RelationshipStage.self, forKey: .relationshipStage) ?? .prelude
        inviteSent = try c.decodeIfPresent(Bool.self, forKey: .inviteSent) ?? false
```

- [ ] **Step 3: Build to verify**

In Xcode: Cmd+B. Expected: build succeeds with no errors. The tolerant decode means existing persisted `couple_profile.json` files without these keys will decode cleanly and default to `.prelude` / `false`.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Models/RelationshipStage.swift BabyTown/Models/CoupleProfile.swift
git commit -m "feat: add RelationshipStage enum and CoupleProfile prelude fields"
```

---

## Task 2: PreludeCapture Model

**Files:**
- Create: `BabyTown/Models/PreludeCapture.swift`

- [ ] **Step 1: Create PreludeCapture.swift**

```swift
// BabyTown/Models/PreludeCapture.swift
import Foundation

struct PreludeCapture: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let type: CaptureType
    var isIncludedInGift: Bool
    var isPartnerRetroactive: Bool

    var noteText: String?
    var notePhotoId: UUID?
    var firstLabel: String?
    var voiceMemoFileId: String?
    var reasonText: String?

    enum CaptureType: String, Codable {
        case note, first, voiceMemo, reason
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: CaptureType,
        isIncludedInGift: Bool = true,
        isPartnerRetroactive: Bool = false,
        noteText: String? = nil,
        notePhotoId: UUID? = nil,
        firstLabel: String? = nil,
        voiceMemoFileId: String? = nil,
        reasonText: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.isIncludedInGift = isIncludedInGift
        self.isPartnerRetroactive = isPartnerRetroactive
        self.noteText = noteText
        self.notePhotoId = notePhotoId
        self.firstLabel = firstLabel
        self.voiceMemoFileId = voiceMemoFileId
        self.reasonText = reasonText
    }

    var displayTitle: String {
        switch type {
        case .note: return noteText?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60).description ?? "Note"
        case .first: return firstLabel ?? "A First"
        case .voiceMemo: return "Voice Memo"
        case .reason: return reasonText?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60).description ?? "A Reason"
        }
    }

    var typeLabel: String {
        switch type {
        case .note: return "Note"
        case .first: return "First"
        case .voiceMemo: return "Voice"
        case .reason: return "Reason"
        }
    }

    var typeIcon: String {
        switch type {
        case .note: return "pencil.and.scribble"
        case .first: return "star.fill"
        case .voiceMemo: return "mic.fill"
        case .reason: return "heart.fill"
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/PreludeCapture.swift
git commit -m "feat: add PreludeCapture model"
```

---

## Task 3: PreludeChapter Model

**Files:**
- Create: `BabyTown/Models/PreludeChapter.swift`

- [ ] **Step 1: Create PreludeChapter.swift**

```swift
// BabyTown/Models/PreludeChapter.swift
import Foundation

struct PreludeChapter: Codable, Equatable {
    let startDate: Date
    let officialDate: Date
    let creatorUserId: String
    let partnerUserId: String
    var giftCaptureIds: [UUID]
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/PreludeChapter.swift
git commit -m "feat: add PreludeChapter model"
```

---

## Task 4: DataPersistenceManager — Prelude Persistence

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

- [ ] **Step 1: Add file URL properties**

Inside `DataPersistenceManager`, after the `memoryCanvasesFileURL` property, add:

```swift
    private var preludeCapturesFileURL: URL {
        documentsDirectory.appendingPathComponent("prelude_captures.json")
    }

    private var preludeChapterFileURL: URL {
        documentsDirectory.appendingPathComponent("prelude_chapter.json")
    }

    private var preludeVoiceMemosDirectory: URL {
        documentsDirectory.appendingPathComponent("PreludeVoiceMemos")
    }

    private func preludeVoiceMemoURL(fileId: String) -> URL {
        preludeVoiceMemosDirectory.appendingPathComponent(fileId)
    }
```

- [ ] **Step 2: Create voice memo directory in createDirectoriesIfNeeded**

Add to `createDirectoriesIfNeeded()`:

```swift
        if !fileManager.fileExists(atPath: preludeVoiceMemosDirectory.path) {
            try? fileManager.createDirectory(at: preludeVoiceMemosDirectory, withIntermediateDirectories: true)
        }
```

- [ ] **Step 3: Add save/load methods for captures**

After `loadMemoryCanvases()` / `saveMemoryCanvas()`, add:

```swift
    // MARK: - Prelude

    func savePreludeCaptures(_ captures: [PreludeCapture]) {
        guard let data = try? encoder.encode(captures) else { return }
        try? data.write(to: preludeCapturesFileURL)
    }

    func loadPreludeCaptures() -> [PreludeCapture] {
        guard fileManager.fileExists(atPath: preludeCapturesFileURL.path),
              let data = try? Data(contentsOf: preludeCapturesFileURL),
              let captures = try? decoder.decode([PreludeCapture].self, from: data) else {
            return []
        }
        return captures
    }

    func savePreludeChapter(_ chapter: PreludeChapter) {
        guard let data = try? encoder.encode(chapter) else { return }
        try? data.write(to: preludeChapterFileURL)
    }

    func loadPreludeChapter() -> PreludeChapter? {
        guard fileManager.fileExists(atPath: preludeChapterFileURL.path),
              let data = try? Data(contentsOf: preludeChapterFileURL),
              let chapter = try? decoder.decode(PreludeChapter.self, from: data) else {
            return nil
        }
        return chapter
    }

    func savePreludeVoiceMemo(data: Data, fileId: String) {
        let url = preludeVoiceMemoURL(fileId: fileId)
        try? data.write(to: url)
    }

    func loadPreludeVoiceMemoData(fileId: String) -> Data? {
        let url = preludeVoiceMemoURL(fileId: fileId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func deletePreludeVoiceMemo(fileId: String) {
        try? fileManager.removeItem(at: preludeVoiceMemoURL(fileId: fileId))
    }
```

- [ ] **Step 4: Update clearAllData() to include prelude data**

Add to the `clearAllData()` method body:

```swift
        try? fileManager.removeItem(at: preludeCapturesFileURL)
        try? fileManager.removeItem(at: preludeChapterFileURL)
        try? fileManager.removeItem(at: preludeVoiceMemosDirectory)
```

- [ ] **Step 5: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat: add prelude persistence methods to DataPersistenceManager"
```

---

## Task 5: PreludeViewModel

**Files:**
- Create: `BabyTown/ViewModels/PreludeViewModel.swift`

- [ ] **Step 1: Create PreludeViewModel.swift**

```swift
// BabyTown/ViewModels/PreludeViewModel.swift
import Foundation
import Combine

@MainActor
final class PreludeViewModel: ObservableObject {

    @Published var captures: [PreludeCapture] = []
    @Published var stage: RelationshipStage = .prelude
    @Published var inviteSent: Bool = false

    private let dpm = DataPersistenceManager.shared

    init() {
        load()
    }

    // MARK: - Load / Save

    func load() {
        captures = dpm.loadPreludeCaptures()
        let profile = dpm.loadCoupleProfile()
        stage = profile.relationshipStage
        inviteSent = profile.inviteSent
    }

    private func saveCaptures() {
        dpm.savePreludeCaptures(captures)
    }

    private func saveStage() {
        var profile = dpm.loadCoupleProfile()
        profile.relationshipStage = stage
        profile.inviteSent = inviteSent
        dpm.saveCoupleProfile(profile)
    }

    // MARK: - Capture CRUD

    func addCapture(_ capture: PreludeCapture) {
        captures.insert(capture, at: 0)
        saveCaptures()
    }

    func updateCapture(_ capture: PreludeCapture) {
        guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[idx] = capture
        saveCaptures()
    }

    func deleteCapture(_ capture: PreludeCapture) {
        if let fileId = capture.voiceMemoFileId {
            dpm.deletePreludeVoiceMemo(fileId: fileId)
        }
        captures.removeAll { $0.id == capture.id }
        saveCaptures()
    }

    func toggleGiftInclusion(for capture: PreludeCapture) {
        guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[idx].isIncludedInGift.toggle()
        saveCaptures()
    }

    // MARK: - Gift

    var giftCaptures: [PreludeCapture] {
        captures.filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
    }

    // MARK: - Stage Transitions

    func sendInvite() {
        inviteSent = true
        saveStage()
    }

    func transitionToOfficial(partnerUserId: String = "partner") {
        let firstCaptureDate = captures.map(\.createdAt).min() ?? Date()
        let chapter = PreludeChapter(
            startDate: firstCaptureDate,
            officialDate: Date(),
            creatorUserId: "local",
            partnerUserId: partnerUserId,
            giftCaptureIds: giftCaptures.map(\.id)
        )
        dpm.savePreludeChapter(chapter)
        stage = .officialCouple
        inviteSent = false
        saveStage()
    }

    func archiveRelationship() {
        stage = .archivedCouple
        saveStage()
    }

    func reconnect() {
        stage = .officialCouple
        saveStage()
    }

    // MARK: - Partner Retroactive

    func addPartnerRetroactiveCapture(_ capture: PreludeCapture) {
        var updated = capture
        updated = PreludeCapture(
            id: capture.id,
            createdAt: capture.createdAt,
            type: capture.type,
            isIncludedInGift: true,
            isPartnerRetroactive: true,
            noteText: capture.noteText,
            notePhotoId: capture.notePhotoId,
            firstLabel: capture.firstLabel,
            voiceMemoFileId: capture.voiceMemoFileId,
            reasonText: capture.reasonText
        )
        captures.append(updated)
        saveCaptures()
    }

    // MARK: - Reflection Prompts

    static let notePrompts: [String] = [
        "What made you think about them today?",
        "What surprised you about them this week?",
        "What do you like about who you are when you're around them?",
        "What's something small they did that you keep thinking about?"
    ]

    static let firstOptions: [String] = [
        "First text conversation",
        "First time they made you laugh",
        "First date",
        "First time you thought \"I'm in trouble\"",
        "First time you felt nervous around them",
        "First time you imagined a future with them"
    ]

    static let reasonPrompt = "One reason I'm falling for you:"
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/ViewModels/PreludeViewModel.swift
git commit -m "feat: add PreludeViewModel with capture CRUD and stage transitions"
```

---

## Task 6: PreludeHomeView

**Files:**
- Create: `BabyTown/Views/Prelude/PreludeHomeView.swift`

- [ ] **Step 1: Create the Prelude directory and PreludeHomeView.swift**

```bash
mkdir -p /path/to/BabyTown/Views/Prelude
```

```swift
// BabyTown/Views/Prelude/PreludeHomeView.swift
import SwiftUI

struct PreludeHomeView: View {

    @StateObject private var viewModel = PreludeViewModel()
    @State private var showCaptureEditor = false
    @State private var editorType: PreludeCapture.CaptureType = .note
    @State private var editingCapture: PreludeCapture?
    @State private var showGiftCuration = false

    private var displayName: String {
        DataPersistenceManager.shared.loadCoupleProfile().displayName ?? "them"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BabyTownTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                inviteBanner
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                if viewModel.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }
            }

            quickAddBar
                .padding(.bottom, 28)
        }
        .sheet(isPresented: $showCaptureEditor, onDismiss: { editingCapture = nil }) {
            CaptureEditorView(
                type: editorType,
                existing: editingCapture,
                viewModel: viewModel,
                onSave: { showCaptureEditor = false },
                onCancel: { showCaptureEditor = false }
            )
        }
        .fullScreenCover(isPresented: $showGiftCuration) {
            GiftCurationView(viewModel: viewModel, onDone: { showGiftCuration = false })
        }
    }

    // MARK: - Invite Banner

    private var inviteBanner: some View {
        Button {
            showGiftCuration = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BabyTownTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.inviteSent {
                        Text("Waiting for them to accept…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    } else {
                        Text("Invite \(displayName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                        Text("Share your Prelude when you're ready")
                            .font(.system(size: 12))
                            .foregroundStyle(BabyTownTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Capture List

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.captures) { capture in
                    CaptureRowCard(capture: capture)
                        .onTapGesture {
                            editingCapture = capture
                            editorType = capture.type
                            showCaptureEditor = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { viewModel.deleteCapture(capture) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.4))
            Text("Start capturing your story")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Text("Notes, firsts, voice memos, and reasons —\nall private until you choose to share.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 0) {
            ForEach(quickAddButtons, id: \.type) { btn in
                Button {
                    editorType = btn.type
                    editingCapture = nil
                    showCaptureEditor = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: btn.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                        Text(btn.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            Capsule()
                .fill(BabyTownTheme.accentGradient)
                .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 12, y: 4)
        )
        .padding(.horizontal, 24)
    }

    private struct QuickAddButton {
        let type: PreludeCapture.CaptureType
        let icon: String
        let label: String
    }

    private let quickAddButtons: [QuickAddButton] = [
        .init(type: .note, icon: "pencil.and.scribble", label: "Note"),
        .init(type: .first, icon: "star.fill", label: "First"),
        .init(type: .voiceMemo, icon: "mic.fill", label: "Voice"),
        .init(type: .reason, icon: "heart.fill", label: "Reason")
    ]
}

// MARK: - CaptureRowCard

private struct CaptureRowCard: View {
    let capture: PreludeCapture

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(BabyTownTheme.cardBackground)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)

                Text(capture.displayTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(2)

                Text(capture.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
    }
}

#Preview {
    PreludeHomeView()
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed (CaptureEditorView and GiftCurationView don't exist yet, so temporarily comment out the two sheet/fullScreenCover blocks to get a green build).

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeHomeView.swift
git commit -m "feat: add PreludeHomeView with capture feed and quick-add bar"
```

---

## Task 7: CaptureEditorView

**Files:**
- Create: `BabyTown/Views/Prelude/CaptureEditorView.swift`

- [ ] **Step 1: Create CaptureEditorView.swift**

```swift
// BabyTown/Views/Prelude/CaptureEditorView.swift
import SwiftUI

struct CaptureEditorView: View {

    let type: PreludeCapture.CaptureType
    let existing: PreludeCapture?
    @ObservedObject var viewModel: PreludeViewModel
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var noteText: String = ""
    @State private var firstLabel: String = ""
    @State private var customFirstLabel: String = ""
    @State private var reasonText: String = ""
    @State private var isGiftIncluded: Bool = true
    @State private var showVoiceRecorder = false
    @State private var savedVoiceMemoFileId: String?
    @State private var promptIndex: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    giftToggle
                    editorContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: loadExisting)
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch type {
        case .note: return "Note"
        case .first: return "A First"
        case .voiceMemo: return "Voice Memo"
        case .reason: return "Reason"
        }
    }

    // MARK: - Gift Toggle

    private var giftToggle: some View {
        Toggle(isOn: $isGiftIncluded) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(BabyTownTheme.accent)
                Text("Include in gift")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
        }
        .tint(BabyTownTheme.accent)
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        switch type {
        case .note:
            noteEditor
        case .first:
            firstEditor
        case .voiceMemo:
            voiceMemoEditor
        case .reason:
            reasonEditor
        }
    }

    // MARK: - Note Editor

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.notePrompts[promptIndex % PreludeViewModel.notePrompts.count])

            TextEditor(text: $noteText)
                .frame(minHeight: 160)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
                .font(.system(size: 16))

            Button("Different prompt") {
                promptIndex += 1
            }
            .font(.system(size: 13))
            .foregroundStyle(BabyTownTheme.accent)
        }
    }

    // MARK: - First Editor

    private var firstEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a first or write your own")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)

            ForEach(PreludeViewModel.firstOptions, id: \.self) { option in
                Button {
                    firstLabel = option
                    customFirstLabel = ""
                } label: {
                    HStack {
                        Text(option)
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if firstLabel == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BabyTownTheme.accent)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(firstLabel == option ? BabyTownTheme.accentSoft : BabyTownTheme.cardBackground)
                    )
                }
                .buttonStyle(.plain)
            }

            TextField("Or write your own first…", text: $customFirstLabel)
                .font(.system(size: 15))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
                .onChange(of: customFirstLabel) { _, val in
                    if !val.isEmpty { firstLabel = val }
                }
        }
    }

    // MARK: - Voice Memo Editor

    private var voiceMemoEditor: some View {
        VStack(spacing: 16) {
            Text("Record up to 3 minutes. Raw, in the moment.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VoiceMemoRecorderView(
                existingFileId: existing?.voiceMemoFileId,
                onSaved: { fileId in
                    savedVoiceMemoFileId = fileId
                }
            )
        }
    }

    // MARK: - Reason Editor

    private var reasonEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.reasonPrompt)

            TextField("One reason I'm falling for you…", text: $reasonText, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .font(.system(size: 16))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.cardBackground)
                )
        }
    }

    // MARK: - Helpers

    private func promptChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(BabyTownTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(BabyTownTheme.accentSoft)
            )
    }

    private var canSave: Bool {
        switch type {
        case .note: return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .first: return !firstLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .voiceMemo: return savedVoiceMemoFileId != nil || existing?.voiceMemoFileId != nil
        case .reason: return !reasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func loadExisting() {
        guard let c = existing else { return }
        isGiftIncluded = c.isIncludedInGift
        noteText = c.noteText ?? ""
        firstLabel = c.firstLabel ?? ""
        reasonText = c.reasonText ?? ""
        savedVoiceMemoFileId = c.voiceMemoFileId
    }

    private func save() {
        let resolvedFileId: String?
        switch type {
        case .voiceMemo:
            resolvedFileId = savedVoiceMemoFileId ?? existing?.voiceMemoFileId
        default:
            resolvedFileId = nil
        }

        let capture = PreludeCapture(
            id: existing?.id ?? UUID(),
            createdAt: existing?.createdAt ?? Date(),
            type: type,
            isIncludedInGift: isGiftIncluded,
            isPartnerRetroactive: existing?.isPartnerRetroactive ?? false,
            noteText: type == .note ? noteText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstLabel: type == .first ? firstLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            voiceMemoFileId: resolvedFileId,
            reasonText: type == .reason ? reasonText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )

        if existing != nil {
            viewModel.updateCapture(capture)
        } else {
            viewModel.addCapture(capture)
        }
        onSave()
    }
}

#Preview {
    CaptureEditorView(
        type: .note,
        existing: nil,
        viewModel: PreludeViewModel(),
        onSave: {},
        onCancel: {}
    )
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed (VoiceMemoRecorderView doesn't exist yet; temporarily stub it as a `Text("Voice recorder coming next")` to get a green build).

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/Prelude/CaptureEditorView.swift
git commit -m "feat: add CaptureEditorView for all four capture types"
```

---

## Task 8: VoiceMemoRecorderView

**Files:**
- Create: `BabyTown/Views/Prelude/VoiceMemoRecorderView.swift`

- [ ] **Step 1: Create VoiceMemoRecorderView.swift**

This view wraps the existing `VoiceRecorder` (which already handles AVFoundation, permissions, record/play). It saves the recorded file to the prelude voice memos directory and calls back with the file ID.

```swift
// BabyTown/Views/Prelude/VoiceMemoRecorderView.swift
import SwiftUI
import AVFoundation

struct VoiceMemoRecorderView: View {

    let existingFileId: String?
    var onSaved: (String) -> Void

    @StateObject private var recorder = VoiceRecorder()
    @State private var savedFileId: String?
    @State private var hasMicPermission: Bool = false

    private let maxDuration: TimeInterval = 180

    var body: some View {
        VStack(spacing: 24) {
            durationDisplay

            recordButton

            if recorder.hasRecording || savedFileId != nil {
                playbackControls
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
        )
        .onAppear {
            checkMicPermission()
            if let fileId = existingFileId, let data = DataPersistenceManager.shared.loadPreludeVoiceMemoData(fileId: fileId) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileId)
                try? data.write(to: tempURL)
                recorder.loadRecording(from: tempURL.path)
                savedFileId = fileId
            }
        }
        .onChange(of: recorder.recordingDuration) { _, dur in
            if dur >= maxDuration {
                recorder.stopRecording()
                persistRecording()
            }
        }
    }

    // MARK: - Duration Display

    private var durationDisplay: some View {
        Text(durationString(recorder.recordingDuration))
            .font(.system(size: 48, weight: .thin, design: .monospaced))
            .foregroundStyle(recorder.isRecording ? BabyTownTheme.accent : BabyTownTheme.textSecondary)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording()
                persistRecording()
            } else {
                if hasMicPermission {
                    if savedFileId != nil {
                        // Clear old recording before starting new one
                        if let old = savedFileId {
                            DataPersistenceManager.shared.deletePreludeVoiceMemo(fileId: old)
                        }
                        savedFileId = nil
                        recorder.deleteRecording()
                    }
                    recorder.startRecording()
                } else {
                    requestMicPermission()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? BabyTownTheme.accentDeep : BabyTownTheme.accent)
                    .frame(width: 72, height: 72)

                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 8, y: 4)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 24) {
            Button {
                if recorder.isPlaying {
                    recorder.stopPlaying()
                } else {
                    recorder.playRecording()
                }
            } label: {
                Image(systemName: recorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            .buttonStyle(.plain)

            Button {
                if let old = savedFileId {
                    DataPersistenceManager.shared.deletePreludeVoiceMemo(fileId: old)
                }
                savedFileId = nil
                recorder.deleteRecording()
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func persistRecording() {
        let fileId = "\(UUID().uuidString).m4a"
        guard let tempPath = recorder.saveRecording(for: UUID()) else { return }
        let tempURL = URL(fileURLWithPath: tempPath)
        guard let data = try? Data(contentsOf: tempURL) else { return }
        DataPersistenceManager.shared.savePreludeVoiceMemo(data: data, fileId: fileId)
        savedFileId = fileId
        onSaved(fileId)
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - floor(duration)) * 10)
        return String(format: "%01d:%02d.%01d", minutes, seconds, tenths)
    }

    private func checkMicPermission() {
        hasMicPermission = AVAudioApplication.shared.recordPermission == .granted
    }

    private func requestMicPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in self.hasMicPermission = granted }
        }
    }
}

#Preview {
    VoiceMemoRecorderView(existingFileId: nil, onSaved: { _ in })
        .padding()
}
```

- [ ] **Step 2: Remove the stub from CaptureEditorView**

In `CaptureEditorView.swift`, replace the temporary stub `Text("Voice recorder coming next")` in `voiceMemoEditor` with the real `VoiceMemoRecorderView(...)` call (already written in Task 7).

- [ ] **Step 3: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/Prelude/VoiceMemoRecorderView.swift BabyTown/Views/Prelude/CaptureEditorView.swift
git commit -m "feat: add VoiceMemoRecorderView and wire into CaptureEditorView"
```

---

## Task 9: GiftCurationView

**Files:**
- Create: `BabyTown/Views/Prelude/GiftCurationView.swift`

- [ ] **Step 1: Create GiftCurationView.swift**

```swift
// BabyTown/Views/Prelude/GiftCurationView.swift
import SwiftUI

struct GiftCurationView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDone: () -> Void

    @State private var showPreview = false
    @State private var showInviteSent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }

                sendButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .padding(.top, 12)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Your Gift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
                if !viewModel.giftCaptures.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Preview") { showPreview = true }
                            .font(.system(size: 15))
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            GiftPreviewSheet(captures: viewModel.giftCaptures)
        }
        .alert("Invite sent!", isPresented: $showInviteSent) {
            Button("Got it") { onDone() }
        } message: {
            Text("Your partner will receive your Prelude when they download the app. You can still add captures and update your gift until they accept.")
        }
    }

    // MARK: - Capture List

    private var captureList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle which captures to include in your gift. Private captures stay private forever.")
                    .font(.system(size: 13))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .padding(.top, 8)

                ForEach(viewModel.captures) { capture in
                    GiftCaptureRow(
                        capture: capture,
                        onToggle: { viewModel.toggleGiftInclusion(for: capture) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No captures yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Text("Go back and add notes, firsts, voice memos, or reasons.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            viewModel.sendInvite()
            showInviteSent = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                Text(viewModel.inviteSent ? "Resend Invite" : "Send Invite")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(viewModel.giftCaptures.isEmpty
                        ? BabyTownTheme.accent.opacity(0.35)
                        : BabyTownTheme.accentGradient)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.giftCaptures.isEmpty)
    }
}

// MARK: - GiftCaptureRow

private struct GiftCaptureRow: View {
    let capture: PreludeCapture
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(BabyTownTheme.cardBackground))

            VStack(alignment: .leading, spacing: 2) {
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
                    .textCase(.uppercase)
                Text(capture.displayTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: .init(get: { capture.isIncludedInGift }, set: { _ in onToggle() }))
                .tint(BabyTownTheme.accent)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(capture.isIncludedInGift ? BabyTownTheme.accentSoft : BabyTownTheme.cardBackground)
        )
    }
}

// MARK: - GiftPreviewSheet

private struct GiftPreviewSheet: View {
    let captures: [PreludeCapture]
    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.background.ignoresSafeArea()

                if captures.isEmpty {
                    Text("No captures included in gift yet.")
                        .foregroundStyle(BabyTownTheme.textSecondary)
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(captures.enumerated()), id: \.offset) { idx, capture in
                            GiftCardView(capture: capture)
                                .tag(idx)
                                .padding(.horizontal, 28)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .navigationTitle("Preview (\(currentIndex + 1)/\(captures.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - GiftCardView

struct GiftCardView: View {
    let capture: PreludeCapture

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accent)

            Text(capture.typeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
                .textCase(.uppercase)

            Text(capture.displayTitle)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(capture.createdAt, style: .date)
                .font(.system(size: 13))
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BabyTownTheme.cardBackground)
                .shadow(color: BabyTownTheme.cardShadow, radius: 8, y: 4)
        )
    }
}

#Preview {
    GiftCurationView(
        viewModel: PreludeViewModel(),
        onDone: {}
    )
}
```

- [ ] **Step 2: Remove the GiftCurationView comment stubs from PreludeHomeView**

In `PreludeHomeView.swift`, restore the `.fullScreenCover(isPresented: $showGiftCuration)` block that was temporarily commented out in Task 6.

- [ ] **Step 3: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/Prelude/GiftCurationView.swift BabyTown/Views/Prelude/PreludeHomeView.swift
git commit -m "feat: add GiftCurationView with capture selection, preview, and invite send"
```

---

## Task 10: GiftRevealView

**Files:**
- Create: `BabyTown/Views/Prelude/GiftRevealView.swift`

- [ ] **Step 1: Create GiftRevealView.swift**

```swift
// BabyTown/Views/Prelude/GiftRevealView.swift
import SwiftUI

struct GiftRevealView: View {

    let captures: [PreludeCapture]
    let creatorName: String
    let firstCaptureDate: Date
    @ObservedObject var viewModel: PreludeViewModel
    var onComplete: () -> Void

    @State private var currentIndex: Int = 0
    @State private var showFinalCard: Bool = false

    private var isOnFinalCard: Bool {
        currentIndex >= captures.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BabyTownTheme.accentDeep.opacity(0.85), BabyTownTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isOnFinalCard {
                finalCard
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                captureCard(captures[currentIndex])
                    .id(currentIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentIndex)
        .animation(.easeInOut(duration: 0.5), value: isOnFinalCard)
    }

    // MARK: - Capture Card

    private func captureCard(_ capture: PreludeCapture) -> some View {
        VStack(spacing: 0) {
            Spacer()

            GiftCardView(capture: capture)
                .padding(.horizontal, 28)

            Spacer()

            advanceButton
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
        }
    }

    private var advanceButton: some View {
        Button {
            withAnimation {
                currentIndex += 1
            }
        } label: {
            Text(currentIndex < captures.count - 1 ? "Next →" : "See what's next →")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Final Card

    private var finalCard: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                Text("\(creatorName) has been writing this since \(firstCaptureDate, style: .date).")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Now you're here.")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                viewModel.transitionToOfficial()
                onComplete()
            } label: {
                Text("Start your story together →")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule().fill(.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    GiftRevealView(
        captures: [
            PreludeCapture(type: .note, noteText: "I keep thinking about the way you laugh."),
            PreludeCapture(type: .reason, reasonText: "The way you always order the weirdest thing on the menu.")
        ],
        creatorName: "Alex",
        firstCaptureDate: Date().addingTimeInterval(-60 * 60 * 24 * 14),
        viewModel: PreludeViewModel(),
        onComplete: {}
    )
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/Prelude/GiftRevealView.swift
git commit -m "feat: add GiftRevealView cinematic partner first-launch experience"
```

---

## Task 11: PreludeChapterView

**Files:**
- Create: `BabyTown/Views/Prelude/PreludeChapterView.swift`

- [ ] **Step 1: Create PreludeChapterView.swift**

```swift
// BabyTown/Views/Prelude/PreludeChapterView.swift
import SwiftUI

struct PreludeChapterView: View {

    let chapter: PreludeChapter
    let captures: [PreludeCapture]
    var isReadOnly: Bool = false
    var onDismiss: () -> Void

    private let dpm = DataPersistenceManager.shared

    private var giftCaptures: [PreludeCapture] {
        let ids = Set(chapter.giftCaptureIds)
        return captures
            .filter { ids.contains($0.id) || $0.isPartnerRetroactive }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    chapterHeader
                        .padding(.horizontal, 24)

                    Divider().padding(.horizontal, 24)

                    ForEach(giftCaptures) { capture in
                        chapterCaptureRow(capture)
                            .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Before We Were Official")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    // MARK: - Header

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before We Were Official")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Text("\(chapter.startDate, style: .date) – \(chapter.officialDate, style: .date)")
                .font(.system(size: 13))
                .foregroundStyle(BabyTownTheme.textSecondary)

            if isReadOnly {
                Label("Read-only", systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
    }

    // MARK: - Capture Row

    private func chapterCaptureRow(_ capture: PreludeCapture) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Image(systemName: capture.typeIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(capture.isPartnerRetroactive ? .purple : BabyTownTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(capture.isPartnerRetroactive ? Color.purple.opacity(0.1) : BabyTownTheme.accentSoft)
                    )

                if capture.isPartnerRetroactive {
                    Text("Partner")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.purple)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(capture.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(capture.isPartnerRetroactive ? .purple : BabyTownTheme.accent)
                    .textCase(.uppercase)

                Text(capture.displayTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text(capture.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
    }
}

#Preview {
    PreludeChapterView(
        chapter: PreludeChapter(
            startDate: Date().addingTimeInterval(-60 * 60 * 24 * 30),
            officialDate: Date(),
            creatorUserId: "local",
            partnerUserId: "partner",
            giftCaptureIds: []
        ),
        captures: [
            PreludeCapture(type: .note, isIncludedInGift: true, noteText: "I keep thinking about the way you laugh."),
            PreludeCapture(type: .reason, isIncludedInGift: true, reasonText: "You remember everything I've told you.")
        ],
        onDismiss: {}
    )
}
```

- [ ] **Step 2: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeChapterView.swift
git commit -m "feat: add PreludeChapterView showing permanent gift captures"
```

---

## Task 12: ArchiveFlowView + ReconnectFlowView (Stubs)

**Files:**
- Create: `BabyTown/Views/Prelude/ArchiveFlowView.swift`
- Create: `BabyTown/Views/Prelude/ReconnectFlowView.swift`

The archive and reconnect flows are designed now and implemented later per the spec. These are functional stubs with the correct UX copy and callbacks.

- [ ] **Step 1: Create ArchiveFlowView.swift**

```swift
// BabyTown/Views/Prelude/ArchiveFlowView.swift
import SwiftUI

struct ArchiveFlowView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDismiss: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "archivebox")
                    .font(.system(size: 56))
                    .foregroundStyle(BabyTownTheme.textSecondary)

                VStack(spacing: 12) {
                    Text("Archive Your Relationship")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Text("This will end your active relationship.\nYour memories are preserved forever.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showConfirmation = true
                    } label: {
                        Text("Archive Relationship")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.gray))
                    }
                    .buttonStyle(.plain)

                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(BabyTownTheme.accent)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Archive this relationship?", isPresented: $showConfirmation) {
            Button("Archive", role: .destructive) {
                viewModel.archiveRelationship()
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Garden and pet will freeze. Your shared timeline and Prelude chapter become read-only.")
        }
    }
}
```

- [ ] **Step 2: Create ReconnectFlowView.swift**

```swift
// BabyTown/Views/Prelude/ReconnectFlowView.swift
import SwiftUI

struct ReconnectFlowView: View {

    @ObservedObject var viewModel: PreludeViewModel
    var onDismiss: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BabyTownTheme.accent)

                VStack(spacing: 12) {
                    Text("Reconnect")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)

                    Text("Your archive chapter will be preserved.\nGarden and pet resume from where they were.")
                        .font(.system(size: 15))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showConfirmation = true
                    } label: {
                        Text("Reconnect")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule().fill(BabyTownTheme.accentGradient)
                            )
                    }
                    .buttonStyle(.plain)

                    Button("Not yet", action: onDismiss)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(BabyTownTheme.background.ignoresSafeArea())
            .navigationTitle("Reconnect")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Reconnect with your partner?", isPresented: $showConfirmation) {
            Button("Reconnect") {
                viewModel.reconnect()
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Both users must confirm to reactivate the relationship.")
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/Prelude/ArchiveFlowView.swift BabyTown/Views/Prelude/ReconnectFlowView.swift
git commit -m "feat: add ArchiveFlowView and ReconnectFlowView stubs"
```

---

## Task 13: ContentView — Stage-Based Routing

**Files:**
- Modify: `BabyTown/ContentView.swift`

This is the critical wiring step. After onboarding, `ContentView` reads `relationshipStage` from persisted `CoupleProfile` and routes to either `PreludeHomeView` (prelude) or the existing `HomeView` (officialCouple / archivedCouple).

- [ ] **Step 1: Add `.prelude` to the `Screen` enum**

In `ContentView.swift`, find:

```swift
    enum Screen {
        case launch, welcome, storyOnboarding, nickname, colorTheme, birthday, firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden
    }
```

Replace with:

```swift
    enum Screen {
        case launch, welcome, storyOnboarding, nickname, colorTheme, birthday, firstMemories, howItWorks, photoAccess, home, selectPhotos
        case loveGarden
        case prelude
    }
```

- [ ] **Step 2: Route to prelude screen after onboarding check**

In `ContentView.init()`, find the block:

```swift
        if hasCompletedOnboarding {
            // Check if user was last on the camera screen
            let lastScreen = DataPersistenceManager.shared.loadLastActiveScreen()
            if lastScreen == "selectPhotos" {
                _targetScreen = State(initialValue: .selectPhotos)
            } else {
                _targetScreen = State(initialValue: .home)
            }
```

Replace with:

```swift
        if hasCompletedOnboarding {
            let lastScreen = DataPersistenceManager.shared.loadLastActiveScreen()
            let stage = DataPersistenceManager.shared.loadCoupleProfile().relationshipStage
            if lastScreen == "selectPhotos" {
                _targetScreen = State(initialValue: .selectPhotos)
            } else if stage == .prelude {
                _targetScreen = State(initialValue: .prelude)
            } else {
                _targetScreen = State(initialValue: .home)
            }
```

- [ ] **Step 3: Add the prelude case to body's switch**

In `ContentView.body`, inside the `switch screen { ... }`, add a new case after the `.home` case:

```swift
            case .prelude:
                PreludeHomeView()
                    .transition(.opacity)
```

- [ ] **Step 4: Build to verify**

Cmd+B — must succeed.

- [ ] **Step 5: Run on Simulator with prelude stage**

In Simulator, delete the app to clear persisted data (or call `DataPersistenceManager.shared.clearAllData()` once). Complete onboarding. The app should land on `PreludeHomeView` since `relationshipStage` defaults to `.prelude` on a fresh install.

Verify:
- Invite banner shows "Invite [name]"
- Tapping any quick-add button opens `CaptureEditorView`
- Creating a note persists and appears in the feed
- Tapping invite banner opens `GiftCurationView`

- [ ] **Step 6: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "feat: gate ContentView routing on RelationshipStage, show PreludeHomeView for prelude users"
```

---

## Verification Checklist (from Spec)

Run through these manually on the Simulator after Task 13 is complete:

- [ ] Create all four capture types. Verify each appears in the feed and survives an app restart.
- [ ] Mark some captures for gift inclusion (`isIncludedInGift = true`), leave others private. Verify private captures never appear in gift preview.
- [ ] Open `GiftCurationView` → tap "Send Invite" → verify `inviteSent = true` is persisted (banner shows "Waiting for them…"). Verify new captures can still be added.
- [ ] Simulate partner accepting: call `viewModel.transitionToOfficial()` from a debug button → verify `stage` transitions to `.officialCouple` → verify app routes to `HomeView`.
- [ ] After going Official, open `PreludeChapterView` (load from `DataPersistenceManager.shared.loadPreludeChapter()`). Verify only gift captures are visible.
- [ ] Private captures (not in gift) — verify they remain accessible to the creator only (still in `captures` array) and never surface in `PreludeChapterView`.
- [ ] Archive: trigger `ArchiveFlowView` → confirm → verify `stage == .archivedCouple` persists. Verify creator can still read their private captures.
- [ ] Reconnect: trigger `ReconnectFlowView` → confirm → verify `stage` returns to `.officialCouple`.

---

## Self-Review Notes

**Spec coverage:**
- ✅ RelationshipStage enum (Task 1)
- ✅ `CoupleProfile.inviteSent` (Task 1)
- ✅ PreludeCapture model (Task 2)
- ✅ PreludeChapter model (Task 3)
- ✅ DataPersistenceManager prelude persistence (Task 4)
- ✅ PreludeViewModel with CRUD + transitions (Task 5)
- ✅ PreludeHomeView feed + quick-add bar (Task 6)
- ✅ CaptureEditorView — all four types + reflection prompts (Task 7)
- ✅ VoiceMemoRecorderView + 3-min cap (Task 8)
- ✅ GiftCurationView select + preview + send (Task 9)
- ✅ GiftRevealView cinematic reveal (Task 10)
- ✅ PreludeChapterView permanent chapter (Task 11)
- ✅ Archive + Reconnect stubs (Task 12)
- ✅ HomeView gating on stage (Task 13, via ContentView)
- ⚠️ Partner's retroactive entries — model supports it (`isPartnerRetroactive`); `addPartnerRetroactiveCapture()` exists on ViewModel; no dedicated UI yet (acceptable for Phase 1 — happens after gift reveal flow is real, which requires backend)
- ⚠️ Couple playlist soft music in GiftRevealView — not wired (requires backend/playlist state); background music infrastructure exists in the app already via `CoupleMusicPlaybackState`/`EmbeddedBackgroundMusicPlayer` but the prelude stage has no couple playlist yet

**Type consistency:**
- `PreludeCapture.voiceMemoFileId: String?` — stored as a filename string, used throughout as `fileId` parameter. Consistent across Task 2, 4, 5, 7, 8.
- `PreludeViewModel.giftCaptures` — filters `isIncludedInGift && !isPartnerRetroactive`. Used in Task 9 (GiftCurationView) and Task 10 (GiftRevealView). Consistent.
- `DataPersistenceManager.savePreludeVoiceMemo(data:fileId:)` + `loadPreludeVoiceMemoData(fileId:)` — `fileId` is a filename string (e.g., `"<UUID>.m4a"`). Consistent with Task 8 where `persistRecording()` generates `"\(UUID().uuidString).m4a"`.
