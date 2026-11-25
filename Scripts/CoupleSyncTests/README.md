# Couple sync tests (BAB-147)

## Logic regression tests (no Xcode needed)

    Scripts/CoupleSyncTests/run.sh

Compiles the real `CoupleSyncEngine`, `CoupleSyncState`, `SyncMedia` and
`CoupleProfileSyncResource` with stubs (`Stubs.swift`) against an in-memory server
(`FakeServer.swift`) and runs the scenarios in `main.swift`.

## Two-simulator integration test (staging only)

`api_probe.py` refuses production hosts and never prints tokens, passwords, invite
codes, signed URLs or names (names and ids appear as `len<n>#<hash>`).

1. Logging proxy in front of the **staging** API:

       python3 -I Scripts/CoupleSyncTests/api_probe.py proxy --upstream https://<staging>/covela/api --port 8787

2. Launch each simulator against it (no scheme edit; the shared scheme points at the
   default server):

       SIMCTL_CHILD_COVELA_API_BASE_URL=http://127.0.0.1:8787/covela/api \
       SIMCTL_CHILD_COVELA_FILE_SERVER_BASE_URL=https://<staging-file-server>/COVELA_FS_API \
       xcrun simctl launch <simulator-udid> LS.Covela

   If requests never reach the proxy and the device log shows NSURLErrorDomain -1022,
   App Transport Security is blocking plain http to localhost; use `probe` instead.

3. Read-only state of one account at any point:

       COVELA_PROBE_EMAIL=... COVELA_PROBE_PASSWORD=... \
         python3 -I Scripts/CoupleSyncTests/api_probe.py probe --api https://<staging>/covela/api

## Where a first profile sync stops (diagnostics)

The engine logs each step (pairing gate → media upload → `PATCH` → `GET` → partner
apply → retry) under subsystem `LS.Covela`, category `CoupleSync`, without ids, names,
tokens or media paths:

    xcrun simctl spawn <simulator-udid> log stream --predicate 'subsystem == "LS.Covela" AND category == "CoupleSync"'
