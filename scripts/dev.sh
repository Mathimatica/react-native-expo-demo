#!/bin/zsh

set -e

# ---------------------------------------------------------
# react-native-expo-demo local development environment
# ---------------------------------------------------------

PROJECT_NAME="react-native-expo-demo"

# iOS 27 - iPhone 17
IOS_UDID="A4231244-9C26-40F2-A738-A7E915B99A1C"

# Android
ANDROID_AVD="Pixel_9a"
ANDROID_PACKAGE="com.anonymous.reactnativeexpodemo"

# Expo Development Client
DEV_CLIENT_URL="exp+react-native-expo-demo://expo-development-client/?url=http%3A%2F%2F127.0.0.1%3A8081"


# ---------------------------------------------------------
# Node / NVM
# ---------------------------------------------------------

export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh"
fi

echo ""
echo "▶ Using project Node version..."
nvm use


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

find_android_emulator() {
  for SERIAL in $(adb devices | awk '/^emulator-/{print $1}'); do
    AVD_NAME=$(adb -s "$SERIAL" emu avd name 2>/dev/null | head -1 | tr -d '\r')

    if [ "$AVD_NAME" = "$ANDROID_AVD" ]; then
      echo "$SERIAL"
      return
    fi
  done
}

ANDROID_SERIAL=$(find_android_emulator)

if [ -z "$ANDROID_SERIAL" ]; then
  echo "  Launching $ANDROID_AVD..."

  emulator -avd "$ANDROID_AVD" \
    > "/tmp/${PROJECT_NAME}-android-emulator.log" 2>&1 &

  echo "  Waiting for emulator..."

  while [ -z "$ANDROID_SERIAL" ]; do
    sleep 2
    ANDROID_SERIAL=$(find_android_emulator)
  done
fi

echo "  Waiting for Android to finish booting..."

while [ "$(adb -s "$ANDROID_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
  sleep 2
done

# Forward Android emulator port 8081 back to Metro on the Mac.
adb -s "$ANDROID_SERIAL" reverse tcp:8081 tcp:8081

echo "✓ Pixel 9a ready ($ANDROID_SERIAL)"


# ---------------------------------------------------------
# Launch apps once Metro becomes available
# ---------------------------------------------------------

launch_apps() {

  echo ""
  echo "▶ Waiting for Metro..."

  until curl -fsS http://127.0.0.1:8081/status 2>/dev/null \
    | grep -q "packager-status:running"; do
    sleep 1
  done

  echo "✓ Metro ready"

  echo ""
  echo "▶ Opening iOS app..."

  xcrun simctl openurl \
    "$IOS_UDID" \
    "$DEV_CLIENT_URL" \
    2>/dev/null || true

  echo "▶ Opening Android app..."

  adb -s "$ANDROID_SERIAL" shell am start \
    -W \
    -a android.intent.action.VIEW \
    -d "$DEV_CLIENT_URL" \
    -p "$ANDROID_PACKAGE" \
    >/dev/null 2>&1 || true

  echo ""
  echo "✓ iOS and Android connected"
}

launch_apps &


# ---------------------------------------------------------
# Metro
# ---------------------------------------------------------

echo ""
echo "▶ Starting Metro..."
echo ""

npx expo start
