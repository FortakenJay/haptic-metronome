#!/usr/bin/env bash
# Boots Apple Watch simulators, launches Tactus in a few states and saves screenshots.
#
#   scripts/screenshots.sh path/to/Tactus.app out-dir
#
# Needs a Debug build for the watchOS simulator (the autostart hook only exists in Debug).
# Tempo and feel are set through launch arguments, which land in UserDefaults' argument domain:
#   -tempo.bpm 120   -tempo.feel strong   -tactus.autostart YES
# Each state is shot several times a fraction of a second apart, so at least one frame catches the beat flash.
set -euo pipefail

APP=$1
OUT=$2
BUNDLE=com.fortakenjay.tactus
mkdir -p "$OUT"

RUNTIME=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "watchOS" and r.get("isAvailable")]
print(rs[-1]["identifier"] if rs else "")')
if [[ -z "$RUNTIME" ]]; then
  echo "No watchOS simulator runtime available" >&2
  exit 1
fi
echo "Runtime: $RUNTIME"

# A watch with no paired iPhone shows a red "iPhone disconnected" icon in its status bar, so each watch
# gets an iPhone simulator to pair with, when the runner has an iOS runtime.
IOS_RUNTIME=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
print(rs[-1]["identifier"] if rs else "")')
PHONE_TYPE=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
names = {t["name"] for t in json.load(sys.stdin)["devicetypes"]}
print(next((n for n in ["iPhone 16", "iPhone 16 Pro", "iPhone 15"] if n in names), ""))')
echo "iOS runtime: ${IOS_RUNTIME:-none}, phone: ${PHONE_TYPE:-none}"

# One small, one mid, one large watch: whichever of these the runtime offers.
DEVICES=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
want = [
    ("small", ["Apple Watch SE (40mm) (2nd generation)", "Apple Watch Series 9 (41mm)", "Apple Watch Series 10 (42mm)"]),
    ("medium", ["Apple Watch Series 10 (46mm)", "Apple Watch Series 9 (45mm)"]),
    ("large", ["Apple Watch Ultra 2 (49mm)", "Apple Watch Ultra (49mm)"]),
]
types = {t["name"]: t["identifier"] for t in json.load(sys.stdin)["devicetypes"]}
for slug, names in want:
    for n in names:
        if n in types:
            print(f"{slug}|{n}|{types[n]}")
            break')
echo "$DEVICES"

shoot() {
  local udid=$1 slug=$2 state=$3
  shift 3
  # --terminate-running-process: a plain terminate-then-launch can race watchOS relaunching the app,
  # and then the new launch arguments never arrive.
  xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE" "$@" >/dev/null
  sleep 6
  for i in 1 2 3 4 5 6 7 8; do
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$slug-$state-$i.png" >/dev/null 2>&1
    sleep 0.07
  done
}

while IFS='|' read -r slug name type; do
  [[ -z "$slug" ]] && continue
  # SHOTS_ONLY=medium shoots one size only (pairing an iPhone per watch is slow).
  if [[ -n "${SHOTS_ONLY:-}" && "$slug" != "$SHOTS_ONLY" ]]; then continue; fi
  echo "== $slug: $name"
  if ! udid=$(xcrun simctl create "tactus-$slug" "$type" "$RUNTIME" 2>/dev/null); then
    echo "   cannot create $name on $RUNTIME, skipped"
    continue
  fi
  phone=""
  if [[ -n "$IOS_RUNTIME" && -n "$PHONE_TYPE" ]]; then
    phone=$(xcrun simctl create "tactus-phone-$slug" "$PHONE_TYPE" "$IOS_RUNTIME" 2>/dev/null || true)
  fi
  pair=""
  if [[ -n "$phone" ]]; then
    pair=$(xcrun simctl pair "$udid" "$phone" 2>/dev/null || true)
    xcrun simctl boot "$phone"
    xcrun simctl bootstatus "$phone" -b >/dev/null
  fi
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  if [[ -n "$pair" ]]; then
    xcrun simctl pair_activate "$pair" >/dev/null 2>&1 || true
    echo "   paired with $PHONE_TYPE"
    sleep 10
  fi
  # Apple's marketing time for watch screenshots. Not every runtime supports it; skip if not.
  xcrun simctl status_bar "$udid" override --time "10:09" >/dev/null 2>&1 || echo "   status bar override not supported"
  xcrun simctl install "$udid" "$APP"
  echo "$name" > "$OUT/$slug-device.txt"

  shoot "$udid" "$slug" stopped -tempo.bpm 100 -tempo.feel light -tactus.autostart NO
  shoot "$udid" "$slug" playing -tempo.bpm 120 -tempo.feel light -tactus.autostart YES
  shoot "$udid" "$slug" strong -tempo.bpm 168 -tempo.feel strong -tactus.autostart YES

  xcrun simctl shutdown "$udid"
  [[ -n "$phone" ]] && xcrun simctl shutdown "$phone"
done <<< "$DEVICES"

ls -la "$OUT"
