#!/usr/bin/env python3
"""keys-film FRAMES_DIR OUT_DIR ID… : the boot animations as pictures in a row, six to a picture, on the places the OP-Z's lights have.
FRAMES_DIR/ID.bin is galaxz-frames' output (240 frames x 53 lights x R G B W). Drawn from Firmware/galaxy/layout.json; needs pillow."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

src, out, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(root, "Firmware/galaxy/layout.json")) as f:
    leds = {int(k): v for k, v in json.load(f)["leds"].items()}
xs, ys = [p[0] for p in leds.values()], [p[1] for p in leds.values()]
W, H, COLS, M = 420, 130, 2, 26
k = (W - 2 * M) / (max(xs) - min(xs))
top = (H - (max(ys) - min(ys)) * k) / 2
place = {i: (M + (x - min(xs)) * k, top + (y - min(ys)) * k) for i, (x, y) in leds.items()}
films = [open(os.path.join(src, i + ".bin"), "rb").read() for i in ids]
rows = (len(ids) + COLS - 1) // COLS
os.makedirs(out, exist_ok=True)
for n, frame in enumerate(range(0, 240, 4)):                       # 60 a second -> 15
    im = Image.new("RGB", (W * COLS * 2, H * rows * 2), (9, 10, 12))
    d = ImageDraw.Draw(im)
    for j, b in enumerate(films):
        ox, oy = j % COLS * W, j // COLS * H
        for i, (x, y) in place.items():
            r, g, bl, w = b[(frame * 53 + i) * 4:(frame * 53 + i) * 4 + 4]
            c = tuple(min(255, int(38 + 0.86 * v + 0.8 * w)) for v in (r, g, bl))
            s = 8 if i < 40 else 6
            X, Y = (ox + x) * 2, (oy + y) * 2
            d.rounded_rectangle((X - 2 * s, Y - 2 * s, X + 2 * s, Y + 2 * s), radius=2 * s if i >= 40 else 9, fill=c)
    glow = im.filter(ImageFilter.GaussianBlur(16))
    im = Image.blend(im, Image.composite(im, glow, im.convert("L").point(lambda v: 255 if v > 60 else 0)), 0.75)
    im.resize((W * COLS, H * rows), Image.LANCZOS).save(os.path.join(out, "keys-%03d.png" % n))
