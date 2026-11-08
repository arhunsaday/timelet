#!/bin/bash
# Builds a Timelet DMG ready to share: universal Release build, then
# scripts/distribute.sh (Developer ID signature, notarization, DMG).
#
#   scripts/release.sh [version]      e.g. scripts/release.sh 1.2.0
#
# Version defaults to MARKETING_VERSION in project.yml, build number to the
# commit count (override with BUILD_NUMBER=…).
# Output: dist/Timelet-<version>.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(sed -n 's/^ *MARKETING_VERSION: *"*\([^"]*\)"*.*$/\1/p' project.yml | head -1)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
DERIVED="build/release"

command -v xcodegen >/dev/null || { echo "✗ XcodeGen is missing: brew install xcodegen" >&2; exit 1; }

echo "→ Timelet $VERSION ($BUILD_NUMBER)"
xcodegen generate --quiet

rm -rf "$DERIVED"
# Signed ad hoc here; distribute.sh replaces it with the Developer ID signature.
xcodebuild build \
  -quiet \
  -project Timelet.xcodeproj \
  -scheme Timelet \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER=""

scripts/distribute.sh "$DERIVED/Build/Products/Release/Timelet.app" "dist/Timelet-$VERSION.dmg"
