# Scrapbook Design Brief — UI/UX Intern Project

**Product:** Covela (Prelude phase)
**Duration:** Three weeks, Mon Jul 13 – Fri Jul 31, 2026 (Jul 9–10 = ramp-up/reading)
**Deliverable:** Complete redesign of the Prelude gift scrapbook in Figma, ready for engineering handoff

---

## 1. What the scrapbook is

Covela has three phases: **Prelude** (one person is quietly falling for someone), **Together** (the couple shares a Cove), and **Breakup**. During Prelude, the user privately captures moments about their crush. When they become official, those captures are packaged into a **gift scrapbook** and sent with the partner invite. The partner opens the scrapbook as the emotional climax of their onboarding: they see exactly how the other person felt before they were ever official. The scrapbook can be reopened later from the couple profile (Secret Garden).

This is the single highest-emotion moment in the app. The scrapbook is a gift, a confession, and a keepsake. It should feel like something handmade and precious, not like a feed of cards.

Read before designing anything:
- `Product/Brand.MD` — three-phase model and brand identity
- `Product/Voice.MD` — copy tone per phase
- `Product/Design.MD` — color system and design tokens
- `docs/superpowers/specs/2026-06-23-prelude-gift-song-vinyl-player-design.md` — song entry spec

---

## 2. The five entry types and what users do with them

There are four capture types plus one song attached to the whole gift. **Each type carries different content, so each needs its own page design.**

### 2.1 Note — icon `pencil.and.scribble`
A free-written reflection. The user writes anything, from a one-liner to multiple paragraphs. They can start from a blank page or from one of four rotating prompts:

- "What made you think about them today?"
- "What surprised you about them this week?"
- "What do you like about who you are when you're around them?"
- "What's something small they did that you keep thinking about?"

They can also tag the note with one of 12 moods (see §2.6) and attach a photo. Both are optional. The date the note was written appears on the page.

**Design must handle:** text only / text + mood / text + photo / all three. Short one-liners and multi-paragraph notes.

### 2.2 First — icon `star.fill`
A milestone "first" the user marks. They pick one from 18 presets (shown six at a time across three shuffleable pages) or write their own:

Page 1:
- "First text conversation"
- "First time they made you laugh"
- "First date"
- "First time you thought \"I'm in trouble\""
- "First time you felt nervous around them"
- "First time you imagined a future with them"

Page 2:
- "First kiss"
- "First time you said \"I love you\""
- "First time meeting their friends"
- "First road trip together"
- "First time you stayed up all night talking"
- "First time you missed them"

Page 3:
- "First time you held hands"
- "First time they cooked for you"
- "First time you met their family"
- "First time you danced together"
- "First time you felt truly seen"
- "First time you couldn't stop smiling"

The user then picks the date the first happened — this date, not the day they logged it, is what places the entry in the timeline. In a second editor step they can attach a photo (optional).

**Design must handle:** with and without photo; long custom labels.

### 2.3 Voice memo — icon `mic.fill`
A recorded message, max **60 seconds**. The recorder offers rotating prompts to help them start talking:

- "What's on your mind about them right now?"
- "Say something you haven't had the words to text"
- "Tell them how a moment this week actually felt"
- "What would you say if they were sitting right here?"
- "Describe the feeling, not the story"

**Design must handle:** playback state (idle / playing / finished), duration display, what the page looks like when there is nothing visual to show. Today the reveal card auto-plays and swaps the icon for an animated waveform, that is all.

### 2.4 Reason — icon `heart.fill`
A completion of the fixed prompt **"One reason I'm falling for you:"** The user finishes the sentence in their own words, short or long.

**Design must handle:** the prompt framing (the sentence stem is part of the emotional design), short and long reasons.

### 2.5 Song — one per gift, not per entry
A single song the user attaches to the whole scrapbook. It auto-plays on loop while the scrapbook is open, with a spinning vinyl widget in the top-right. If no song was chosen, the vinyl does not appear.

