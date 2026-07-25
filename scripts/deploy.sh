#!/bin/bash
# TITAN / VALKYRIE — archive and upload to TestFlight in one command.
#
# Usage:
#   ./scripts/deploy.sh titan
#   ./scripts/deploy.sh valkyrie
#
# One-time setup (App Store Connect API key, so no password prompts):
#   1. appstoreconnect.apple.com -> Users and Access -> Integrations
#      -> App Store Connect API -> Team Keys -> Generate (role: App Manager).
#   2. Download the .p8 file (you only get one chance) and note the
#      KEY ID and ISSUER ID shown on that page.
#   3. Put the .p8 somewhere safe (NOT in this repo), e.g. ~/asc-keys/
#   4. Export these in your shell profile (~/.zshrc):
#        export ASC_KEY_ID="XXXXXXXXXX"
#        export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#        export ASC_KEY_PATH="$HOME/asc-keys/AuthKey_XXXXXXXXXX.p8"
set -euo pipefail

case "${1:-}" in
  titan)    SCHEME="Titan" ;;
  valkyrie) SCHEME="Valkyrie" ;;
  *) echo "Usage: $0 [titan|valkyrie]"; exit 1 ;;
esac

: "${ASC_KEY_ID:?Set ASC_KEY_ID (see comments at top of this script)}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH}"

cd "$(dirname "$0")/.."

BUILD_NUM="$(date +%Y%m%d%H%M)"
ARCHIVE="build/${SCHEME}.xcarchive"
EXPORT_DIR="build/${SCHEME}-export"

echo "==> Archiving ${SCHEME} (build ${BUILD_NUM})"
xcodebuild \
  -project Titan.xcodeproj \
  -scheme "${SCHEME}" \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUM}" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${ASC_KEY_PATH}" \
  -authenticationKeyID "${ASC_KEY_ID}" \
  -authenticationKeyIssuerID "${ASC_ISSUER_ID}" \
  archive | tail -5

if [ ! -d "${ARCHIVE}/Products/Applications" ] || [ -z "$(ls -A "${ARCHIVE}/Products/Applications" 2>/dev/null)" ]; then
  echo "ERROR: archive has no app inside (Products/Applications is empty)."
  echo "Run the archive command without '| tail' to see the full log."
  exit 1
fi
echo "==> Archive OK: $(ls "${ARCHIVE}/Products/Applications")"

cat > build/exportOptions.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST

echo "==> Uploading ${SCHEME} to App Store Connect / TestFlight"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportOptionsPlist build/exportOptions.plist \
  -exportPath "${EXPORT_DIR}" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${ASC_KEY_PATH}" \
  -authenticationKeyID "${ASC_KEY_ID}" \
  -authenticationKeyIssuerID "${ASC_ISSUER_ID}"

echo ""
echo "==> DONE. Build ${BUILD_NUM} uploaded — it will appear in TestFlight"
echo "    after processing (5-15 min). Testers get it automatically."
