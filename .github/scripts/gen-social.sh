#!/bin/bash
# gen-social.sh - Generate GitHub social preview image
# Usage: ./gen-social.sh "ProjectName" icon1.svg icon2.svg ...
#
# Example: ./gen-social.sh "AppLock" apple.svg signal.svg
#
# Output: assets/social-preview.png (1280x640)

set -e

PROJECT="${1:-ProjectName}"
shift 1 2>/dev/null || true
ICONS=("$@")

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/assets/social-preview.png"
mkdir -p "$ROOT/assets"

# Create gradient background (soft gray metallic)
magick -size 1280x640 gradient:'#f0f0f0'-'#c8c8c8' /tmp/bg.png

# Add icons if provided
if [[ ${#ICONS[@]} -gt 0 ]]; then
    ICON_SIZE=70
    ICON_GAP=40
    TOTAL_WIDTH=$(( ${#ICONS[@]} * ICON_SIZE + (${#ICONS[@]} - 1) * ICON_GAP ))
    START_X=$(( (1280 - TOTAL_WIDTH) / 2 ))
    ICON_Y=200
    
    cp /tmp/bg.png /tmp/with-icons.png
    
    X_POS=$START_X
    for icon in "${ICONS[@]}"; do
        if [[ -f "$icon" ]]; then
            magick "$icon" -resize ${ICON_SIZE}x${ICON_SIZE} -background none -flatten /tmp/icon.png 2>/dev/null && \
            magick /tmp/with-icons.png /tmp/icon.png -gravity northwest -geometry +${X_POS}+${ICON_Y} -composite /tmp/with-icons.png
            X_POS=$((X_POS + ICON_SIZE + ICON_GAP))
        fi
    done
    
    # Add text below icons
    magick /tmp/with-icons.png \
        -gravity center \
        -font Helvetica-Bold -pointsize 90 \
        -fill black -annotate +0+100 "$PROJECT" \
        "$OUT"
else
    # Just text, no icons
    magick /tmp/bg.png \
        -gravity center \
        -font Helvetica-Bold -pointsize 90 \
        -fill black -annotate +0+0 "$PROJECT" \
        "$OUT"
fi

echo "✓ $OUT"
