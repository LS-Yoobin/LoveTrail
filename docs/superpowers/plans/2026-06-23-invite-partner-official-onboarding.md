# Invite Partner — Official Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert an invite/referral step into the "Already Official" onboarding path, add a locked pending home screen while waiting for the partner, and wire a gift reveal + celebration sequence that plays when the partner accepts.

**Architecture:** Four new views (`OnboardingInviteView`, `PendingHomeView`, `PartnerGiftRevealView`, `JustPickPhotosView`) are wired as new `Screen` enum cases in `ContentView`. A stub `InviteAPIClient` follows the existing `ArchiveAPIClient` pattern — protocol + stub with `// TODO` comments for real network calls. Polling runs inside `PendingHomeView` using a `Timer`.

**Tech Stack:** SwiftUI, existing `TypingTextView` and `PulsingDotsLoader` components, `BabyTownTheme` tokens, `DataPersistenceManager`, `PartnerInvite` (existing code generation).

## Global Constraints

- No dash characters (`-`, `–`, `—`) in any user-facing string
- All UI copy uses sentence case
- All colors via `BabyTownTheme.*` tokens — no hardcoded hex or RGB
- Both Pink and Blue themes must work — never assume one
- File naming: PascalCase `.swift`; asset naming: snake_case
- Ellipsis in copy is the `…` character, not three dots

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `BabyTown/Services/DataPersistenceManager.swift` | Modify | 3 new keys + 6 new persistence methods for pending invite state |
| `BabyTown/Services/InviteAPIClient.swift` | **Create** | Protocol + stub for `POST /create-invite`, `GET /invite/:code`, `POST /accept-invite` |
| `BabyTown/Views/OnboardingInviteView.swift` | **Create** | Three-state invite screen (choose action / pending / enter code) |
| `BabyTown/Views/PartnerGiftRevealView.swift` | **Create** | Scrollable gift reveal, parameterized by captures + revealer name |
| `BabyTown/Views/JustPickPhotosView.swift` | **Create** | Celebration bridge with founding moment polaroids |
| `BabyTown/Views/PendingHomeView.swift` | **Create** | Locked home shell while waiting for partner |
| `BabyTown/ContentView.swift` | Modify | 4 new Screen cases + navigation wiring |

---

## Task 1: DataPersistenceManager — pending invite persistence

**Files:**
- Modify: `BabyTown/Services/DataPersistenceManager.swift`

**Interfaces:**
- Produces:
  - `func setPendingPartnerInvite(_ pending: Bool)`
  - `func hasPendingPartnerInvite() -> Bool`
  - `func savePendingInviteCode(_ code: String)`
  - `func loadPendingInviteCode() -> String?`
  - `func savePendingInvitePartnerName(_ name: String)`
  - `func loadPendingInvitePartnerName() -> String?`
  - `func clearPendingInviteState()`

- [ ] **Step 1: Add the three UserDefaults key constants**

Open `DataPersistenceManager.swift`. Find the block of `private let *Key` constants (around line 107). Add after the existing keys:

```swift
private let pendingPartnerInviteKey = "pendingPartnerInvite"
private let pendingInviteCodeKey = "pendingInviteCode"
private let pendingInvitePartnerNameKey = "pendingInvitePartnerName"
```

- [ ] **Step 2: Add the six persistence methods**

Find `func setOnboardingCompleted`. Add the following block immediately before it:

```swift
func setPendingPartnerInvite(_ pending: Bool) {
    userDefaults.set(pending, forKey: pendingPartnerInviteKey)
}

func hasPendingPartnerInvite() -> Bool {
    userDefaults.bool(forKey: pendingPartnerInviteKey)
}

func savePendingInviteCode(_ code: String) {
    userDefaults.set(code, forKey: pendingInviteCodeKey)
}

func loadPendingInviteCode() -> String? {
    userDefaults.string(forKey: pendingInviteCodeKey)
}

func savePendingInvitePartnerName(_ name: String) {
    userDefaults.set(name, forKey: pendingInvitePartnerNameKey)
}

func loadPendingInvitePartnerName() -> String? {
    userDefaults.string(forKey: pendingInvitePartnerNameKey)
}

func clearPendingInviteState() {
    userDefaults.removeObject(forKey: pendingPartnerInviteKey)
    userDefaults.removeObject(forKey: pendingInviteCodeKey)
    userDefaults.removeObject(forKey: pendingInvitePartnerNameKey)
}
```

