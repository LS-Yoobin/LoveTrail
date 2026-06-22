# Partner Onboarding Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 6-step partner onboarding flow triggered by a deep link or a settings preview button, collecting the partner's identity and revealing the inviter's Prelude gift before transitioning to Official mode.

**Architecture:** A self-contained `PartnerOnboardingFlow` view owns a `Step` enum and advances linearly with no back navigation. All transitions use `.transition(.opacity)` crossfade driven by `withAnimation`. The flow is presented as a full-screen case in `ContentView.Screen` and is reachable via deep link (`babytown://invite/CODE?from=NAME`) or a new "Preview Partner Onboarding" row in `PreludeSettingsSheet`.

**Tech Stack:** SwiftUI, PhotosUI (PhotosPicker), UIKit (UIImage JPEG), UserDefaults, existing `BabyTownTheme`, `DataPersistenceManager`, `ThemeManager`, `BookFlipView`, `GiftCaptureRow`, `ColorThemeView`.

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift` | All 6 onboarding steps + private step structs |
| Modify | `BabyTown/Services/DataPersistenceManager.swift` | Add `savePartnerEmail`, `savePartnerProfilePhoto`, `loadPartnerProfilePhoto` |
| Modify | `BabyTown/Views/Prelude/GiftCurationView.swift` | Make `GiftCaptureRow` non-private so partner flow can reuse it |
| Modify | `BabyTown/Views/Prelude/PreludeSettingsSheet.swift` | Add `onSimulatePartnerInvite` closure + new Testing row |
| Modify | `BabyTown/Views/Prelude/PreludeHomeView.swift` | Add `onSimulatePartnerInvite` param; thread to settings sheet |
| Modify | `BabyTown/ContentView.swift` | Add `.partnerOnboarding` case, `.onOpenURL`, pass simulate closure |
| Xcode config | BabyTown target > Info tab > URL Types | Register `babytown` URL scheme |

---

## Task 1: DataPersistenceManager — partner persistence additions

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

- [ ] **Step 1: Add private constants and URL**

  In the `// MARK: -` private keys block (around line 103), add the new UserDefaults key:
  ```swift
  private let partnerEmailKey = "partnerEmail"
  ```

  After `userAvatarURL` (around line 90), add the partner photo URL:
  ```swift
  private var partnerAvatarURL: URL {
      pinnedPhotosDirectory.appendingPathComponent("partner_avatar.jpg")
  }
  ```

- [ ] **Step 2: Add save/load methods**

  After `loadUserAvatar()` (after line 363), add:
  ```swift
  func savePartnerEmail(_ email: String) {
      let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }
      userDefaults.set(trimmed, forKey: partnerEmailKey)
  }

  func savePartnerProfilePhoto(_ image: UIImage) {
      guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
      try? jpeg.write(to: partnerAvatarURL)
  }

  func loadPartnerProfilePhoto() -> UIImage? {
      guard fileManager.fileExists(atPath: partnerAvatarURL.path),
            let data = try? Data(contentsOf: partnerAvatarURL) else { return nil }
      return UIImage(data: data)
  }
  ```

- [ ] **Step 3: Clear in clearAllData()**

  Inside `clearAllData()`, after the `try? fileManager.removeItem(at: userAvatarURL)` line, add:
  ```swift
  try? fileManager.removeItem(at: partnerAvatarURL)
  ```

  After `userDefaults.removeObject(forKey: colorThemeKey)`, add:
  ```swift
  userDefaults.removeObject(forKey: partnerEmailKey)
  ```

- [ ] **Step 4: Build to verify**

  In Xcode press `Cmd+B`. Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**
  ```bash
  git add BabyTown/Services/DataPersistenceManager.swift
  git commit -m "feat(persistence): add partner email and photo storage"
  ```

---

## Task 2: GiftCaptureRow — make non-private

**Files:**
- Modify: `BabyTown/Views/Prelude/GiftCurationView.swift:111`

- [ ] **Step 1: Remove `private` access modifier**

  On line 111, change:
  ```swift
  private struct GiftCaptureRow: View {
  ```
  to:
  ```swift
  struct GiftCaptureRow: View {
  ```

- [ ] **Step 2: Build to verify**

  `Cmd+B`. Expected: build succeeds, no change in behavior.

