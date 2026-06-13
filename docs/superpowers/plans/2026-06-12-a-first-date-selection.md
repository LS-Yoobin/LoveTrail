# A First Date Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users set the date a "first" actually happened when recording an "A First" capture, defaulting to today but editable to any past date.

**Architecture:** Add an optional `firstDate` field to `PreludeCapture` (backward-compatible via `Codable` nil fallback), restructure the `.first` editor into a fixed header zone (date banner + picker) and a scrollable chips zone, and unlock tap-to-edit for `.first` rows in the capture list.

**Tech Stack:** SwiftUI, Swift `Codable`, `DatePicker` (`.graphical` style), `LinearGradient` mask

---

## File Map

| File | Change |
|---|---|
| `BabyTown/Models/PreludeCapture.swift` | Add `var firstDate: Date?`; add parameter to `init` |
| `BabyTown/Views/Prelude/CaptureEditorView.swift` | Add two `@State` vars; restructure `body` and `firstEditor`; update `loadExisting()` and `save()` |
| `BabyTown/Views/Prelude/PreludeHomeView.swift` | Update `CaptureRowCard` date display; remove `.first` tap guard |

---

## Task 1: Add `firstDate` to `PreludeCapture`

**Files:**
- Modify: `BabyTown/Models/PreludeCapture.swift`

- [ ] **Step 1: Add the stored property and update `init`**

Replace the entire file content with:

```swift
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
    var firstDate: Date?

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
        reasonText: String? = nil,
        firstDate: Date? = nil
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
        self.firstDate = firstDate
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

- [ ] **Step 2: Build to verify no regressions**

In Xcode: **Cmd+B**. Expected: build succeeds with zero errors.

> `firstDate` has a default of `nil` in `init`, so all existing call sites compile unchanged. Existing JSON records that lack `firstDate` will decode it as `nil` automatically — no migration needed.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Models/PreludeCapture.swift
git commit -m "feat(prelude): add firstDate field to PreludeCapture"
```

---

## Task 2: Restructure `CaptureEditorView` for `.first` type

**Files:**
- Modify: `BabyTown/Views/Prelude/CaptureEditorView.swift`

This task replaces the entire file. The key changes are:

1. Add `@State private var firstDate: Date = Date()` and `@State private var isDatePickerExpanded: Bool = false`.
2. Change `body` so `.first` type bypasses the outer `ScrollView` and renders `firstEditor` directly (which manages its own scrollable zone for chips).
3. Rewrite `firstEditor` into a fixed zone + scrollable zone layout with the date banner.
4. Update `loadExisting()` to restore `firstDate`.
5. Update `save()` to pass `firstDate` for `.first` captures.

- [ ] **Step 1: Replace `CaptureEditorView.swift` with the new implementation**