- [ ] **Step 3: Add clearPendingInviteState to clearAllData**

Find `func clearAllData()`. Add `clearPendingInviteState()` inside that function body, alongside the other `removeObject` calls.

- [ ] **Step 4: Build to verify no compile errors**

In Xcode: Product → Build (⌘B). Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Services/DataPersistenceManager.swift
git commit -m "feat: add pending invite persistence to DataPersistenceManager"
```

---

## Task 2: InviteAPIClient — stub API client

**Files:**
- Create: `BabyTown/Services/InviteAPIClient.swift`

**Interfaces:**
- Produces:
  - `struct GiftRevealCapture: Identifiable` — display model passed to `PartnerGiftRevealView`
  - `struct InviteCreatedResponse`
  - `struct InviteStatusResponse` with nested `enum Status`
  - `struct InviteAcceptedResponse`
  - `protocol InviteAPIClientProtocol`
  - `final class StubInviteAPIClient: InviteAPIClientProtocol` with `static let shared`

- [ ] **Step 1: Create the file**

Create `BabyTown/Services/InviteAPIClient.swift` with this complete content:

```swift
import Foundation

// MARK: - Display model

/// Lightweight display-only capture passed to PartnerGiftRevealView.
/// Produced by the API response; not the full PreludeCapture model.
struct GiftRevealCapture: Identifiable {
    let id: UUID
    let type: PreludeCapture.CaptureType
    let displayText: String
    let typeIcon: String
}

// MARK: - Response types

struct InviteCreatedResponse {
    let code: String
    let link: String
}

struct InviteStatusResponse {
    enum Status: String { case pending, accepted, expired, cancelled }
    let status: Status
}

struct InviteAcceptedResponse {
    /// Captures to show in PartnerGiftRevealView. Empty means skip the reveal screen.
    let revealCaptures: [GiftRevealCapture]
    /// The name shown in the reveal header, e.g. "Sarah's Prelude".
    let revealerName: String
}

// MARK: - Protocol

protocol InviteAPIClientProtocol {
    /// POST /create-invite
    func createInvite(inviterName: String) async throws -> InviteCreatedResponse
    /// GET /invite/:code — polls for partner acceptance
    func checkInviteStatus(code: String) async throws -> InviteStatusResponse
    /// POST /accept-invite — called when user enters a referral code
    func acceptInvite(code: String) async throws -> InviteAcceptedResponse
}

// MARK: - Stub (replace with real URLSession calls when backend is ready)

final class StubInviteAPIClient: InviteAPIClientProtocol {
    static let shared = StubInviteAPIClient()
    private init() {}

    func createInvite(inviterName: String) async throws -> InviteCreatedResponse {
        // TODO: POST /create-invite with body { inviterName, gift_capture_ids }
        try await Task.sleep(nanoseconds: 600_000_000)
        let code = PartnerInvite.generateCode()
        return InviteCreatedResponse(
            code: code,
            link: "https://covela.app/invite/\(code)"
        )
    }

    func checkInviteStatus(code: String) async throws -> InviteStatusResponse {
        // TODO: GET /invite/:code — check status field in response JSON
        return InviteStatusResponse(status: .pending)
    }

