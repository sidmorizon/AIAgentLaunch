#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AIAgentLaunch"
VERSION_FILE="version"
VERSION="${1:-}"
REPOSITORY="${2:-${AIAgentLaunch_GITHUB_REPOSITORY:-}}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
REQUIRE_SPARKLE_PUBLIC_KEY="${REQUIRE_SPARKLE_PUBLIC_KEY:-0}"
ENABLE_UPDATE_CHECKS="${ENABLE_UPDATE_CHECKS:-0}"
ARM64_TRIPLE="arm64-apple-macosx14.0"
X86_64_TRIPLE="x86_64-apple-macosx14.0"
ICON_SOURCE_PATH="Resources/AppIcon.icns"

if [[ -z "$VERSION" ]]; then
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Missing version file: $VERSION_FILE" >&2
    exit 1
  fi
  VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
fi

if [[ -z "$VERSION" ]]; then
  echo "Version is empty" >&2
  exit 1
fi

if [[ "$REQUIRE_SPARKLE_PUBLIC_KEY" == "1" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "Missing SPARKLE_PUBLIC_ED_KEY while REQUIRE_SPARKLE_PUBLIC_KEY=1" >&2
  exit 1
fi

swift build -c release --product "$APP_NAME" --triple "$ARM64_TRIPLE"
swift build -c release --product "$APP_NAME" --triple "$X86_64_TRIPLE"

ARM64_BINARY=".build/arm64-apple-macosx/release/$APP_NAME"
X86_64_BINARY=".build/x86_64-apple-macosx/release/$APP_NAME"

if [[ ! -f "$ARM64_BINARY" ]]; then
  echo "Missing arm64 binary: $ARM64_BINARY" >&2
  exit 1
fi

if [[ ! -f "$X86_64_BINARY" ]]; then
  echo "Missing x86_64 binary: $X86_64_BINARY" >&2
  exit 1
fi

DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$DIST_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

lipo -create \
  "$ARM64_BINARY" \
  "$X86_64_BINARY" \
  -output "$CONTENTS_DIR/MacOS/$APP_NAME"
chmod +x "$CONTENTS_DIR/MacOS/$APP_NAME"
cp "$VERSION_FILE" "$CONTENTS_DIR/Resources/version"
lipo -info "$CONTENTS_DIR/MacOS/$APP_NAME"

SPARKLE_FRAMEWORK_PATH=".build/arm64-apple-macosx/release/Sparkle.framework"
if [[ ! -d "$SPARKLE_FRAMEWORK_PATH" ]]; then
  SPARKLE_FRAMEWORK_PATH="$(find .build -type d -path '*/release/Sparkle.framework' | head -n 1)"
fi
if [[ -n "$SPARKLE_FRAMEWORK_PATH" ]]; then
  mkdir -p "$CONTENTS_DIR/Frameworks"
  cp -R "$SPARKLE_FRAMEWORK_PATH" "$CONTENTS_DIR/Frameworks/"

  if ! otool -l "$CONTENTS_DIR/MacOS/$APP_NAME" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$CONTENTS_DIR/MacOS/$APP_NAME"
  fi
fi

SU_FEED_BLOCK=""
if [[ -n "$REPOSITORY" ]]; then
  SU_FEED_BLOCK=$(cat <<BLOCK
    <key>SUFeedURL</key>
    <string>https://github.com/$REPOSITORY/releases/latest/download/appcast.xml</string>
BLOCK
)
fi

SPARKLE_PUBLIC_KEY_BLOCK=""
if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  SPARKLE_PUBLIC_KEY_BLOCK=$(cat <<BLOCK
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_ED_KEY</string>
BLOCK
)
fi

UPDATE_CHECKS_BLOCK=""
if [[ "$ENABLE_UPDATE_CHECKS" == "1" ]]; then
  UPDATE_CHECKS_BLOCK=$(cat <<BLOCK
    <key>AIAgentLaunchEnableUpdateChecks</key>
    <string>1</string>
BLOCK
)
fi

ICON_BLOCK=""
if [[ -f "$ICON_SOURCE_PATH" ]]; then
  cp "$ICON_SOURCE_PATH" "$CONTENTS_DIR/Resources/AppIcon.icns"
  ICON_BLOCK=$(cat <<BLOCK
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
BLOCK
)
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.onekey.$APP_NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUEnableAutomaticChecks</key>
    <false/>
$UPDATE_CHECKS_BLOCK
$SU_FEED_BLOCK
$SPARKLE_PUBLIC_KEY_BLOCK
$ICON_BLOCK
</dict>
</plist>
EOF_PLIST

DMG_NAME="$APP_NAME-$VERSION.dmg"

DMG_STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$DMG_STAGING_DIR"
}
trap cleanup EXIT

cp -R "$APP_DIR" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DIST_DIR/$DMG_NAME" >/dev/null

trap - EXIT
cleanup

echo "Created $DIST_DIR/$DMG_NAME"
