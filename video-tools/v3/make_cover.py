"""Cover: Dividenden-ETFs über 10 % (1080x1920, JPG + PNG)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
D = os.path.dirname(os.path.abspath(__file__)); SP = os.path.dirname(D); ROOT = os.path.dirname(SP)
W, H = 1080, 1920
ANTON = f"{SP}/pkgs/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
MONT = f"{SP}/pkgs/expo-google-fonts-montserrat-0.2.3/package/Montserrat_900Black.ttf"
bg = Image.open(f"{D}/test_13.jpg").convert("RGBA")
# 3D-Kachel etwas nach unten/größer
top = bg.getpixel((W // 2, 5))
bg = bg.resize((int(W * 1.1), int(H * 1.1)), Image.LANCZOS)
fr = Image.new("RGBA", (W, H), top); fr.alpha_composite(bg, (-54, 70))
d = ImageDraw.Draw(fr)
def ctext(txt, path, size, y, fill, stroke=0, sfill=(255, 255, 255), maxw=1000):
    f = ImageFont.truetype(path, size)
    while f.getbbox(txt, stroke_width=stroke)[2] > maxw: size -= 4; f = ImageFont.truetype(path, size)
    bb = f.getbbox(txt, stroke_width=stroke)
    d.text(((W - (bb[2] - bb[0])) / 2 - bb[0], y - bb[1]), txt, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill)
    return y + bb[3] - bb[1]
# Badge
f = ImageFont.truetype(MONT, 36); t = "BÖRSENLEHRE · 22.11."; bb = f.getbbox(t)
d.rounded_rectangle((40, 50, 40 + bb[2] + 56, 50 + bb[3] + 34), 18, fill=(255, 214, 10)); d.text((68, 67 - bb[1] + 0), t, font=f, fill=(14, 27, 56))
y = ctext("DIVIDENDEN-ETFS", ANTON, 190, 150, (17, 19, 26), 8)
y = ctext("ÜBER 10 %?!", ANTON, 200, y + 30, (220, 38, 38), 8)
# blaue Pill
f = ImageFont.truetype(MONT, 54); t = "3 ETFS + DER HAKEN"; bb = f.getbbox(t)
pw, ph = bb[2] - bb[0] + 90, bb[3] - bb[1] + 56; px = (W - pw) // 2; py = y + 40
d.rounded_rectangle((px, py, px + pw, py + ph), 26, fill=(37, 99, 235), outline=(255, 255, 255), width=6)
d.text((px + 45 - bb[0], py + 28 - bb[1]), t, font=f, fill=(255, 255, 255))
# Emojis
for code, x, yy, s, rot in [("1f4b0", 70, 920, 190, 12), ("1f4b8", 830, 900, 190, -12), ("1f914", 860, 1240, 150, 0)]:
    e = Image.open(f"{SP}/icons/{code}.png").convert("RGBA").resize((s, s), Image.LANCZOS).rotate(rot, Image.BICUBIC, expand=True)
    fr.alpha_composite(e, (x, yy))
# Pinguin Close-up
sys.path.insert(0, D)
sp = Image.open(f"{D}/m_q_open.png").convert("RGB")
import numpy as np
a = np.asarray(sp).astype(np.int16); r, g, b = a[..., 0], a[..., 1], a[..., 2]
dom = g - np.maximum(r, b); al = np.clip(255 - (dom - 30) * 4, 0, 255).astype(np.uint8)
pen = Image.fromarray(np.dstack([np.asarray(sp), al]), "RGBA"); pen = pen.crop(pen.getbbox())
k = 1180 / pen.width; pen = pen.resize((int(pen.width * k), int(pen.height * k)), Image.LANCZOS)
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0)); ImageDraw.Draw(sh).ellipse((140, 1830, 940, 1990), fill=(0, 0, 0, 90)); sh = sh.filter(ImageFilter.GaussianBlur(30))
fr.alpha_composite(sh)
fr.alpha_composite(pen, ((W - pen.width) // 2 + 20, 1170))
out = fr.convert("RGB")
out.save(f"{ROOT}/cover_dividenden_etfs_10prozent.png"); out.save(f"{ROOT}/cover_dividenden_etfs_10prozent.jpg", quality=93)
out.resize((405, 720)).save(f"{D}/cover_preview.jpg")