    func acceptInvite(code: String) async throws -> InviteAcceptedResponse {
        // TODO: POST /accept-invite with body { code }
        // On success, map inviter_gift_captures to GiftRevealCapture array.
        // If inviter had no prelude captures, return empty revealCaptures.
        try await Task.sleep(nanoseconds: 600_000_000)
        return InviteAcceptedResponse(revealCaptures: [], revealerName: "Your partner")
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

Product → Build (⌘B). Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Services/InviteAPIClient.swift
git commit -m "feat: add InviteAPIClient stub for partner invite endpoints"
```

---

## Task 3: OnboardingInviteView

**Files:**
- Create: `BabyTown/Views/OnboardingInviteView.swift`

**Interfaces:**
- Consumes:
  - `DataPersistenceManager.shared.setPendingPartnerInvite(_:)` — Task 1
  - `DataPersistenceManager.shared.savePendingInviteCode(_:)` — Task 1
  - `DataPersistenceManager.shared.savePendingInvitePartnerName(_:)` — Task 1
  - `DataPersistenceManager.shared.loadUserNickname() -> String?` — existing
  - `StubInviteAPIClient.shared.createInvite(inviterName:)` — Task 2
  - `StubInviteAPIClient.shared.checkInviteStatus(code:)` — Task 2
  - `StubInviteAPIClient.shared.acceptInvite(code:)` — Task 2
  - `GiftRevealCapture` — Task 2
  - `BabyTownTheme.*`, `PulsingDotsLoader` — existing

- Produces:
  - `struct OnboardingInviteView: View`
  - Callbacks: `onSkip: () -> Void`, `onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void`

- [ ] **Step 1: Create the file with the full view**

Create `BabyTown/Views/OnboardingInviteView.swift`:

```swift
import SwiftUI

struct OnboardingInviteView: View {
    var onSkip: () -> Void
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void

    private enum InviteState {
        case choosingAction
        case pending(code: String)
        case enteringCode
    }

    @State private var state: InviteState = .choosingAction
    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var codeError: String? = nil
    @State private var pollTimer: Timer? = nil
    @FocusState private var codeFocused: Bool

    private var inviterName: String {
        DataPersistenceManager.shared.loadUserNickname() ?? "You"
    }

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

                switch state {
                case .choosingAction:
                    choosingActionContent
                case .pending(let code):
                    pendingContent(code: code)
                case .enteringCode:
                    enteringCodeContent
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.35), value: stateTag)
        }
        .onboardingBackButton(action: handleBack)
        .onDisappear { stopPolling() }
    }

    private var stateTag: Int {
        switch state {
        case .choosingAction: return 0
        case .pending: return 1
        case .enteringCode: return 2
        }
    }

    // MARK: State A — Choose action

    private var choosingActionContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Connect with your partner")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Choose how you want to get started.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                InviteActionCard(
                    icon: "envelope.heart.fill",
                    title: "Invite your partner",
                    subtitle: "Send them a link. They tap it and you are connected."
                ) {
                    Task { await sendInvite() }
                }

                InviteActionCard(
                    icon: "key.fill",
                    title: "I have a code",
                    subtitle: "Enter the code from the email your partner sent you."
                ) {
                    withAnimation { state = .enteringCode }
                }
            }
        }
    }

    // MARK: State B — Pending

    private func pendingContent(code: String) -> some View {
        VStack(spacing: 28) {
            PulsingRingsView()
                .frame(width: 160, height: 160)

            VStack(spacing: 10) {
                Text("Invitation sent")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("We will let you know the moment they join.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                UIPasteboard.general.string = code
            } label: {
                Text("Copy invite code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BabyTownTheme.accent)
            }

            Button {
                stopPolling()
                onSkip()
            } label: {
                Text("Continue to your space")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
        }
    }

    // MARK: State C — Enter code

    private var enteringCodeContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter your code")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Enter the 6-character code from the invite email.")
                    .font(.system(size: 15))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                TextField("Enter your 6-character code", text: $codeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: BabyTownTheme.accent.opacity(0.12), radius: 8, y: 4)
                    )
                    .focused($codeFocused)
                    .onChange(of: codeInput) { _, new in
                        codeInput = String(new.prefix(6))
                        codeError = nil
                    }
                    .onAppear { codeFocused = true }

                if let err = codeError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }

            Button {
                Task { await joinWithCode() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(codeInput.count == 6 ? BabyTownTheme.accentGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .disabled(codeInput.count < 6 || isLoading)
        }
    }

    // MARK: Actions

    private func sendInvite() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response = try await StubInviteAPIClient.shared.createInvite(inviterName: inviterName)
            DataPersistenceManager.shared.setPendingPartnerInvite(true)
            DataPersistenceManager.shared.savePendingInviteCode(response.code)
            DataPersistenceManager.shared.savePendingInvitePartnerName(inviterName)
            withAnimation { state = .pending(code: response.code) }
            startPolling(code: response.code)
        } catch {
            // Remain on choosingAction — user can retry
        }
        isLoading = false
    }

    private func joinWithCode() async {
        guard codeInput.count == 6, !isLoading else { return }
        isLoading = true
        do {
            let response = try await StubInviteAPIClient.shared.acceptInvite(code: codeInput)
            DataPersistenceManager.shared.clearPendingInviteState()
            onPartnerJoined(response.revealCaptures, response.revealerName)
        } catch {
            codeError = "That code is not valid or has expired."
        }
        isLoading = false
    }

    private func startPolling(code: String) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { await checkForAcceptance(code: code) }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkForAcceptance(code: String) async {
        guard let status = try? await StubInviteAPIClient.shared.checkInviteStatus(code: code) else { return }
        if status.status == .accepted {
            stopPolling()
            DataPersistenceManager.shared.clearPendingInviteState()
            // Stub returns empty captures — real backend will return gift payload
            onPartnerJoined([], DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "Your partner")
        }
    }

    private func handleBack() {
        switch state {
        case .choosingAction:
            break // back button from ContentView handles navigation
        case .pending, .enteringCode:
            stopPolling()
            withAnimation { state = .choosingAction }
        }
    }
}

