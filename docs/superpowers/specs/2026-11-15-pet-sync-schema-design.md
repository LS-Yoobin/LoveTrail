# Pet, Room and Tricks Sync: Server Schema

**Epic:** BAB-47 Couple Cloud Sync · **Tickets:** BAB-60 (backend), BAB-69 (iOS)
**Status:** Decided 2026-11-15 · **Backend:** pocketverse `src/server/covela`

## Decisions

| | Decision |
|---|---|
| A | The server changes to match the iOS pet model. No app feature is removed. |
| B | The **app** owns need decay. The server stores each need as `{ value, as_of }` and never decays it. |
| C | Simultaneous edits use whole-document last write wins (409 on stale `base_updated_at`). A rare lost feeding is accepted. |
| D | Shared vs personal split below. Check-in streak is **per person** (stays on device). |

## Shared vs personal

**Shared (synced):** owned cats, adopted (active) cat, adoption date, custom cat names, needs, food servings, toilet paper mess state, rooms per cat, tricks per cat.

**Personal (stay on each phone, never sent):** pet / play / plant watering cooldowns, last interaction time ("pet misses you" reminder), pet room tutorial seen, check-in date and streak, selected play toy, play toy usage order.

**Coins:** not part of these documents. They move to the coin ledger (decision 2, pending). The server must keep ignoring any `coins` field here.

## What changes on the server

1. **Cat ids** use the iOS raw values: `calico`, `cowCat`, `bombay`. Drop the `Artemis` / `Arabella` enum. Migrate existing rows: `Artemis` → `calico`, `Arabella` → `cowCat`.
2. **Remove server decay** (`applyNeedsDecay`). Store and return needs exactly as sent.
3. **Room and tricks become per cat**: one document per couple, holding a map keyed by cat id.
4. Nested objects can be stored as Mongoose `Mixed` (or explicit sub-schemas). The server validates types and sizes only; the app owns the meaning.
5. All three endpoints keep the existing contract: couple membership middleware, `base_updated_at` → 409 `stale_write`, server-set `updated_at`, silent push to the partner after a write.

## Endpoints

All under `/covela/api/couple`. `GET` returns the document, or `null` fields if none exists yet. `PUT` replaces the whole document (fields omitted in the body are left unchanged). Responses include `updated_at`.

### `GET` / `PUT /pet`

```json
{
  "adopted_skin": "calico",
  "adopted_date": "2026-06-24T17:00:00.000Z",
  "owned_skins": ["calico", "bombay"],
  "custom_names": { "calico": "Mochi" },
  "food_servings": 3,
  "needs": {
    "hunger":    { "value": 82.5, "as_of": "2026-11-15T20:01:02.003Z" },
    "thirst":    { "value": 40.0, "as_of": "2026-11-15T20:01:02.003Z" },
    "litter":    { "value": 100,  "as_of": "2026-11-15T18:00:00.000Z" },
    "happiness": { "value": 64.2, "as_of": "2026-11-15T19:30:00.000Z" }
  },
  "toilet_paper_mess_by_pet": {
    "calico": {
      "week_key": "2026-W46",
      "scheduled_event_times": [1794700000, 1794900000],
      "consumed_event_indices": [0],
      "active_event_index": null
    }
  },
  "updated_at": "2026-11-15T20:01:02.010Z"
}
```

Validation: `adopted_skin` null or a cat id; `owned_skins` array of cat ids; need `value` is a number from 0 to 100; `as_of` is ISO 8601; `custom_names` values are strings of at most 24 characters.

### `GET` / `PUT /pet/room`

```json
{
  "layouts_by_pet": {
    "calico": {
      "built_in_layout_version": 11,
      "owned_item_ids": ["cat_tree", "plant_monstera"],
      "stashed_item_ids": [],
      "prop_positions": { "cat_tree": { "x": 0.805, "y": 0.2 } },
      "flipped_item_ids": ["plant_monstera"],
      "wall_color_id": "blush",
      "picture_frame_moments": { "frame_small": "6553a1b2c3d4e5f601234567" },
      "equipped_items": { "collar": "collar_red" }
    }
  },
  "updated_at": "2026-11-15T20:01:02.010Z"
}
```

`picture_frame_moments` values are **moment ids** (the same 24-hex ids used by `/moments`). The server stores them as plain strings and does not need to check them.

### `GET` / `PUT /pet/tricks`

```json
{
  "training_by_pet": {
    "calico": {
      "progress": {
        "paw":  { "is_unlocked": true,  "successes": 12, "snack_reinforcements": 3 },
        "spin": { "is_unlocked": false, "successes": 0,  "snack_reinforcements": 0 }
      },
      "smart_meter_xp": 140
    }
  },
  "updated_at": "2026-11-15T20:01:02.010Z"
}
```

## First sync

The app treats a document as "has content" when `/pet` has a non-null `adopted_skin`, or when `/pet/room` / `/pet/tricks` have a non-empty map. On first pairing, the server copy wins if it has content; otherwise the phone uploads its own. The server needs no special logic for this.

## Out of scope

- Coin balance and purchases (coin ledger, decision 2).
- Merging needs field by field (decision C: not needed).

## Tests (backend)

- Partner A `PUT /pet`, partner B `GET /pet` returns identical needs (no decay applied).
- `PUT /pet` with stale `base_updated_at` returns 409 with `server_updated_at`.
- `bombay` accepted; `Artemis` rejected after migration; the migration converts existing rows.
- Room and tricks keep separate entries per cat; updating `calico` does not touch `bombay`.
- A user from another couple gets 403 on all three endpoints.
