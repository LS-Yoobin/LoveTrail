# Spec: Watch Together Camera

**Date:** 2026-06-25
**Phase:** Together only (official paired couple)
**Status:** Approved (join flow: push/in-app invite)

---

## Overview

Extend Watch Together so a couple can watch a YouTube video while optionally seeing each other in a FaceTime-style camera overlay. The camera feed appears in the bottom-right corner over the YouTube player. Users can mute their microphone and turn off their camera at any time.

Video calls are **1:1 only** (host + paired partner). Media is **peer-to-peer via WebRTC** so ongoing vendor cost stays at **$0** for normal couple usage. Signaling rides on the existing MongoDB backend.

YouTube playback remains **local per device** in v1. Playback sync (shared play/pause/seek) is explicitly out of scope for this release.

---

## Goals

| Goal | Detail |
|---|---|
| Intimacy while apart | See your partner while watching the same video |
| Zero media cost | P2P WebRTC; no paid RTC vendor; no video through Covela servers |
| Simple controls | Camera on/off, mic mute, dismiss overlay |
| Covela-native join | Partner A starts; Partner B receives push/in-app invite |
| Network quality | Camera only on WiFi or cellular (5G/LTE) |

---

## Non-Goals (v1)

- Playback sync (play/pause/seek timestamps)
- Group calls (3+ people)
- Recording calls
- Breakup / Prelude phases
- TURN relay server (deferred; add only if connection failure rate is unacceptable)
- Embedding Apple FaceTime

---

## User Flow

### Partner A (host)

1. Opens Watch Together from the garden TV (existing entry sheet).
2. Pastes a YouTube link and taps **Watch Together**.
3. Rotates to landscape → `WatchTogetherPlayerView` opens full screen.
4. YouTube begins playing (existing embed flow).
5. Taps **See each other** in the player chrome.
6. App checks network (WiFi or cellular required).
7. App requests camera + microphone permission if not yet granted.
8. Backend creates a `watch_together_session` and sends Partner B a push notification.
9. Camera overlay appears bottom-right while waiting for Partner B.
10. When Partner B joins, P2P WebRTC connects and both feeds render in the PiP cluster.

### Partner B (invitee)

1. Receives push notification: *"[Name] wants to watch together"* with **Join** action.
2. If app is foregrounded, an in-app banner offers the same **Join** action.
3. Tapping **Join** opens `WatchTogetherPlayerView` with the same YouTube URL, locked to landscape.
4. Camera + mic permissions requested if needed.
5. Joins the session via signaling; WebRTC connects; overlay shows both feeds.

### During the session

- **Mic button**: toggles local audio track (muted state persists until toggled back).
- **Camera button**: toggles local video track. When off, local inset shows partner's theme-tinted avatar circle with initial.
- **See each other** toggle (host only can disable for self; either partner can leave camera mode): ends local camera tracks and hides overlay. Session remains active for re-enable.
- **Close (X)**: ends Watch Together for that user. If host leaves, session status → `ended` and partner sees *"[Name] left"* toast; YouTube keeps playing.

---

## UI — Landscape Player

Layer order (bottom → top):

1. Black background
2. `WatchTogetherWebPlayer` (YouTube, full bleed)
3. `WatchTogetherCallOverlay` (bottom-right, only when camera mode active)
4. Player chrome: close button (top-right), **See each other** toggle (top-left)

### Call overlay (`WatchTogetherCallOverlay`)

Positioned bottom-right with 20pt inset from safe area (above home indicator in landscape).

**PiP cluster** (~156×200pt total):

| Element | Size | Notes |
|---|---|---|
| Partner feed | 140×186pt | Main rounded rect (16pt radius), `BabyTownTheme.accent` 1pt border at 30% opacity |
| Self inset | 56×74pt | Bottom-left corner of partner feed, 8pt inset, 10pt radius |
| Control bar | Full width below feeds | Two icon buttons, 44pt tap targets |

**Control bar buttons:**

| Button | Icon (on) | Icon (off) | Accessibility label |
|---|---|---|---|
| Microphone | `mic.fill` | `mic.slash.fill` | "Mute microphone" / "Unmute microphone" |
| Camera | `video.fill` | `video.slash.fill` | "Turn off camera" / "Turn on camera" |

Off states use `BabyTownTheme.textSecondary`; on states use white on semi-transparent black pill background.

