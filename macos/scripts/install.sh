#!/usr/bin/env bash
# Builds Retro8Bit.saver and the Retro 8-Bit app (Release) and installs both for the current user:
# the saver into ~/Library/Screen Savers, the app into ~/Applications.
# Usage: scripts/install.sh            build and install
#        scripts/install.sh --uninstall remove both
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="$HOME/Library/Screen Savers"
SAVER="Retro8Bit.saver"
APP_DEST="$HOME/Applications"
APP="Retro 8-Bit.app"
PRODUCTS="build/DerivedData/Build/Products/Release"

# The screen saver host keeps loaded bundles in memory; quit it so changes take effect.
restart_host() {
    killall legacyScreenSaver 2>/dev/null || true
    killall "legacyScreenSaver (Wallpaper)" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -rf "${DEST:?}/$SAVER" "${APP_DEST:?}/$APP"
    restart_host
    echo "Removed $DEST/$SAVER and $APP_DEST/$APP"
    exit 0
fi

if command -v xcodegen >/dev/null; then
    xcodegen generate --quiet
fi

# A generic destination builds a universal (arm64 + x86_64) binary.
for scheme in RetroSVR RetroSVRApp; do
    xcodebuild -project RetroSVR.xcodeproj -scheme "$scheme" -configuration Release \
        -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData -quiet build
done

mkdir -p "$DEST" "$APP_DEST"
rm -rf "${DEST:?}/$SAVER" "${APP_DEST:?}/$APP"
cp -R "$PRODUCTS/$SAVER" "$DEST/"
cp -R "$PRODUCTS/$APP" "$APP_DEST/"
restart_host

echo "Installed $DEST/$SAVER"
echo "Installed $APP_DEST/$APP (runs the saver in a window; ⌃⌘F for full screen)"
echo "Choose \"Retro 8-Bit\" in System Settings > Screen Saver."
open "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" || true
