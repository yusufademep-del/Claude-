"""Cover im Stil der Vorlage (TikTok-Raster 3:4): weißer Grund, Rubrik mit Farbbalken,
große Anton-Headline (gemischte Schreibweise, ein Wort/Zeile in Rubrikfarbe), Pastell-Feld mit Pinguin-Brustbild.
Konfig: compose4.json → "cover". Rubriken: BÖRSENNEWS (grün), SPEZIALAUSGABE (rot), ERKLÄRT (grau).
Wichtiger Inhalt liegt im 3:4-Ausschnitt (y 240–1680), weil TikTok das Profilraster so beschneidet."""
import json, os, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
D = os.path.dirname(os.path.abspath(__file__)); SP = os.path.dirname(D); ROOT = os.path.dirname(SP)
W, H = 1080, 1920
ANTON = f"{SP}/pkgs/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
CFG = json.load(open(f"{D}/compose4.json"))["cover"]
RUB = {"BÖRSENNEWS": ((46, 125, 50), (221, 238, 224)), "SPEZIALAUSGABE": ((211, 38, 38), (249, 223, 230)),
       "ERKLÄRT": ((95, 95, 100), (228, 227, 240))}
accent, pastel = RUB[CFG["rubrik"]]
COLS = {"black": (17, 17, 17), "accent": accent, "grey": (95, 95, 100)}
im = Image.new("RGB", (W, H), (255, 255, 255)); d = ImageDraw.Draw(im)
X0 = 44; y = 268
# Rubrik
fr = ImageFont.truetype(ANTON, 50); d.rectangle((X0, y + 4, X0 + 9, y + 58), fill=accent)
d.text((X0 + 28, y + 2 - fr.getbbox("Ä")[1] + 6), CFG["rubrik"], font=fr, fill=(17, 17, 17))
y += 96
# Headline
size = CFG.get("size", 190)
lines = CFG["lines"]
def fit(txt, s):
    f = ImageFont.truetype(ANTON, s)
    while f.getlength(txt) > W - 2 * X0 and s > 60: s -= 4; f = ImageFont.truetype(ANTON, s)
    return f
s_common = min(fit(t, size).size for t, _ in lines)
for txt, col in lines:
    f = ImageFont.truetype(ANTON, s_common); bb = f.getbbox(txt)
    d.text((X0 - bb[0], y - f.getbbox("Ag")[1]), txt, font=f, fill=COLS[col])
    y += int(s_common * 1.08)
# Pastell-Feld mit Brustbild
top = max(y + 30, CFG.get("panel_top", 760))
d.rectangle((24, top, W - 24, H), fill=pastel)
a = np.asarray(Image.open(f"{D}/m_{CFG.get('pose', 'q')}_{CFG.get('mouth', 'closed')}.png").convert("RGB")).astype(np.int16)
dom = a[..., 1] - np.maximum(a[..., 0], a[..., 2]); al = np.clip(255 - (dom - 30) * 4, 0, 255).astype(np.uint8)
pen = Image.fromarray(np.dstack([a.astype(np.uint8), al]), "RGBA"); pen = pen.crop(pen.getbbox())
k = CFG.get("pen_w", 980) / pen.width; pen = pen.resize((int(pen.width * k), int(pen.height * k)), Image.LANCZOS)
lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); lay.alpha_composite(pen, ((W - pen.width) // 2 + CFG.get("pen_dx", 0), top + 50))
m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).rectangle((24, top, W - 24, H), fill=255)
lay.putalpha(Image.composite(lay.split()[3], Image.new("L", (W, H), 0), m))
im = im.convert("RGBA"); im.alpha_composite(lay); im = im.convert("RGB")
name = CFG["file"]
im.save(f"{ROOT}/{name}.png"); im.save(f"{ROOT}/{name}.jpg", quality=93)
im.crop((0, 240, W, 1680)).resize((405, 540)).save(f"{D}/cover_grid_preview.jpg")
im.resize((405, 720)).save(f"{D}/cover_preview.jpg")
