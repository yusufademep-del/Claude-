"""Instagram-Story (1080x1920) im Börsenlehre-v4-Stil: Vorteils-Kacheln + freie Mitte für den Link-Sticker.
Erzeugt PNG (Standbild) und MP4 (60 fps, Loop-freundlich). Konfig: story.json
Nutzung: python3 make_story.py            -> <file>.png, <file>_ohne_hinweis.png, <file>_60fps.mp4"""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
D = os.path.dirname(os.path.abspath(__file__)); SP = os.path.dirname(D); ROOT = os.path.dirname(SP)
C = json.load(open(f"{D}/story.json"))
W, H = 1080, 1920; FPS = C["fps"]; DUR = C["dur"]; NF = int(DUR * FPS)
PK = f"{SP}/pkgs"
ANTON = f"{PK}/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
INTER = lambda w: f"{PK}/expo-google-fonts-inter-0.2.3/package/Inter_{w}.ttf"
GREEN = (19, 198, 54); INK = (24, 24, 30); GREY = (110, 112, 124)
_f = {}
def F(p, s):
    if (p, s) not in _f: _f[(p, s)] = ImageFont.truetype(p, s)
    return _f[(p, s)]
def clamp(x, a=0, b=1): return max(a, min(b, x))
def back(x, s=1.6): x = clamp(x); return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2
def ease_io(x): x = clamp(x); return 4 * x ** 3 if x < .5 else 1 - (-2 * x + 2) ** 3 / 2
def emoji(code, s): return Image.open(f"{SP}/icons/{code}.png").convert("RGBA").resize((s, s), Image.LANCZOS)
def paste_c(fr, im, cx, cy, sc=1.0, a=1.0):
    if sc < .01 or a < .01: return
    if abs(sc - 1) > .005: im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.BILINEAR)
    if a < .99: im = im.copy(); im.putalpha(im.split()[3].point(lambda v: int(v * a)))
    fr.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))

# ---- Hintergrund: weichgezeichnete 3D-Stadt + heller Schleier ----
bg = Image.open(f"{D}/city.jpg").convert("RGB").resize((W, H)).filter(ImageFilter.GaussianBlur(14)).convert("RGBA")
veil = Image.new("RGBA", (W, H)); vd = ImageDraw.Draw(veil)
for y in range(H): k = y / H; vd.line([(0, y), (W, y)], fill=(250, 248, 253, int(150 + 60 * (1 - abs(k - .45) * 2))))
bg.alpha_composite(veil)

# ---- Pinguin-Sprites ----
def key(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int16)
    dom = a[..., 1] - np.maximum(a[..., 0], a[..., 2]); al = np.clip(255 - (dom - 30) * 4, 0, 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([a.astype(np.uint8), al]), "RGBA"); return im.crop(im.getbbox())
V4 = f"{SP}/v4"
PEN = {(p, m): key(f"{V4}/m_{p}_{m}.png") for p in ["base", "q", "explain", "shock"] for m in ["closed", "open"]}
def pen(p, m, h): im = PEN[(p, m)]; return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
_pc = {}
def penc(p, m, h):
    k = (p, m, h)
    if k not in _pc: _pc[k] = pen(p, m, h)
    return _pc[k]
shadow = Image.new("RGBA", (600, 160), (0, 0, 0, 0)); ImageDraw.Draw(shadow).ellipse((60, 40, 540, 120), fill=(40, 30, 70, 70)); shadow = shadow.filter(ImageFilter.GaussianBlur(22))

