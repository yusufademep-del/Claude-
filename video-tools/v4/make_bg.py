"""bgimg.js für v4: sehr heller, lavendel-weißer Hintergrund mit dezentem Börsengebäude und Straße."""
import base64, io, os
from PIL import Image, ImageDraw, ImageFilter
D = os.path.dirname(os.path.abspath(__file__)); W, H = 1080, 1920
im = Image.new("RGB", (W, H)); d = ImageDraw.Draw(im)
for y in range(H):
    k = y / H; d.line([(0, y), (W, y)], fill=(int(247 - 4 * k), int(245 - 6 * k), int(251 - 3 * k)))
L = Image.new("RGBA", (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(L)
c = (224, 219, 235, 255); c2 = (233, 229, 241, 255)
# Seitliche Gebäude (Straßenflucht)
for x0, w, top in [(-40, 230, 380), (930, 220, 420)]:
    g.rectangle((x0, top, x0 + w, 1560), outline=c, width=8)
    for r in range(10):
        for col in range(3):
            g.rectangle((x0 + 24 + col * 66, top + 40 + r * 108, x0 + 64 + col * 66, top + 110 + r * 108), outline=c2, width=5)
# Börsengebäude Mitte
g.polygon([(220, 700), (540, 540), (860, 700)], outline=c, width=9)
g.rectangle((220, 700, 860, 750), outline=c, width=9)
for i in range(6):
    x = 255 + i * 105; g.rectangle((x, 770, x + 46, 1480), outline=c2, width=8)
for k in range(3):
    g.rectangle((200 - k * 20, 1480 + k * 34, 880 + k * 20, 1514 + k * 34), outline=c, width=7)
# Straße / Boden
g.line([(0, 1590), (W, 1590)], fill=c, width=6)
for x in range(-200, W + 200, 180):
    g.line([(540, 1590), (x * 2 - 540, H)], fill=(232, 228, 240, 255), width=3)
L = L.filter(ImageFilter.GaussianBlur(1.0)); im = im.convert("RGBA"); im.alpha_composite(L)
im = im.convert("RGB").filter(ImageFilter.GaussianBlur(2.2))
buf = io.BytesIO(); im.save(buf, "JPEG", quality=88)
open(f"{D}/bgimg.js", "w").write("window.BGIMG='data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode() + "';")
