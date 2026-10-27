#!/bin/bash
# Refresh the 7-day provisioning profile on your iPhone.
#
# Free Apple IDs expire development installs after 7 days. Run this
# weekly (phone plugged in via USB and unlocked) to rebuild, reinstall,
# and relaunch — no Xcode, no manual steps.
#
#   scripts/refresh-app.sh

set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.oliver.desktopbrowser"

# ---------------------------------------------------------------- device
echo "==> Looking for your iPhone..."
DEVICES_JSON="$(mktemp)"
trap 'rm -f "$DEVICES_JSON"' EXIT
xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1

DEVICE_INFO="$(python3 - "$DEVICES_JSON" <<'PY'
import json, sys

devs = json.load(open(sys.argv[1]))["result"]["devices"]
phones = [
    d for d in devs
    if d.get("visibilityClass") != "simulators"
    and d.get("hardwareProperties", {}).get("platform") == "iOS"
    and d.get("connectionProperties", {}).get("pairingState") == "paired"
]
if not phones:
    sys.exit(1)
d = phones[0]
print(d["hardwareProperties"]["udid"])
print(d.get("deviceProperties", {}).get("name") or "iPhone")
PY
)"
if [[ -z "$DEVICE_INFO" ]]; then
    echo "❌ No paired iPhone found." >&2
    echo "   Connect it via USB, or wirelessly: same Wi-Fi as this Mac," >&2
    echo "   unlocked, with 'Connect via network' enabled in Xcode's" >&2
    echo "   Devices & Simulators window." >&2
    exit 1
fi
UDID="$(sed -n '1p' <<<"$DEVICE_INFO")"
PHONE_NAME="$(sed -n '2p' <<<"$DEVICE_INFO")"
echo "    Found: $PHONE_NAME ($UDID)"

# ---------------------------------------------------------------- project
if [[ ! -d DesktopBrowser.xcodeproj ]]; then
    echo "==> No .xcodeproj found — regenerating with XcodeGen..."
    xcodegen generate
fi

# ---------------------------------------------------------------- build
echo "==> Building with a fresh provisioning profile..."
xcodebuild \
    -project DesktopBrowser.xcodeproj \
    -scheme DesktopBrowser \
    -destination "platform=iOS,id=$UDID" \
    -derivedDataPath build/phone \
    -allowProvisioningUpdates \
    -quiet build

APP="build/phone/Build/Products/Debug-iphoneos/DesktopBrowser.app"

# ---------------------------------------------------------------- install
echo "==> Installing on $PHONE_NAME..."
xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null

# ---------------------------------------------------------------- launch
echo "==> Launching..."
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >/dev/null

echo "✅ Done — profile clock reset for another 7 days."
echo "   Tip: run this every Monday, or whenever you think of it."
