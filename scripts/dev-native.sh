#!/usr/bin/env bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/dev-common.sh"
prepare_devices

# Invalidate first: a partial/failed rebuild must never look up to date.
mkdir -p "$(dirname "$FINGERPRINT_FILE")"
rm -f "$FINGERPRINT_FILE"
echo "▶ Regenerating native projects (replaces ios/ and android/)..."
npx expo prebuild --clean

# Prebuild can update dependencies; fingerprint the inputs actually compiled.
BUILD_FINGERPRINT=$(native_fingerprint)
npx expo run:ios --device "$IOS_UDID" --no-bundler
# Expo resolves Android --device by AVD name; adb commands use its serial.
npx expo run:android --device "$ANDROID_AVD" --no-bundler

if [ "$BUILD_FINGERPRINT" != "$(native_fingerprint)" ]; then
  echo "Native inputs changed during the build. Run npm run dev:native again." >&2
  exit 1
fi
printf '%s\n' "$BUILD_FINGERPRINT" > "$FINGERPRINT_FILE.tmp"
mv "$FINGERPRINT_FILE.tmp" "$FINGERPRINT_FILE"
echo "✓ Both native builds installed; fingerprint saved."

# The saved fingerprint matches, so normal startup will not prompt again.
exec bash "$REPO_ROOT/scripts/dev.sh"
