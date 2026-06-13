# Invite Partner Banner — Theme-Adaptive Colour Design

**Date:** 2026-06-12
**Branch:** watch

## Problem

The invite partner banner in `PreludeHomeView` fills with `BabyTownTheme.cardBackground` — the same light blue (blue theme) or soft rose (pink theme) used by every capture row card in the scroll list behind it. Because the bottom chrome sits in a ZStack with no backdrop, the banner visually merges with the scroll content, making it hard to distinguish as a distinct interactive element.

## Decision

Replace the banner's fill, border, and text colours with four new semantic tokens in `BabyTownTheme`. No layout, blur, or structural changes.

## New Semantic Tokens

Add to `BabyTownTheme.swift`:

| Token | Blue theme | Pink theme |
|---|---|---|
| `inviteBannerFill` | `#FFF3D6` — rich warm cream | `#E8DEFF` — rich lavender |
| `inviteBannerBorder` | `#E0B060` — amber | `#A888D0` — violet |
| `inviteBannerText` | `#5A3800` — dark amber | `#3A2860` — dark violet |
| `inviteBannerSubtext` | `#7A5000` — mid amber | `#5A4080` — mid violet |

## Changes to `PreludeHomeView.inviteBanner`

| Element | Before | After |
|---|---|---|
| Background fill | `BabyTownTheme.cardBackground` | `BabyTownTheme.inviteBannerFill` |
| Border | none | 1.5pt `BabyTownTheme.inviteBannerBorder` overlay |
| Title text | `BabyTownTheme.textPrimary` | `BabyTownTheme.inviteBannerText` |
| Subtitle text | `.black` | `BabyTownTheme.inviteBannerSubtext` |
| Chevron | `BabyTownTheme.textSecondary` | `BabyTownTheme.inviteBannerText` |

The icon (`envelope.heart.fill`) keeps its current `BabyTownTheme.accent` colour — it already contrasts well in both themes.

The border is applied as an `.overlay` on the existing `RoundedRectangle(cornerRadius: 14, style: .continuous)` background shape using `.strokeBorder(BabyTownTheme.inviteBannerBorder, lineWidth: 1.5)` — matching the corner radius already in use.

## Out of Scope

- No changes to the quick add bar gradient
- No frosted/blur backdrop behind the bottom chrome
- No layout or positioning changes
- No changes to `InvitePartnerBanner` (the home-feed component — separate file)
- Pink theme: the `invitedSent` state ("Waiting for them to accept…") uses the same new tokens, no special casing needed

## Files Touched

1. `BabyTown/Theme/BabyTownTheme.swift` — add 4 tokens
2. `BabyTown/Views/Prelude/PreludeHomeView.swift` — update `inviteBanner` colour usage
