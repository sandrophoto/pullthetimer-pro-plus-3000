#!/bin/bash
# Build + zip + signature + mise à jour de l'appcast pour une nouvelle version.
#   ./release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
[ -z "$VERSION" ] && { echo "Usage : ./release.sh <version>   (ex. ./release.sh 1.0.0)"; exit 1; }

GITHUB_USER="sandrophoto"
REPO="dropptimer"

PLIST="Info.plist"
GEN="bin/generate_appcast"

echo "▸ Version $VERSION dans l'Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PLIST"

echo "▸ Build de l'app + zip de distribution (signature propre, hors iCloud)"
mkdir -p releases
ZIP="releases/PullTheTimer-$VERSION.zip"
ZIP_OUT="$PWD/$ZIP" ./build.sh

echo "▸ Génération + signature de l'appcast (EdDSA)"
"$GEN" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/$GITHUB_USER/$REPO/releases/download/v$VERSION/" \
    releases
cp releases/appcast.xml ./appcast.xml

echo ""
echo "✓ Version $VERSION prête. (Ou publie tout d'un coup : ./publish.sh $VERSION)"
