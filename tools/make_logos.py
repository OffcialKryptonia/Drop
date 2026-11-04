#!/usr/bin/env python3
"""In-app logo images for the Drop apps, from the same two master icons.

Usage: python3 tools/make_logos.py <rider_master.png> <driver_master.png>
 - images/app_images/ic_app_logo.png: the app icon (shown in a rounded square on sign-in/about)
 - ic_logo_white.png / ic_driver_white.png: white "D" mark on transparent (splash on brand colour)
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from make_icons import white_mask, ROOT

def white_mark(rider):
    mask = white_mask(rider)
    w, h = mask.size
    d = mask.crop((0, 0, w, int(h * 0.59)))        # the "D" above the wordmark (gap is rows 1139-1222 of 2000)
    d = d.crop(d.getbbox())
    side = max(d.size)
    canvas = Image.new("L", (side, side), 0)
    canvas.paste(d, ((side - d.width) // 2, (side - d.height) // 2))
    out = Image.new("RGBA", canvas.size, (255, 255, 255, 0)); out.putalpha(canvas)
    pad = int(side * 0.1)
    framed = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (255, 255, 255, 0))
    framed.paste(out, (pad, pad), out)
    return framed.resize((500, 500), Image.LANCZOS)

if __name__ == "__main__":
    rider = Image.open(sys.argv[1]).convert("RGB"); driver = Image.open(sys.argv[2]).convert("RGB")
    mark = white_mark(rider)
    r = os.path.join(ROOT, "drop-rider", "images", "app_images"); d = os.path.join(ROOT, "drop-driver", "images", "app_images")
    rider.resize((1024, 1024), Image.LANCZOS).save(f"{r}/ic_app_logo.png", optimize=True)
    mark.save(f"{r}/ic_logo_white.png", optimize=True)
    driver.resize((1024, 1024), Image.LANCZOS).save(f"{d}/ic_app_logo.png", optimize=True)
    mark.save(f"{d}/ic_driver_white.png", optimize=True)
    print("logos written")
