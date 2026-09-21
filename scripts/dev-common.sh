#!/usr/bin/env bash
# Shared setup for dev.sh and dev-native.sh. Source this file from Bash.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT_NAME="react-native-expo-demo"
# Pinned iOS 27 / iPhone 17 and Android Pixel 9a.
IOS_UDID="A4231244-9C26-40F2-A738-A7E915B99A1C"
ANDROID_AVD="Pixel_9a"
FINGERPRINT_FILE="$REPO_ROOT/.expo/native-build-fingerprint"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "NVM is missing at $NVM_DIR. Install NVM before starting development." >&2
  exit 1
fi
source "$NVM_DIR/nvm.sh"
echo "▶ Using project Node version..."
nvm use || { echo "Run nvm install to install the version in .nvmrc." >&2; exit 1; }

native_fingerprint() {
  node "$REPO_ROOT/scripts/native-fingerprint.cjs"
}

check_android_timeout() {
  if (( SECONDS >= ANDROID_DEADLINE )); then
    echo "Timed out waiting for $ANDROID_AVD. See /tmp/${PROJECT_NAME}-android-emulator.log." >&2
    exit 1
  fi
}

prepare_devices() {
  # ---------------------------------------------------------
  # iOS
  # ---------------------------------------------------------

  echo ""
  echo "▶ Starting iOS 27 / iPhone 17..."

  if ! xcrun simctl list devices | grep "$IOS_UDID" | grep -q "(Booted)"; then
    xcrun simctl boot "$IOS_UDID" 2>/dev/null || true
  fi

  xcrun simctl bootstatus "$IOS_UDID" -b

  # Xcode 27 uses Device Hub
  open -a DeviceHub 2>/dev/null || true

  echo "✓ iPhone 17 ready"


  # ---------------------------------------------------------
  # Android
  # ---------------------------------------------------------

  echo ""
  echo "▶ Starting Android / Pixel 9a..."
  local ANDROID_DEADLINE=$((SECONDS + 300))

  find_android_emulator() {
    local SERIAL AVD_NAME
    for SERIAL in $(adb devices | awk '/^emulator-/{print $1}'); do
      AVD_NAME=$(adb -s "$SERIAL" emu avd name 2>/dev/null | head -1 | tr -d '\r')

      if [ "$AVD_NAME" = "$ANDROID_AVD" ]; then
        echo "$SERIAL"
        return 0
      fi
    done
    return 0
  }

  ANDROID_SERIAL=$(find_android_emulator)

  if [ -z "$ANDROID_SERIAL" ]; then
    echo "  Launching $ANDROID_AVD..."

    emulator -avd "$ANDROID_AVD" \
      > "/tmp/${PROJECT_NAME}-android-emulator.log" 2>&1 &

    echo "  Waiting for emulator..."

    while [ -z "$ANDROID_SERIAL" ]; do
      check_android_timeout
      sleep 2
      ANDROID_SERIAL=$(find_android_emulator)
    done
  fi

  echo "  Waiting for Android to finish booting..."

  while [ "$(adb -s "$ANDROID_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    check_android_timeout
    sleep 2
  done

  # Forward Android emulator port 8081 back to Metro on the Mac.
  adb -s "$ANDROID_SERIAL" reverse tcp:8081 tcp:8081

  echo "✓ Pixel 9a ready ($ANDROID_SERIAL)"


}
