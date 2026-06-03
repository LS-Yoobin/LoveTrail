# Love Garden & Couple Profile — Design Spec (v1)

Date: 2026-06-02
Status: Draft for review (design only — no implementation)

## 1. Vision

A premium **Couple Profile ("Us")** experience whose centerpiece is a shared
**Love Garden**: a living space that grows from the loving acts the couple
already performs in BabyTown — capturing moments, writing love notes and
letters, visiting places, and celebrating milestones. The garden is a *mirror
that makes the relationship feel seen and celebrated*, not an analytics
dashboard.

Emotional center of gravity (decided): **celebrate / nostalgia**.
Health model (decided): **growth metaphor only — never a score, never punishing**.
Town relationship (decided): **unified** — the garden lives in the app's world
and feeds the existing coin/town economy.
Location (decided): a **dedicated "Us" garden scene**, reachable from the cat
room via a **door/portal** the user taps to "go visit the Garden."
v1 tentpole (decided): **the Love Garden itself** (+ the Couple Profile shell it
lives in). Relationship Wrapped, the deep Analyst, Important Dates, and keepsakes
are later phases.

## 2. Goals / Non-goals

**v1 Goals**
- A dedicated "Us" page that hosts the Love Garden and a nostalgia-first header.
- A Love Garden scene where loving acts plant/grow visible blooms.
- A kind growth model: the garden blooms with activity and gently *rests* when
  quiet — it never wilts, shames, or loses progress.
- A door in the cat room that navigates to the Garden.
- Coin tie-in: loving acts drip into the existing economy.
- A clear free-vs-premium boundary that paywalls *richness and keepsakes*, never
  the couple's memories themselves.

**Non-goals (explicitly deferred — see §11)**
- Real two-device sync of a shared garden (blocked on partner backend; see §9).
- Relationship Wrapped recap.
- Deep Relationship Analyst insights / love-language inference.
- Important Dates engine (countdowns, reminders, anniversary recaps).
- "Year in Love" exportable keepsake book and Our-World map.

## 3. Access states

The experience adapts to two axes — partnership and subscription:

| State | Garden behavior |
|-------|-----------------|
| Solo (no partner invited) | "Us" entry is a soft teaser inviting them to connect a partner; a starter plot may grow from the solo user's own moments to show the promise. |
| Partner invited, Free | Starter plot, basic bloom types, garden grows but limited variety; teaser of premium blooms/landmarks behind a clear upsell. |
| Partner invited, Us+ (premium) | Full garden: rare/seasonal/co-blooms, milestone landmarks, celebratory Analyst voice lines, future Wrapped/keepsakes. |

The partner-invite moment is the highest-intent emotional moment in the app and
is where the "Us" space should bloom into existence / be most strongly surfaced.

## 4. Information architecture & navigation

- **Cat room → Garden door:** a tappable door/portal prop in the existing room
  scene. Tapping transitions to the Garden scene. (Placement and art TBD; should
  not collide with existing care props or the floorband rules.)
- **Home → "Us" tab/section:** the Couple Profile page is also reachable from the
  app's home surface (introduced/elevated after partner invite).
- The Garden scene is its own SpriteKit (or equivalent) scene, separate from the
  cat room scene, so it doesn't destabilize the existing room.

## 5. The Love Garden — mechanic

### 5.1 Acts → growth mapping
Each loving act the app already records grows the garden:

| Loving act (existing data) | Garden growth |
|----------------------------|---------------|
| Capture a **moment** | A flower blooms; tapping it surfaces that memory |
| Write a **love letter** | A tree grows / gains a ring |
| Write a **love note** | A small bloom / sprout |
| Visit a **new place** | A new plant species tied to that trip |
| Reach a **milestone/anniversary** | A permanent **landmark** (arch, fountain) |
| Steady weekly cadence | **Seasonal** blooms / ambient flourish |

(Exact mapping and art are tunable; the principle is *every meaningful act
leaves a visible, tappable trace*.)

### 5.2 The kindness rule (core, non-negotiable)
- Inactivity **never** kills plants or removes progress.
- A quiet stretch puts the garden into a gentle **resting season** (e.g. a calm
  winter palette), framed warmly.
- The **first** act after a quiet stretch revives it immediately with an
  affirming line ("Welcome back — your garden missed you 🌱").
- No streaks that can be "lost," no decay meter, no red/negative states.
- Rationale: couples in busy or rough patches must never feel judged by the app;
  that is precisely when a guilt mechanic would cause churn and harm.

### 5.3 Co-bloom ("two hands") — design, deferred build
- Certain special blooms only open when **both** partners contribute (one plants,
  the other waters).
- Rewards reciprocity warmly; the opposite of a "who loves more" leaderboard.
- **Depends on real partner sync (§9).** For v1 without a backend, co-blooms are
  either (a) deferred, or (b) simulated single-device as a preview. Default: mark
  as Phase 2, gated behind the backend.

### 5.4 Town economy tie-in
- Loving acts drip a modest amount of **coins** into the existing economy (a new,
  gentle faucet — not the primary reward).
- Milestone **landmarks double as town décor** (e.g. an anniversary fountain can
  appear in the room as well — light-touch, optional).
