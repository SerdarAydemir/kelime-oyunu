#!/usr/bin/env bash
# tools/make_icons.sh — rasterise the launcher icon / splash PNGs from the
# design SVGs and regenerate the platform resources.
#
# Sources (single source of truth: docs/design/):
#   app-icon-1a.svg            full icon (iOS flat, Play Store 1024)
#   app-icon-1a-foreground.svg Android adaptive foreground (no background)
#   LOGO_BG in kz-tokens.js    linear-gradient(160deg, #1c3358 0%, #0b1a33 100%)
#
# Outputs (assets/icon/, committed):
#   app_icon.png             1024×1024 full icon
#   app_icon_foreground.png  1024×1024, drawing trimmed + centred with the
#                            content diagonal < 66 dp of the 108 dp canvas
#                            (farthest corner ≈ 31 dp < 33 dp safe radius),
#                            so flutter_launcher_icons runs with inset 0
#   app_icon_background.png  1024×1024 LOGO_BG gradient (CSS 160°: direction
#                            (sin160°, −cos160°); gradient length
#                            1024·(|sin|+|cos|) ≈ 1312 px → the two barycentric
#                            anchors sit ±656 px from the centre along it)
#   splash_icon_android12.png 1152×1152 Android 12+ splash icon (mark only,
#                            navy icon circle comes from flutter_native_splash)
#   splash_logo.png          480×480 rounded tile (r28/120 → 96 px). 480 px is
#                            deliberate: flutter_native_splash treats the
#                            source as xxxhdpi (÷4 per density), so 480 px
#                            renders as the 120 dp splash box on Android.
#
# Requires ImageMagick 7 with the rsvg delegate (`magick -list format | grep SVG`).
# Outputs are byte-deterministic: PNG date/time chunks are excluded so a
# re-run over unchanged SVGs produces no git diff.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=docs/design
PNG=(-define png:exclude-chunks=date,time)
OUT=assets/icon
mkdir -p "$OUT"

magick "${PNG[@]}" -background none -density 384 "$SRC/app-icon-1a.svg" \
  -resize 1024x1024 "$OUT/app_icon.png"

magick "${PNG[@]}" -background none -density 384 "$SRC/app-icon-1a-foreground.svg" \
  -trim +repage -resize 440x440 \
  -gravity center -background none -extent 1024x1024 "$OUT/app_icon_foreground.png"

magick "${PNG[@]}" -size 1024x1024 xc: \
  -sparse-color barycentric '288,-105 rgb(28,51,88) 736,1129 rgb(11,26,51)' \
  "$OUT/app_icon_background.png"

magick "${PNG[@]}" "$OUT/app_icon.png" \
  \( -size 1024x1024 xc:none -fill white -draw "roundrectangle 0,0 1023,1023 239,239" \) \
  -compose DstIn -composite -resize 480x480 "$OUT/splash_logo.png"

# Android 12+ splash icon: 1152 px = 288 dp @4x; the system masks a 240 dp
# circle and the mark must sit inside the inner 192 dp, so the trimmed
# drawing is scaled to 560 px (diagonal ≈ 175 dp) and centred.
magick "${PNG[@]}" -background none -density 384 "$SRC/app-icon-1a-foreground.svg" \
  -trim +repage -resize 560x560 \
  -gravity center -background none -extent 1152x1152 "$OUT/splash_icon_android12.png"

# Safe-zone check for the adaptive foreground (fails loudly if the drawing
# would be clipped by a circular launcher mask).
magick "$OUT/app_icon_foreground.png" -trim -print "%w %h %X %Y\n" null: | python3 -c '
import math, sys
w, h, x, y = [int(v.lstrip("+")) for v in sys.stdin.read().split()]
r = max(math.hypot(px - 512, py - 512) for px in (x, x + w) for py in (y, y + h))
dp = r / 1024 * 108
print(f"foreground: farthest corner {dp:.1f} dp from centre (safe radius 33 dp)")
sys.exit(0 if dp <= 33 else 1)
'

dart run flutter_launcher_icons
dart run flutter_native_splash:create
