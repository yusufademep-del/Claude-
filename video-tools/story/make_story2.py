"""Börsenlehre-Story „Eisscholle“ (1080x1920): eigenes Pinguin-Konzept.
Vorteile auf schaukelnden Eisschollen, Link-Sticker kommt aufs Eisloch (= „Einstieg wagen“),
News-Laufband oben, Schneefall, Fische, Pinguin mit Comic-Sprechblase. Konfig: story.json
Nutzung: python3 make_story2.py [--still]"""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
D = os.path.dirname(os.path.abspath(__file__)); SP = os.path.dirname(D); ROOT = os.path.dirname(SP)
C = json.load(open(f"{D}/story.json"))
W, H = 1080, 1920; FPS = C["fps"]; DUR = C["dur"]; NF = int(DUR * FPS)
PK = f"{SP}/pkgs"
ANTON = f"{PK}/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
INTER = lambda w: f"{PK}/expo-google-fonts-inter-0.2.3/package/Inter_{w}.ttf"
NAVY = (14, 27, 56); YEL = (255, 210, 20); GREEN = (19, 198, 54); INK = (18, 26, 44)
_f = {}
def F(p, s):
    if (p, s) not in _f: _f[(p, s)] = ImageFont.truetype(p, s)
    return _f[(p, s)]
def clamp(x, a=0, b=1): return max(a, min(b, x))
def back(x, s=1.6): x = clamp(x); return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2
def emoji(code, s): return Image.open(f"{SP}/icons/{code}.png").convert("RGBA").resize((s, s), Image.LANCZOS)
_e = {}
def em(code, s):
    if (code, s) not in _e: _e[(code, s)] = emoji(code, s)
    return _e[(code, s)]
def paste_c(fr, im, cx, cy, sc=1.0, a=1.0, rot=0):
    if sc < .01 or a < .01: return
    if abs(sc - 1) > .005: im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.BILINEAR)
    if abs(rot) > .2: im = im.rotate(rot, Image.BICUBIC, expand=True)
    if a < .99: im = im.copy(); im.putalpha(im.split()[3].point(lambda v: int(v * a)))
    fr.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))

# ---- Hintergrund: eisiger Verlauf, Wasserlinie, Eisberge ----
bg = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(bg)
for y in range(H):
    k = y / H
    c = (int(232 - 40 * k), int(244 - 22 * k), int(252 - 8 * k)) if y < 1080 else (int(150 - 40 * (k - .56)), int(205 - 50 * (k - .56)), int(232 - 30 * (k - .56)))
    d.line([(0, y), (W, y)], fill=c + (255,))
berg = Image.new("RGBA", (W, H), (0, 0, 0, 0)); bd = ImageDraw.Draw(berg)
bd.polygon([(-40, 1080), (120, 820), (230, 900), (340, 760), (470, 1080)], fill=(250, 253, 255, 235))
bd.polygon([(620, 1080), (760, 870), (850, 930), (960, 800), (1120, 1080)], fill=(244, 250, 255, 235))
bd.polygon([(340, 760), (300, 1080), (470, 1080)], fill=(205, 228, 244, 200))
bd.polygon([(960, 800), (930, 1080), (1120, 1080)], fill=(205, 228, 244, 200))
bg.alpha_composite(berg.filter(ImageFilter.GaussianBlur(3)))
for i in range(14):  # Wellenlinien im Wasser
    y = 1120 + i * 60; ImageDraw.Draw(bg).arc((-200 + (i % 3) * 180, y, 1300 - (i % 2) * 140, y + 60), 200, 340, fill=(255, 255, 255, 70), width=3)

