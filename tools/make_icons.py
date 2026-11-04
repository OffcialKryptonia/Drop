#!/usr/bin/env python3
"""Generate Android + iOS launcher icons for the Drop apps from the two master images.

Usage: python3 tools/make_icons.py <rider_master.png> <driver_master.png>
Masters are 2000x2000 squares. Writes into apps/drop-rider and apps/drop-driver.
"""
import os, sys
from PIL import Image, ImageFilter, ImageChops

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "apps")
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPT = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
SAFE = 0.62  # artwork occupies this fraction of the adaptive canvas (safe zone is 66/108)


def fit(img, size):
    return img.resize((size, size), Image.LANCZOS)


def art_on_canvas(art_rgba, canvas):
    """Place artwork (RGBA, square) centred at SAFE scale on a transparent square canvas."""
    s = int(canvas * SAFE)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    a = fit(art_rgba, s)
    out.paste(a, ((canvas - s) // 2, (canvas - s) // 2), a)
    return out


def bilinear_background(src, size):
    """Smooth background from the four corner colours + centre-edge samples of the master."""
    px = src.convert("RGB")
    w, h = px.size
    m = 12
    def c(x, y): return px.getpixel((x, y))
    tl, tr, bl, br = c(m, m), c(w - m, m), c(m, h - m), c(w - m, h - m)
    g = Image.new("RGB", (2, 2))
    g.putpixel((0, 0), tl); g.putpixel((1, 0), tr); g.putpixel((0, 1), bl); g.putpixel((1, 1), br)
    return g.resize((size, size), Image.BILINEAR)


def white_mask(src):
    """Alpha mask of near-white pixels (the rider art is white on orange)."""
    rgb = src.convert("RGB")
    r, g, b = rgb.split()
    mn = ImageChops.darker(ImageChops.darker(r, g), b)  # min channel: high only for white
    return mn.point(lambda v: 0 if v < 170 else min(255, (v - 170) * 255 // 60))


def bright_mask(src):
    """Alpha mask of the bright artwork on the dark driver master."""
    lum = src.convert("L")
    return lum.point(lambda v: 0 if v < 45 else min(255, (v - 45) * 255 // 25))


def write(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def android(app, src, kind):
    res = os.path.join(ROOT, app, "android", "app", "src", "main", "res")
    if kind == "rider":
        mask = white_mask(src)
        art = Image.new("RGBA", src.size, (255, 255, 255, 0)); art.putalpha(mask)
        fg_art = art
        bg_full = bilinear_background(src, 1024)
        mono_mask = mask
    else:
        # art stays in colour on a flat dark background
        # The master background is one flat dark colour, so the full artwork can be the foreground
        # as it is (its square edge is invisible against the identical background layer).
        lum_mask = bright_mask(src)
        fg_art = src.convert("RGBA")
        bg_full = Image.new("RGB", (1024, 1024), src.convert("RGB").getpixel((12, 12)))
        mono_mask = lum_mask
    for dens, px in LEGACY.items():
        write(fit(src.convert("RGB"), px), f"{res}/mipmap-{dens}/ic_launcher.png")
    for dens, px in ADAPT.items():
        write(art_on_canvas(fg_art, px), f"{res}/mipmap-{dens}/ic_launcher_foreground.png")
        write(fit(bg_full, px), f"{res}/mipmap-{dens}/ic_launcher_background.png")
        mono = Image.new("RGBA", fg_art.size, (0, 0, 0, 255)); mono.putalpha(mono_mask)
        write(art_on_canvas(mono, px), f"{res}/mipmap-{dens}/ic_launcher_monochrome.png")
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '  <background android:drawable="@mipmap/ic_launcher_background"/>\n'
           '  <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '  <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
           '</adaptive-icon>\n')
    with open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w") as f:
        f.write(xml)


def ios(app, src):
    d = os.path.join(ROOT, app, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    flat = src.convert("RGB")  # App Store icons must have no alpha
    for name in os.listdir(d):
        if name.endswith(".png"):
            size = int(name[:-4])
            write(fit(flat, size), os.path.join(d, name))


if __name__ == "__main__":
    rider = Image.open(sys.argv[1]).convert("RGB")
    driver = Image.open(sys.argv[2]).convert("RGB")
    android("drop-rider", rider, "rider"); ios("drop-rider", rider)
    android("drop-driver", driver, "driver"); ios("drop-driver", driver)
    print("icons written")