- [ ] **Step 3: Commit**
  ```bash
  git add BabyTown/Views/Prelude/GiftCurationView.swift
  git commit -m "refactor(prelude): expose GiftCaptureRow for reuse in partner onboarding"
  ```

---

## Task 3: PreludeSettingsSheet — add simulate row

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeSettingsSheet.swift`

- [ ] **Step 1: Add new closure parameter**

  Change the struct declaration to add the new parameter:
  ```swift
  struct PreludeSettingsSheet: View {
      var onReturnToOnboarding: () -> Void
      var onSwitchToOfficial: () -> Void
      var onSimulatePartnerInvite: () -> Void
  ```

- [ ] **Step 2: Add new row to Testing section**

  Replace the entire Testing section (the first `Section { ... }` block) with:
  ```swift
  Section {
      Button {
          dismiss()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              onSwitchToOfficial()
          }
      } label: {
          Label("Switch to Official Mode", systemImage: "heart.circle.fill")
              .foregroundStyle(.primary)
      }

      Button {
          dismiss()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              onSimulatePartnerInvite()
          }
      } label: {
          Label("Preview Partner Onboarding", systemImage: "person.crop.circle")
              .foregroundStyle(.primary)
      }
  } header: {
      Text("Testing")
  } footer: {
      Text("Launches the partner invite flow with a mock inviter name.")
          .font(.footnote)
  }
  ```

- [ ] **Step 3: Update the Preview**

  The `#Preview` at the bottom will fail to compile because it is missing the new parameter. Update it:
  ```swift
  #Preview {
      PreludeSettingsSheet(
          onReturnToOnboarding: { print("return to onboarding") },
          onSwitchToOfficial: { print("switch to official") },
          onSimulatePartnerInvite: { print("simulate partner invite") }
      )
  }
  ```

- [ ] **Step 4: Build to verify**

  `Cmd+B`. Expected: build succeeds.

- [ ] **Step 5: Commit**
  ```bash
  git add BabyTown/Views/Prelude/PreludeSettingsSheet.swift
  git commit -m "feat(settings): add Preview Partner Onboarding row to testing section"
  ```

---

