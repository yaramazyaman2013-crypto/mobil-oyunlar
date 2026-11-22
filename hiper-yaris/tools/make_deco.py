"""Pist kenarı afiş ve tribün seyirci dokularını üretir (assets/deco/)."""
import os, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "deco")
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
rng = np.random.default_rng(5)

# Hayali sponsor afişleri (1024x128)
banners = [("HİPER YARIŞ", (230, 90, 20), (255, 255, 255)), ("NİTRO X", (20, 70, 180), (255, 220, 40)),
           ("KANYON 500", (25, 25, 30), (255, 140, 30)), ("TURBO GAZ", (200, 20, 30), (255, 255, 255)),
           ("ÇÖL KARTALI", (240, 200, 40), (30, 30, 30)), ("V12 LASTİK", (30, 30, 35), (90, 220, 255))]
for i, (txt, bg, fg) in enumerate(banners):
    im = Image.new("RGB", (1024, 128), bg)
    d = ImageDraw.Draw(im)
    size = 86
    f = ImageFont.truetype(FONT, size)
    while d.textlength(txt, font=f) > 440 and size > 30:
        size -= 2
        f = ImageFont.truetype(FONT, size)
    w = d.textlength(txt, font=f)
    for k in range(2):  # iki kez tekrar, her yarıda ortalı
        x = k * 512 + (512 - w) / 2
        d.text((x, 64 - size * 0.62), txt, font=f, fill=fg)
    d.rectangle([0, 0, 1023, 8], fill=fg); d.rectangle([0, 119, 1023, 127], fill=fg)
    im.save(os.path.join(OUT, "banner_%d.png" % i))
print("afişler tamam")

# Dama bayrağı / başlangıç şeridi
im = Image.new("RGB", (256, 64), (255, 255, 255)); d = ImageDraw.Draw(im)
for x in range(0, 256, 32):
    for y in range(0, 64, 32):
        if (x // 32 + y // 32) % 2 == 0: d.rectangle([x, y, x + 31, y + 31], fill=(15, 15, 15))
im.save(os.path.join(OUT, "checker.png"))

# Tribün seyircisi: sıra sıra renkli kişiler (512x512, tekrarlanabilir)
W = H = 512
im = Image.new("RGBA", (W, H), (60, 60, 66, 255)); d = ImageDraw.Draw(im)
rows = 8
palette = [(220, 40, 40), (40, 90, 220), (250, 200, 40), (240, 240, 240), (30, 160, 80), (250, 120, 30), (150, 60, 180), (30, 30, 30)]
skin = [(240, 200, 170), (200, 150, 110), (150, 100, 70), (90, 60, 40)]
for r in range(rows):
    y0 = r * (H // rows)
    d.rectangle([0, y0 + H // rows - 10, W, y0 + H // rows], fill=(90, 90, 96, 255))  # basamak
    x = rng.integers(0, 10)
    while x < W:
        cw = rng.integers(22, 30)
        col = tuple(int(c) for c in palette[rng.integers(0, len(palette))])
        sk = tuple(int(c) for c in skin[rng.integers(0, len(skin))])
        by = y0 + H // rows - 12
        d.rounded_rectangle([x, by - 30, x + cw - 6, by], radius=6, fill=col)       # gövde
        d.ellipse([x + 2, by - 46, x + cw - 8, by - 28], fill=sk)                  # baş
        if rng.random() < 0.3:                                                       # kaldırılmış kol / bayrak
            d.line([x + cw - 8, by - 26, x + cw - 2, by - 54], fill=sk, width=4)
            if rng.random() < 0.5:
                d.rectangle([x + cw - 2, by - 60, x + cw + 14, by - 50], fill=tuple(int(c) for c in palette[rng.integers(0, 6)]))
        x += cw + int(rng.integers(0, 6))
im = im.filter(ImageFilter.SMOOTH)
im.save(os.path.join(OUT, "crowd.png"))
print("seyirci tamam")