```swift
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
    @State private var savedVoiceMemoFileId: String?
    @State private var promptIndex: Int = 0
    @State private var firstDate: Date = Date()
    @State private var isDatePickerExpanded: Bool = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if type == .first {
                    firstEditor
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            if existing != nil {
                                giftToggle
                            }
                            editorContent
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
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
        .onAppear {
            loadExisting()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isEditorFocused = true
            }
        }
    }

    private var navigationTitle: String {
        switch type {
        case .note: return "Note"
        case .first: return "A First"
        case .voiceMemo: return "Voice Memo"
        case .reason: return "Reason"
        }
    }

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

    @ViewBuilder
    private var editorContent: some View {
        switch type {
        case .note:
            noteEditor
        case .first:
            EmptyView()
        case .voiceMemo:
            voiceMemoEditor
        case .reason:
            reasonEditor
        }
    }

    // MARK: - First Editor

    private var firstEditor: some View {
        VStack(spacing: 0) {
            // Fixed zone
            VStack(alignment: .leading, spacing: 12) {
                if existing != nil {
                    giftToggle
                        .padding(.bottom, 4)
                }

                Text("📅 WHEN WAS THIS?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .padding(.top, 4)

                dateBanner

                if isDatePickerExpanded {
                    DatePicker("", selection: $firstDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(BabyTownTheme.accent)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                firstSectionDivider

                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.black)
                    TextField(
                        "",
                        text: $customFirstLabel,
                        prompt: Text("Write your own first…").foregroundStyle(Color.black.opacity(0.5))
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .focused($isEditorFocused)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            .black,
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                        )
                )
                .onChange(of: customFirstLabel) { _, val in
                    if !val.isEmpty { firstLabel = val }
                }

                Text("or pick one")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .animation(.easeInOut(duration: 0.2), value: isDatePickerExpanded)

            // Scrollable zone
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .frame(maxHeight: .infinity)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white, location: 0.85),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var dateBanner: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDatePickerExpanded.toggle()
            }
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(firstDate, format: .dateTime.month(.wide).day())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text(firstDate, format: .dateTime.year())
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("📅")
                        .font(.system(size: 20))
                    Text("tap to change")
                        .font(.system(size: 11))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 253 / 255, green: 240 / 255, blue: 234 / 255),
                                Color(red: 252 / 255, green: 232 / 255, blue: 222 / 255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var firstSectionDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(BabyTownTheme.accent.opacity(0.3))
                .frame(height: 1)
            Text("What was the first?")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.accent)
                .lineLimit(1)
                .fixedSize()
            Rectangle()
                .fill(BabyTownTheme.accent.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Other Editors

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.notePrompts[promptIndex % PreludeViewModel.notePrompts.count])

            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.black)
                    .frame(minHeight: 160)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BabyTownTheme.cardBackground)
                    )
                    .font(.system(size: 16))
                    .focused($isEditorFocused)
                if noteText.isEmpty {
                    Text(PreludeViewModel.notePrompts[promptIndex % PreludeViewModel.notePrompts.count])
                        .font(.system(size: 16))
                        .foregroundStyle(Color(uiColor: .darkGray).opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            Button("Different prompt") {
                promptIndex += 1
            }
            .font(.system(size: 13))
            .foregroundStyle(BabyTownTheme.accent)
        }
    }

    private var voiceMemoEditor: some View {
        VStack(spacing: 16) {
            Text("Record up to 1 minute. Raw, in the moment.")
                .font(.system(size: 14))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            VoiceMemoRecorderView(
                existingFileId: existing?.voiceMemoFileId,
                onSaved: { fileId in
                    savedVoiceMemoFileId = fileId
                }
            )
        }
    }

    private var reasonEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            promptChip(PreludeViewModel.reasonPrompt)

            TextField(
                "", text: $reasonText,
                prompt: Text("One reason I'm falling for you…").foregroundStyle(Color(uiColor: .darkGray).opacity(0.55)),
                axis: .vertical
            )
            .foregroundStyle(.black)
            .lineLimit(3, reservesSpace: true)
            .font(.system(size: 16))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BabyTownTheme.cardBackground)
            )
            .focused($isEditorFocused)
        }
    }

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

    // MARK: - Save / Load

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
        firstDate = c.firstDate ?? Date()
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
            reasonText: type == .reason ? reasonText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            firstDate: type == .first ? firstDate : nil
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
        type: .first,
        existing: nil,
        viewModel: PreludeViewModel(),
        onSave: {},
        onCancel: {}
    )
}
```

- [ ] **Step 2: Build to verify no regressions**

In Xcode: **Cmd+B**. Expected: build succeeds with zero errors and zero warnings related to these changes.

- [ ] **Step 3: Verify `.first` editor in Preview**