## Task 4: PreludeHomeView — thread simulate closure

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeHomeView.swift`

- [ ] **Step 1: Add new parameter to PreludeHomeView**

  In the property declarations at the top of `PreludeHomeView`, after `var onSwitchToOfficial: () -> Void = {}`, add:
  ```swift
  var onSimulatePartnerInvite: () -> Void = {}
  ```

- [ ] **Step 2: Pass closure to PreludeSettingsSheet**

  In the `.sheet(isPresented: $showSettings)` modifier body, update the `PreludeSettingsSheet` call:
  ```swift
  .sheet(isPresented: $showSettings) {
      PreludeSettingsSheet(
          onReturnToOnboarding: onReturnToOnboarding,
          onSwitchToOfficial: onSwitchToOfficial,
          onSimulatePartnerInvite: onSimulatePartnerInvite
      )
  }
  ```

- [ ] **Step 3: Build to verify**

  `Cmd+B`. Expected: build succeeds. Existing call sites in ContentView still compile because `onSimulatePartnerInvite` has a default value of `{}`.

- [ ] **Step 4: Commit**
  ```bash
  git add BabyTown/Views/Prelude/PreludeHomeView.swift
  git commit -m "feat(prelude): thread onSimulatePartnerInvite through PreludeHomeView"
  ```

---

## Task 5: ContentView — partnerOnboarding case + URL handling

**Files:**
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Add new case to Screen enum**

  In the `enum Screen` declaration (line 12), add at the end:
  ```swift
  case partnerOnboarding(inviterName: String)
  ```

- [ ] **Step 2: Add the new case to the switch body**

  After the `case .archivedCouple:` block (before the closing brace of the ZStack switch), add:
  ```swift
  case .partnerOnboarding(let inviterName):
      PartnerOnboardingFlow(
          inviterName: inviterName,
          onComplete: {
              var profile = DataPersistenceManager.shared.loadCoupleProfile()
              profile.relationshipStage = .officialCouple
              DataPersistenceManager.shared.saveCoupleProfile(profile)
              DataPersistenceManager.shared.setOnboardingCompleted(true)
              withAnimation(.easeInOut(duration: 0.4)) {
                  screen = .home
              }
          }
      )
      .transition(.opacity)
  ```

- [ ] **Step 3: Pass simulate closure to PreludeHomeView**

  In the `case .prelude:` block, update `PreludeHomeView(...)` to add the new closure:
  ```swift
  case .prelude:
      PreludeHomeView(
          onReturnToOnboarding: {
              DataPersistenceManager.shared.setOnboardingCompleted(false)
              withAnimation(.easeInOut(duration: 0.4)) {
                  screen = .welcome
              }
          },
          onSwitchToOfficial: {
              var profile = DataPersistenceManager.shared.loadCoupleProfile()
              profile.relationshipStage = .officialCouple
              DataPersistenceManager.shared.saveCoupleProfile(profile)
              withAnimation(.easeInOut(duration: 0.4)) {
                  screen = .home
              }
          },
          onSimulatePartnerInvite: {
              withAnimation(.easeInOut(duration: 0.4)) {
                  screen = .partnerOnboarding(inviterName: "Justin")
              }
          }
      )
      .transition(.opacity)
  ```

- [ ] **Step 4: Add .onOpenURL modifier**

  After the existing `.onChange(of: scenePhase)` modifier (near line 385), add:
  ```swift
  .onOpenURL { url in
      guard url.scheme == "babytown",
            url.host == "invite" else { return }
      let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
          .queryItems?
          .first(where: { $0.name == "from" })?
          .value ?? "your partner"
      withAnimation(.easeInOut(duration: 0.4)) {
          screen = .partnerOnboarding(inviterName: name)
      }
  }
  ```

- [ ] **Step 5: Build to verify**

  `Cmd+B`. Expected: build succeeds. Note: `PartnerOnboardingFlow` does not exist yet so this step will fail to compile — that is expected. Keep this task's code changes staged and move to Task 6 (Xcode config) and Task 7+ (the new file) before building.

  > **Build order note:** Complete Tasks 6 and 7 first, then return here and build.

- [ ] **Step 6: Commit (after Tasks 6–11 all compile)**
  ```bash
  git add BabyTown/ContentView.swift
  git commit -m "feat(navigation): add partnerOnboarding screen case and deep link handler"
  ```

---

## Task 6: Register `babytown` URL scheme in Xcode

This is a manual Xcode step — no Swift file changes.

- [ ] **Step 1: Open Xcode target settings**

  In Xcode, click the `BabyTown` project in the Navigator, select the `BabyTown` target, and open the **Info** tab.

- [ ] **Step 2: Add URL Type**

  Scroll to **URL Types**, click `+`, and fill in:
  - **Identifier:** `LS.BabyTown`
  - **URL Schemes:** `babytown`
  - **Role:** Editor (default)

- [ ] **Step 3: Verify**

  Build and run on Simulator. Open Safari and navigate to `babytown://invite/TEST?from=Alex`. The app should open. The partner onboarding flow will appear once Task 7–11 are complete.

---

## Task 7: PartnerOnboardingFlow — skeleton + Welcome step

