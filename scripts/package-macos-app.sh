#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AIAgentLaunch"
VERSION_FILE="version"
VERSION="${1:-}"
REPOSITORY="${2:-${AIAgentLaunch_GITHUB_REPOSITORY:-}}"

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

swift build -c release --product "$APP_NAME"

DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$DIST_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

cp ".build/release/$APP_NAME" "$CONTENTS_DIR/MacOS/$APP_NAME"
chmod +x "$CONTENTS_DIR/MacOS/$APP_NAME"
cp "$VERSION_FILE" "$CONTENTS_DIR/Resources/version"

SPARKLE_FRAMEWORK_PATH="$(find .build -type d -path '*/release/Sparkle.framework' | head -n 1)"
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
$SU_FEED_BLOCK
</dict>
</plist>
EOF_PLIST

ARCHIVE_NAME="$APP_NAME-$VERSION.zip"
(
  cd "$DIST_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ARCHIVE_NAME"
)

echo "Created $DIST_DIR/$ARCHIVE_NAME"