**Waiting state** (partner not yet connected): partner feed area shows pulsing accent ring + *"Waiting for [partner name]…"* in `.subheadline`.

**Disconnected state**: partner feed shows *"[Name] left"* for 3 seconds, then returns to waiting state if session is still active.

### See each other toggle

Pill button top-left (mirrors close button padding):

- Off: `video.badge.plus` icon + label **See each other**
- On: `video.fill` icon + label **Camera on** (accent fill)

Disabled (40% opacity) when network gate fails, with inline toast explaining why.

---

## Copy (Together phase)

| Context | Copy |
|---|---|
| Toggle off | See each other |
| Toggle on | Camera on |
| Push notification title | [Name] wants to watch together |
| Push notification body | Tap to join and watch |
| In-app banner | [Name] started Watch Together |
| Join button | Join |
| Network blocked | Connect to WiFi or mobile data to see each other |
| Permission pre-prompt | Covela needs camera and microphone so you two can watch together |
| Waiting | Waiting for [name]… |
| Partner left | [Name] left |
| Connection failed | Couldn't connect. Check your connection and try again. |

No ` - ` (space dash space) in any string.

---

## Network Gate

`WatchTogetherNetworkGate` wraps `NWPathMonitor`:

| Path | Camera allowed |
|---|---|
| WiFi | Yes |
| Cellular | Yes |
| Wired / other / unsatisfied | No |

Does not block YouTube playback; only blocks enabling camera.

Optional: treat `path.isConstrained` as blocked (cellular low data mode). Defer to v1.1 unless needed.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                  WatchTogetherPlayerView                 │
│  ┌─────────────────────┐  ┌──────────────────────────┐  │
│  │ WatchTogetherWeb    │  │ WatchTogetherCallOverlay │  │
│  │ Player (YouTube)    │  │  ├─ partner RTCVideoView │  │
│  └─────────────────────┘  │  ├─ self RTCVideoView    │  │
│                            │  └─ mic / camera buttons │  │
│                            └──────────────────────────┘  │
│  WatchTogetherCallController (WebRTC)                    │
│  WatchTogetherSessionService (signaling)                 │
└─────────────────────────────────────────────────────────┘
          │ WebSocket (signaling only)          │
          ▼                                       ▼
   ┌──────────────┐                    ┌──────────────┐
   │ Partner A    │◄──── P2P media ───►│ Partner B    │
   └──────────────┘                    └──────────────┘
```

### Signaling flow

1. Host creates session → `POST /watch_together/sessions`
2. Backend stores session, sends push to `partner_id`
3. Both clients open `wss://api.covela.app/watch_together/{session_id}` (authenticated with existing JWT)
4. Host sends SDP offer → server forwards → invitee sends SDP answer → ICE candidates exchanged
5. WebRTC connects P2P; video/audio never touch Covela media servers

### STUN

Use Google's public STUN: `stun:stun.l.google.com:19302` (free, no TURN in v1).

---

## Backend

### Collection: `watch_together_sessions`

```json
{
  "_id": "uuid",
  "couple_id": "ref: couples._id",
  "host_user_id": "ref: users._id",
  "video_url": "string (validated YouTube or direct)",
  "status": "waiting | active | ended",
  "created_at": "ISODate",
  "expires_at": "ISODate (created_at + 4 hours)"
}
```

TTL index on `expires_at` auto-deletes stale sessions.

### REST endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/watch_together/sessions` | JWT | Host creates session; triggers push to partner |
| GET | `/watch_together/sessions/active` | JWT | Returns active session for caller's couple, if any |
| POST | `/watch_together/sessions/{id}/join` | JWT | Invitee marks joined; status → `active` |
| POST | `/watch_together/sessions/{id}/end` | JWT | Either partner ends session |

Access control: caller must be `host_user_id` or the couple's `partner_id`.

### WebSocket: `/watch_together/{session_id}/signal`

Message envelope:

```json
{
  "type": "offer | answer | ice_candidate",
  "from_user_id": "uuid",
  "payload": {}
}
```

Server validates session membership and forwards to the other peer only. No persistence of SDP/ICE (ephemeral).

### Push notification payload

```json
{
  "type": "watch_together_invite",
  "session_id": "uuid",
  "host_name": "string",
  "video_url": "string"
}
```

Tapping notification deep-links to `WatchTogetherPlayerView` with `session_id` + `video_url`.

---

## iOS Modules

