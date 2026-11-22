"""Erzeugt bgimg.js: heller Hintergrund mit Börsengebäude und Chartlinie (wie gewohnt)."""
import base64, io, os, math
from PIL import Image, ImageDraw, ImageFilter
D = os.path.dirname(os.path.abspath(__file__))
W, H = 1080, 1920
im = Image.new("RGB", (W, H), (244, 241, 243)); d = ImageDraw.Draw(im)
for y in range(H):
    k = y / H; d.line([(0, y), (W, y)], fill=(int(246 - 6 * k), int(243 - 8 * k), int(246 - 4 * k)))
L = Image.new("RGBA", (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(L)
c = (196, 190, 200, 255); c2 = (214, 209, 218, 255)
# Gebäude
bx0, bx1, by = 90, 990, 1500
g.polygon([(bx0 - 20, 640), (540, 430), (bx1 + 20, 640)], outline=c, width=10)
g.rectangle((bx0 - 20, 640, bx1 + 20, 700), outline=c, width=10)
for i in range(7):
    x = bx0 + 40 + i * 132
    g.rectangle((x, 720, x + 60, by - 60), outline=c2, width=9)
    g.rectangle((x - 14, 700, x + 74, 728), fill=c2)
for k in range(3):
    g.rectangle((bx0 - 40 - k * 25, by - 60 + k * 40, bx1 + 40 + k * 25, by - 20 + k * 40), outline=c, width=8)
# Chartlinie
pts = [(-20, 1180), (140, 1080), (260, 1140), (400, 930), (520, 990), (650, 780), (780, 860), (900, 620), (1100, 520)]
g.line(pts, fill=(205, 196, 210, 255), width=16, joint="curve")
L = L.filter(ImageFilter.GaussianBlur(1.2))
im = im.convert("RGBA"); im.alpha_composite(L)
im = im.convert("RGB").filter(ImageFilter.GaussianBlur(2))
buf = io.BytesIO(); im.save(buf, "JPEG", quality=88)
open(f"{D}/bgimg.js", "w").write("window.BGIMG='data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode() + "';")
im.resize((540, 960)).save(f"{D}/bg_preview.jpg")