# ---- statische Teile ----
def card_img(code, title, sub, w=478, h=128):
    lay = Image.new("RGBA", (w + 60, h + 60), (0, 0, 0, 0))
    sh = Image.new("RGBA", lay.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle((30, 38, 30 + w, 30 + h + 6), 18, fill=(60, 160, 80, 45))
    lay.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(lay); d.rounded_rectangle((30, 30, 30 + w, 30 + h), 18, fill=(255, 255, 255, 236), outline=(232, 236, 240, 255), width=2)
    lay.alpha_composite(emoji(code, 64), (30 + 22, 30 + (h - 64) // 2))
    ft = F(INTER("800ExtraBold"), 30)
    while ft.getlength(title) > w - 130 and ft.size > 20: ft = F(INTER("800ExtraBold"), ft.size - 2)
    d.text((30 + 104, 30 + 30), title, font=ft, fill=INK)
    fs = F(INTER("500Medium"), 22)
    while fs.getlength(sub) > w - 124 and fs.size > 15: fs = F(INTER("500Medium"), fs.size - 1)
    d.text((30 + 104, 30 + 74), sub, font=fs, fill=(46, 140, 70))
    return lay
CARDS = [card_img(*c) for c in C["cards"]]

def text_c(d, txt, font, y, fill, x=W / 2):
    w = font.getlength(txt); bb = font.getbbox(txt); d.text((x - w / 2, y - bb[1]), txt, font=font, fill=fill)

def frame(t, hint=True, static=False):
    fr = bg.copy(); d = ImageDraw.Draw(fr)
    # Partikel
    rng = np.random.RandomState(3)
    for i in range(10):
        x0, y0, r = rng.uniform(0, W), rng.uniform(300, 1700), rng.uniform(20, 44)
        x = x0 + math.sin(t * .6 + i) * 30; y = y0 + math.cos(t * .5 + i * 1.7) * 24
        b = Image.new("RGBA", (int(r * 4), int(r * 4)), (0, 0, 0, 0)); ImageDraw.Draw(b).ellipse((r, r, r * 3, r * 3), fill=(120, 110, 210, 70))
        fr.alpha_composite(b.filter(ImageFilter.GaussianBlur(r * .5)), (int(x - r * 2), int(y - r * 2)))
    # Kopfzeile
    fn = F(INTER("600SemiBold"), 26); note = C["top_note"]
    head, _, rest = note.partition(" · ")
    tw = fn.getlength(head + " · ") + F(INTER("500Medium"), 26).getlength(rest)
    x = W / 2 - tw / 2; d.text((x, 168), head + " · ", font=fn, fill=INK); d.text((x + fn.getlength(head + " · "), 168), rest, font=F(INTER("500Medium"), 26), fill=INK)
    # Titel
    e = 1 if static else back(t / .6)
    tl = Image.new("RGBA", (W, 260), (0, 0, 0, 0)); td = ImageDraw.Draw(tl)
    text_c(td, C["title"], F(ANTON, 92), 20, INK)
    fb = F(INTER("900Black"), 104); bw = fb.getlength(C["brand"])
    td.text((W / 2 - bw / 2, 128 - fb.getbbox(C["brand"])[1]), C["brand"], font=fb, fill=GREEN)
    paste_c(fr, tl, W / 2, 220 + 130, max(.01, .85 + .15 * e), clamp(e * 2))
    # Kacheln 2x4
    for i, cim in enumerate(CARDS):
        col, row = i % 2, i // 2
        cx = W / 2 + (-1 if col == 0 else 1) * (cim.width - 60 + 20) / 2
        cy = 560 + row * 150
        k = 1 if static else back((t - .35 - i * .09) / .5)
        bob = 0 if static else math.sin(t * 2 + i) * 2
        paste_c(fr, cim, cx, cy + bob + (1 - clamp(k)) * 40, max(.01, .9 + .1 * k), clamp(k * 2))
    # Link-Zone (Mitte)
    ly = 1215
    if hint:
        pulse = .5 + .5 * math.sin(t * 3.2)
        z = Image.new("RGBA", (560, 150), (0, 0, 0, 0)); zd = ImageDraw.Draw(z)
        zd.rounded_rectangle((8, 8, 552, 142), 40, fill=(255, 255, 255, int(110 + 50 * pulse)))
        for xx in range(30, 530, 26): zd.line([(xx, 8), (xx + 12, 8)], fill=(19, 198, 54, 220), width=4); zd.line([(xx, 142), (xx + 12, 142)], fill=(19, 198, 54, 220), width=4)
        for yy in range(36, 120, 26): zd.line([(8, yy), (8, yy + 12)], fill=(19, 198, 54, 220), width=4); zd.line([(552, yy), (552, yy + 12)], fill=(19, 198, 54, 220), width=4)
        fh = F(INTER("700Bold"), 34); hw = fh.getlength(C["link_hint_text"])
        zd.text((280 - hw / 2, 75 - fh.size * .62), C["link_hint_text"], font=fh, fill=(40, 120, 60))
        paste_c(fr, z, W / 2, ly, 1 + .02 * pulse)
    # Pfeile/Sterne zur Mitte
    for sgn in (-1, 1):
        s = emoji("2728", 64); paste_c(fr, s, W / 2 + sgn * 330, ly - 70 + math.sin(t * 3 + sgn) * 10, .8 + .2 * math.sin(t * 4 + sgn))
    # Pinguine: links (zeigt zur Mitte), rechts, Mitte unten
    hop = lambda ph: 0 if static else abs(math.sin(t * 2.2 + ph)) * 10
    talk = (not static) and (math.sin(t * 9) > .2) and ((t % 2.6) < 1.8)
    side_h = 330
    lp = penc("q", "closed", side_h); fr.alpha_composite(shadow.resize((300, 80)), (int(140 - 150), int(1395 - 40)))
    fr.alpha_composite(lp, (int(140 - lp.width / 2), int(1395 - lp.height - hop(0))))
    rpose = "explain" if (static or (t % 4) < 2) else "base"
    rp = penc(rpose, "closed", side_h); fr.alpha_composite(shadow.resize((300, 80)), (int(940 - 150), int(1395 - 40)))
    fr.alpha_composite(rp, (int(940 - rp.width / 2), int(1395 - rp.height - hop(1.3))))
    cpose = "explain" if (static or (t % 3.2) < 2.0) else "q"
    cp = penc(cpose, "open" if talk else "closed", 520)
    fr.alpha_composite(shadow, (int(W / 2 - 300), int(1840 - 80)))
    fr.alpha_composite(cp, (int(W / 2 - cp.width / 2), int(1840 - cp.height - hop(2.1))))
    # Sprechblase
    fb2 = F(INTER("700Bold"), 32); bt = C["bubble"]; bw = fb2.getlength(bt)
    bb = Image.new("RGBA", (int(bw) + 110, 120), (0, 0, 0, 0)); bd = ImageDraw.Draw(bb)
    sh2 = Image.new("RGBA", bb.size, (0, 0, 0, 0)); ImageDraw.Draw(sh2).rounded_rectangle((25, 30, bb.width - 25, 100), 22, fill=(40, 30, 70, 60)); bb.alpha_composite(sh2.filter(ImageFilter.GaussianBlur(10)))
    bd.rounded_rectangle((25, 22, bb.width - 25, 92), 22, fill=(255, 255, 255, 245), outline=(225, 228, 236, 255), width=2)
    bd.text((55, 57 - fb2.size * .62), bt, font=fb2, fill=INK)
    k = 1 if static else back((t - 1.2) / .5)
    paste_c(fr, bb, W / 2, 1600 + math.sin(t * 2.4) * 4, max(.01, .85 + .15 * k), clamp(k * 2))
    # Risikohinweis ganz unten (klein)
    fr2 = F(INTER("400Regular"), 21); rt = C["risk"]; words = rt.split(); lines = [""]
    for w_ in words:
        if fr2.getlength(lines[-1] + " " + w_) > 940: lines.append(w_)
        else: lines[-1] = (lines[-1] + " " + w_).strip()
    for i, ln in enumerate(lines): text_c(d, ln, fr2, 1862 + i * 26, (90, 92, 104))
    return fr.convert("RGB")

name = C["file"]
frame(0, True, True).save(f"{ROOT}/{name}.png"); frame(0, False, True).save(f"{ROOT}/{name}_ohne_hinweis.png")
if "--still" in sys.argv: sys.exit()
ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", f"{ROOT}/{name}_60fps.mp4"], stdin=subprocess.PIPE)
for i in range(NF): ff.stdin.write(frame(i / FPS, C.get("link_hint", True)).tobytes())
ff.stdin.close(); ff.wait(); print("done", NF)
