#!/bin/bash
# Build and drive the tvOS app in the Apple TV simulator.
#
#   scripts/tv-sim.sh build              compile the KinoPubTV scheme
#   scripts/tv-sim.sh run [section]      build, install and launch (Debug) — opens on a section:
#                                        home, search, watching, sport, settings, movies, series,
#                                        bookmarks, history, collections
#   scripts/tv-sim.sh relaunch [section] relaunch the installed build without rebuilding
#   scripts/tv-sim.sh logs               stream the app's logs (Ctrl-C to stop)
#   scripts/tv-sim.sh shot [name]        save a screenshot to ~/Desktop/<name>.png
#   scripts/tv-sim.sh reset-epg          delete the cached TV guide (forces a fresh download)
#   scripts/tv-sim.sh signout            wipe the simulator keychain (back to the sign-in screen)
#
# SIM overrides the simulator (default: Apple TV 4K (4th generation) (at 1080p) — the one Xcode runs on).

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SIM="${SIM:-Apple TV 4K (4th generation) (at 1080p)}"
BUNDLE_ID="com.kino.pub.tv"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/KinoPubTV-sim"
APP="$DERIVED/Build/Products/Debug-appletvsimulator/KinoPub.app"

device_id() {
  xcrun simctl list devices available | grep -F "$SIM (" | grep -oE '[0-9A-F-]{36}' | head -1
}

boot() {
  local id; id="$(device_id)"
  [ -n "$id" ] || { echo "No simulator named '$SIM'" >&2; exit 1; }
  if ! xcrun simctl list devices | grep -F "$id" | grep -q Booted; then
    xcrun simctl boot "$id"
    xcrun simctl bootstatus "$id" -b >/dev/null
  fi
  open -a "$(xcode-select -p)/Applications/Simulator.app" --args -CurrentDeviceUDID "$id"
  echo "$id"
}

build() {
  xcodebuild -project "$REPO/KinoPubAppleClient.xcodeproj" -scheme KinoPubTV \
    -destination "platform=tvOS Simulator,id=$(device_id)" -skipPackagePluginValidation \
    -derivedDataPath "$DERIVED" clean build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)' | sort -u
}

launch() {
  local id="$1" section="${2:-home}"
  xcrun simctl terminate "$id" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$id" "$BUNDLE_ID" -tvTab "$section"
}

case "${1:-}" in
  build)
    build ;;
  run)
    build | tee /dev/stderr | grep -q 'BUILD SUCCEEDED'
    id="$(boot | tail -1)"
    xcrun simctl install "$id" "$APP"
    launch "$id" "${2:-home}" ;;
  relaunch)
    id="$(boot | tail -1)"
    launch "$id" "${2:-home}" ;;
  logs)
    xcrun simctl spawn "$(device_id)" log stream --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  shot)
    out="$HOME/Desktop/${2:-tv-$(date +%H%M%S)}.png"
    xcrun simctl io "$(device_id)" screenshot "$out" && echo "$out" ;;
  reset-epg)
    container="$(xcrun simctl get_app_container "$(device_id)" "$BUNDLE_ID" data)"
    find "$container/Library/Caches" -name 'epg-cache-*.json' -print -delete ;;
  signout)
    xcrun simctl keychain "$(device_id)" reset && echo "Keychain wiped — relaunch to see the sign-in screen." ;;
  *)
    sed -n '2,15p' "$0"; exit 1 ;;
esac
