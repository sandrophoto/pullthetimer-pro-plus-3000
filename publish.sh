#!/bin/bash
# Publie une version DE BOUT EN BOUT sur GitHub (via gh) : build + zip + appcast,
# création/MAJ de la Release + upload du zip, et commit de l'appcast.xml.
# Pré-requis (une fois) : `gh auth login` + le dépôt GitHub créé.
#   ./publish.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
[ -z "$VERSION" ] && { echo "Usage : ./publish.sh <version>   (ex. ./publish.sh 1.0.0)"; exit 1; }

GITHUB_USER="sandrophoto"
REPO="dropptimer"
SLUG="$GITHUB_USER/$REPO"

if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh n'est pas authentifié. Lance d'abord : gh auth login"; exit 1
fi

# 1) Build + zip + appcast signé.
./release.sh "$VERSION"
ZIP="releases/PullTheTimer-$VERSION.zip"

# 2) Release GitHub : créer (ou mettre à jour) + uploader le zip.
echo "▸ Publication de la Release v$VERSION sur GitHub"
if gh release view "v$VERSION" -R "$SLUG" >/dev/null 2>&1; then
    gh release upload "v$VERSION" "$ZIP" -R "$SLUG" --clobber
else
    gh release create "v$VERSION" "$ZIP" -R "$SLUG" \
        -t "PullTheTimer Pro Plus 3000 $VERSION" -n "Mise à jour automatique $VERSION."
fi

# 3) Commit de appcast.xml via l'API (sans clone local).
echo "▸ Mise en ligne de appcast.xml"
CONTENT="$(base64 < appcast.xml | tr -d '\n')"
SHA="$(gh api "repos/$SLUG/contents/appcast.xml" --jq .sha 2>/dev/null || true)"
if [ -n "$SHA" ]; then
    gh api -X PUT "repos/$SLUG/contents/appcast.xml" \
        -f message="appcast $VERSION" -f content="$CONTENT" -f sha="$SHA" >/dev/null
else
    gh api -X PUT "repos/$SLUG/contents/appcast.xml" \
        -f message="appcast $VERSION" -f content="$CONTENT" >/dev/null
fi

echo ""
echo "✓ Publié : v$VERSION en ligne (Release + appcast). Les utilisateurs seront notifiés automatiquement."
