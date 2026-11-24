"""Cover im Stil der Vorlage (TikTok-Raster 3:4): weißer Grund, Rubrik mit Farbbalken,
große Anton-Headline (gemischte Schreibweise, ein Wort/Zeile in Rubrikfarbe), Pastell-Feld mit Pinguin-Brustbild.
Konfig: compose4.json → "cover". Rubriken: BÖRSENNEWS (grün), SPEZIALAUSGABE (rot), ERKLÄRT (grau).
Wichtiger Inhalt liegt im 3:4-Ausschnitt (y 240–1680), weil TikTok das Profilraster so beschneidet."""
import json, os, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
D = os.path.dirname(os.path.abspath(__file__)); SP = os.path.dirname(D); ROOT = os.path.dirname(SP)
S = 2 if "--4k" in sys.argv else 1  # --4k: 2160x3840, Text nativ scharf gerendert
W, H = 1080 * S, 1920 * S
ANTON = f"{SP}/pkgs/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
CFG = json.load(open(f"{D}/compose4.json"))["cover"]
RUB = {"BÖRSENNEWS": ((46, 125, 50), (221, 238, 224)), "SPEZIALAUSGABE": ((211, 38, 38), (249, 223, 230)),
       "ERKLÄRT": ((95, 95, 100), (228, 227, 240))}
accent, pastel = RUB[CFG["rubrik"]]
COLS = {"black": (17, 17, 17), "accent": accent, "grey": (95, 95, 100)}
im = Image.new("RGB", (W, H), (255, 255, 255)); d = ImageDraw.Draw(im)
X0 = 44 * S; y = 268 * S
# Rubrik
fr = ImageFont.truetype(ANTON, 50 * S); d.rectangle((X0, y + 4 * S, X0 + 9 * S, y + 58 * S), fill=accent)
d.text((X0 + 28 * S, y + (8 * S) - fr.getbbox("Ä")[1]), CFG["rubrik"], font=fr, fill=(17, 17, 17))
y += 96 * S
# Headline
size = CFG.get("size", 190) * S
lines = CFG["lines"]
def fit(txt, s):
    f = ImageFont.truetype(ANTON, s)
    while f.getlength(txt) > W - 2 * X0 and s > 60: s -= 2; f = ImageFont.truetype(ANTON, s)
    return f
s_common = min(fit(t, size).size for t, _ in lines)
for txt, col in lines:
    f = ImageFont.truetype(ANTON, s_common); bb = f.getbbox(txt)
    d.text((X0 - bb[0], y - f.getbbox("Ag")[1]), txt, font=f, fill=COLS[col])
    y += int(s_common * 1.08)
# Pastell-Feld mit Brustbild
top = max(y + 30 * S, CFG.get("panel_top", 760) * S)
d.rectangle((24 * S, top, W - 24 * S, H), fill=pastel)
a = np.asarray(Image.open(f"{D}/m_{CFG.get('pose', 'q')}_{CFG.get('mouth', 'closed')}.png").convert("RGB")).astype(np.int16)
dom = a[..., 1] - np.maximum(a[..., 0], a[..., 2]); al = np.clip(255 - (dom - 30) * 4, 0, 255).astype(np.uint8)
pen = Image.fromarray(np.dstack([a.astype(np.uint8), al]), "RGBA"); pen = pen.crop(pen.getbbox())
k = CFG.get("pen_w", 980) * S / pen.width; pen = pen.resize((int(pen.width * k), int(pen.height * k)), Image.LANCZOS)
if S > 1:  # Hochskalierung nachschärfen (Comic-Konturen)
    rgb_ = pen.convert("RGB").filter(ImageFilter.UnsharpMask(radius=3 * S, percent=90, threshold=2)); pen = Image.merge("RGBA", (*rgb_.split(), pen.split()[3]))
lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); lay.alpha_composite(pen, ((W - pen.width) // 2 + CFG.get("pen_dx", 0) * S, top + 50 * S))
m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).rectangle((24 * S, top, W - 24 * S, H), fill=255)
lay.putalpha(Image.composite(lay.split()[3], Image.new("L", (W, H), 0), m))
im = im.convert("RGBA"); im.alpha_composite(lay); im = im.convert("RGB")
name = CFG["file"] + ("_4k" if S > 1 else "")
im.save(f"{ROOT}/{name}.png"); im.save(f"{ROOT}/{name}.jpg", quality=97, subsampling=0)
im.crop((0, 240 * S, W, 1680 * S)).resize((405, 540)).save(f"{D}/cover_grid_preview.jpg")
im.resize((405, 720)).save(f"{D}/cover_preview.jpg")
