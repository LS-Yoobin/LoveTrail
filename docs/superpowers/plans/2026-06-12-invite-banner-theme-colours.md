# Invite Banner Theme-Adaptive Colours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the invite banner's hardcoded colour usage with four new semantic tokens in `BabyTownTheme` so the banner visually distinguishes itself from the scroll-list cards in both blue and pink themes.

**Architecture:** Two-file change only — add 4 `static var` tokens to `BabyTownTheme` (following the existing `isBlue ? blue : pink` pattern), then update the `inviteBanner` computed property in `PreludeHomeView` to use those tokens plus a 1.5pt border overlay. No layout, blur, or structural changes.

**Tech Stack:** SwiftUI, `BabyTownTheme` enum, `Color(red:green:blue:)` initialiser

---

## File Map

| File | Change |
|---|---|
| `BabyTown/Theme/BabyTownTheme.swift` | Add `// MARK: - Invite Banner` section with 4 tokens |
| `BabyTown/Views/Prelude/PreludeHomeView.swift` | Update `inviteBanner` — fill, border overlay, title/subtitle/chevron colours |

> **Note on TDD:** These are pure colour-token and view-layer changes with no logic to unit-test. The verification step is a successful Xcode build — the compiler will catch any typo in token names. Visual inspection in Simulator confirms correctness.

---

### Task 1: Add 4 invite banner tokens to `BabyTownTheme`

**Files:**
- Modify: `BabyTown/Theme/BabyTownTheme.swift` — insert new `// MARK: - Invite Banner` section after the `// MARK: - Cards` block (after line 68, before `// MARK: - Buttons`)

- [ ] **Step 1: Open the file and locate the insertion point**

  `BabyTown/Theme/BabyTownTheme.swift`, line 74 — the blank line before `// MARK: - Buttons`. The new section goes there.

- [ ] **Step 2: Insert the 4 tokens**

  Add this block between the Cards section and the Buttons section:

  ```swift
      // MARK: - Invite Banner

      static var inviteBannerFill: Color {
          isBlue ? Color(red: 1.000, green: 0.953, blue: 0.839) : Color(red: 0.910, green: 0.871, blue: 1.000)
      }
      static var inviteBannerBorder: Color {
          isBlue ? Color(red: 0.878, green: 0.690, blue: 0.376) : Color(red: 0.659, green: 0.533, blue: 0.816)
      }
      static var inviteBannerText: Color {
          isBlue ? Color(red: 0.353, green: 0.220, blue: 0.000) : Color(red: 0.227, green: 0.157, blue: 0.376)
      }
      static var inviteBannerSubtext: Color {
          isBlue ? Color(red: 0.478, green: 0.314, blue: 0.000) : Color(red: 0.353, green: 0.251, blue: 0.502)
      }
  ```

  Colour reference (hex → RGB):
  | Token | Blue hex | Blue RGB | Pink hex | Pink RGB |
  |---|---|---|---|---|
  | `inviteBannerFill` | `#FFF3D6` | 1.000, 0.953, 0.839 | `#E8DEFF` | 0.910, 0.871, 1.000 |
  | `inviteBannerBorder` | `#E0B060` | 0.878, 0.690, 0.376 | `#A888D0` | 0.659, 0.533, 0.816 |
  | `inviteBannerText` | `#5A3800` | 0.353, 0.220, 0.000 | `#3A2860` | 0.227, 0.157, 0.376 |
  | `inviteBannerSubtext` | `#7A5000` | 0.478, 0.314, 0.000 | `#5A4080` | 0.353, 0.251, 0.502 |

- [ ] **Step 3: Commit**

  ```bash
  git add BabyTown/Theme/BabyTownTheme.swift
  git commit -m "feat(theme): add invite banner semantic colour tokens"
  ```

---

### Task 2: Update `inviteBanner` in `PreludeHomeView`

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeHomeView.swift` — replace the `inviteBanner` computed property body (lines 83–120)

**Changes:**

| Element | Before | After |
|---|---|---|
| Background fill | `BabyTownTheme.cardBackground` | `BabyTownTheme.inviteBannerFill` |
| Border | none | `.overlay` with `strokeBorder(BabyTownTheme.inviteBannerBorder, lineWidth: 1.5)` |
| Title text (both states) | `BabyTownTheme.textPrimary` | `BabyTownTheme.inviteBannerText` |
| Subtitle text | `.black` | `BabyTownTheme.inviteBannerSubtext` |
| Chevron | `BabyTownTheme.textSecondary` | `BabyTownTheme.inviteBannerText` |

- [ ] **Step 1: Replace the `inviteBanner` computed property**

  Replace the entire `private var inviteBanner: some View { … }` block with:

  ```swift
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
                          .foregroundStyle(BabyTownTheme.inviteBannerText)
                  } else {
                      Text("Invite \(displayName)")
                          .font(.system(size: 15, weight: .semibold))
                          .foregroundStyle(BabyTownTheme.inviteBannerText)
                      Text("Share your Prelude when you're ready")
                          .font(.system(size: 12))
                          .foregroundStyle(BabyTownTheme.inviteBannerSubtext)
                  }
              }

              Spacer()

              Image(systemName: "chevron.right")
                  .font(.system(size: 14, weight: .medium))
                  .foregroundStyle(BabyTownTheme.inviteBannerText)
          }
          .padding(14)
          .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(BabyTownTheme.inviteBannerFill)
                  .overlay(
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                          .strokeBorder(BabyTownTheme.inviteBannerBorder, lineWidth: 1.5)
                  )
          )
      }
      .buttonStyle(.plain)
  }
  ```

- [ ] **Step 2: Build to verify**

  In Xcode: **Product → Build** (⌘B), or via CLI:

  ```bash
  xcodebuild -project BabyTown.xcodeproj -scheme BabyTown -destination 'platform=iOS Simulator,name=iPhone 16' build | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
  ```

  Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Visual check in Simulator**

  Launch the app, navigate to Prelude home. Verify:
  - Blue theme: banner fills with warm cream, amber border, dark amber text
  - Pink theme (toggle in settings if available): banner fills with lavender, violet border, dark violet text
  - Icon (`envelope.heart.fill`) retains its accent colour
  - `inviteSent` state ("Waiting for them to accept…") shows correct `inviteBannerText` colour

- [ ] **Step 4: Commit**

  ```bash
  git add BabyTown/Views/Prelude/PreludeHomeView.swift
  git commit -m "feat(prelude): apply theme-adaptive colours to invite banner"
  ```