# ---- Eisscholle ----
def floe(code, title, sub, seed):
    rng = np.random.RandomState(seed); w, h = 440, 170
    pts = []
    for k in range(14):
        a = k / 14 * 2 * math.pi; r = 1 + rng.uniform(-.06, .08)
        pts.append((w / 2 + math.cos(a) * w / 2 * r * .96, h / 2 + math.sin(a) * h / 2 * r * .92))
    lay = Image.new("RGBA", (w + 60, h + 80), (0, 0, 0, 0)); ld = ImageDraw.Draw(lay)
    sh = Image.new("RGBA", lay.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).polygon([(x + 30, y + 52) for x, y in pts], fill=(20, 70, 120, 70)); lay.alpha_composite(sh.filter(ImageFilter.GaussianBlur(12)))
    ld.polygon([(x + 30, y + 44) for x, y in pts], fill=(150, 200, 232, 255))          # Unterseite (Dicke)
    ld.polygon([(x + 30, y + 30) for x, y in pts], fill=(255, 255, 255, 255), outline=(198, 226, 244, 255))
    ld.polygon([(x + 30 + 10, y + 30 + 6) for x, y in pts[:5]] + [(w / 2 + 30, h / 2 + 30)], fill=(238, 248, 255, 255))
    lay.alpha_composite(em(code, 70), (30 + 26, 30 + (h - 70) // 2))
    ft = F(INTER("800ExtraBold"), 36)
    while ft.getlength(title) > w - 140: ft = F(INTER("800ExtraBold"), ft.size - 2)
    ld.text((30 + 112, 30 + 46), title, font=ft, fill=INK)
    ld.text((30 + 112, 30 + 96), sub, font=F(INTER("600SemiBold"), 25), fill=(30, 120, 170))
    return lay
FLOES = [floe(c, a, b, i + 4) for i, (c, a, b) in enumerate(C["floes"])]

def key(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int16)
    dom = a[..., 1] - np.maximum(a[..., 0], a[..., 2]); al = np.clip(255 - (dom - 30) * 4, 0, 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([a.astype(np.uint8), al]), "RGBA"); return im.crop(im.getbbox())
PEN = {}
def pen(p, m, h):
    k = (p, m, h)
    if k not in PEN:
        im = key(f"{SP}/v4/m_{p}_{m}.png"); PEN[k] = im.resize((int(im.width * h / im.height), h), Image.LANCZOS)
    return PEN[k]

def frame(t, hint=True, static=False):
    fr = bg.copy(); d = ImageDraw.Draw(fr)
    # Schnee (hinter allem Inhalt)
    rng = np.random.RandomState(9)
    for i in range(40):
        x0, sp, sz = rng.uniform(0, W), rng.uniform(60, 140), rng.uniform(4, 10)
        y = (rng.uniform(0, H) + (0 if static else t * sp)) % H; x = x0 + math.sin(t * .8 + i) * 18
        d.ellipse((x - sz, y - sz, x + sz, y + sz), fill=(255, 255, 255, 220))
    # Laufband oben
    d.rectangle((0, 140, W, 196), fill=NAVY)
    ft = F(ANTON, 34); txt = (C["ticker"] * 6); off = 0 if static else (t * 160) % ft.getlength(C["ticker"])
    d.text((20 - off, 147), txt, font=ft, fill=YEL)
    d.rectangle((0, 140, 170, 196), fill=YEL); d.text((22, 147), "LIVE", font=ft, fill=NAVY)
    d.ellipse((120, 160, 140, 180), fill=(220, 38, 38) if (static or (t * 2) % 2 < 1.3) else NAVY)
    # Werbung-Hinweis
    fn = F(INTER("600SemiBold"), 24); nt = C["top_note"]; nw = fn.getlength(nt); d.text((W / 2 - nw / 2, 214), nt, font=fn, fill=INK)
    # Headline
    e = 1 if static else back(t / .6)
    hl = Image.new("RGBA", (W, 330), (0, 0, 0, 0)); hd = ImageDraw.Draw(hl)
    for i, (tx, sz) in enumerate([(C["headline1"], 110), (C["headline2"], 110)]):
        f = F(ANTON, sz); w_ = f.getlength(tx); hd.text((W / 2 - w_ / 2, 8 + i * 118 - f.getbbox(tx)[1]), tx, font=f, fill=INK)
    fb = F(INTER("900Black"), 64); bl = C["brand_line"]; bw = fb.getlength(bl)
    hd.rounded_rectangle((W / 2 - bw / 2 - 30, 250, W / 2 + bw / 2 + 30, 322), 36, fill=GREEN)
    hd.text((W / 2 - bw / 2, 286 - fb.size * .6), bl, font=fb, fill=(255, 255, 255))
    paste_c(fr, hl, W / 2, 268 + 165, max(.01, .88 + .12 * e), clamp(e * 2), (1 - clamp(e)) * -4)
    # Eisschollen (Zickzack)
    pos = [(285, 700), (795, 700), (285, 880), (795, 880), (285, 1060), (795, 1060)]
    for i, (im, (x, y)) in enumerate(zip(FLOES, pos)):
        k = 1 if static else back((t - .4 - i * .12) / .55)
        bob = 0 if static else math.sin(t * 1.8 + i * 1.1) * 7
        rot = 0 if static else math.sin(t * 1.3 + i) * 1.6
        paste_c(fr, im, x, y + bob + (1 - clamp(k)) * 60, max(.01, .85 + .15 * k), clamp(k * 2), rot)
    # Eisloch (Link-Fläche)
    hx, hy = W / 2, 1300
    ice = Image.new("RGBA", (760, 300), (0, 0, 0, 0)); idr = ImageDraw.Draw(ice)
    idr.ellipse((10, 30, 750, 290), fill=(255, 255, 255, 255), outline=(205, 228, 244, 255), width=4)
    idr.ellipse((90, 70, 670, 250), fill=(36, 110, 160, 255))
    idr.ellipse((110, 82, 650, 238), fill=(52, 140, 196, 255))
    for r in range(3):  # Wellenringe
        ph = ((0 if static else t * .6) + r / 3) % 1
        rx, ry = 120 + ph * 150, 40 + ph * 48
        idr.ellipse((380 - rx, 160 - ry, 380 + rx, 160 + ry), outline=(255, 255, 255, int(150 * (1 - ph))), width=3)
    fr.alpha_composite(ice, (int(hx - 380), int(hy - 160)))
    for j, code in enumerate(["1f41f", "1f420"]):  # Fische kreisen
        a = (0 if static else t * 1.1) + j * math.pi
        paste_c(fr, em(code, 70), hx + math.cos(a) * 200, hy + math.sin(a) * 52, 1, .9 if math.sin(a) > -.2 else .5)
    if hint:
        pulse = .5 + .5 * math.sin(t * 3.2)
        fh = F(INTER("800ExtraBold"), 36); ht = C["hole_text"]; hw = fh.getlength(ht)
        pill = Image.new("RGBA", (int(hw) + 80, 86), (0, 0, 0, 0)); pd = ImageDraw.Draw(pill)
        pd.rounded_rectangle((4, 4, pill.width - 4, 82), 40, fill=(255, 255, 255, int(200 + 40 * pulse)), outline=GREEN + (255,), width=4)
        pd.text((40, 43 - fh.size * .6), ht, font=fh, fill=(28, 120, 60))
        paste_c(fr, pill, hx, hy, 1 + .03 * pulse)
    # Pinguin rechts unten zeigt aufs Loch, Sprechblase links
    pose = "q" if (static or (t % 3.4) < 2.2) else "explain"
    talk = (not static) and math.sin(t * 9) > .2 and (t % 2.8) < 1.9
    p = pen(pose, "open" if talk else "closed", 470)
    hop = 0 if static else abs(math.sin(t * 2.4)) * 12
    shd = Image.new("RGBA", (420, 120), (0, 0, 0, 0)); ImageDraw.Draw(shd).ellipse((40, 30, 380, 90), fill=(20, 60, 100, 80))
    fr.alpha_composite(shd.filter(ImageFilter.GaussianBlur(16)), (int(800 - 210), 1800 - 60))
    fr.alpha_composite(p, (int(800 - p.width / 2), int(1800 - p.height - hop)))
    # Comic-Sprechblase
    fb2 = F(INTER("800ExtraBold"), 40); bt = C["bubble2"]; bw2 = fb2.getlength(bt)
    bb = Image.new("RGBA", (int(bw2) + 100, 170), (0, 0, 0, 0)); bdr = ImageDraw.Draw(bb)
    bdr.rounded_rectangle((10, 10, bb.width - 10, 110), 34, fill=(255, 255, 255, 255), outline=NAVY + (255,), width=5)
    bdr.polygon([(bb.width - 120, 106), (bb.width - 60, 106), (bb.width - 40, 160)], fill=(255, 255, 255, 255), outline=NAVY + (255,))
    bdr.line([(bb.width - 118, 108), (bb.width - 62, 108)], fill=(255, 255, 255, 255), width=8)
    bdr.text((50, 60 - fb2.size * .62), bt, font=fb2, fill=NAVY)
    k = 1 if static else back((t - 1.3) / .5)
    paste_c(fr, bb, 330, 1560 + (0 if static else math.sin(t * 2) * 5), max(.01, .8 + .2 * k), clamp(k * 2), 0 if static else math.sin(t * 1.5) * 2)
    # Risikohinweis
    fr2 = F(INTER("500Medium"), 21); words = C["risk"].split(); lines = [""]
    for w_ in words:
        if fr2.getlength(lines[-1] + " " + w_) > 960: lines.append(w_)
        else: lines[-1] = (lines[-1] + " " + w_).strip()
    for i, ln in enumerate(lines):
        lw = fr2.getlength(ln); d.text((W / 2 - lw / 2, 1846 + i * 26), ln, font=fr2, fill=(235, 245, 252))
    return fr.convert("RGB")

name = C["file2"]
frame(0, True, True).save(f"{ROOT}/{name}.png"); frame(0, False, True).save(f"{ROOT}/{name}_ohne_hinweis.png")
if "--still" in sys.argv: sys.exit()
ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", f"{ROOT}/{name}_60fps.mp4"], stdin=subprocess.PIPE)
for i in range(NF): ff.stdin.write(frame(i / FPS, C.get("link_hint", True)).tobytes())
ff.stdin.close(); ff.wait(); print("done", NF)
