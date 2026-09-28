#!/bin/bash
# Build the .app bundle. Pass --install to copy it into /Applications.
set -euo pipefail

cd "$(dirname "$0")"

NAME="ClaudeUsageMonitor"
BUILD_DIR="build.noindex"
BUNDLE="${BUILD_DIR}/${NAME}.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

swift build -c release --product UsageApp

rm -rf "$BUNDLE"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"

cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
cp "$(swift build -c release --show-bin-path)/UsageApp" "${BUNDLE}/Contents/MacOS/${NAME}"
cp -R locales "${BUNDLE}/Contents/Resources/locales"

# The linker signs only the executable, with its file name as the identifier.
# macOS tracks menu bar permissions and Keychain access by app identity,
# so sign the whole bundle to bind the identifier to CFBundleIdentifier.
codesign --force --sign - "$BUNDLE"

echo "Built ${BUNDLE}"

if [ "${1:-}" = "--install" ]; then
  # Replacing a running app leaves a stale process behind.
  pkill -f "${NAME}" 2>/dev/null || true
  rm -rf "/Applications/${NAME}.app"
  # Move rather than copy. Two bundles with the same identifier leave system
  # settings free to resolve the app to the build copy instead of the installed one.
  mv "${BUNDLE}" /Applications/
  # The build bundle was registered while it existed. Drop the stale record.
  "$LSREGISTER" -u "$BUNDLE" 2>/dev/null || true
  open "/Applications/${NAME}.app"
  echo "Installed to /Applications and launched"
else
  echo "Run ./build.sh --install to install it"
fi
