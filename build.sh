#!/bin/bash
# Build the .app bundle.
#   --install  move it into /Applications and launch it
#   --dmg      also package it as a disk image for a release
set -euo pipefail

cd "$(dirname "$0")"

# SwiftPM's default build system fails with only the Command Line Tools.
if xcode-select -p 2>/dev/null | grep -q CommandLineTools; then
  echo "error: Xcode is required. The Command Line Tools alone cannot build this package." >&2
  echo "Install Xcode, then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

NAME="AIUsageChecker"
DISPLAY_NAME="AI Usage Checker"
# The app was called ClaudeUsageMonitor before. It has a different bundle ID,
# so both would run side by side with duplicate menu bar items.
LEGACY_NAME="ClaudeUsageMonitor"
BUILD_DIR="build.noindex"
BUNDLE="${BUILD_DIR}/${NAME}.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
# One binary for Apple Silicon and Intel.
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}" --product UsageApp
BIN_PATH="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$BUNDLE"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"

cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
cp "${BIN_PATH}/UsageApp" "${BUNDLE}/Contents/MacOS/${NAME}"
cp -R locales "${BUNDLE}/Contents/Resources/locales"

# The linker signs only the executable, with its file name as the identifier.
# macOS tracks menu bar permissions and Keychain access by app identity,
# so sign the whole bundle to bind the identifier to CFBundleIdentifier.
codesign --force --sign - "$BUNDLE"

echo "Built ${BUNDLE}"

case "${1:-}" in
  --install)
    # Replacing a running app leaves a stale process behind.
    pkill -x "${NAME}" 2>/dev/null || true
    rm -rf "/Applications/${NAME}.app"
    if [ -d "/Applications/${LEGACY_NAME}.app" ]; then
      pkill -x "${LEGACY_NAME}" 2>/dev/null || true
      rm -rf "/Applications/${LEGACY_NAME}.app"
      echo "Removed the old ${LEGACY_NAME}.app"
    fi
    # Move rather than copy. Two bundles with the same identifier leave system
    # settings free to resolve the app to the build copy instead of the installed one.
    mv "${BUNDLE}" /Applications/
    # The build bundle was registered while it existed. Drop the stale record.
    "$LSREGISTER" -u "$BUNDLE" 2>/dev/null || true
    open "/Applications/${NAME}.app"
    echo "Installed to /Applications and launched"
    ;;
  --dmg)
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
    DMG="${BUILD_DIR}/${NAME}-${VERSION}.dmg"
    STAGING="${BUILD_DIR}/dmg"
    rm -rf "$STAGING" "$DMG"
    mkdir -p "$STAGING"
    cp -R "$BUNDLE" "$STAGING/"
    # Drag-to-install target.
    ln -s /Applications "${STAGING}/Applications"
    hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGING" -format UDZO -quiet "$DMG"
    rm -rf "$STAGING"
    # The build bundle stays, so drop only the registration LaunchServices
    # made for the staging copy.
    "$LSREGISTER" -u "${STAGING}/${NAME}.app" 2>/dev/null || true
    echo "Packaged ${DMG}"
    ;;
  *)
    echo "Run ./build.sh --install to install it"
    ;;
esac
