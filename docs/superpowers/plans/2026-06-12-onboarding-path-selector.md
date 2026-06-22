# Onboarding Path Selector + Prelude Intro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a path-selection screen ("Prelude" vs "Already Official") after the Birthday onboarding step, build a Prelude intro explanation screen, and add a Settings icon to PreludeHomeView that lets users return to onboarding.

**Architecture:** Three new SwiftUI views are added (`PathSelectorView`, `PreludeOnboardingView`, `PreludeSettingsSheet`), ContentView gains two new Screen cases and updated navigation wiring, and PreludeHomeView gains a settings icon overlay backed by a sheet. No new models or persistence keys are needed — the existing `RelationshipStage.prelude` and `setOnboardingCompleted` API cover all state transitions.

**Tech Stack:** SwiftUI, BabyTownTheme, DataPersistenceManager, SF Symbols

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `BabyTown/ContentView.swift` | Add `.pathSelector` + `.preludeOnboarding` Screen cases; wire all navigation |
| Create | `BabyTown/Views/PathSelectorView.swift` | Two-card screen: "Prelude" or "Already Official" |
| Create | `BabyTown/Views/Prelude/PreludeOnboardingView.swift` | Single-scroll Prelude intro with feature rows and gift section |
| Create | `BabyTown/Views/Prelude/PreludeSettingsSheet.swift` | Settings sheet shown from PreludeHomeView |
| Modify | `BabyTown/Views/Prelude/PreludeHomeView.swift` | Add settings gear icon + sheet presentation + `onReturnToOnboarding` callback |

---

## Task 1: Extend ContentView.Screen and add stub cases

**Files:**
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Add two new cases to the Screen enum**

Open `ContentView.swift`. The `Screen` enum is on line 12. Add the two new cases:

```swift
enum Screen {
    case launch, welcome, storyOnboarding, nickname, colorTheme, birthday
    case pathSelector          // NEW — branch point after birthday
    case firstMemories, howItWorks, photoAccess, home, selectPhotos
    case loveGarden
    case prelude
    case preludeOnboarding     // NEW — prelude intro screen
    case archivedCouple
}
```

- [ ] **Step 2: Update the birthday case's onContinue to navigate to pathSelector instead of firstMemories**

Find this block in `ContentView.swift` (around line 134):

```swift
case .birthday:
    UserBirthdayView(
        onBack: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .colorTheme
            }
        },
        onContinue: { birthday in
            let nickname = DataPersistenceManager.shared.loadUserNickname() ?? ""
            DataPersistenceManager.shared.saveOnboardingUserBirthday(birthday, nickname: nickname)
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .firstMemories
            }
        }
    )
    .transition(.opacity)
```

Replace the `screen = .firstMemories` line so birthday flows to pathSelector:

```swift
case .birthday:
    UserBirthdayView(
        onBack: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .colorTheme
            }
        },
        onContinue: { birthday in
            let nickname = DataPersistenceManager.shared.loadUserNickname() ?? ""
            DataPersistenceManager.shared.saveOnboardingUserBirthday(birthday, nickname: nickname)
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .pathSelector
            }
        }
    )
    .transition(.opacity)
```

- [ ] **Step 3: Add stub cases for pathSelector and preludeOnboarding inside the switch**

In the `body` ZStack switch, add these two cases right after the `.birthday` case (before `.firstMemories`):

```swift
case .pathSelector:
    Color.clear
        .transition(.opacity)

case .preludeOnboarding:
    Color.clear
        .transition(.opacity)
```

- [ ] **Step 4: Build the app to confirm it compiles**

In Xcode press ⌘B. Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "feat(onboarding): add pathSelector and preludeOnboarding Screen cases"
```

---

## Task 2: Build PathSelectorView

**Files:**
- Create: `BabyTown/Views/PathSelectorView.swift`

- [ ] **Step 1: Create the file with the full view**

```swift
import SwiftUI

struct PathSelectorView: View {

    var onSelectPrelude: () -> Void
    var onSelectOfficial: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Where are you right now?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("We will set things up just right for you.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 80)

                Spacer()

                VStack(spacing: 16) {
                    PathCard(
                        icon: "envelope.heart.fill",
                        title: "Prelude",
                        description: "There is someone special on your mind. Not official yet.",
                        action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSelectPrelude()
                        }
                    )

                    PathCard(
                        icon: "heart.circle.fill",
                        title: "Already Official",
                        description: "You are in a relationship and ready to build your shared space.",
                        action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSelectOfficial()
                        }
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
    }
}

