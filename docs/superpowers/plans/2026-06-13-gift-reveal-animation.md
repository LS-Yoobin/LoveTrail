# Gift Reveal Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stub `PartnerGiftRevealStep` with the animated parchment-page gift reveal described in the design spec, inserted between the welcome and username onboarding steps.

**Architecture:** All changes live in a single file (`PartnerOnboardingFlow.swift`). The `advance()` flow order is corrected so `.welcome` → `.giftReveal` → `.username`. The `PartnerGiftRevealStep` struct is fully rewritten: a zooming book-image animation transitions into a parchment overlay where the inviter's captures are displayed one at a time with Prev/Next page navigation.

**Tech Stack:** SwiftUI (iOS 26.2+), `withAnimation` completion closure (iOS 17+), `GeometryReader` for screen-width offset, `DataPersistenceManager` for live capture data.

---

## File Map

| File | Change |
|------|--------|
| `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift` | Fix `advance()` flow order; fully rewrite `PartnerGiftRevealStep`; update `.giftReveal` case in body switch |

No other files need changes. `DataPersistenceManager.loadPreludeCaptures()`, `BookFlip4` asset, `BabyTownTheme.accentGradient`, and all `PreludeCapture` computed properties (`typeIcon`, `typeLabel`, `displayTitle`) already exist.

---

## Color Reference

The spec uses hex literals; this codebase uses `Color(red:green:blue:)`. Conversions used throughout this plan:

| Spec hex | RGB decimal | Purpose |
|----------|-------------|---------|
| `#fdf6ec` | `Color(red: 0.992, green: 0.965, blue: 0.925)` | Parchment top |
| `#f8e8d0` | `Color(red: 0.973, green: 0.910, blue: 0.816)` | Parchment mid |
| `#f3dfc0` | `Color(red: 0.953, green: 0.875, blue: 0.753)` | Parchment bottom |
| `#3d1800` | `Color(red: 0.239, green: 0.094, blue: 0.000)` | Capture title text |
| `#c2642a` | `Color(red: 0.761, green: 0.392, blue: 0.165)` | Type label + Next Page fill |
| `#a07050` | `Color(red: 0.627, green: 0.439, blue: 0.314)` | Date text |
| warm brown | `Color(red: 0.392, green: 0.235, blue: 0.078)` | Ruled lines + Prev Page |

---

## Task 1: Fix the flow order in `advance()`

**Files:**
- Modify: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift:59-74`

The current `advance()` routes `.welcome → .username` and `.colorTheme → .giftReveal`. The spec requires `.welcome → .giftReveal → .username` and `.colorTheme → onComplete()`.

- [ ] **Step 1: Update `advance()` switch**

Replace the existing `advance()` function body:

```swift
private func advance() {
    let next: Step?
    switch step {
    case .welcome:      next = .giftReveal
    case .giftReveal:   next = .username
    case .username:     next = .email
    case .email:        next = .profilePhoto
    case .profilePhoto: next = .colorTheme
    case .colorTheme:   next = nil
    }
    if let next {
        withAnimation(.easeInOut(duration: 0.4)) { step = next }
    } else {
        onComplete()
    }
}
```

- [ ] **Step 2: Update the `.giftReveal` case in the body switch**

The current `.giftReveal` case passes `inviterName` and uses `onComplete` directly. It should now call `advance()` (which routes to `.username`):

```swift
case .giftReveal:
    PartnerGiftRevealStep(onComplete: advance)
        .transition(.opacity)
```

- [ ] **Step 3: Build and confirm no compiler errors**

Build target `BabyTown` in Xcode. Expected: compiles cleanly (the old `PartnerGiftRevealStep` still exists but its `inviterName` parameter is now unused — that's fine until Task 2 replaces it).

---

## Task 2: Rewrite `PartnerGiftRevealStep`

**Files:**
- Modify: `BabyTown/Views/Prelude/PartnerOnboardingFlow.swift` — replace the entire `PartnerGiftRevealStep` struct (currently lines 367–433)

Replace the full struct with the implementation below. Read each section carefully before pasting.

- [ ] **Step 1: Replace the struct with the full implementation**

```swift
private struct PartnerGiftRevealStep: View {
    var onComplete: () -> Void

    @State private var captures: [PreludeCapture] = []
    @State private var currentIndex = 0
    @State private var bookScale: CGFloat = 1.0
    @State private var bookOffsetX: CGFloat = 0.0
    @State private var capturesVisible = false

    private static let parchmentGradient = LinearGradient(
        colors: [
            Color(red: 0.992, green: 0.965, blue: 0.925),
            Color(red: 0.973, green: 0.910, blue: 0.816),
            Color(red: 0.953, green: 0.875, blue: 0.753)
        ],
        startPoint: .top,
        endPoint: .bottomTrailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Self.parchmentGradient
                    .ignoresSafeArea()

                Image("BookFlip4")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160)
                    .scaleEffect(bookScale)
                    .offset(x: bookOffsetX)