**Files:**
- Create: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift`

- [ ] **Step 1: Create the file with skeleton**

  Create `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift`:
  ```swift
  import SwiftUI
  import PhotosUI

  struct PartnerOnboardingFlow: View {
      let inviterName: String
      var onComplete: () -> Void

      private enum Step: Equatable {
          case welcome, username, email, profilePhoto, colorTheme, giftReveal
      }

      @State private var step: Step = .welcome

      var body: some View {
          ZStack {
              switch step {
              case .welcome:
                  welcomeStep
                      .transition(.opacity)
              case .username:
                  PartnerUsernameStep { username in
                      DataPersistenceManager.shared.saveUserNickname(username)
                      advance()
                  }
                  .transition(.opacity)
              case .email:
                  PartnerEmailStep { email in
                      DataPersistenceManager.shared.savePartnerEmail(email)
                      advance()
                  }
                  .transition(.opacity)
              case .profilePhoto:
                  PartnerPhotoStep { image in
                      if let image {
                          DataPersistenceManager.shared.savePartnerProfilePhoto(image)
                      }
                      advance()
                  }
                  .transition(.opacity)
              case .colorTheme:
                  ColorThemeView(
                      onBack: {},
                      onContinue: { theme in
                          ThemeManager.shared.setTheme(theme)
                          advance()
                      }
                  )
                  .transition(.opacity)
              case .giftReveal:
                  PartnerGiftRevealStep(
                      inviterName: inviterName,
                      onComplete: onComplete
                  )
                  .transition(.opacity)
              }
          }
      }

      private func advance() {
          let next: Step?
          switch step {
          case .welcome:      next = .username
          case .username:     next = .email
          case .email:        next = .profilePhoto
          case .profilePhoto: next = .colorTheme
          case .colorTheme:   next = .giftReveal
          case .giftReveal:   next = nil
          }
          if let next {
              withAnimation(.easeInOut(duration: 0.4)) { step = next }
          } else {
              onComplete()
          }
      }

      // MARK: - Welcome Step

      private var welcomeStep: some View {
          ZStack {
              LinearGradient(
                  colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                  startPoint: .top,
                  endPoint: .bottom
              )
              .ignoresSafeArea()

              VStack(spacing: 0) {
                  Spacer()

                  BookFlipView(animating: true, frameInterval: 0.18, size: 160)
                      .padding(.bottom, 40)

                  VStack(spacing: 14) {
                      Text("\(inviterName) wants to share something with you")
                          .font(.system(size: 26, weight: .light, design: .serif))
                          .foregroundStyle(.primary)
                          .multilineTextAlignment(.center)
                          .padding(.horizontal, 32)

                      Text("A private Prelude, just for you")
                          .font(.system(size: 15))
                          .foregroundStyle(Color(.secondaryLabel))
                  }

                  Spacer()

                  Button(action: advance) {
                      Text("Open it")
                          .font(.system(size: 17, weight: .medium))
                          .foregroundStyle(.white)
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 18)
                          .background(
                              Capsule()
                                  .fill(BabyTownTheme.buttonGradient)
                                  .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                          )
                  }
                  .padding(.horizontal, 40)
                  .padding(.bottom, 52)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Add stub private step structs so the file compiles**

  Append these stubs at the bottom of the file (below `PartnerOnboardingFlow`). They will be replaced in Tasks 8–11:
  ```swift
  // MARK: - Step Stubs (replaced in Tasks 8–11)

  private struct PartnerUsernameStep: View {
      var onContinue: (String) -> Void
      var body: some View { Color.clear }
  }

  private struct PartnerEmailStep: View {
      var onContinue: (String) -> Void
      var body: some View { Color.clear }
  }

  private struct PartnerPhotoStep: View {
      var onContinue: (UIImage?) -> Void
      var body: some View { Color.clear }
  }

  private struct PartnerGiftRevealStep: View {
      let inviterName: String
      var onComplete: () -> Void
      var body: some View { Color.clear }
  }
  ```

- [ ] **Step 3: Build to verify**

  `Cmd+B`. Expected: build succeeds with all stubs in place. The welcome screen is wired and the other steps show blank (to be filled in).

- [ ] **Step 4: Smoke test welcome screen**

  Run on Simulator. In Prelude home, open Settings > "Preview Partner Onboarding". The welcome screen should appear with `BookFlipView` animating, the correct inviter name "Justin", and an "Open it" button that advances to a blank username step.

- [ ] **Step 5: Commit**
  ```bash
  git add BabyTown/Views/Prelude/PartnerOnboardingFlow.swift BabyTown/ContentView.swift
  git commit -m "feat(partner): add PartnerOnboardingFlow skeleton with welcome step"
  ```

---

## Task 8: PartnerOnboardingFlow — Username and Email steps

**Files:**
- Modify: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift`

- [ ] **Step 1: Replace PartnerUsernameStep stub**

  Replace the stub:
  ```swift
  private struct PartnerUsernameStep: View {
      var onContinue: (String) -> Void
      var body: some View { Color.clear }
  }
  ```
  with:
  ```swift
  private struct PartnerUsernameStep: View {
      var onContinue: (String) -> Void

      @State private var username = ""
      @FocusState private var isFieldFocused: Bool

      private var trimmed: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
      private var canContinue: Bool { !trimmed.isEmpty }

      var body: some View {
          ZStack {
              LinearGradient(
                  colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                  startPoint: .top,
                  endPoint: .bottom
              )
              .ignoresSafeArea()

              VStack(spacing: 0) {
                  Spacer()

                  Text("What should we call you?")
                      .font(.system(size: 26, weight: .light, design: .serif))
                      .foregroundStyle(.primary)
                      .multilineTextAlignment(.center)
                      .padding(.horizontal, 32)
                      .padding(.bottom, 32)

                  TextField("Your nickname", text: $username)
                      .textContentType(.nickname)
                      .autocorrectionDisabled()
                      .textInputAutocapitalization(.words)
                      .submitLabel(.continue)
                      .focused($isFieldFocused)
                      .padding(.horizontal, 18)
                      .padding(.vertical, 16)
                      .background(
                          RoundedRectangle(cornerRadius: 14)
                              .fill(Color(.systemGray6))
                              .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                      )
                      .padding(.horizontal, 40)
                      .onSubmit { if canContinue { onContinue(trimmed) } }

                  Spacer()

                  Button {
                      if canContinue { onContinue(trimmed) }
                  } label: {
                      Text("Continue")
                          .font(.system(size: 17, weight: .medium))
                          .foregroundStyle(.white)
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 18)
                          .background(
                              Capsule()
                                  .fill(
                                      canContinue
                                          ? BabyTownTheme.buttonGradient
                                          : LinearGradient(
                                              colors: [Color(.systemGray4), Color(.systemGray4).opacity(0.8)],
                                              startPoint: .leading,
                                              endPoint: .trailing
                                          )
                                  )
                                  .shadow(
                                      color: canContinue ? BabyTownTheme.accent.opacity(0.3) : .clear,
                                      radius: 12, y: 6
                                  )
                          )
                  }
                  .disabled(!canContinue)
                  .padding(.horizontal, 40)
                  .padding(.bottom, 52)
                  .animation(.easeInOut(duration: 0.3), value: canContinue)
              }
          }
          .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFieldFocused = true }
          }
      }
  }
  ```

- [ ] **Step 2: Replace PartnerEmailStep stub**

  Replace the stub:
  ```swift
  private struct PartnerEmailStep: View {
      var onContinue: (String) -> Void
      var body: some View { Color.clear }
  }
  ```
  with:
  ```swift
  private struct PartnerEmailStep: View {
      var onContinue: (String) -> Void

      @State private var email = ""
      @FocusState private var isFieldFocused: Bool

      private var trimmed: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
      private var canContinue: Bool { !trimmed.isEmpty }

      var body: some View {
          ZStack {
              LinearGradient(
                  colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                  startPoint: .top,
                  endPoint: .bottom
              )
              .ignoresSafeArea()

              VStack(spacing: 0) {
                  Spacer()

                  VStack(spacing: 14) {
                      Text("Where can we reach you?")
                          .font(.system(size: 26, weight: .light, design: .serif))
                          .foregroundStyle(.primary)
                          .multilineTextAlignment(.center)

                      Text("For account recovery when we launch")
                          .font(.system(size: 15))
                          .foregroundStyle(Color(.secondaryLabel))
                  }
                  .padding(.horizontal, 32)
                  .padding(.bottom, 32)

                  TextField("Email address", text: $email)
                      .textContentType(.emailAddress)
                      .keyboardType(.emailAddress)
                      .autocorrectionDisabled()
                      .textInputAutocapitalization(.never)
                      .submitLabel(.continue)
                      .focused($isFieldFocused)
                      .padding(.horizontal, 18)
                      .padding(.vertical, 16)
                      .background(
                          RoundedRectangle(cornerRadius: 14)
                              .fill(Color(.systemGray6))
                              .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                      )
                      .padding(.horizontal, 40)
                      .onSubmit { if canContinue { onContinue(trimmed) } }

                  Spacer()

                  Button {
                      if canContinue { onContinue(trimmed) }
                  } label: {
                      Text("Continue")
                          .font(.system(size: 17, weight: .medium))
                          .foregroundStyle(.white)
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 18)
                          .background(
                              Capsule()
                                  .fill(
                                      canContinue
                                          ? BabyTownTheme.buttonGradient
                                          : LinearGradient(
                                              colors: [Color(.systemGray4), Color(.systemGray4).opacity(0.8)],
                                              startPoint: .leading,
                                              endPoint: .trailing
                                          )
                                  )
                                  .shadow(
                                      color: canContinue ? BabyTownTheme.accent.opacity(0.3) : .clear,
                                      radius: 12, y: 6
                                  )
                          )
                  }
                  .disabled(!canContinue)
                  .padding(.horizontal, 40)
                  .padding(.bottom, 52)
                  .animation(.easeInOut(duration: 0.3), value: canContinue)
              }
          }
          .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFieldFocused = true }
          }
      }
  }
  ```

- [ ] **Step 3: Build to verify**

  `Cmd+B`. Expected: build succeeds.

- [ ] **Step 4: Test username and email steps**

  Run on Simulator, trigger preview. Advance past welcome. Confirm:
  - Username screen shows with auto-focused field. Continue enabled only when non-empty. Tapping Continue advances to email.
  - Email screen shows correct label and subtext. Email keyboard type active. Continue advances to blank photo step.

- [ ] **Step 5: Commit**
  ```bash
  git add BabyTown/Views/Prelude/PartnerOnboardingFlow.swift
  git commit -m "feat(partner): add username and email onboarding steps"
  ```

---

## Task 9: PartnerOnboardingFlow — Profile Photo step

**Files:**
- Modify: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift`

