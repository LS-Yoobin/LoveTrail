# Settings: Log Out + Account Info — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Log Out button to SettingsSheet and an Account Info subpage showing email, username, and birthday in read-only form.

**Architecture:** All UI changes live in `SettingsSheet.swift` (a new `onLogOut` closure param, an Account section with a NavigationLink, a Log Out button in the App section, and a private `AccountInfoView` struct). The callback threads up through `HomeView` → `ContentView` and `PendingHomeView` → `ContentView`, where the actual `AuthService.shared.signOut()` call and screen transition live.

**Tech Stack:** SwiftUI, `DataPersistenceManager`, `AuthService`, `SpecialDate`

## Global Constraints

- Never use ` - ` (space dash space) in any user-facing string
- Always use `BabyTownTheme.*` tokens for colors — never hardcode hex or RGB
- Both Pink and Blue themes must always be supported
- No editing of account info fields in this iteration (read-only)

---

### Task 1: SettingsSheet — add `onLogOut`, Account section, Log Out button, and `AccountInfoView`

**Files:**
- Modify: `BabyTown/Components/SettingsSheet.swift`

**Interfaces:**
- Produces: `SettingsSheet(onResetApp:onReplayStory:onVisitPet:onOpenCoupleProfile:onLogOut:)`
- Produces: `private struct AccountInfoView: View` at bottom of file

- [ ] **Step 1: Add `onLogOut` closure property and `showLogOutConfirmation` state**

  In `SettingsSheet`, after the existing `var onOpenCoupleProfile: () -> Void = {}` line, add:

  ```swift
  var onLogOut: () -> Void = {}
  ```

  After `@State private var showResetConfirmation = false`, add:

  ```swift
  @State private var showLogOutConfirmation = false
  ```

- [ ] **Step 2: Add Account section (after Subscription section)**

  In the `List`, immediately after the closing `}` of the Subscription `Section`, insert:

  ```swift
  Section {
      NavigationLink {
          AccountInfoView()
      } label: {
          Text("Account Info")
      }
  } header: {
      Text("Account")
  }
  ```

- [ ] **Step 3: Add Log Out button to App section**

  Replace the current App `Section`:

  ```swift
  Section {
      // Temporarily hidden: Replay Our Story
      Button(role: .destructive) {
          showResetConfirmation = true
      } label: {
          HStack {
              Image(systemName: "arrow.counterclockwise")
                  .font(.system(size: 16))
              Text("Reset App")
                  .font(.system(size: 16))
          }
      }
  } header: {
      Text("App")
  }
  ```

  With:

  ```swift
  Section {
      // Temporarily hidden: Replay Our Story
      Button(role: .destructive) {
          showResetConfirmation = true
      } label: {
          HStack {
              Image(systemName: "arrow.counterclockwise")
                  .font(.system(size: 16))
              Text("Reset App")
                  .font(.system(size: 16))
          }
      }

      Button(role: .destructive) {
          showLogOutConfirmation = true
      } label: {
          HStack {
              Image(systemName: "rectangle.portrait.and.arrow.right")
                  .font(.system(size: 16))
              Text("Log Out")
                  .font(.system(size: 16))
          }
      }
  } header: {
      Text("App")
  }
  ```

- [ ] **Step 4: Add `confirmationDialog` for Log Out**

  After the existing `confirmationDialog` for Reset App (which ends around line 243), add:

  ```swift
  .confirmationDialog(
      "Log out of Covela?",
      isPresented: $showLogOutConfirmation,
      titleVisibility: .visible
  ) {
      Button("Log Out", role: .destructive) {
          onLogOut()
          dismiss()
      }
      Button("Cancel", role: .cancel) {}
  } message: {
      Text("Your data stays on this device.")
  }
  ```

- [ ] **Step 5: Add `AccountInfoView` private struct**

  After the closing `}` of the `SettingsSheet` struct (before `private struct AppIconViewerOverlay`), insert:

  ```swift
  private struct AccountInfoView: View {
      private var email: String {
          DataPersistenceManager.shared.loadUserEmail()
              ?? AuthService.shared.currentUser?.email
              ?? "Not set"
      }

      private var username: String {
          DataPersistenceManager.shared.loadUserNickname() ?? "Not set"
      }

      private var birthday: String {
          let profile = DataPersistenceManager.shared.loadCoupleProfile()
          guard let entry = profile.specialDates.first(where: { $0.id == SpecialDate.localUserBirthdayID }) else {
              return "Not set"
          }
          let formatter = DateFormatter()
          formatter.dateFormat = "MMM d, yyyy"
          return formatter.string(from: entry.date)
      }

      var body: some View {
          List {
              Section {
                  HStack {
                      Text("Email")
                          .foregroundStyle(.primary)
                      Spacer()
                      Text(email)
                          .foregroundStyle(.secondary)
                  }
                  HStack {
                      Text("Username")
                          .foregroundStyle(.primary)
                      Spacer()
                      Text(username)
                          .foregroundStyle(.secondary)
                  }
                  HStack {
                      Text("Birthday")
                          .foregroundStyle(.primary)
                      Spacer()
                      Text(birthday)
                          .foregroundStyle(.secondary)
                  }
              }
          }
          .navigationTitle("Account Info")
          .navigationBarTitleDisplayMode(.inline)
      }
  }
  ```