// MARK: - Subviews

private struct InviteActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(BabyTownTheme.accent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.4))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: BabyTownTheme.accent.opacity(0.1), radius: 10, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Three concentric rings that expand outward in a loop.
private struct PulsingRingsView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(BabyTownTheme.accent.opacity(animate ? 0.0 : [0.4, 0.25, 0.12][i]), lineWidth: 2)
                    .scaleEffect(animate ? 1.6 + CGFloat(i) * 0.3 : 0.6)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.5),
                        value: animate
                    )
            }

            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accent)
        }
        .onAppear { animate = true }
    }
}

#Preview("Choose action") {
    OnboardingInviteView(onSkip: {}, onPartnerJoined: { _, _ in })
}

#Preview("Pending") {
    OnboardingInviteView(onSkip: {}, onPartnerJoined: { _, _ in })
}
```

- [ ] **Step 2: Build to verify no compile errors**

Product → Build (⌘B). Expected: succeeds.

- [ ] **Step 3: Open the preview and verify visually**

In Xcode, open `OnboardingInviteView.swift` and click Resume in the Preview canvas. Verify:
- Two cards visible with correct icons, labels, subtext
- Both theme colors (Pink / Blue) look correct — toggle theme in preview if needed

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/OnboardingInviteView.swift
git commit -m "feat: add OnboardingInviteView with invite, pending, and code-entry states"
```

---

## Task 4: PartnerGiftRevealView

**Files:**
- Create: `BabyTown/Views/PartnerGiftRevealView.swift`

**Interfaces:**
- Consumes:
  - `GiftRevealCapture` — Task 2
  - `BabyTownTheme.*` — existing
- Produces:
  - `struct PartnerGiftRevealView: View`
  - Init: `captures: [GiftRevealCapture], revealerName: String, onContinue: () -> Void`

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/PartnerGiftRevealView.swift`:

```swift
import SwiftUI

struct PartnerGiftRevealView: View {
    let captures: [GiftRevealCapture]
    let revealerName: String
    var onContinue: () -> Void

    @State private var firstCardScrolledPast = false

    private let backgroundGradient = LinearGradient(
        colors: [Color(hex: "4a1942"), Color(hex: "8b3d5c")],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(captures.enumerated()), id: \.element.id) { index, capture in
                            CaptureRevealCard(capture: capture)
                                .padding(.horizontal, 24)
                                .onAppear {
                                    if index == 0 { firstCardScrolledPast = true }
                                }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }

            continueButton
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(revealerName)'s Prelude")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This is how they felt before you were ever official.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(firstCardScrolledPast ? Color(hex: "4a1942") : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(firstCardScrolledPast ? .white : .white.opacity(0.15))
                )
        }
        .disabled(!firstCardScrolledPast)
        .animation(.easeInOut(duration: 0.3), value: firstCardScrolledPast)
    }
}

private struct CaptureRevealCard: View {
    let capture: GiftRevealCapture

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: capture.typeIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(capture.type.typeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(capture.displayText)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.12))
        )
    }
}

private extension PreludeCapture.CaptureType {
    var typeLabel: String {
        switch self {
        case .note: return "Note"
        case .first: return "First"
        case .voiceMemo: return "Voice"
        case .reason: return "Reason"
        }
    }
}

// Color(hex:) helper — add only if not already defined project-wide
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    PartnerGiftRevealView(
        captures: [
            GiftRevealCapture(id: UUID(), type: .note, displayText: "I keep thinking about you.", typeIcon: "pencil.and.scribble"),
            GiftRevealCapture(id: UUID(), type: .reason, displayText: "The way you always laugh first.", typeIcon: "heart.fill"),
            GiftRevealCapture(id: UUID(), type: .first, displayText: "First time we danced.", typeIcon: "star.fill")
        ],
        revealerName: "Sarah",
        onContinue: {}
    )
}
```

> **Note on `Color(hex:)`:** Search the project for an existing `Color(hex:)` extension before adding the one above. If found, delete the private extension from this file.

- [ ] **Step 2: Search for existing Color(hex:) extension**

```bash
grep -r "init(hex:" /Users/ybstudio/Desktop/Projects/Covela/BabyTown --include="*.swift" -l
```

If any file is returned, remove the `private extension Color` block from `PartnerGiftRevealView.swift`.

- [ ] **Step 3: Build to verify no compile errors**

Product → Build (⌘B). Expected: succeeds.

- [ ] **Step 4: Open preview and verify visually**

Resume the preview canvas. Confirm dark plum gradient background, white card text, "Continue" button is disabled until first card appears.

- [ ] **Step 5: Commit**

```bash
git add BabyTown/Views/PartnerGiftRevealView.swift
git commit -m "feat: add PartnerGiftRevealView for post-acceptance gift reveal"
```

---

## Task 5: JustPickPhotosView

**Files:**
- Create: `BabyTown/Views/JustPickPhotosView.swift`

**Interfaces:**
- Consumes: `BabyTownTheme.*` — existing
- Produces:
  - `struct JustPickPhotosView: View`
  - Init: `officialPhoto: UIImage, firstMetPhoto: UIImage?, onContinue: () -> Void`

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/JustPickPhotosView.swift`:

```swift
import SwiftUI

struct JustPickPhotosView: View {
    let officialPhoto: UIImage
    let firstMetPhoto: UIImage?
    var onContinue: () -> Void

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

                polaroidCollage
                    .padding(.bottom, 40)

                VStack(spacing: 10) {
                    Text("Just pick photos of us.")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Covela does the rest.")
                        .font(.system(size: 18))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: onContinue) {
                    Text("Let's go")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(BabyTownTheme.accentGradient)
                                .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private var polaroidCollage: some View {
        ZStack {
            if let firstMet = firstMetPhoto {
                PolaroidCard(image: firstMet, rotation: -6)
                    .offset(x: -30, y: 10)

                PolaroidCard(image: officialPhoto, rotation: 5)
                    .offset(x: 30, y: -10)
            } else {
                PolaroidCard(image: officialPhoto, rotation: 0)
            }
        }
        .frame(height: 260)
    }
}

private struct PolaroidCard: View {
    let image: UIImage
    let rotation: Double

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipped()

            Color.clear.frame(height: 30)
        }
        .frame(width: 180, height: 200)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    JustPickPhotosView(
        officialPhoto: UIImage(systemName: "heart.fill")!,
        firstMetPhoto: UIImage(systemName: "star.fill")!,
        onContinue: {}
    )
}
```

