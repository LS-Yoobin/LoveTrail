# Couples Profile — Slices 2 & 3 (implemented)

**Slice 2 — Stickers**
- `SubjectLiftService` — Vision foreground mask + circular fallback
- `ProfileSticker` model + `CoupleProfile.stickers` persistence (PNG files)
- `ProfileStickerSync` — auto stickers for user avatar, special-date photos, adopted pet
- `ProfileStickersLayer` — drag to reposition in Customize mode
- Header **Customize** / **Done** + `CustomizeProfileBanner`

**Slice 3 — Garden polish**
- `LoveGardenScene` — gradient sky, parallax hills, drifting clouds, falling petals (blooming season)

**Navigation (“the rest” without backend)**
- Cat room wall **Us** portal → `CoupleProfileView` (`PetRoomScene` + `PetRoomView`)
- Home **Settings → Our Garden**
- Removed launch jump to temp `.loveGarden` route
- Partner slot shows invite share, or a locked **Partner** placeholder when subscription is unlocked (real self-authored profile still needs sync backend)

**Still deferred**
- True partner-authored profile (backend)
- Premium garden gating surfaces
- Co-bloom, Wrapped, deep Analyst