- [ ] **Step 6: Update the `#Preview` to include `onLogOut`**

  Replace:
  ```swift
  #Preview {
      SettingsSheet(onResetApp: {}, onReplayStory: {}, onVisitPet: {})
  }
  ```
  With:
  ```swift
  #Preview {
      SettingsSheet(onResetApp: {}, onReplayStory: {}, onVisitPet: {}, onLogOut: {})
  }
  ```

- [ ] **Step 7: Build the project to verify no compiler errors**

  Open Xcode and build (`Cmd+B`). Expected: build succeeds with no errors.

- [ ] **Step 8: Commit**

  ```bash
  git add BabyTown/Components/SettingsSheet.swift
  git commit -m "feat: add Log Out button and Account Info subpage to SettingsSheet"
  ```

---

### Task 2: Thread `onLogOut` through `HomeView` and `PendingHomeView`

**Files:**
- Modify: `BabyTown/Views/HomeView.swift`
- Modify: `BabyTown/Views/PendingHomeView.swift`

**Interfaces:**
- Consumes: `onLogOut: () -> Void` closure from `SettingsSheet` (Task 1)
- Produces: `HomeView(... onLogOut: (() -> Void)? = nil ...)` — both `init` overloads updated
- Produces: `PendingHomeView(... onLogOut: () -> Void = {} ...)` — stored property added

#### HomeView

- [ ] **Step 1: Add `onLogOut` stored property**

  In `HomeView`, after `var onReplayStory: (() -> Void)? = nil`, add:

  ```swift
  var onLogOut: (() -> Void)? = nil
  ```

- [ ] **Step 2: Add `onLogOut` to both `init` overloads**

  First `init` (lines ~103-123). After `onReplayStory: (() -> Void)? = nil,` in the parameter list add:
  ```swift
  onLogOut: (() -> Void)? = nil,
  ```
  And after `self.onReplayStory = onReplayStory` in the body add:
  ```swift
  self.onLogOut = onLogOut
  ```

  Second `init` (lines ~125-139). Same pattern — add `onLogOut: (() -> Void)? = nil,` to the parameter list and `self.onLogOut = onLogOut` to the body.

- [ ] **Step 3: Pass `onLogOut` to `SettingsSheet` call site**

  In `HomeView.body`, find the `.sheet(isPresented: $showSettings)` block (around line 549). Replace:

  ```swift
  .sheet(isPresented: $showSettings) {
      SettingsSheet(
          onResetApp: { onResetApp?() },
          onReplayStory: { onReplayStory?() },
          onVisitPet: { showVisitPet = true },
          onOpenCoupleProfile: { showCoupleProfile = true }
      )
  }
  ```

  With:

  ```swift
  .sheet(isPresented: $showSettings) {
      SettingsSheet(
          onResetApp: { onResetApp?() },
          onReplayStory: { onReplayStory?() },
          onVisitPet: { showVisitPet = true },
          onOpenCoupleProfile: { showCoupleProfile = true },
          onLogOut: { onLogOut?() }
      )
  }
  ```

#### PendingHomeView

- [ ] **Step 4: Add `onLogOut` stored property**

  In `PendingHomeView`, after `var onResetApp: () -> Void = {}`, add:

  ```swift
  var onLogOut: () -> Void = {}
  ```

- [ ] **Step 5: Pass `onLogOut` to `SettingsSheet` call site**

  In `PendingHomeView.body`, find the `.sheet(isPresented: $showSettings)` block (around line 74). Replace:

  ```swift
  .sheet(isPresented: $showSettings) {
      SettingsSheet(
          onResetApp: {
              showSettings = false
              onResetApp()
          },
          onReplayStory: {},
          onVisitPet: {
              showSettings = false
              showVisitPet = true
          },
          onOpenCoupleProfile: {
              showSettings = false
              showWaitingGarden = true
          }
      )
  }
  ```

  With:

  ```swift
  .sheet(isPresented: $showSettings) {
      SettingsSheet(
          onResetApp: {
              showSettings = false
              onResetApp()
          },
          onReplayStory: {},
          onVisitPet: {
              showSettings = false
              showVisitPet = true
          },
          onOpenCoupleProfile: {
              showSettings = false
              showWaitingGarden = true
          },
          onLogOut: { onLogOut() }
      )
  }
  ```

