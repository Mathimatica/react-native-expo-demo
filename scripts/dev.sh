#!/usr/bin/env bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/dev-common.sh"

CURRENT_FINGERPRINT=$(native_fingerprint)
SAVED_FINGERPRINT=""
if [ -f "$FINGERPRINT_FILE" ]; then
  SAVED_FINGERPRINT=$(cat "$FINGERPRINT_FILE")
fi

if [ "$CURRENT_FINGERPRINT" != "$SAVED_FINGERPRINT" ]; then
  echo "Native configuration changed, or no successful native build is recorded."
  echo "Rebuilding regenerates ios/ and android/ with expo prebuild --clean."
  REBUILD=""
  if [ -t 0 ]; then
    read -r -p "Rebuild iOS and Android now? [y/N] " REBUILD || true
  fi
  case "$REBUILD" in
    y|Y|yes|YES|Yes) exec bash "$REPO_ROOT/scripts/dev-native.sh" ;;
    *) echo "Warning: native builds may be stale. Run npm run dev:native to rebuild." ;;
  esac
fi

# All clients use this fixed port; never silently switch to another Metro port.
if lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port 8081 is already in use. Stop its server before running npm run dev." >&2
  exit 1
fi

prepare_devices
ANDROID_PACKAGE=$(node -p 'require("./app.json").expo.android.package')
DEV_CLIENT_SCHEME=$(node -p '"exp+" + require("./app.json").expo.slug')
DEV_CLIENT_URL="${DEV_CLIENT_SCHEME}://expo-development-client/?url=http%3A%2F%2F127.0.0.1%3A8081"

# ---------------------------------------------------------
# Launch apps once Metro becomes available
# ---------------------------------------------------------

launch_apps() {

  echo ""
  echo "▶ Waiting for Metro..."

  local metro_deadline=$((SECONDS + 120))
  until curl --max-time 2 -fsS http://127.0.0.1:8081/status 2>/dev/null \
    | grep -q "packager-status:running"; do
    if (( SECONDS >= metro_deadline )); then
      echo "Timed out waiting for Metro on port 8081." >&2
      return 1
    fi
    sleep 1
  done

  echo "✓ Metro ready"

  echo ""
  echo "▶ Opening iOS app..."

  xcrun simctl openurl \
    "$IOS_UDID" \
    "$DEV_CLIENT_URL" \
    || { echo "Could not open the iOS development client." >&2; return 1; }

  echo "▶ Opening Android app..."

  adb -s "$ANDROID_SERIAL" shell am start \
    -W \
    -a android.intent.action.VIEW \
    -d "$DEV_CLIENT_URL" \
    -p "$ANDROID_PACKAGE" \
    || { echo "Could not open the Android development client." >&2; return 1; }

  echo ""
  echo "✓ iOS and Android connected"
}

launch_apps &
LAUNCH_PID=$!
# Do not leave the readiness watcher running if Metro fails or is interrupted.
trap 'kill "$LAUNCH_PID" 2>/dev/null || true' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM


echo "▶ Starting Metro..."
npx expo start --dev-client --localhost --port 8081