private struct PathCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(BabyTownTheme.accent)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(BabyTownTheme.accent.opacity(0.1)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(BabyTownTheme.accent.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PathSelectorView(
        onSelectPrelude: { print("prelude") },
        onSelectOfficial: { print("official") }
    )
}
```

- [ ] **Step 2: Build and check the preview renders correctly**

In Xcode press ⌘B, then open the preview canvas for `PathSelectorView.swift`. You should see two rounded cards on a soft gradient background with the correct text and icons.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/PathSelectorView.swift
git commit -m "feat(onboarding): add PathSelectorView with Prelude and Already Official cards"
```

---

## Task 3: Wire PathSelectorView into ContentView

**Files:**
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Replace the stub pathSelector case with the real view**

Find the stub case you added in Task 1:

```swift
case .pathSelector:
    Color.clear
        .transition(.opacity)
```

Replace it with:

```swift
case .pathSelector:
    PathSelectorView(
        onSelectPrelude: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .preludeOnboarding
            }
        },
        onSelectOfficial: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .firstMemories
            }
        }
    )
    .transition(.opacity)
```

- [ ] **Step 2: Build (⌘B) and verify no errors**

- [ ] **Step 3: Run the app in Simulator, complete Welcome → Nickname → ColorTheme → Birthday, and confirm the PathSelectorView appears with both cards**

- [ ] **Step 4: Tap "Already Official" and confirm it navigates to FirstMemoriesView**

- [ ] **Step 5: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "feat(onboarding): wire PathSelectorView; Already Official routes to FirstMemories"
```

---

## Task 4: Build PreludeOnboardingView

**Files:**
- Create: `BabyTown/Views/Prelude/PreludeOnboardingView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct PreludeOnboardingView: View {

    var onBegin: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    featureList
                    giftSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    beginButton
                        .padding(.horizontal, 40)
                        .padding(.top, 24)
                        .padding(.bottom, 52)
                }
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BabyTownTheme.accent.opacity(0.18),
                    BabyTownTheme.accent.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                Text("💌")
                    .font(.system(size: 54))
                    .padding(.top, 44)

                Text("Your space to fall in love, quietly.")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Capture every feeling before you are official.")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(
                icon: "pencil.and.scribble",
                title: "Notes & Reflections",
                description: "Write how you feel whenever it hits you. Even the small stuff."
            )
            Divider().padding(.leading, 60)
            featureRow(
                icon: "star.fill",
                title: "Firsts",
                description: "Every first has a story. Do not let a single one slip away."
            )
            Divider().padding(.leading, 60)
            featureRow(
                icon: "mic.fill",
                title: "Voice Memos",
                description: "Speak your mind in the moment. Raw, real, and unfiltered."
            )
            Divider().padding(.leading, 60)
            featureRow(
                icon: "heart.fill",
                title: "Reasons",
                description: "The little things you love about them, in your own words."
            )
        }
        .background(Color(.systemBackground))
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(BabyTownTheme.accent.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Gift section

    private var giftSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🎁")
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 5) {
                Text("When you are ready, send them a gift.")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Package your captured moments into a scrapbook. When they join, they will see exactly how you felt before you were ever official.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.29, green: 0.10, blue: 0.26),
                            Color(red: 0.55, green: 0.24, blue: 0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - CTA

    private var beginButton: some View {
        Button(action: onBegin) {
            Text("Begin my Prelude")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.accentGradient)
                        .shadow(color: BabyTownTheme.accent.opacity(0.35), radius: 14, y: 6)
                )
        }
    }
}

#Preview {
    PreludeOnboardingView(onBegin: { print("begin") })
}
```

- [ ] **Step 2: Build (⌘B) and open the Xcode preview**

You should see the pink gradient hero at top, four feature rows with dividers, the dark plum gift card, and the CTA button.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeOnboardingView.swift
git commit -m "feat(onboarding): add PreludeOnboardingView with hero, features, gift section"
```

---

## Task 5: Wire PreludeOnboardingView into ContentView and complete the Prelude path

**Files:**
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Replace the stub preludeOnboarding case**

Find:

```swift
case .preludeOnboarding:
    Color.clear
        .transition(.opacity)
```

Replace with:

```swift
case .preludeOnboarding:
    PreludeOnboardingView(
        onBegin: {
            var profile = DataPersistenceManager.shared.loadCoupleProfile()
            profile.relationshipStage = .prelude
            DataPersistenceManager.shared.saveCoupleProfile(profile)
            DataPersistenceManager.shared.setOnboardingCompleted(true)
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .prelude
            }
        }
    )
    .transition(.opacity)
```

- [ ] **Step 2: Build (⌘B)**

- [ ] **Step 3: Run in Simulator and walk the full Prelude path**

Welcome → Nickname → ColorTheme → Birthday → PathSelectorView → tap "Prelude" → PreludeOnboardingView → tap "Begin my Prelude" → PreludeHomeView appears.

Kill and relaunch the app — it should return directly to PreludeHomeView (onboarding is marked complete, stage is .prelude).

- [ ] **Step 4: Commit**

```bash
git add BabyTown/ContentView.swift
git commit -m "feat(onboarding): wire PreludeOnboardingView; Prelude path complete end-to-end"
```

---

## Task 6: Build PreludeSettingsSheet

**Files:**
- Create: `BabyTown/Views/Prelude/PreludeSettingsSheet.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct PreludeSettingsSheet: View {

    var onReturnToOnboarding: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onReturnToOnboarding()
                        }
                    } label: {
                        Label("Return to Onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("This will take you back to the beginning. Your captures are kept safe.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    PreludeSettingsSheet(onReturnToOnboarding: { print("return to onboarding") })
}
```

The `asyncAfter(0.35)` gives the sheet time to fully dismiss before ContentView transitions screens — without it the navigation animation can stutter.

- [ ] **Step 2: Build (⌘B) and check the preview**

You should see a List with one row "Return to Onboarding" and a footer note, plus a "Done" toolbar button.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeSettingsSheet.swift
git commit -m "feat(prelude): add PreludeSettingsSheet with return-to-onboarding action"
```

---

## Task 7: Add settings icon to PreludeHomeView and wire the callback

**Files:**
- Modify: `BabyTown/Views/Prelude/PreludeHomeView.swift`
- Modify: `BabyTown/ContentView.swift`

- [ ] **Step 1: Add the callback property and sheet state to PreludeHomeView**

Open `PreludeHomeView.swift`. The struct declaration currently reads:

```swift
struct PreludeHomeView: View {

    @StateObject private var viewModel = PreludeViewModel()
    @State private var showCaptureEditor = false
```

Add the callback and sheet state:

```swift
struct PreludeHomeView: View {

    var onReturnToOnboarding: () -> Void = {}

    @StateObject private var viewModel = PreludeViewModel()
    @State private var showCaptureEditor = false
    @State private var showSettings = false
```

- [ ] **Step 2: Add the settings icon overlay to the body**

The `body` currently ends with `.fullScreenCover(isPresented: $showGiftCuration)`. Add the settings overlay and sheet after the existing modifiers:

```swift
.overlay(alignment: .topLeading) {
    Button {
        showSettings = true
    } label: {
        Image(systemName: "gearshape")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(BabyTownTheme.textSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.leading, 12)
    .padding(.top, 4)
}
.sheet(isPresented: $showSettings) {
    PreludeSettingsSheet(onReturnToOnboarding: onReturnToOnboarding)
}
```

- [ ] **Step 3: Build (⌘B) and open the PreludeHomeView preview**

You should see a gear icon at the top-left of the screen. Tap it in the Simulator — the settings sheet should slide up with the "Return to Onboarding" row.

- [ ] **Step 4: Update ContentView to pass the onReturnToOnboarding callback**

In `ContentView.swift`, find:

```swift
case .prelude:
    PreludeHomeView()
        .transition(.opacity)
```

Replace with:

```swift
case .prelude:
    PreludeHomeView(
        onReturnToOnboarding: {
            DataPersistenceManager.shared.setOnboardingCompleted(false)
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .welcome
            }
        }
    )
    .transition(.opacity)
```

- [ ] **Step 5: Build (⌘B) and run the full settings return-to-onboarding flow in Simulator**

Navigate to PreludeHomeView → tap gear icon → tap "Return to Onboarding" → confirm app transitions to WelcomeView → complete onboarding again → confirm it routes back to PreludeHomeView correctly.

- [ ] **Step 6: Commit**

```bash
git add BabyTown/Views/Prelude/PreludeHomeView.swift BabyTown/ContentView.swift
git commit -m "feat(prelude): add settings icon with return-to-onboarding; wire ContentView callback"
```