- [ ] **Step 2: Build and verify preview**

Product → Build (⌘B). Confirm polaroid collage renders and "Let's go" button is visible. With a single photo the card is centered; with two photos they overlap at rotated offsets.

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/JustPickPhotosView.swift
git commit -m "feat: add JustPickPhotosView celebration bridge screen"
```

---

## Task 6: PendingHomeView

**Files:**
- Create: `BabyTown/Views/PendingHomeView.swift`

**Interfaces:**
- Consumes:
  - `TypingTextView` — existing component
  - `DataPersistenceManager.shared.loadPendingInvitePartnerName()` — Task 1
  - `DataPersistenceManager.shared.clearPendingInviteState()` — Task 1
  - `StubInviteAPIClient.shared.checkInviteStatus(code:)` — Task 2
  - `DataPersistenceManager.shared.loadPendingInviteCode()` — Task 1
  - `GiftRevealCapture` — Task 2
  - `BabyTownTheme.*`, `AdoptAPetRootView` — existing

- Produces:
  - `struct PendingHomeView: View`
  - Init: `onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void`

- [ ] **Step 1: Create the file**

Create `BabyTown/Views/PendingHomeView.swift`:

```swift
import SwiftUI

struct PendingHomeView: View {
    var onPartnerJoined: (_ captures: [GiftRevealCapture], _ revealerName: String) -> Void

    @State private var selectedTab = 0
    @State private var pollTimer: Timer? = nil
    @State private var showLockedToast = false
    @State private var bannerVisible = true

    private var partnerName: String {
        DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "your partner"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                navBar
                if bannerVisible { waitingBanner }
                tabContent
                Spacer()
                tabBar
            }
            .ignoresSafeArea(edges: .bottom)

            if showLockedToast {
                lockedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: Nav bar

    private var navBar: some View {
        HStack {
            Text("Covela")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(BabyTownTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.white)
    }

    // MARK: Waiting banner

    private var waitingBanner: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(BabyTownTheme.accent)

            Text("Waiting for \(partnerName)\u{2026}")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(BabyTownTheme.accent.opacity(0.12))
        )
        .padding(.vertical, 8)
    }

    // MARK: Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            lockedPlaceholderTab(
                icon: "photo.on.rectangle.angled",
                message: "Your memories will live here once your partner joins."
            )
        case 1:
            petTab
        case 2:
            secretGardenTab
        default:
            lockedPlaceholderTab(icon: "lock.fill", message: "Available once your partner joins.")
        }
    }

    private var petTab: some View {
        AdoptAPetRootView()
    }

    private var secretGardenTab: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.97), BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                TypingTextView(
                    text: "Waiting for your partner\u{2026}",
                    font: .system(size: 28, weight: .bold, design: .serif),
                    color: BabyTownTheme.textPrimary
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                Spacer()
            }
        }
    }

    private func lockedPlaceholderTab(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.35))
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { showToast() }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(icon: "photo.stack", label: "Memories", tag: 0, locked: true)
            tabBarItem(icon: "pawprint.fill", label: "Pet", tag: 1, locked: false)
            tabBarItem(icon: "leaf.fill", label: "Garden", tag: 2, locked: false)
            tabBarItem(icon: "envelope.fill", label: "Letters", tag: 3, locked: true)
        }
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -2)))
    }

    private func tabBarItem(icon: String, label: String, tag: Int, locked: Bool) -> some View {
        Button {
            if locked {
                showToast()
            } else {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(
                locked
                    ? BabyTownTheme.textSecondary.opacity(0.3)
                    : (selectedTab == tag ? BabyTownTheme.accent : BabyTownTheme.textSecondary.opacity(0.6))
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: Toast

    private var lockedToast: some View {
        Text("Available once your partner joins")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.black.opacity(0.75))
            )
    }

    private func showToast() {
        withAnimation { showLockedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showLockedToast = false }
        }
    }

    // MARK: Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { await checkAcceptance() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkAcceptance() async {
        guard let code = DataPersistenceManager.shared.loadPendingInviteCode() else { return }
        guard let status = try? await StubInviteAPIClient.shared.checkInviteStatus(code: code) else { return }
        if status.status == .accepted {
            stopPolling()
            withAnimation { bannerVisible = false }
            DataPersistenceManager.shared.clearPendingInviteState()
            let name = DataPersistenceManager.shared.loadPendingInvitePartnerName() ?? "Your partner"
            onPartnerJoined([], name)
        }
    }
}