- [ ] **Step 1: Replace PartnerPhotoStep stub**

  Replace the stub:
  ```swift
  private struct PartnerPhotoStep: View {
      var onContinue: (UIImage?) -> Void
      var body: some View { Color.clear }
  }
  ```
  with:
  ```swift
  private struct PartnerPhotoStep: View {
      var onContinue: (UIImage?) -> Void

      @State private var pickerItem: PhotosPickerItem?
      @State private var selectedImage: UIImage?

      var body: some View {
          ZStack {
              LinearGradient(
                  colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                  startPoint: .top,
                  endPoint: .bottom
              )
              .ignoresSafeArea()

              VStack(spacing: 0) {
                  Spacer()

                  VStack(spacing: 14) {
                      Text("Add a photo of yourself")
                          .font(.system(size: 26, weight: .light, design: .serif))
                          .foregroundStyle(.primary)
                          .multilineTextAlignment(.center)

                      Text("Your partner will see this")
                          .font(.system(size: 15))
                          .foregroundStyle(Color(.secondaryLabel))
                  }
                  .padding(.horizontal, 32)
                  .padding(.bottom, 32)

                  PhotosPicker(selection: $pickerItem, matching: .images) {
                      ZStack {
                          Circle()
                              .fill(Color(.systemGray5))
                              .frame(width: 120, height: 120)

                          if let selectedImage {
                              Image(uiImage: selectedImage)
                                  .resizable()
                                  .scaledToFill()
                                  .frame(width: 120, height: 120)
                                  .clipShape(Circle())
                          } else {
                              Image(systemName: "plus")
                                  .font(.system(size: 32, weight: .light))
                                  .foregroundStyle(BabyTownTheme.accent)
                          }
                      }
                  }
                  .onChange(of: pickerItem) { _, newItem in
                      guard let newItem else { return }
                      Task {
                          if let data = try? await newItem.loadTransferable(type: Data.self),
                             let image = UIImage(data: data) {
                              selectedImage = image
                          }
                      }
                  }

                  Spacer()

                  VStack(spacing: 14) {
                      Button {
                          onContinue(selectedImage)
                      } label: {
                          Text("Continue")
                              .font(.system(size: 17, weight: .medium))
                              .foregroundStyle(.white)
                              .frame(maxWidth: .infinity)
                              .padding(.vertical, 18)
                              .background(
                                  Capsule()
                                      .fill(BabyTownTheme.buttonGradient)
                                      .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                              )
                      }
                      .padding(.horizontal, 40)

                      Button {
                          onContinue(nil)
                      } label: {
                          Text("Skip")
                              .font(.system(size: 15))
                              .foregroundStyle(Color(.secondaryLabel))
                      }
                  }
                  .padding(.bottom, 52)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  `Cmd+B`. Expected: build succeeds.

- [ ] **Step 3: Test photo step**

  Run on Simulator. Advance to photo step. Confirm:
  - Grey circle with `+` icon shows.
  - Tapping opens photo library.
  - After selection, circle shows selected photo.
  - "Continue" saves photo and advances. "Skip" advances without saving.

- [ ] **Step 4: Commit**
  ```bash
  git add BabyTown/Views/Prelude/PartnerOnboardingFlow.swift
  git commit -m "feat(partner): add profile photo onboarding step with PhotosPicker"
  ```

---

## Task 10: PartnerOnboardingFlow — Color Theme step

The color theme step is already wired in the main `body` switch using `ColorThemeView(onBack: {}, onContinue: { ... })` from Task 7. No stub to replace. This task verifies it works.

**Files:**
- Modify: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift` (no changes needed if Task 7 is complete)