| File | Responsibility |
|---|---|
| `WatchTogetherSessionService.swift` | REST + WebSocket signaling |
| `WatchTogetherCallController.swift` | WebRTC peer connection, local/remote tracks, mute/camera |
| `WatchTogetherCallOverlay.swift` | PiP SwiftUI layout over player |
| `WatchTogetherNetworkGate.swift` | NWPathMonitor wrapper |
| `WatchTogetherPlayerView.swift` | Host existing YouTube layer + overlay + chrome |
| `WatchTogetherEntryView.swift` | Unchanged entry; passes `coupleId` context to player |

### Dependencies

- WebRTC binary via SPM (`stasel/WebRTC` or equivalent maintained fork)
- Existing `OrientationManager` for landscape lock
- Existing push notification infrastructure (`docs/superpowers/specs/2026-06-03-push-notifications-design.md`)

### Permissions (Info.plist)

- `NSCameraUsageDescription`: "Covela uses your camera so you and your partner can see each other while watching together."
- `NSMicrophoneUsageDescription`: "Covela uses your microphone so you and your partner can talk while watching together."

---

## WebRTC Details

| Setting | Value |
|---|---|
| Video codec | VP8 preferred, H.264 fallback |
| Audio | Opus |
| Camera | Front-facing, 640×480 capture |
| Connection model | 1:1 mesh (single peer connection) |
| ICE | STUN only (v1) |

`WatchTogetherCallController` exposes:

```swift
@Published var isConnected: Bool
@Published var isMicMuted: Bool
@Published var isCameraOff: Bool
var localVideoTrack: RTCVideoTrack?
var remoteVideoTrack: RTCVideoTrack?

func startCall(sessionID: String, isHost: Bool)
func toggleMic()
func toggleCamera()
func endCall()
```

---

## Error Handling

| Scenario | Behavior |
|---|---|
| No network | Disable **See each other**; toast with network copy |
| Permission denied | Alert with link to Settings |
| Partner doesn't join within 5 min | Overlay shows waiting state; session stays open |
| WebRTC connection fails | Toast *"Couldn't connect…"*; overlay stays, retry button appears |
| Host ends session | Partner toast + overlay hides; YouTube continues |
| Invalid/expired session on join | Alert *"This watch session has ended"*; dismiss player |

---

## Privacy & Security

- Sessions scoped to `couple_id`; JWT validates membership before signaling
- No call recording, no server-side media storage
- Signaling messages are ephemeral (not logged)
- Camera/mic active only while overlay is enabled and session is live
- WebSocket connections require valid JWT; session ID alone is insufficient

---

## Phased Delivery

### v1 (this spec)

- Push/in-app invite join flow (Option A)
- P2P WebRTC camera overlay with mic/camera toggles
- Network gate (WiFi + cellular)
- Bottom-right PiP layout over YouTube player

### v1.1

- Reconnect on brief network drop
- Connection quality dot indicator on PiP
- `path.isConstrained` blocking

### v2

- Playback sync via signaling (play/pause/seek events, not stream rebroadcast)

### v2.1

- Self-hosted TURN (`coturn`) only if P2P failure rate > 10%

---

## Testing Checklist

- [ ] Host starts session → partner receives push
- [ ] Partner taps Join → both see video overlay
- [ ] Mic mute: remote hears silence; local icon updates
- [ ] Camera off: remote sees avatar inset; local icon updates
- [ ] Either partner on WiFi, other on 5G: call connects
- [ ] Offline: **See each other** disabled
- [ ] Host leaves: partner notified, YouTube keeps playing
- [ ] Session expires after 4 hours
- [ ] Non-couple user cannot join session (403)
- [ ] Pink and Blue themes: overlay borders/accents respect `BabyTownTheme`

---

## Files Touched (implementation reference)

| Area | Files |
|---|---|
| Player UI | `BabyTown/Views/WatchTogether/WatchTogetherPlayerView.swift` |
| New views | `WatchTogetherCallOverlay.swift` |
| New services | `WatchTogetherCallController.swift`, `WatchTogetherSessionService.swift`, `WatchTogetherNetworkGate.swift` |
| Entry | `WatchTogetherEntryView.swift` (pass session context) |
| Push handling | `AppDelegate.swift` or existing push router |
| Backend | New routes + WebSocket handler + `watch_together_sessions` collection |
| Project | `BabyTown.xcodeproj` (WebRTC SPM dependency) |
| Info.plist | Camera + microphone usage strings |
