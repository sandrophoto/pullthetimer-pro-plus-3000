#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="PullTheTimer Pro Plus 3000.app"
EXEC="PullTheTimer"
DEST="${DEST:-Dist}"          # où atterrit le .app final (copie locale)
ZIP_OUT="${ZIP_OUT:-}"        # si défini : produit un zip pristine depuis le staging

# On assemble ET on signe dans un dossier temporaire hors iCloud Drive : iCloud
# réinjecte des xattrs (FinderInfo) qui font échouer codesign de façon aléatoire.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/dropptimer.XXXXXX")"
APP="$STAGE/$APP_NAME"
trap 'rm -rf "$STAGE"' EXIT

echo "→ Compilation universelle (arm64 + x86_64) avec Sparkle…"
mkdir -p .build
swiftc -O -target arm64-apple-macos13  Sources/main.swift -o .build/$EXEC-arm64 \
    -framework Cocoa -F Vendor -framework Sparkle
swiftc -O -target x86_64-apple-macos13 Sources/main.swift -o .build/$EXEC-x86_64 \
    -framework Cocoa -F Vendor -framework Sparkle

echo "→ Assemblage du bundle (hors iCloud : $STAGE)…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
lipo -create .build/$EXEC-arm64 .build/$EXEC-x86_64 -output "$APP/Contents/MacOS/$EXEC"
rm -rf .build
cp Info.plist "$APP/Contents/Info.plist"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" || true

echo "→ Intégration de Sparkle…"
ditto Vendor/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$EXEC" 2>/dev/null || true

echo "→ Signature ad-hoc…"
xattr -cr "$APP"
SPK="$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$SPK/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign - "$SPK/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign - "$SPK/Versions/B/Updater.app"
codesign --force --sign - "$SPK/Versions/B/Autoupdate"
codesign --force --sign - "$SPK"
codesign --force --sign - \
    --identifier com.tigre.dropptimer \
    --entitlements DroppTimer.entitlements \
    "$APP"
codesign -v --strict "$APP" && echo "   signature vérifiée ✓"

# Zip de distribution (pristine, depuis le staging hors iCloud).
if [ -n "$ZIP_OUT" ]; then
    echo "→ Zip de distribution : $ZIP_OUT"
    mkdir -p "$(dirname "$ZIP_OUT")"; rm -f "$ZIP_OUT"
    ditto -c -k --keepParent "$APP" "$ZIP_OUT"
fi

# Copie locale lançable dans DEST.
echo "→ Livraison : $DEST/$APP_NAME"
mkdir -p "$DEST"; rm -rf "$DEST/$APP_NAME"
ditto "$APP" "$DEST/$APP_NAME"

echo "✅ Build terminé : $DEST/$APP_NAME"