- [ ] **Step 1: Verify wiring in body**

  In the main `body` switch in `PartnerOnboardingFlow`, confirm this case is present:
  ```swift
  case .colorTheme:
      ColorThemeView(
          onBack: {},
          onContinue: { theme in
              ThemeManager.shared.setTheme(theme)
              advance()
          }
      )
      .transition(.opacity)
  ```

  If it's missing (wasn't included in Task 7), add it now.

- [ ] **Step 2: Test color theme step**

  Run on Simulator. Advance through photo step to reach color theme. Confirm:
  - ColorThemeView renders with existing visual. 
  - The back button (from `onBack: {}`) does nothing when tapped.
  - Selecting a theme and tapping Continue advances to a blank gift reveal step.

- [ ] **Step 3: Commit (only if a code change was needed)**
  ```bash
  git add BabyTown/Views/Prelude/PartnerOnboardingFlow.swift
  git commit -m "feat(partner): wire ColorThemeView into partner onboarding step"
  ```

---

## Task 11: PartnerOnboardingFlow — Gift Reveal step

**Files:**
- Modify: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift`

- [ ] **Step 1: Replace PartnerGiftRevealStep stub**

  Replace:
  ```swift
  private struct PartnerGiftRevealStep: View {
      let inviterName: String
      var onComplete: () -> Void
      var body: some View { Color.clear }
  }
  ```
  with:
  ```swift
  private struct PartnerGiftRevealStep: View {
      let inviterName: String
      var onComplete: () -> Void

      @State private var bookAnimating = true

      private static let mockCaptures: [PreludeCapture] = [
          PreludeCapture(type: .note, noteText: "I keep thinking about you."),
          PreludeCapture(type: .voiceMemo),
          PreludeCapture(type: .first, firstLabel: "Our first real conversation"),
      ]

      var body: some View {
          ZStack {
              LinearGradient(
                  colors: [BabyTownTheme.accentDeep.opacity(0.85), BabyTownTheme.background],
                  startPoint: .top,
                  endPoint: .bottom
              )
              .ignoresSafeArea()

              VStack(spacing: 0) {
                  BookFlipView(animating: bookAnimating, frameInterval: 0.18, size: 160)
                      .padding(.top, 60)
                      .padding(.bottom, 24)

                  Text("\(inviterName) made this for you")
                      .font(.system(size: 24, weight: .light, design: .serif))
                      .foregroundStyle(.white)
                      .multilineTextAlignment(.center)
                      .padding(.horizontal, 32)
                      .padding(.bottom, 24)

                  ScrollView(showsIndicators: false) {
                      VStack(spacing: 10) {
                          ForEach(Self.mockCaptures) { capture in
                              GiftCaptureRow(capture: capture, onToggle: {})
                          }
                      }
                      .padding(.horizontal, 20)
                      .padding(.bottom, 16)
                  }

                  Button(action: onComplete) {
                      Text("Open our space")
                          .font(.system(size: 17, weight: .semibold))
                          .foregroundStyle(.white)
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 18)
                          .background(
                              Capsule()
                                  .fill(AnyShapeStyle(BabyTownTheme.accentGradient))
                          )
                  }
                  .buttonStyle(.plain)
                  .padding(.horizontal, 28)
                  .padding(.top, 12)
                  .padding(.bottom, 52)
              }
          }
          .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                  bookAnimating = false
              }
          }
      }
  }
  ```

- [ ] **Step 2: Remove the stub comment**

  Remove the `// MARK: - Step Stubs (replaced in Tasks 8–11)` comment line added in Task 7.