#Preview {
    PendingHomeView(onPartnerJoined: { _, _ in })
}
```

- [ ] **Step 2: Build and verify preview**

Product → Build (⌘B). Preview the view — confirm:
- Nav bar and waiting banner visible at top
- Memories and Letters tabs show dimmed placeholder with tap-to-toast behaviour
- Pet tab shows the pet adoption UI
- Secret Garden tab shows the typing animation looping

- [ ] **Step 3: Commit**

```bash
git add BabyTown/Views/PendingHomeView.swift
git commit -m "feat: add PendingHomeView with locked features and polling"
```

---

## Task 7: ContentView — wire everything

**Files:**
- Modify: `BabyTown/ContentView.swift`

**Interfaces:**
- Consumes all views from Tasks 3–6 plus Task 1 persistence methods
- Produces: updated Screen enum and navigation graph

- [ ] **Step 1: Add four new Screen enum cases**

Find the `enum Screen: Equatable` block (line ~13). Add four cases:

```swift
case invitePartner
case officialPending
case partnerGiftReveal(captures: [GiftRevealCapture], revealerName: String)
case justPickPhotos
```

> `partnerGiftReveal` carries its payload directly so ContentView doesn't need extra `@State` vars for this data.

Note: `GiftRevealCapture` is not `Equatable` by default. Add conformance by adding this extension to `InviteAPIClient.swift` (Task 2 file):

```swift
extension GiftRevealCapture: Equatable {
    static func == (lhs: GiftRevealCapture, rhs: GiftRevealCapture) -> Bool {
        lhs.id == rhs.id
    }
}
```

- [ ] **Step 2: Add three new @State vars for founding moment photos**

ContentView already has `@State private var firstMetPhoto: UIImage?` and `@State private var officialPhoto: UIImage?`. These are what `JustPickPhotosView` will use — no new vars needed. Confirm they exist (lines ~24–25).

- [ ] **Step 3: Update the relaunch logic in init to handle officialPending**

Find the `if hasCompletedOnboarding` block in `init()` (line ~37). After the existing `stage == .prelude` check, add:

```swift
} else if DataPersistenceManager.shared.hasPendingPartnerInvite() {
    _targetScreen = State(initialValue: .officialPending)
```

Place this before the final `else { _targetScreen = .home }` branch.

- [ ] **Step 4: Change firstMemories onFinished to route to invitePartner**

Find the `.firstMemories` case in `body` (line ~189). The `onFinished` closure currently ends with:

```swift
withAnimation(.easeInOut(duration: 0.4)) {
    screen = .howItWorks
}
```

Change that final navigation line to:

```swift
withAnimation(.easeInOut(duration: 0.4)) {
    screen = .invitePartner
}
```

- [ ] **Step 5: Add the four new Screen cases to the switch**

Find the end of the `switch screen` block, before the closing `}`. Add:

```swift
case .invitePartner:
    OnboardingInviteView(
        onSkip: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .officialPending
            }
        },
        onPartnerJoined: { captures, revealerName in
            withAnimation(.easeInOut(duration: 0.4)) {
                if captures.isEmpty {
                    screen = .justPickPhotos
                } else {
                    screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
                }
            }
        }
    )
    .transition(.opacity)

case .officialPending:
    PendingHomeView(
        onPartnerJoined: { captures, revealerName in
            withAnimation(.easeInOut(duration: 0.4)) {
                if captures.isEmpty {
                    screen = .justPickPhotos
                } else {
                    screen = .partnerGiftReveal(captures: captures, revealerName: revealerName)
                }
            }
        }
    )
    .transition(.opacity)
    .onAppear {
        DataPersistenceManager.shared.saveLastActiveScreen("officialPending")
    }

