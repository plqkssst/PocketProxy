#!/usr/bin/env python3
"""Generates the iOS app icon set.

The asset catalog uses the single-size form, so three 1024x1024 PNGs are needed:
the default appearance plus the dark and tinted variants. Everything is drawn at
4x and downsampled, because PIL's polygon fill is not antialiased.

    python scripts/generate-app-icon.py

Writes into SFI/Assets.xcassets/AppIcon.appiconset/.
"""

import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO_ROOT, "SFI", "Assets.xcassets", "AppIcon.appiconset")

SIZE = 1024
SCALE = 4
CANVAS = SIZE * SCALE

# Nose, left wing tip, fold, tail.
PLANE_UPPER = [(0.86, 0.14), (0.13, 0.47), (0.44, 0.60)]
PLANE_LOWER = [(0.86, 0.14), (0.44, 0.60), (0.33, 0.88)]

# iOS masks the icon into a squircle, so anything near a corner is at risk of being
# clipped. The artwork is fitted into a centred box of this fraction of the canvas.
SAFE_BOX = 0.74


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def fit(polygons, box):
    xs = [x for polygon in polygons for x, _ in polygon]
    ys = [y for polygon in polygons for _, y in polygon]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    span = max(max_x - min_x, max_y - min_y)
    scale = box / span
    # Centre the bounding box on the canvas.
    offset_x = 0.5 - (min_x + max_x) / 2 * scale
    offset_y = 0.5 - (min_y + max_y) / 2 * scale
    return [
        [(x * scale + offset_x, y * scale + offset_y) for x, y in polygon]
        for polygon in polygons
    ]


def gradient(top, bottom):
    image = Image.new("RGB", (CANVAS, CANVAS))
    draw = ImageDraw.Draw(image)
    for y in range(CANVAS):
        draw.line([(0, y), (CANVAS, y)], fill=lerp(top, bottom, y / (CANVAS - 1)))
    return image


def points(polygon):
    return [(x * CANVAS, y * CANVAS) for x, y in polygon]


def render(top, bottom, upper, lower):
    plane_upper, plane_lower = fit([PLANE_UPPER, PLANE_LOWER], SAFE_BOX)
    image = gradient(top, bottom)
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon(points(plane_upper), fill=upper)
    draw.polygon(points(plane_lower), fill=lower)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    variants = {
        "1024.png": ((0x1B, 0x5C, 0xE6), (0x6A, 0x36, 0xF0), (255, 255, 255, 255), (255, 255, 255, 168)),
        "1024-dark.png": ((0x07, 0x10, 0x22), (0x2A, 0x14, 0x52), (255, 255, 255, 255), (255, 255, 255, 150)),
        "1024-tinted.png": ((0x1A, 0x1A, 0x1A), (0x3A, 0x3A, 0x3A), (255, 255, 255, 255), (255, 255, 255, 160)),
    }

    for name, (top, bottom, upper, lower) in variants.items():
        image = render(top, bottom, upper, lower)
        path = os.path.join(OUT_DIR, name)
        image.save(path, "PNG", optimize=True)
        print(f"wrote {path}  {image.size[0]}x{image.size[1]} {image.mode}")


if __name__ == "__main__":
    main()