- [ ] **Step 3: Build to verify**

  `Cmd+B`. Expected: build succeeds with no errors.

- [ ] **Step 4: End-to-end test**

  Run on Simulator. Open Settings > "Preview Partner Onboarding". Walk the full flow:
  1. Welcome — BookFlipView animating, "Open it" CTA → username step
  2. Username — type a name, Continue → email step  
  3. Email — type an email, Continue → photo step
  4. Photo — tap Skip → color theme step
  5. Color theme — select any theme, Continue → gift reveal step
  6. Gift reveal — BookFlipView animates ~1.5s then stops; three mock capture rows visible; "Open our space" → transitions to Official home (`HomeView`)

- [ ] **Step 5: Commit**
  ```bash
  git add BabyTown/Views/Prelude/PartnerOnboardingFlow.swift
  git commit -m "feat(partner): complete gift reveal step; partner onboarding flow done"
  ```

---

## Self-Review Checklist

**Spec coverage:**

| Spec requirement | Task covering it |
|---|---|
| Welcome screen — BookFlipView 160pt, 0.18 interval | Task 7 |
| Welcome headline + subtext + "Open it" CTA | Task 7 |
| Username — "What should we call you?", saves via `saveUserNickname` | Task 8 |
| Email — label, subtext, `.emailAddress` keyboard, saves via `savePartnerEmail` | Task 8 |
| Photo — 120pt circle, PhotosPicker, Skip link, saves via `savePartnerProfilePhoto` | Task 9 |
| Color theme — existing `ColorThemeView`, calls `ThemeManager.shared.setTheme` | Task 10 |
| Gift reveal — warm/dark bg, BookFlipView 1.5s then stops, headline, mock rows | Task 11 |
| Gift reveal — "Open our space" → `onComplete()` | Task 11 |
| `PartnerOnboardingFlow` struct + `Step` enum | Task 7 |
| `ContentView` new case `.partnerOnboarding(inviterName:)` | Task 5 |
| `.onOpenURL` parses `babytown://invite/CODE?from=NAME` | Task 5 |
| `onComplete` sets `.officialCouple`, `hasCompletedOnboarding = true`, → `.home` | Task 5 |
| URL scheme `babytown` in Info.plist | Task 6 |
| `DataPersistenceManager.savePartnerEmail` — UserDefaults key "partnerEmail" | Task 1 |
| `DataPersistenceManager.savePartnerProfilePhoto` — JPEG in documents dir | Task 1 |
| `PreludeSettingsSheet` "Preview Partner Onboarding" row + footer | Task 3 |
| No back navigation after welcome | Tasks 7–10 (no `onboardingBackButton`, `onBack: {}` in ColorThemeView) |
| All transitions `.transition(.opacity)` | Tasks 7–11 |

**Placeholder scan:** No TBD, TODO, or "implement later" in this plan. All code blocks are complete.

**Type consistency check:**
- `GiftCaptureRow(capture:onToggle:)` — defined in `GiftCurationView.swift` (made non-private in Task 2), used in Task 11. ✓
- `DataPersistenceManager.shared.savePartnerEmail(_:)` — defined in Task 1, called in Task 7. ✓
- `DataPersistenceManager.shared.savePartnerProfilePhoto(_:)` — defined in Task 1, called in Task 7. ✓
- `ThemeManager.shared.setTheme(_:)` — pre-existing, used in Task 10. ✓
- `BookFlipView(animating:frameInterval:size:)` — pre-existing, used in Tasks 7 and 11. ✓
- `PreludeCapture(type:noteText:)` / `PreludeCapture(type:)` / `PreludeCapture(type:firstLabel:)` — all valid constructors per the model. ✓
- `BabyTownTheme.buttonGradient`, `.accentDeep`, `.accentGradient`, `.accent`, `.background` — all confirmed present in `BabyTownTheme.swift`. ✓
- `PartnerUsernameStep`, `PartnerEmailStep`, `PartnerPhotoStep`, `PartnerGiftRevealStep` — defined and referenced consistently throughout. ✓