- [ ] **Step 6: Build the project to verify no compiler errors**

  Build in Xcode (`Cmd+B`). Expected: build succeeds with no errors.

- [ ] **Step 7: Commit**

  ```bash
  git add BabyTown/Views/HomeView.swift BabyTown/Views/PendingHomeView.swift
  git commit -m "feat: thread onLogOut callback through HomeView and PendingHomeView"
  ```

---

### Task 3: Wire sign-out logic in `ContentView`

**Files:**
- Modify: `BabyTown/ContentView.swift`

**Interfaces:**
- Consumes: `HomeView(... onLogOut: (() -> Void)? = nil ...)` (Task 2)
- Consumes: `PendingHomeView(... onLogOut: () -> Void = {} ...)` (Task 2)
- Consumes: `AuthService.shared.signOut()` — sets `currentUser = nil`

- [ ] **Step 1: Add `onLogOut` to the `HomeView` call site**

  In `ContentView`, find the `case .home:` block (around line 306). The `HomeView(...)` call currently ends with `selectedPrompt: $selectedPrompt`. Add `onLogOut` before the closing `)`:

  Replace:
  ```swift
  HomeView(
      viewModel: homeViewModel,
      onSelectPhotos: {
          screen = .selectPhotos
      },
      onOpenPhotoViewer: { _, _ in },
      onResetApp: resetAppToWelcome,
      onReplayStory: {
          withAnimation(.easeInOut(duration: 0.4)) {
              screen = .storyOnboarding
          }
      },
      selectedPrompt: $selectedPrompt
  )
  ```

  With:
  ```swift
  HomeView(
      viewModel: homeViewModel,
      onSelectPhotos: {
          screen = .selectPhotos
      },
      onOpenPhotoViewer: { _, _ in },
      onResetApp: resetAppToWelcome,
      onReplayStory: {
          withAnimation(.easeInOut(duration: 0.4)) {
              screen = .storyOnboarding
          }
      },
      selectedPrompt: $selectedPrompt,
      onLogOut: {
          AuthService.shared.signOut()
          withAnimation(.easeInOut(duration: 0.4)) {
              screen = .auth
          }
      }
  )
  ```

- [ ] **Step 2: Add `onLogOut` to the `PendingHomeView` call site**

  In `ContentView`, find the `case .officialPending:` block (around line 450). Replace:

  ```swift
  PendingHomeView(
      onPartnerJoined: { captures, revealerName in
          withAnimation(.easeInOut(duration: 0.4)) {
              if captures.isEmpty {
                  screen = .justPickPhotos
              } else {
                  screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
              }
          }
      },
      onResetApp: resetAppToWelcome
  )
  ```

  With:

  ```swift
  PendingHomeView(
      onPartnerJoined: { captures, revealerName in
          withAnimation(.easeInOut(duration: 0.4)) {
              if captures.isEmpty {
                  screen = .justPickPhotos
              } else {
                  screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
              }
          }
      },
      onResetApp: resetAppToWelcome,
      onLogOut: {
          AuthService.shared.signOut()
          withAnimation(.easeInOut(duration: 0.4)) {
              screen = .auth
          }
      }
  )
  ```

- [ ] **Step 3: Build the project to verify no compiler errors**

  Build in Xcode (`Cmd+B`). Expected: build succeeds with no errors.

- [ ] **Step 4: Manual smoke test — Log Out flow**

  1. Run the app on simulator
  2. Complete onboarding (or launch into an existing `.home` state)
  3. Tap the settings gear icon
  4. Verify the **Account** section appears above Color Theme with an "Account Info" row
  5. Tap "Account Info" — verify a pushed view appears titled "Account Info" with Email, Username, and Birthday rows
  6. Tap Back
  7. Scroll to the **App** section — verify "Log Out" appears below "Reset App" in red
  8. Tap "Log Out" — verify the confirmation dialog reads "Log out of Covela?" with message "Your data stays on this device."
  9. Tap Cancel — verify nothing happens
  10. Tap "Log Out" again, then confirm — verify the sheet dismisses and the app returns to the auth screen

- [ ] **Step 5: Manual smoke test — PendingHomeView Log Out**

  1. Put the app into the `.officialPending` state (via Reset App or direct launch)
  2. Open Settings and repeat steps 7–10 above — verify same behavior

- [ ] **Step 6: Commit**

  ```bash
  git add BabyTown/ContentView.swift
  git commit -m "feat: wire onLogOut in ContentView to sign out and return to auth screen"
  ```
