#!/usr/bin/env python3
"""Builds all launcher/store icon files from assets/icon/icon_source.png (RGB, rounded square on white corners).

Outputs:
  assets/icon/android/res/...      legacy + adaptive icon resources (copied into android/ by tool/patch_android.py)
  store/assets/icon_512.png        Google Play store icon (full-bleed square, Play applies its own mask)
Run from the project root:  python3 tool/make_android_icons.py   (needs Pillow, numpy, scipy)
"""
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

SRC = "assets/icon/icon_source.png"
RES = "assets/icon/android/res"

im = Image.open(SRC).convert("RGB")
a = np.asarray(im).astype(np.float32)
h, w, _ = a.shape

# 1) outside-of-rounded-square mask: near-white pixels connected to a corner
near_white = (a.min(axis=2) > 232)
lab, n = ndi.label(near_white)
outside = np.zeros_like(near_white)
for (y, x) in [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]:
    if lab[y, x]:
        outside |= (lab == lab[y, x])
outside = ndi.binary_dilation(outside, iterations=7)          # eat the anti-aliased white fringe

# 2) full-bleed square: fill the corners with the nearest real colour, then smooth only the filled area
idx = ndi.distance_transform_edt(outside, return_distances=False, return_indices=True)
filled = a[idx[0], idx[1]]
blur = np.asarray(Image.fromarray(filled.astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))).astype(np.float32)
m3 = ndi.gaussian_filter(outside.astype(np.float32), 3)[..., None]
filled = filled * (1 - m3) + blur * m3
square = Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))

# 3) rounded version with transparent corners (legacy icons, API < 26)
alpha = ndi.gaussian_filter((~outside).astype(np.float32), 1.6)
rounded = Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8)).convert("RGBA")
rounded.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)))

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)

# the rounded-square rim/vignette is baked into the source: crop it away so square outputs have no visible frame
INSET = 90
core = square.crop((INSET, INSET, w - INSET, h - INSET))
cw = core.size[0]

# store icon
sq = core.resize((512, 512), Image.LANCZOS).convert("RGBA")
save(sq, "store/assets/icon_512.png")

# legacy launcher icons
for dens, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(rounded.resize((px, px), Image.LANCZOS), f"{RES}/mipmap-{dens}/ic_launcher.png")

# adaptive icon (API 26+): 108dp canvas = 432px at xxxhdpi, visible area ~72dp, safe zone 66dp
C = 432
def corner(x0, y0):
    return np.asarray(core.crop((x0, y0, x0 + 30, y0 + 30))).reshape(-1, 3).mean(axis=0)
tl, tr, bl, br = corner(0, 0), corner(cw - 30, 0), corner(0, cw - 30), corner(cw - 30, cw - 30)
yy, xx = np.mgrid[0:C, 0:C].astype(np.float32) / (C - 1)
bg = ((1 - yy)[..., None] * ((1 - xx)[..., None] * tl + xx[..., None] * tr)
      + yy[..., None] * ((1 - xx)[..., None] * bl + xx[..., None] * br))
save(Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)), f"{RES}/drawable-xxxhdpi/ic_launcher_background.png")

FG = 216                                                       # artwork size inside the 432px layer (keeps it inside circular masks)
art = core.resize((FG, FG), Image.LANCZOS).convert("RGBA")
f = 10                                                         # feather the square edge into the background layer
ramp = np.minimum(np.minimum(np.arange(FG), np.arange(FG)[::-1]) / f, 1.0)
art.putalpha(Image.fromarray((np.outer(ramp, ramp) * 255).astype(np.uint8)))
fg = Image.new("RGBA", (C, C), (0, 0, 0, 0))
fg.alpha_composite(art, ((C - FG) // 2, (C - FG) // 2))
save(fg, f"{RES}/drawable-xxxhdpi/ic_launcher_foreground.png")

os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
open(f"{RES}/mipmap-anydpi-v26/ic_launcher.xml", "w", encoding="utf-8").write(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n')
# ---- Play feature graphic 1024x500 (needs a system font with Arabic glyphs, e.g. DejaVu Sans)
from PIL import ImageDraw, ImageFont
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
if os.path.exists(FB) and os.path.exists(FR):
    W, H = 1024, 500
    c1, c2 = tuple(int(v) for v in tl), tuple(int(v) for v in br)
    gy, gx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = ((gx / W) * 0.6 + (gy / H) * 0.4)[..., None]
    g = np.array(c1, np.float32) * (1 - t) + np.array(c2, np.float32) * t
    feat = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8)).convert("RGBA")
    icon = rounded.resize((320, 320), Image.LANCZOS)
    feat.alpha_composite(icon, (60, 90))
    d = ImageDraw.Draw(feat)
    def rtl(text, font, right, y, fill):
        bb = d.textbbox((0, 0), text, font=font, direction="rtl", language="ar")
        d.text((right - (bb[2] - bb[0]) - bb[0], y), text, font=font, fill=fill, direction="rtl", language="ar")
    rtl("اكتشف شخصيتك", ImageFont.truetype(FB, 64), 960, 155, (255, 255, 255, 255))
    rtl("اختبار شخصية · خطة تطوير", ImageFont.truetype(FR, 34), 960, 265, (255, 214, 120, 255))
    rtl("بياناتك تبقى على جهازك", ImageFont.truetype(FR, 29), 960, 322, (225, 235, 255, 255))
    save(feat.convert("RGB"), "store/assets/feature_1024x500.png")
print("icons generated")
