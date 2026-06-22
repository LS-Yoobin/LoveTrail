# Prelude Capture Delete Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a visible trash icon button to each capture row card in `PreludeHomeView` that triggers a confirmation alert before deleting.

**Architecture:** Single-file change to `PreludeHomeView.swift`. `CaptureRowCard` gains an `onDelete` callback that fires when the trash button is tapped. `PreludeHomeView` holds `@State var captureToDelete` and presents a `.alert` confirmation that calls `viewModel.deleteCapture`.

**Tech Stack:** SwiftUI, existing `PreludeViewModel`, `BabyTownTheme`

---

### Task 1: Add `onDelete` callback to `CaptureRowCard` and render the trash button

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeHomeView.swift:185-223`

- [ ] **Step 1: Add `onDelete` parameter to `CaptureRowCard`**

Find the `CaptureRowCard` struct (line 185) and update its stored properties:

```swift
private struct CaptureRowCard: View {
    let capture: PreludeCapture
    let onDelete: () -> Void
```

- [ ] **Step 2: Replace the trailing `Spacer()` with a Spacer + trash button**

Inside `CaptureRowCard.body`, the `HStack` currently ends with `Spacer()` after the content `VStack`. Replace that `Spacer()` with:

```swift
Spacer()

Button(action: onDelete) {
    Image(systemName: "trash")
        .font(.system(size: 14))
        .foregroundStyle(BabyTownTheme.textSecondary)
        .padding(8)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
```

- [ ] **Step 3: Build the project to confirm no errors**

Open Xcode and build (⌘B), or run:
```bash
xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: Build succeeds. The compiler will error on every call site of `CaptureRowCard` because `onDelete` is now required — that is expected and fixed in Task 2.

---

### Task 2: Wire `onDelete` in `captureList` and add confirmation alert

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeHomeView.swift:6-115`

- [ ] **Step 1: Add `captureToDelete` state to `PreludeHomeView`**

After the existing `@State` declarations (around line 9), add:

```swift
@State private var captureToDelete: PreludeCapture?
```

- [ ] **Step 2: Pass `onDelete` into each `CaptureRowCard` in `captureList`**

Inside `captureList`, update the `ForEach` body so `CaptureRowCard` receives the callback:

```swift
ForEach(viewModel.captures) { capture in
    CaptureRowCard(capture: capture, onDelete: { captureToDelete = capture })
        .onTapGesture {
            guard capture.type != .first else { return }
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
```

- [ ] **Step 3: Attach the confirmation alert to `captureList`**

Add `.alert` to the `ScrollView` inside `captureList`, right after `.padding(.bottom, 120)`:

```swift
.alert(
    "Delete capture?",
    isPresented: Binding(
        get: { captureToDelete != nil },
        set: { if !$0 { captureToDelete = nil } }
    ),
    presenting: captureToDelete
) { capture in
    Button("Delete", role: .destructive) {
        withAnimation { viewModel.deleteCapture(capture) }
        captureToDelete = nil
    }
    Button("Cancel", role: .cancel) {
        captureToDelete = nil
    }
} message: { _ in }
```

- [ ] **Step 4: Build to confirm everything compiles**

```bash
xcodebuild -scheme BabyTown -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: Build succeeds with no errors or warnings related to `CaptureRowCard` or `captureToDelete`.

- [ ] **Step 5: Manually verify in simulator**

Run the app on a simulator, navigate to the Prelude home, confirm:
1. Each capture card shows a muted trash icon on the right
2. Tapping it shows "Delete capture?" alert with Delete (red) and Cancel
3. Tapping Delete removes the card with animation
4. Tapping Cancel dismisses with no change
5. Swipe-to-delete still works as before

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeHomeView.swift
git commit -m "feat(prelude): add trash button with confirmation alert to capture rows"
```
