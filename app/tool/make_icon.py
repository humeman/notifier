#!/usr/bin/env python3
"""Generates the launcher icon source images.

Draws a bell with an alert dot, in the app's accent blue on the app's
background black — the same palette as the UI, so the icon reads as part of
the app rather than bolted on. On Android 17 this icon is also what the
notification shade shows beside every alert, so it's kept bold and simple.

Outputs (regenerate with `task app:icon`):
  assets/icon/icon.png             1024x1024, full-bleed. Legacy launcher icon.
  assets/icon/icon_foreground.png  1024x1024, transparent, artwork inset to the
                                   adaptive-icon safe zone so Android's mask
                                   can't clip it.

`flutter_launcher_icons` turns these into the mipmap densities.
"""

from PIL import Image, ImageDraw

SIZE = 1024
# Supersampled, then downscaled — Pillow has no antialiased shape drawing.
SCALE = 4
CANVAS = SIZE * SCALE

BACKGROUND = (10, 10, 11, 255)   # Palette.background
ACCENT = (124, 200, 255, 255)    # Palette.accent
CLEAR = (0, 0, 0, 0)


def draw_artwork(layer, box):
    """Draws the bell and its alert dot into a square `box` px wide."""
    draw = ImageDraw.Draw(layer)

    def r(x0, y0, x1, y1):
        return [x0 * box, y0 * box, x1 * box, y1 * box]

    # Dome: an ellipse whose lower half is covered by the body below.
    draw.ellipse(r(0.24, 0.14, 0.76, 0.66), fill=ACCENT)
    # Body, flaring out toward the rim.
    draw.polygon(
        [(0.24 * box, 0.40 * box), (0.76 * box, 0.40 * box),
         (0.84 * box, 0.72 * box), (0.16 * box, 0.72 * box)],
        fill=ACCENT,
    )
    # Rim.
    draw.rounded_rectangle(r(0.10, 0.68, 0.90, 0.78), radius=0.05 * box, fill=ACCENT)
    # Clapper.
    draw.ellipse(r(0.43, 0.79, 0.57, 0.93), fill=ACCENT)
    # Crown knob.
    draw.ellipse(r(0.45, 0.08, 0.55, 0.18), fill=ACCENT)

    # Alert dot, top right, punched out of the bell with a clear ring so it
    # reads as a separate mark at launcher sizes.
    draw.ellipse(r(0.62, 0.02, 0.98, 0.38), fill=CLEAR)
    draw.ellipse(r(0.67, 0.07, 0.93, 0.33), fill=ACCENT)


def build(path, background, inset):
    """Renders one icon; `inset` is the fraction of each edge left empty.

    The artwork is drawn oversized, cropped to its own alpha bounding box, then
    centred, so its nominal coordinates don't have to be perfectly balanced.
    """
    layer = Image.new("RGBA", (CANVAS, CANVAS), CLEAR)
    draw_artwork(layer, CANVAS)
    art = layer.crop(layer.getbbox())

    target = CANVAS * (1 - 2 * inset)
    ratio = target / max(art.width, art.height)
    art = art.resize(
        (max(1, round(art.width * ratio)), max(1, round(art.height * ratio))),
        Image.LANCZOS,
    )

    image = Image.new("RGBA", (CANVAS, CANVAS), background)
    image.alpha_composite(
        art,
        ((CANVAS - art.width) // 2, (CANVAS - art.height) // 2),
    )
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    image.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    import os

    os.makedirs("assets/icon", exist_ok=True)
    build("assets/icon/icon.png", BACKGROUND, inset=0.22)
    # Adaptive foreground: flutter_launcher_icons adds a 16% inset and Android
    # masks to the middle 66%, so this stays light to avoid a tiny glyph.
    build("assets/icon/icon_foreground.png", CLEAR, inset=0.22)