- Reuses existing economy constants/patterns (`PetEconomy`) for balance.

## 6. Couple Profile ("Us") page — anatomy (nostalgia-first)

Top to bottom:
1. **Couple header** — both names/photos, a chosen couple title, and
   **"Together since"** (days, or days since the first shared moment).
2. **The Garden** — the hero; a live view / entry into the Garden scene, with a
   bloom tally that acts as the living counter.
3. **On This Day (couple)** — resurfaces a moment/letter from a year ago (uses
   existing moment timestamps).
4. **Highlights** — "your place" (most-captured location), "your word" (most
   frequent loving word), favorite moment + favorite letter (pinned).
5. **Celebratory Analyst line** — one warm, data-grounded sentence
   ("This season bloomed mostly with Adventure — 6 new places"). Lightweight in
   v1; the deep Analyst is a later phase.

## 7. Data model (conceptual — not implementation)

New shared/couple-scoped state, conceptually:
- **Garden state:** the set of grown elements (type, source act reference,
  timestamp, position), current season/rest state, and last-activity timestamp.
- **Couple profile:** couple title, together-since anchor date, pinned
  moment/letter references, important-date placeholders (future).
- **Derived/celebration data:** computed from existing moments, places, notes,
  letters (no duplication — read from existing stores).

Persistence: v1 uses the existing local `DataPersistenceManager` pattern with
Codable + tolerant decoding (default-on-missing) so the format can grow safely,
mirroring `PetState`. The model should be shaped so it can migrate to a shared
backend record per couple (see §9) without redesign.

## 8. Premium gating

- **Free:** starter plot, Together-since, On This Day, a couple basic bloom
  types and one/two basic landmarks; premium blooms/landmarks visible but
  locked with a clear, warm upsell ("unlock your garden's full bloom").
- **Us+ (premium):** full bloom variety incl. rare/seasonal, milestone
  landmarks, co-blooms (when backend lands), celebratory Analyst lines, and the
  on-ramp to future Wrapped/Important Dates/keepsakes.
- **Pricing posture:** one subscription **for the couple** (not per-seat); annual
  framed as "less than one date night." Never paywall the memories themselves —
  paywall richness, variety, and keepsakes (preserves trust).

## 9. Dependency: partner sync backend (critical)

`PartnerInvite` currently states the partner-join backend does **not** exist; all
state is local. A genuinely *shared* garden between two devices therefore
requires backend work that is out of scope for v1.

**v1 approach:** build the Love Garden to grow from the **local user's**
relationship data now, with the data model and UI structured so that, once a
per-couple shared record + sync exists, the same garden becomes the shared one.
Backend-dependent pieces (co-bloom, true mutual state, cross-device consistency,
conflict resolution) are explicitly **Phase 2**, gated on the backend. This must
be called out to stakeholders so v1 isn't mis-sold as fully shared.

## 10. Relationship guardrails (design principles)

- **No single relationship score** — ever. Growth metaphor only.
- **No competition that breeds insecurity** — "who writes more" is playful,
  opt-in, never a leaderboard.
- **Symmetry & trust** — both partners see the same shared truths; no
  "spy on your partner" framing. Insights are always "you two," never
  "they didn't…".
- **Advice = affirming + specific + tiny** — invitations, never lectures.
- **Resting, not failing** — dormancy is warm and instantly reversible.

## 11. Future phases (out of v1 scope)

1. **Relationship Wrapped** — monthly mini + yearly big recap; primary share/viral
   loop.
2. **Important Dates ritual** — milestones, countdowns, reminders, anniversary
   auto-recaps, landmark spawns. The renewal engine.
3. **Deep Relationship Analyst** — love-language inference, themes, conversation
   starters, date ideas from their own data.
4. **Keepsakes** — exportable "Year in Love" book; Our-World map.
5. **Co-bloom & true shared garden** — once the partner backend exists.

## 12. Success metrics (to validate v1)

- Partner-invite → "Us" page open rate.
- Garden return visits / week.
- Loving-act rate lift after garden ships (do couples capture/write more?).
- Free → Us+ conversion from garden upsell surfaces.
- Qualitative: do users screenshot/share garden states? (signal of cherish-value)

## 13. Open questions / risks

- **Backend timeline** for partner sync — gates the "shared" promise and co-bloom.
- **Garden scene tech** — new scene vs reuse of room scene infrastructure; asset
  budget for blooms/landmarks (watch the SpriteKit 16384px texture limit and keep
  sheets downscaled).
- **Door placement/art** in the cat room and the transition animation.
- **Bloom taxonomy & art scope** — how many bloom types in v1 to feel alive
  without over-scoping art.
- **Solo experience** — how much garden to show before a partner is connected
  without over-promising.

## 14. Validation / testing considerations

- Garden grows correctly from each act type; tapping a bloom surfaces the right
  memory.
- Dormancy: after a quiet stretch the garden rests, and a single act revives it
  with the warm copy — never shows loss.
- Free vs Us+ gating renders correctly per access state.
- Door navigates to the Garden and back without disturbing room state.
- Local persistence survives app restart (tolerant decode), and the model is
  shaped for future backend migration.
