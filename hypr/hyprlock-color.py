#!/usr/bin/env python3
# Reads an ImageMagick "%c histogram" on stdin and prints two hex colours:
#   <vivid dominant colour> <lighter variant>
# Used by ~/Scripts/hyprlock.sh to colour the lock-screen clock.
import sys, re, colorsys

best = None
for line in sys.stdin:
    m = re.search(r'(\d+):\s*\([^)]*\)\s*#([0-9A-Fa-f]{6})', line)
    if not m:
        continue
    count = int(m.group(1)); hx = m.group(2)
    r, g, b = (int(hx[i:i+2], 16) / 255 for i in (0, 2, 4))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v < 0.15 or v > 0.97 or s < 0.18:   # skip near-black/white and greys
        continue
    score = count * (s ** 1.5) * v          # favour frequent, saturated, bright
    if best is None or score > best[0]:
        best = (score, r, g, b, h, s, v)


def hexc(r, g, b):
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


if best is None:
    print("#dddddd #f0f0f0")
else:
    _, r, g, b, h, s, v = best
    hour = hexc(r, g, b)
    lr, lg, lb = colorsys.hsv_to_rgb(h, max(0.0, s * 0.5), min(1.0, v * 0.55 + 0.45))
    print(hour, hexc(lr, lg, lb))