**Design must handle:** vinyl present vs absent, where the song name appears (today it doesn't appear in the book at all), whether the reader can pause it.

### 2.6 Mood palette (for Note pages)
12 moods, each with a name, SF Symbol, and pastel tint: Butterflies, Giddy, Smitten, Playful, Tender, Dreamy, Cozy, Longing, Sad, Angry, Confused, Jealous. Yes, negative moods exist — Prelude captures the whole feeling, not just the cute parts.

### 2.7 Behaviors that affect design

- The user curates which entries go into the gift; excluded ones stay private and never appear in the book
- After joining, the partner can add entries retroactively; those never appear in the gift book either
- Timeline order: firsts sort by the date the user picked; everything else sorts by when it was written

---

## 3. The screens that exist today

| Surface | File | What it does |
|---|---|---|
| Prelude home (timeline) | `BabyTown/Views/Prelude/PreludeHomeView.swift` | List of captures + quick-add bar for the 4 types |
| Capture editor | `BabyTown/Views/Prelude/CaptureEditorView.swift` | Creation/edit sheet, per-type fields, prompts |
| Voice recorder | `BabyTown/Views/Prelude/VoiceMemoRecorderView.swift` | 60s recorder with circular progress |
| Gift curation | `BabyTown/Views/Prelude/GiftCurationView.swift` | Toggle entries in/out of gift, add/remove song, preview, send invite |
| Gift reveal | `BabyTown/Views/Prelude/GiftRevealView.swift` | Partner's first viewing: card-by-card advance, final card |
| **Gift scrapbook (reader)** | `BabyTown/Views/Prelude/PreludeGiftBookView.swift` | Parchment page-by-page reader; vinyl overlay; reopened from `CoupleProfileView` |

### The design gap (why this project exists)

The current scrapbook reader renders **every entry type with the same layout**: icon + type label + one line of text + date, on a parchment background. Concretely:

- Note and reason text is truncated at **60 characters** — the actual writing is cut off
- Attached photos are **never shown** in the book
- Moods are **never shown** in the book
- Voice memos show the words "Voice Memo" with **no player** in the book (only the reveal cards auto-play)
- The song's name appears nowhere; the vinyl is ambient only
- No cover page, no ending page, pagination is "Prev Page / Next Page" buttons

The intern's core job: **design a distinct, complete page treatment for each of the five entry types** so no captured data is lost, plus the book structure around them.

---

## 4. Required scope

### A. The scrapbook reader (the heart of the project)
1. **Cover page** — creator's name, date range of the Prelude chapter, song hint if present
2. **Note page** — full text, mood stamp (using mood tint + icon), optional photo. Handle all data combinations from §2.1
3. **First page** — milestone framing, date, optional photo
4. **Voice memo page** — playback UI (play/pause, progress, duration), a visual identity for sound
5. **Reason page** — the prompt stem + answer as one composition
6. **Ending page** — the emotional close, leads to the "Open our space" action
7. **Song/vinyl treatment** — present and absent states; whether the song name is surfaced
8. **Navigation model** — paging interaction (swipe? page-curl? current buttons?), page indicator, first-open vs reopen
9. **States** — empty book, single entry, 20+ entries, missing photo file, audio playback failure

### B. Supporting flows (redesign to match the new reader)
10. **Gift curation** — entry toggle list, song card, preview, send
11. **Gift reveal** — the partner's first-time card sequence and final card (may merge with the reader concept if her design justifies it)

### C. Out of scope
- The capture editor and Prelude home timeline (unless her scrapbook design forces small changes — propose, don't redesign)
- Breakup-phase archive views (`ScrapbookHomeView` etc. under `Views/Breakup/` are a different feature despite the name)
- Backend/sync, Together-phase playlist, pet/game layer

### D. Her own ideas — explicitly invited
On top of the required scope, she should pitch **at least one improvement of her own** that makes the scrapbook better. Ideas we'd welcome exploration of: page textures/themes, stickers or handwriting accents, a dedication page, photo layouts, ambient motion, haptics choreography for page turns. Constraints on ideas: nothing social (no sharing feeds, likes, or public anything), nothing that adds user effort without removing more, iOS-native feel.

---

## 5. Design constraints (non-negotiable)

- **Both themes:** every screen must work in Pink and Blue themes. Colors come from `BabyTownTheme` tokens only — no hardcoded hex in final specs; map any new color to a proposed token
- **Copy rules:** sentence case everywhere; verbs on buttons; no exclamation points in errors; no dash characters in any user-facing string; warm but direct tone; match Prelude voice in `Product/Voice.MD`
- **No social mechanics:** no likes, counts, sharing pressure
- **Photography/content is the hero; UI recedes**
- **Motion:** interactive springs `response 0.4 / damping 0.75`, screen fades `easeInOut 0.3` — design motion specs within this family
- Accessibility: Dynamic Type on all text pages, VoiceOver labels for the vinyl and voice player, reduced-motion fallback for page transitions

---

## 6. Three-week plan

### Ramp (Thu Jul 9 – Fri Jul 10)
Install the build, run through the full Prelude flow (create all 4 entry types + song, curate, send, open the gift as partner). Read the four docs in §1.

### Week 1 — Understand and structure (Mon Jul 13 – Fri Jul 17)
- Audit of the current flow with screenshots and pain points
- Inspiration/competitive research (physical scrapbooks, Apple Journal, Locket, paper-craft apps)
- User flow map: capture → curate → send → reveal → reopen
- Low-fi wireframes: book structure, all 5 page types, cover and ending
- **Checkpoint: Fri Jul 17 — wireframe walkthrough, direction locked**

### Week 2 — High fidelity (Mon Jul 20 – Fri Jul 24)
- Hi-fi designs for all reader pages in **both themes**, covering every data combination in §2
- Curation and reveal screens updated to match
- Edge/empty/error states from §4.A.9
- Her own improvement pitch (one-pager + mockup)
- **Checkpoint: Wed Jul 22 — mid-fi review. Fri Jul 24 — hi-fi review + pitch**

### Week 3 — Polish and handoff (Mon Jul 27 – Fri Jul 31)
- Revisions from review
- Motion specs (page transition, vinyl, voice waveform, reveal choreography)
- Component specs: spacing, type scale, new theme tokens for both themes, asset exports (snake_case naming)
- Final Figma file organized for engineering handoff + a short recorded walkthrough
- **Final review: Thu Jul 30. Handoff complete: Fri Jul 31**

### Working rhythm
- Daily async update (what she did, what's next, blockers)
- Design reviews on the checkpoint dates above; she should surface blockers immediately rather than sitting on them per the project's when-stuck protocol
