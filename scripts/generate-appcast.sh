#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AIAgentLaunch"
VERSION_FILE="version"
VERSION="${1:-}"
REPOSITORY="${2:-${GITHUB_REPOSITORY:-}}"
ARCHIVE_PATH="${3:-}"
OUTPUT_PATH="${4:-dist/appcast.xml}"

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
  ARCHIVE_PATH="dist/$APP_NAME-$VERSION.zip"
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Missing archive: $ARCHIVE_PATH" >&2
  exit 1
fi

ARCHIVE_SIZE="$(stat -f%z "$ARCHIVE_PATH")"
PUBLISH_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
DOWNLOAD_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION/$APP_NAME-$VERSION.zip"

mkdir -p "$(dirname "$OUTPUT_PATH")"

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
        length="$ARCHIVE_SIZE"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF_XML

echo "Created $OUTPUT_PATH"