                if capturesVisible {
                    ZStack {
                        Self.parchmentGradient
                            .ignoresSafeArea()

                        ruledLines(height: geo.size.height)

                        parchmentPage(geo: geo)
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                captures = DataPersistenceManager.shared.loadPreludeCaptures()
                    .filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
                    .sorted { $0.createdAt < $1.createdAt }

                let screenWidth = geo.size.width
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.85)) {
                        bookScale = 5.0
                        bookOffsetX = -(screenWidth * 0.255)
                    } completion: {
                        withAnimation(.easeIn(duration: 0.4)) {
                            capturesVisible = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ruled lines

    private func ruledLines(height: CGFloat) -> some View {
        Canvas { ctx, size in
            let lineCount = Int(size.height / 28) + 1
            for i in 0..<lineCount {
                let y = CGFloat(i) * 28
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(
                    path,
                    with: .color(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.06)),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Parchment page content

    private func parchmentPage(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if captures.count > 1 {
                Text("PAGE \(currentIndex + 1) OF \(captures.count)")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.4))
                    .tracking(2)
                    .padding(.top, 60)
            } else {
                Spacer().frame(height: 60)
            }

            Spacer()

            if captures.isEmpty {
                Text("Nothing here yet — check back soon.")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Color(red: 0.239, green: 0.094, blue: 0.000))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                captureContent(captures[currentIndex])
            }

            Spacer()

            navigationRow
                .padding(.bottom, 52)
        }
    }

    // MARK: - Single capture display

    private func captureContent(_ capture: PreludeCapture) -> some View {
        VStack(spacing: 12) {
            Image(systemName: capture.typeIcon)
                .font(.system(size: 36))
                .foregroundStyle(BabyTownTheme.accent)

            Text(capture.typeLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.761, green: 0.392, blue: 0.165))
                .tracking(2)

            Text(capture.displayTitle)
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(Color(red: 0.239, green: 0.094, blue: 0.000))
                .lineSpacing(17 * 0.6)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text(capture.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Color(red: 0.627, green: 0.439, blue: 0.314))
        }
    }

    // MARK: - Navigation row

    private var navigationRow: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { currentIndex -= 1 }
            } label: {
                Text("← Prev Page")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(Color(red: 0.392, green: 0.235, blue: 0.078))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.392, green: 0.235, blue: 0.078).opacity(0.10))
                    )
            }
            .opacity(currentIndex == 0 ? 0 : 1)

            Spacer()

            if captures.isEmpty || currentIndex == captures.count - 1 {
                Button(action: onComplete) {
                    Text("Open our space")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AnyShapeStyle(BabyTownTheme.accentGradient))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { currentIndex += 1 }
                } label: {
                    Text("Next Page →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.761, green: 0.392, blue: 0.165))
                        )
                }
            }
        }
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 2: Build and confirm no compiler errors**

Build target `BabyTown`. Expected: zero errors, zero warnings on the changed file.

- [ ] **Step 3: Run on simulator and verify the animation sequence**

Launch the app on an iPhone simulator and navigate to the partner onboarding flow. Verify:

1. Welcome screen shows `BookFlipView` animating. Tapping "Open it" crossfades.
2. `GiftRevealStep` appears — book is static at BookFlip4 (open pages).
3. After ~0.05s, the book zooms and pans left (scale 1→5, offset shifts right page to center). Duration ~0.85s.
4. Parchment overlay fades in after zoom. Ruled lines visible at low opacity.
5. If captures exist: first capture shows icon, uppercased type label, title, date. No card background.
6. "← Prev Page" is hidden on the first page (`opacity(0)`).
7. Tapping "Next Page →" advances; tapping "← Prev Page" goes back.
8. On the last capture, "Next Page →" is replaced by "Open our space" with accent gradient fill.
9. Tapping "Open our space" advances to the username step (not app home — verify the flow continues to the username field).
10. Empty gift (no matching captures): single parchment page with "Nothing here yet — check back soon." and only "Open our space" button.

- [ ] **Step 4: Commit**

```bash
git add BabyTown/Views/Prelude/PartnerOnboardingFlow.swift
git commit -m "feat(partner): implement gift reveal animation with parchment page and pagination"
```

---

## Self-Review Against Spec

| Spec requirement | Covered by |
|-----------------|-----------|
| Flow: `.welcome` → `.giftReveal` → `.username` | Task 1 Step 1 |
| `Step` enum has `.giftReveal` between welcome and username | Enum already has it; `advance()` fix routes it correctly |
| Welcome still shows `BookFlipView(animating: true, size: 160)` | Unchanged (lines 90–92) |
| GiftReveal shows `Image("BookFlip4")` (not BookFlipView) | Task 2 Step 1 |
| 0.05s delay before zoom | `.asyncAfter(deadline: .now() + 0.05)` |
| `.easeInOut(duration: 0.85)` zoom to scale 5, offset `-(w * 0.255)` | `withAnimation` block |
| Parchment gradient on top after zoom | `capturesVisible` toggle + `withAnimation(.easeIn(0.4))` |
| Decorative ruled lines, 28pt apart, opacity 0.06 | `ruledLines(height:)` using Canvas |
| Page counter, 10pt serif, warm brown 40% opacity, uppercased, tracked | `Text("PAGE X OF Y")` with `.tracking(2)` |
| Page counter hidden for single capture | `if captures.count > 1` |
| Icon 36pt, BabyTownTheme.accent | `Image(systemName:)` |
| Type label 9pt semibold, `#c2642a`, 2pt tracking, uppercased | `Text(capture.typeLabel.uppercased()).tracking(2)` |
| Title 17pt serif, `#3d1800`, lineLimit 4, minimumScaleFactor 0.8 | `captureContent` |
| Date 11pt serif, `#a07050` | `capture.createdAt.formatted(...)` |
| No card background | No background modifier on content |
| Prev Page: pill, rgba fill, warm brown text, hidden at index 0 | `navigationRow` with `.opacity(currentIndex == 0 ? 0 : 1)` |
| Next Page: `#c2642a` fill, white text | `navigationRow` else branch |
| Open our space: `accentGradient` fill, calls `onComplete()` | Last-page condition |
| Loads real captures filtered and sorted | `.onAppear` in `PartnerGiftRevealStep` |
| Empty gift: placeholder text + only Open our space | `captures.isEmpty` branches |
| Voice memo: displayed same as others, no playback | `captureContent` treats all types identically |
| Long text: lineLimit(4) + minimumScaleFactor(0.8) | `captureContent` |