In Xcode, open [CaptureEditorView.swift](BabyTown/Views/Prelude/CaptureEditorView.swift) and run the `#Preview`. Confirm:
- Date banner renders with today's month+day (large bold) and year (smaller muted), warm peach gradient background, "📅 tap to change" on the right.
- Tapping the banner expands the graphical `DatePicker` inline; tapping again collapses it.
- "What was the first?" divider renders between the date section and the dashed text field.
- Preset chips are in a scrollable list below the fixed zone.
- Bottom of the chip list fades out.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/Prelude/CaptureEditorView.swift
git commit -m "feat(prelude): add date picker to A First capture editor"
```

---

## Task 3: Update `CaptureRowCard` date display and enable editing in `PreludeHomeView`

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeHomeView.swift`

Two targeted changes:
1. `CaptureRowCard` — display `firstDate ?? createdAt` for `.first` captures.
2. `captureList` — remove the guard that blocks `.first` rows from opening the editor.

- [ ] **Step 1: Update the date display in `CaptureRowCard`**

In [PreludeHomeView.swift](BabyTown/Views/Prelude/PreludeHomeView.swift) at line 234, change:

```swift
Text(capture.createdAt, style: .date)
```

to:

```swift
Text(capture.type == .first ? (capture.firstDate ?? capture.createdAt) : capture.createdAt, style: .date)
```

- [ ] **Step 2: Remove the `.first` tap guard**

In [PreludeHomeView.swift](BabyTown/Views/Prelude/PreludeHomeView.swift) around line 98, remove these two lines entirely:

```swift
guard capture.type != .first else { return }
```

The resulting `.onTapGesture` block should be:

```swift
.onTapGesture {
    editingCapture = capture
    editorType = capture.type
    showCaptureEditor = true
}
```

- [ ] **Step 3: Build to verify no regressions**

In Xcode: **Cmd+B**. Expected: build succeeds with zero errors.

- [ ] **Step 4: Manual smoke test**

Run the app on a simulator (iPhone 15, iOS 17+):

1. Tap **First** in the quick-add bar → editor opens → date banner shows today → tap banner → graphical picker opens → navigate to a past month → select a date → tap banner again to collapse → select a preset first → tap Save.
2. Confirm the new row in the list shows the *past date* you selected (not today's date).
3. Tap the row → editor reopens → date banner shows the date you previously set → change the date → Save → confirm the row now shows the updated date.
4. Create a Note capture, tap its row → note editor opens → date display on the row shows `createdAt` (unchanged).

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeHomeView.swift
git commit -m "feat(prelude): show firstDate in capture row and enable first editing"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Covered by |
|---|---|
| `firstDate: Date?` on `PreludeCapture` | Task 1 |
| `createdAt` unchanged, `firstDate` nil for old records | Task 1 — optional field with default `nil` in init; Codable decodes missing key as nil |
| Default value `Date()` on new `.first` captures | Task 2 — `@State private var firstDate: Date = Date()` |
| Fixed zone: date label, banner, picker, divider, text field, "or pick one" | Task 2 — `firstEditor` fixed zone |
| Date banner: warm gradient, month+day bold, year muted, "tap to change" | Task 2 — `dateBanner` |
| Inline `DatePicker` (`.graphical`) toggled by banner tap | Task 2 — `isDatePickerExpanded` + `DatePicker` conditional |
| Section divider "What was the first?" with horizontal lines | Task 2 — `firstSectionDivider` |
| Scrollable chip zone with bottom fade mask | Task 2 — `ScrollView` + `LinearGradient` mask |
| Chip / custom field mutual exclusion (existing behavior) | Task 2 — unchanged `onChange` / button logic |
| `loadExisting()` restores `firstDate` | Task 2 |
| `save()` passes `firstDate` for `.first`, nil for all other types | Task 2 |
| `CaptureRowCard` shows `firstDate ?? createdAt` for `.first` | Task 3, Step 1 |
| Other capture types still show `createdAt` | Task 3, Step 1 |
| `.first` row tap opens editor | Task 3, Step 2 |
| No changes to `PreludeViewModel`, `DataPersistenceManager`, or other views | All tasks — only 3 files touched |
