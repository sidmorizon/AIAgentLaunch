#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AIAgentLaunch"
VERSION_FILE="version"
VERSION="${1:-}"
REPOSITORY="${2:-${GITHUB_REPOSITORY:-}}"
ARCHIVE_PATH="${3:-}"
OUTPUT_PATH="${4:-dist/appcast.xml}"
SPARKLE_PRIVATE_ED_KEY="${SPARKLE_PRIVATE_ED_KEY:-}"
SPARKLE_SIGN_UPDATE_BIN="${SPARKLE_SIGN_UPDATE_BIN:-}"
REQUIRE_SPARKLE_SIGNING="${REQUIRE_SPARKLE_SIGNING:-0}"

if [[ -z "$VERSION" ]]; then
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Missing version file: $VERSION_FILE" >&2
    exit 1
  fi
  VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
fi

if [[ -z "$REPOSITORY" ]]; then
  echo "Missing repository. Pass owner/repo as 2nd argument." >&2
  exit 1
fi

if [[ -z "$ARCHIVE_PATH" ]]; then
  ARCHIVE_PATH="dist/$APP_NAME-$VERSION.dmg"
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Missing archive: $ARCHIVE_PATH" >&2
  exit 1
fi

if [[ -z "$SPARKLE_PRIVATE_ED_KEY" && "$REQUIRE_SPARKLE_SIGNING" == "1" ]]; then
  echo "Missing SPARKLE_PRIVATE_ED_KEY while REQUIRE_SPARKLE_SIGNING=1" >&2
  exit 1
fi

if [[ -z "$SPARKLE_SIGN_UPDATE_BIN" ]]; then
  for candidate in \
    ".build/artifacts/sparkle/Sparkle/bin/sign_update" \
    ".build/checkouts/Sparkle/bin/sign_update" \
    "sign_update"
  do
    if command -v "$candidate" >/dev/null 2>&1; then
      SPARKLE_SIGN_UPDATE_BIN="$candidate"
      break
    fi
  done
fi

if [[ -n "$SPARKLE_PRIVATE_ED_KEY" && -z "$SPARKLE_SIGN_UPDATE_BIN" ]]; then
  echo "Unable to locate sign_update binary for Sparkle signing" >&2
  exit 1
fi

ARCHIVE_SIZE="$(stat -f%z "$ARCHIVE_PATH")"
PUBLISH_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
ARCHIVE_FILENAME="$(basename "$ARCHIVE_PATH")"
DOWNLOAD_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION/$ARCHIVE_FILENAME"
ARCHIVE_TYPE="application/octet-stream"
case "$ARCHIVE_FILENAME" in
  *.dmg)
    ARCHIVE_TYPE="application/x-apple-diskimage"
    ;;
  *.zip)
    ARCHIVE_TYPE="application/zip"
    ;;
esac
SPARKLE_ED_SIGNATURE=""

if [[ -n "$SPARKLE_PRIVATE_ED_KEY" ]]; then
  SPARKLE_ED_SIGNATURE="$(
    printf '%s\n' "$SPARKLE_PRIVATE_ED_KEY" \
      | "$SPARKLE_SIGN_UPDATE_BIN" --ed-key-file - -p "$ARCHIVE_PATH"
  )"
  SPARKLE_ED_SIGNATURE="$(printf '%s' "$SPARKLE_ED_SIGNATURE" | tr -d '[:space:]')"

  if [[ -z "$SPARKLE_ED_SIGNATURE" ]]; then
    echo "Sparkle signature generation returned an empty signature" >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

SPARKLE_SIGNATURE_ATTRIBUTE=""
if [[ -n "$SPARKLE_ED_SIGNATURE" ]]; then
  SPARKLE_SIGNATURE_ATTRIBUTE="sparkle:edSignature=\"$SPARKLE_ED_SIGNATURE\""
fi

cat > "$OUTPUT_PATH" <<EOF_XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>$APP_NAME Updates</title>
    <description>Latest updates for $APP_NAME</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUBLISH_DATE</pubDate>
      <enclosure
        url="$DOWNLOAD_URL"
        sparkle:version="$VERSION"
        sparkle:shortVersionString="$VERSION"
        $SPARKLE_SIGNATURE_ATTRIBUTE
        length="$ARCHIVE_SIZE"
        type="$ARCHIVE_TYPE"/>
    </item>
  </channel>
</rss>
EOF_XML

echo "Created $OUTPUT_PATH"
