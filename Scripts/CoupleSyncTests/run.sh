#!/bin/sh
# BAB-147 couple profile sync regression tests.
# Compiles the real sync engine + couple profile resource with test stubs and runs
# them on macOS (no Xcode or simulator needed; Command Line Tools are enough).
# Usage: Scripts/CoupleSyncTests/run.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/../../BabyTown"
OUT="${TMPDIR:-/tmp}/covela-couple-sync-tests"
swiftc -swift-version 5 -default-isolation MainActor -o "$OUT" \
  "$APP/Services/Sync/CoupleSyncEngine.swift" \
  "$APP/Services/Sync/CoupleSyncResource.swift" \
  "$APP/Services/Sync/CoupleSyncState.swift" \
  "$APP/Services/Sync/SyncMedia.swift" \
  "$APP/Services/Sync/Resources/CoupleProfileSyncResource.swift" \
  "$APP/Services/CovelaMediaPath.swift" \
  "$HERE/Stubs.swift" "$HERE/FakeServer.swift" "$HERE/main.swift"
"$OUT"
