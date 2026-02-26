#!/usr/bin/env bash
set -euo pipefail

OUTPUT_ICNS="${1:-Resources/AppIcon.icns}"

TMP_DIR="$(mktemp -d)"
BASE_PNG="$TMP_DIR/AppIcon-1024.png"
ICONSET_DIR="$TMP_DIR/AppIcon.iconset"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

swift - "$BASE_PNG" <<'SWIFT'
import AppKit
import Foundation

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let pixels = Int(size)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to create bitmap buffer.\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Missing graphics context.\n", stderr)
    exit(1)
}
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }
context.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let circleInset: CGFloat = 70
let circleRect = NSRect(
    x: circleInset,
    y: circleInset,
    width: size - circleInset * 2,
    height: size - circleInset * 2
)
let circlePath = NSBezierPath(ovalIn: circleRect)

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.28)
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowBlurRadius = 30
shadow.set()

let backgroundGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.74, blue: 0.94, alpha: 1.0),
    NSColor(calibratedRed: 0.07, green: 0.39, blue: 0.86, alpha: 1.0),
    NSColor(calibratedRed: 0.05, green: 0.24, blue: 0.66, alpha: 1.0),
])!
backgroundGradient.draw(in: circlePath, angle: 230)

NSGraphicsContext.saveGraphicsState()
let highlightRect = circleRect.insetBy(dx: 70, dy: 70)
let highlightPath = NSBezierPath(ovalIn: highlightRect)
NSColor(calibratedWhite: 1.0, alpha: 0.09).setFill()
highlightPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
circlePath.lineWidth = 22
circlePath.stroke()

func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: size * x, y: size * y)
}

let bolt = NSBezierPath()
bolt.move(to: point(0.40, 0.77))
bolt.line(to: point(0.31, 0.55))
bolt.line(to: point(0.41, 0.55))
bolt.line(to: point(0.35, 0.33))
bolt.line(to: point(0.58, 0.56))
bolt.line(to: point(0.47, 0.56))
bolt.close()

let boltGradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.56, alpha: 1.0),
    NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.16, alpha: 1.0),
])!
boltGradient.draw(in: bolt, angle: -95)

NSColor(calibratedWhite: 1.0, alpha: 0.32).setStroke()
bolt.lineWidth = 10
bolt.stroke()

let brain = NSBezierPath()
brain.move(to: point(0.56, 0.42))
brain.curve(to: point(0.54, 0.55), controlPoint1: point(0.53, 0.44), controlPoint2: point(0.51, 0.51))
brain.curve(to: point(0.59, 0.66), controlPoint1: point(0.54, 0.62), controlPoint2: point(0.56, 0.66))
brain.curve(to: point(0.68, 0.67), controlPoint1: point(0.62, 0.69), controlPoint2: point(0.66, 0.69))
brain.curve(to: point(0.76, 0.62), controlPoint1: point(0.71, 0.66), controlPoint2: point(0.74, 0.64))
brain.curve(to: point(0.80, 0.52), controlPoint1: point(0.79, 0.59), controlPoint2: point(0.81, 0.55))
brain.curve(to: point(0.76, 0.42), controlPoint1: point(0.79, 0.48), controlPoint2: point(0.79, 0.44))
brain.curve(to: point(0.67, 0.37), controlPoint1: point(0.74, 0.39), controlPoint2: point(0.71, 0.37))
brain.curve(to: point(0.56, 0.42), controlPoint1: point(0.63, 0.36), controlPoint2: point(0.58, 0.38))
brain.close()

NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
brain.fill()

NSColor(calibratedWhite: 1.0, alpha: 0.95).setStroke()
brain.lineWidth = 16
brain.lineJoinStyle = .round
brain.lineCapStyle = .round
brain.stroke()

func drawFold(_ start: NSPoint, _ c1: NSPoint, _ c2: NSPoint, _ end: NSPoint) {
    let fold = NSBezierPath()
    fold.move(to: start)
    fold.curve(to: end, controlPoint1: c1, controlPoint2: c2)
    fold.lineWidth = 11
    fold.lineCapStyle = .round
    NSColor(calibratedWhite: 1.0, alpha: 0.78).setStroke()
    fold.stroke()
}

drawFold(point(0.60, 0.47), point(0.58, 0.56), point(0.61, 0.60), point(0.64, 0.63))
drawFold(point(0.66, 0.45), point(0.64, 0.52), point(0.67, 0.57), point(0.71, 0.60))
drawFold(point(0.72, 0.46), point(0.70, 0.52), point(0.73, 0.56), point(0.76, 0.56))

guard
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to rasterize icon image.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Failed to write icon PNG: \(error)\n", stderr)
    exit(1)
}
SWIFT

mkdir -p "$(dirname "$OUTPUT_ICNS")"
mkdir -p "$ICONSET_DIR"

cp "$BASE_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
sips -z 16 16 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
echo "Created $OUTPUT_ICNS"