case .partnerGiftReveal(let captures, let revealerName):
    PartnerGiftRevealView(
        captures: captures,
        revealerName: revealerName,
        onContinue: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .justPickPhotos
            }
        }
    )
    .transition(.opacity)

case .justPickPhotos:
    JustPickPhotosView(
        officialPhoto: officialPhoto ?? UIImage(systemName: "heart.fill")!,
        firstMetPhoto: firstMetPhoto,
        onContinue: {
            withAnimation(.easeInOut(duration: 0.4)) {
                screen = .howItWorks
            }
        }
    )
    .transition(.opacity)
```

- [ ] **Step 6: Update loadLastActiveScreen relaunch to handle "officialPending"**

Find the `if lastScreen == "selectPhotos"` check in `init()`. Add a parallel check before it:

```swift
if lastScreen == "officialPending" || DataPersistenceManager.shared.hasPendingPartnerInvite() {
    _targetScreen = State(initialValue: .officialPending)
} else if lastScreen == "selectPhotos" {
```

- [ ] **Step 7: Build to verify no compile errors**

Product → Build (⌘B). Expected: succeeds. Fix any type errors — most likely the `Screen: Equatable` conformance needing explicit `==` for the associated-value cases.

If `Screen: Equatable` fails, add this to `ContentView.swift` inside or after the enum:

```swift
extension ContentView.Screen: Equatable {
    static func == (lhs: ContentView.Screen, rhs: ContentView.Screen) -> Bool {
        switch (lhs, rhs) {
        case (.partnerGiftReveal(let lc, let ln), .partnerGiftReveal(let rc, let rn)):
            return lc.map(\.id) == rc.map(\.id) && ln == rn
        default:
            return "\(lhs)" == "\(rhs)"
        }
    }
}
```

- [ ] **Step 8: Run the official onboarding path manually**

Launch the app on Simulator. Start a fresh onboarding:
1. Welcome → Nickname → Color Theme → Birthday → "Already Official"
2. Confirm FirstMemories completes and lands on `OnboardingInviteView`
3. Tap "Invite your partner" — confirm transition to pending state with rings animation
4. Tap "Continue to your space" — confirm `PendingHomeView` loads with banner
5. Tap Memories / Letters tab — confirm toast "Available once your partner joins" appears
6. Tap Pet tab — confirm pet adoption UI loads
7. Tap Secret Garden — confirm "Waiting for your partner…" typing loop plays
8. Force-quit and relaunch — confirm app returns to `PendingHomeView`

- [ ] **Step 9: Commit**

```bash
git add BabyTown/ContentView.swift BabyTown/Services/InviteAPIClient.swift
git commit -m "feat: wire invite partner onboarding flow in ContentView"
```

---

## Self-Review Checklist

- [x] InvitePartnerView spec: choose action, pending with rings, enter code — all three states covered
- [x] "Skip for now" only available after invite sent (pending state) — enforced by `onSkip` only being called from pending state
- [x] PendingHomeView: pet functional, camera/scan/prompt/letters locked with toast
- [x] Secret Garden: `TypingTextView` used with "Waiting for your partner…" (ellipsis character)
- [x] Waiting banner uses `\u{2026}` not three dots
- [x] `PartnerGiftRevealView` accepts `captures` + `revealerName` — works for both inviter seeing partner's captures and partner seeing inviter's captures
- [x] If `captures` is empty, `partnerGiftReveal` screen is skipped and flow goes directly to `justPickPhotos`
- [x] Polling uses `GET /invite/:code` with stored code (not a nonexistent `/couple/status` endpoint)
- [x] `officialPending` persisted to `lastActiveScreen` so relaunch restores correctly
- [x] `clearPendingInviteState()` called on acceptance in both `OnboardingInviteView` and `PendingHomeView`
- [x] No dash characters in any user-facing strings
- [x] `BabyTownTheme.*` used throughout — no hardcoded colors except the plum gradient hex values (needed because theme tokens don't cover this specific shade)
