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
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$BUNDLE" "$@" >/dev/null
  sleep 5
  for i in 1 2 3 4 5 6 7 8; do
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$slug-$state-$i.png" >/dev/null 2>&1
    sleep 0.07
  done
}

while IFS='|' read -r slug name type; do
  [[ -z "$slug" ]] && continue
  echo "== $slug: $name"
  if ! udid=$(xcrun simctl create "tactus-$slug" "$type" "$RUNTIME" 2>/dev/null); then
    echo "   cannot create $name on $RUNTIME, skipped"
    continue
  fi
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$APP"
  echo "$name" > "$OUT/$slug-device.txt"

  shoot "$udid" "$slug" stopped -tempo.bpm 100 -tempo.feel light -tactus.autostart NO
  shoot "$udid" "$slug" playing -tempo.bpm 120 -tempo.feel light -tactus.autostart YES
  shoot "$udid" "$slug" strong -tempo.bpm 168 -tempo.feel strong -tactus.autostart YES

  xcrun simctl shutdown "$udid"
done <<< "$DEVICES"

ls -la "$OUT"
