"""Börsenlehre v4 compositor – Stil nach der „finanzlehre“-Vorlage (Screen-Recording 22.11.):
cremefarbene Kopfleiste (Avatar · Kanal · THEMA Datum), große dunkle Anton-Headlines (1–2 Zeilen, Pop-in),
großer Charakter mit weichen Kamerafahrten (Ganzkörper ↔ Close-up), gelbes Einzelwort über dem Kopf
(+ Betonungsstriche), weiße Milchglas-Karten (Inter) mit hochzählendem Wert und durchgestrichenem Altwert,
große grüne/rote Prozentzahl mit grauer Unterzeile, Sticker-Emojis. Keine Fortschrittsleiste, kein Weißblitz.
Nutzung: python3 compose4.py out.mp4 | python3 compose4.py test <t...>"""
import json, math, os, subprocess, sys, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

D = os.path.dirname(os.path.abspath(__file__))
SP = os.path.dirname(D)
W, H = 1080, 1920
CFG = json.load(open(f"{D}/compose4.json"))
FPS, DUR = CFG["fps"], CFG["dur"]
NF = int(round(DUR * FPS))
PK = f"{SP}/pkgs"
ANTON = f"{PK}/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
MONT = f"{PK}/expo-google-fonts-montserrat-0.2.3/package/Montserrat_900Black.ttf"
MONT8 = f"{PK}/expo-google-fonts-montserrat-0.2.3/package/Montserrat_800ExtraBold.ttf"
INTER = {w: f"{PK}/expo-google-fonts-inter-0.2.3/package/Inter_{w}.ttf" for w in ["400Regular", "500Medium", "600SemiBold", "700Bold", "800ExtraBold"]}
COL = {"red": (214, 40, 40), "green": (22, 150, 70), "blue": (37, 99, 235), "yellow": (255, 210, 20), "black": (28, 28, 32),
       "grey": (120, 122, 132), "lgrey": (160, 162, 172), "white": (255, 255, 255), "dark": (36, 36, 40)}

words = [w for w in json.load(open(f"{D}/words.json"))["words"] if w["type"] == "word" and w["text"] not in "–-"]

def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease_out(x): return 1 - (1 - x) ** 3
def ease_io(x): return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2
def back(x, s=1.7): x = clamp(x); return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2
def spring(x):
    if x <= 0: return 0.0
    return 1 - math.exp(-6 * x) * math.cos(11 * x)

# ---------------- Charakter ----------------
def key_green(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dom = g - np.maximum(r, b)
    al = np.clip(255 - (dom - 30) * 4, 0, 255).astype(np.uint8)
    g2 = np.where(dom > 0, np.maximum(r, b), g)
    im = Image.fromarray(np.dstack([r, g2, b, al]).astype(np.uint8), "RGBA")
    im.putalpha(im.split()[3].filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8)))
    return im
MOUTHS = ["closed", "mid", "open"]
POSE_NAMES = ["base", "q", "shock", "explain"]
raw = {(n, m): key_green(f"{D}/m_{n}_{m}.png") for n in POSE_NAMES for m in MOUTHS}
bx = None
for im in raw.values():
    bb = im.getbbox(); bx = bb if bx is None else (min(bx[0], bb[0]), min(bx[1], bb[1]), max(bx[2], bb[2]), max(bx[3], bb[3]))
BASE_H = 1500
k = BASE_H / (bx[3] - bx[1])
SPR = {kk: im.crop(bx).resize((int((bx[2] - bx[0]) * k), BASE_H), Image.LANCZOS) for kk, im in raw.items()}
SPW = next(iter(SPR.values())).width
_sc = {}
def spr_scaled(key, h):
    h = int(round(h / 4) * 4)  # Cache in 4px-Schritten
    kk = (key, h)
    if kk not in _sc:
        if len(_sc) > 400: _sc.clear()
        s = h / BASE_H; _sc[kk] = SPR[key].resize((max(1, int(SPW * s)), h), Image.BILINEAR)
    return _sc[kk]


_bk = {}
def spr_bucket(key, h):
    hb = int(math.ceil(h / 64.0) * 64)
    kk = (key, hb)
    if kk not in _bk:
        if len(_bk) > 120: _bk.clear()
        _bk[kk] = SPR[key].resize((max(1, int(SPW * hb / BASE_H)), hb), Image.LANCZOS)
    return _bk[kk]
def place_sprite(frame, key, h, fx, fy, ang_deg, key2=None, mix=0.0):
    """Zeichnet den Pinguin subpixel-genau: exakte Höhe h, Fußpunkt (fx, fy), Drehung um den Fuß – ohne Rundungs-Ruckeln."""
    src = spr_bucket(key, h); wc, hc = src.size; k = h / hc
    bw, bh = int(wc * k * 1.12) + 8, int(hc * k * 1.04) + 8
    ox, oy = int(math.floor(fx - bw / 2)), int(math.floor(fy - bh + 4))
    a = math.radians(ang_deg); ca, sa = math.cos(a), math.sin(a)
    # Ausgabe (X,Y) -> Welt -> relativ zum Fuß -> zurückdrehen -> zurückskalieren -> Quellkoordinaten
    c0x, c0y = ox - fx, oy - fy
    A = ca / k; B = sa / k; C = (ca * c0x + sa * c0y) / k + wc / 2
    D = -sa / k; E = ca / k; F = (-sa * c0x + ca * c0y) / k + hc
    def tf(im): return im.transform((bw, bh), Image.AFFINE, (A, B, C, D, E, F), resample=Image.BILINEAR)
    out = tf(src)
    if key2 is not None and mix > 0:
        src2 = spr_bucket(key2, h)
        if src2.size == src.size: out = Image.blend(tf(src2), out, 1 - mix) if mix < 1 else tf(src2)
    frame.alpha_composite(out, (ox, oy))

pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", f"{D}/voice.wav", "-ac", "1", "-ar", "48000", "-f", "f32le", "-"], capture_output=True).stdout
A = np.frombuffer(pcm, dtype=np.float32)
hop = 48000 // FPS
env = np.array([np.sqrt(np.mean(A[i * hop:(i + 2) * hop] ** 2)) if i * hop < len(A) else 0 for i in range(NF)])
env = env / (np.percentile(env[env > 0], 92) + 1e-9)
env = np.convolve(env, np.ones(5) / 5, mode="same")
mouth, cur, hold = [], 0, 0
for i in range(NF):
    t = i / FPS
    inw = any(w["start"] - 0.03 <= t <= w["end"] + 0.03 for w in words)
    want = 0 if (not inw or env[i] < 0.2) else (1 if env[i] < 0.55 else 2)
    if want != cur and hold <= 0: cur, hold = want, int(FPS * 0.066)
    hold -= 1; mouth.append(MOUTHS[cur])

POSES = CFG["poses"]
SHOT = {"full": (560, 1690), "mid": (900, 2120), "close": (1350, 2620)}
SHOTS = [(s[0], *(SHOT[s[1]] if isinstance(s[1], str) else (s[1], s[2]))) for s in CFG["shots"]]
def shot_at(t):
    idx = max(i for i, s in enumerate(SHOTS) if t >= s[0] or i == 0)
    cur_ = SHOTS[idx]
    if idx == 0: return cur_[1], cur_[2]
    p0 = SHOTS[idx - 1]; u = ease_io(clamp((t - cur_[0]) / CFG.get("shot_dur", 0.55)))
    return p0[1] + (cur_[1] - p0[1]) * u, p0[2] + (cur_[2] - p0[2]) * u

glow = Image.new("RGBA", (1000, 240), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((170, 80, 830, 180), fill=(40, 30, 70, 70)); glow = glow.filter(ImageFilter.GaussianBlur(30))

# ---------------- Text-Helfer ----------------
_fc = {}
def font(p, s):
    if (p, s) not in _fc: _fc[(p, s)] = ImageFont.truetype(p, s)
    return _fc[(p, s)]
_tc = {}
def text_img(txt, path, size, fill, stroke=0, sfill=(255, 255, 255), track=0):
    key = (txt, path, size, fill, stroke, sfill, track)
    if key in _tc: return _tc[key]
    f = font(path, size)
    if track:
        ws = [f.getbbox(ch, stroke_width=stroke) for ch in txt]
        adv = [f.getlength(ch) + track for ch in txt]
        tw = int(sum(adv) + stroke * 2 + 20); bb = f.getbbox(txt, stroke_width=stroke)
        im = Image.new("RGBA", (tw, bb[3] - bb[1] + 20), (0, 0, 0, 0)); d = ImageDraw.Draw(im); x = 10
        for ch, a in zip(txt, adv):
            d.text((x, 10 - bb[1]), ch, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill); x += a
    else:
        bb = f.getbbox(txt, stroke_width=stroke)
        im = Image.new("RGBA", (bb[2] - bb[0] + 20, bb[3] - bb[1] + 20), (0, 0, 0, 0))
        ImageDraw.Draw(im).text((10 - bb[0], 10 - bb[1]), txt, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill)
    _tc[key] = im; return im
def paste_c(frame, im, cx, cy, sc=1.0, alpha=1.0, rot=0.0):
    if sc <= 0.01 or alpha <= 0.01: return
    if abs(sc - 1) > 0.005: im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.BILINEAR)
    if abs(rot) > 0.2: im = im.rotate(rot, Image.BICUBIC, expand=True)
    if alpha < 0.99:
        im = im.copy(); im.putalpha(im.split()[3].point(lambda v: int(v * alpha)))
    frame.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))
_ec = {}
def emoji(code, size):
    if (code, size) not in _ec: _ec[(code, size)] = Image.open(f"{SP}/icons/{code}.png").convert("RGBA").resize((size, size), Image.LANCZOS)
    return _ec[(code, size)]
def fmt_num(v, dec):
    s = f"{abs(v):,.{dec}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return s

# ---------------- Kopfleiste ----------------
def make_topbar():
    bar = Image.new("RGBA", (W, 150), (0, 0, 0, 0)); d = ImageDraw.Draw(bar)
    for y in range(150):
        a = 235 if y < 110 else int(235 * (1 - (y - 110) / 40))
        d.line([(0, y), (W, y)], fill=(250, 244, 230, a))
    # Avatar: Pinguinkopf im Kreis
    head = SPR[("base", "closed")]; hb = head.getbbox(); hw = hb[2] - hb[0]
    hc = head.crop((hb[0] + int(hw * 0.18), hb[1], hb[2] - int(hw * 0.18), hb[1] + int(hw * 0.64)))
    hc = hc.resize((84, int(84 * hc.height / hc.width)), Image.LANCZOS).crop((0, 0, 84, 84))
    circ = Image.new("RGBA", (92, 92), (0, 0, 0, 0)); cd = ImageDraw.Draw(circ)
    cd.ellipse((0, 0, 91, 91), fill=(255, 255, 255, 255), outline=(60, 50, 40, 255), width=3)
    m = Image.new("L", (84, 84), 0); ImageDraw.Draw(m).ellipse((0, 0, 83, 83), fill=255)
    circ.paste(hc, (4, 4), Image.composite(hc.split()[3], Image.new("L", (84, 84), 0), m))
    bar.alpha_composite(circ, (30, 22))
    d.text((136, 48), CFG.get("channel", "börsenlehre"), font=font(INTER["700Bold"], 34), fill=(30, 30, 34))
    topic, date = CFG["topic"], CFG["date_long"]
    ft, fd = font(INTER["800ExtraBold"], 34), font(INTER["500Medium"], 32)
    tw, dw = ft.getlength(topic), fd.getlength(date)
    x = W - 40 - dw - 14 - tw
    d.text((x, 48), topic, font=ft, fill=(30, 30, 34)); d.text((x + tw + 14, 50), date, font=fd, fill=(150, 150, 158))
    return bar
TOPBAR = make_topbar()
def make_tint():
    FL = CFG.get("filter") or {}; col = tuple(FL.get("tint", [246, 206, 222])); top = tuple(FL.get("tint_top", [250, 246, 252]))
    a = np.zeros((H, W, 4), dtype=np.uint8); ys = np.linspace(0, 1, H)[:, None]
    k = np.clip((ys - 0.25) / 0.75, 0, 1) ** 1.2
    for i in range(3): a[..., i] = (top[i] * (1 - k) + col[i] * k).astype(np.uint8)
    a[..., 3] = (FL.get("strength", 0.55) * 255 * (0.35 + 0.65 * k)).astype(np.uint8)[:, 0][:, None]
    return Image.fromarray(a, "RGBA")
TINT = make_tint()

# ---------------- Milchglas-Karte ----------------
def draw_card(frame, c, t):
    e = back(clamp((t - c["t0"]) / 0.5), 1.2); xo = clamp((t - c["t1"]) / 0.35)
    alpha = clamp(min(clamp((t - c["t0"]) / 0.25), 1 - xo))
    sc = max(0.01, 0.88 + 0.12 * e); dy = (1 - clamp(e)) * 60 - ease_out(xo) * 120
    cw = W - 220; rows = c["rows"]; h = 200 + 112 * len(rows) + (70 if c.get("footer") else 20)
    M = 70; y0 = int(c.get("y", 330) + dy)
    lay = Image.new("RGBA", (cw + 2 * M, h + 2 * M + 20), (0, 0, 0, 0))
    sh = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((M, M + 18, M + cw, M + h + 10), 14, fill=(40, 30, 80, 55))
    lay.alpha_composite(sh.filter(ImageFilter.GaussianBlur(24)))
    region = frame.crop((110, max(0, y0), 110 + cw, max(0, y0) + h)).convert("RGBA").filter(ImageFilter.GaussianBlur(22))
    region.alpha_composite(Image.new("RGBA", region.size, (252, 251, 255, 178)))
    mask = Image.new("L", region.size, 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, cw - 1, h - 1), 14, fill=255)
    lay.paste(region, (M, M), mask)
    d = ImageDraw.Draw(lay); x0, x1, Y = M, M + cw, M
    d.rounded_rectangle((x0, Y, x1, Y + h), 14, outline=(255, 255, 255, 230), width=3)
    d.text((x0 + 44, Y + 44), c["title"], font=font(INTER["700Bold"], 46), fill=(30, 30, 36))
    if c.get("tag"):
        ftg = font(INTER["800ExtraBold"], 26); d.text((x1 - 44 - ftg.getlength(c["tag"]), Y + 58), c["tag"], font=ftg, fill=(40, 40, 46))
    if c.get("sub"): d.text((x0 + 44, Y + 114), c["sub"], font=font(INTER["400Regular"], 30), fill=(150, 150, 160))
    if c.get("emoji") and t < c.get("emoji_t1", 1e9):
        ee = back(clamp((t - c["t0"] - 0.2) / 0.5)); eo = clamp((t - c.get("emoji_t1", 1e9) + 0.3) / 0.3)
        paste_c(lay, emoji(c["emoji"], 170), (x0 + x1) / 2, Y + h / 2 + 30, max(0.01, ee * (1 - eo)), 1.0, math.sin(t * 5) * 6)
    for i, r in enumerate(rows):
        re_ = clamp((t - r["t"]) / 0.35)
        if re_ <= 0: continue
        ry = Y + 230 + i * 112; ra = int(255 * re_)
        d.text((x0 + 44, ry - 26), r["label"], font=font(INTER["500Medium"], 42), fill=(60, 60, 68, ra))
        if "count" in r:
            cc = r["count"]; p = ease_out(clamp((t - r["t"]) / cc.get("dur", 1.2)))
            val = cc.get("prefix", "") + fmt_num(cc["from"] + (cc["to"] - cc["from"]) * p, cc.get("dec", 0)) + cc.get("suffix", "")
        else: val = r.get("value", "")
        if val:
            fv = font(INTER["700Bold"], r.get("size", 70)); vw = fv.getlength(val)
            d.text((x1 - 44 - vw, ry - fv.size * 0.62), val, font=fv, fill=COL[r.get("color", "dark")] + (ra,))
        if r.get("old"):
            fo = font(INTER["500Medium"], 34); ow = fo.getlength(r["old"]); ox = x1 - 44 - ow; oy = ry + 40
            d.text((ox, oy), r["old"], font=fo, fill=(150, 150, 160, ra))
            st = clamp((t - r.get("strike_t", 1e9)) / 0.3)
            if st > 0: d.line([(ox - 6, oy + 22), (ox - 6 + (ow + 12) * st, oy + 22)], fill=COL["red"] + (255,), width=5)
    if c.get("footer"):
        ff_ = font(INTER["400Regular"], 26); fw = ff_.getlength(c["footer"])
        d.text(((x0 + x1) / 2 - fw / 2, Y + h - 56), c["footer"], font=ff_, fill=(165, 165, 175))
    paste_c(frame, lay, W / 2, y0 - M + lay.height / 2, sc, alpha)


# ---------------- Elemente aus Vorlage 2 (Rechenzentren im All) ----------------
def make_particles():
    rng = np.random.RandomState(7); P = []
    for i in range(CFG.get("particles", {}).get("n", 14)):
        P.append(dict(x=rng.uniform(0, W), y=rng.uniform(250, H - 300), r=rng.uniform(18, 46), vx=rng.uniform(-22, 22), vy=rng.uniform(-14, 10),
                      a=rng.uniform(0.25, 0.55), ph=rng.uniform(0, 6.28), star=(i % 4 == 0)))
    return P
PARTS = make_particles() if CFG.get("particles") else []
_blob = {}
def blob(r):
    r = int(r)
    if r not in _blob:
        im = Image.new("RGBA", (r * 4, r * 4), (0, 0, 0, 0)); ImageDraw.Draw(im).ellipse((r, r, r * 3, r * 3), fill=(110, 100, 200, 255))
        _blob[r] = im.filter(ImageFilter.GaussianBlur(r * 0.55))
    return _blob[r]
def draw_particles(frame, t):
    PC = CFG.get("particles") or {}
    if not (PC.get("t0", 0) <= t < PC.get("t1", 1e9)): return
    for q in PARTS:
        x = (q["x"] + q["vx"] * t) % (W + 200) - 100; y = q["y"] + q["vy"] * t + math.sin(t * 0.7 + q["ph"]) * 20
        if q["star"]:
            a = 0.5 + 0.5 * math.sin(t * 3 + q["ph"]); d = ImageDraw.Draw(frame); L = 9 + 5 * a
            d.line([(x - L, y), (x + L, y)], fill=(250, 200, 90, int(200 * a)), width=3); d.line([(x, y - L), (x, y + L)], fill=(250, 200, 90, int(200 * a)), width=3)
        else:
            b = blob(q["r"]); b2 = b.copy(); b2.putalpha(b.split()[3].point(lambda v, aa=q["a"]: int(v * aa)))
            frame.alpha_composite(b2, (int(x - b.width / 2), int(y - b.height / 2)))

def draw_banner(frame, t):
    B = CFG.get("banner")
    if not B or not (B["t0"] <= t < B["t1"] + 0.35): return
    e = back(clamp((t - B["t0"]) / 0.5), 1.3); xo = clamp((t - B["t1"]) / 0.35)
    lines = B["lines"]; size = B.get("size", 92); lh = int(size * 1.12)
    bw = W - 40; bh = 50 + lh * len(lines)
    lay = Image.new("RGBA", (bw + 60, bh + 70), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    sh = Image.new("RGBA", lay.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rectangle((30, 40, 30 + bw, 30 + bh + 12), fill=(60, 40, 90, 50))
    lay.alpha_composite(sh.filter(ImageFilter.GaussianBlur(16)))
    d.rectangle((30, 30, 30 + bw, 30 + bh), fill=(253, 250, 244, 238), outline=(255, 255, 255, 255), width=3)
    f = font(ANTON, size)
    for li, segs in enumerate(lines):
        tw = sum(f.getlength(tx) for tx, _ in segs) + f.getlength(" ") * (len(segs) - 1)
        x = 30 + bw / 2 - tw / 2; y = 30 + 25 + li * lh
        for tx, col in segs:
            c = COL.get(col, (233, 160, 20)) if col != "gold" else (238, 162, 18)
            d.text((x, y - f.getbbox("ÄAg")[1]), tx, font=f, fill=c); x += f.getlength(tx + " ")
    paste_c(frame, lay, W / 2, B.get("y", 250) + bh / 2 - (1 - clamp(e)) * 40 - ease_out(xo) * 160, max(0.01, 0.9 + 0.1 * e), clamp(min(e * 2, 1 - xo)))

def draw_pills_top(frame, t):
    for pl in CFG.get("toppills", []):
        if not (pl["t0"] <= t < pl["t1"] + 0.3): continue
        e = back(clamp((t - pl["t0"]) / 0.45)); xo = clamp((t - pl["t1"]) / 0.3)
        f = font(INTER["600SemiBold"], 38); tw = f.getlength(pl["text"])
        im = Image.new("RGBA", (int(tw) + 120, 130), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle((30, 34, im.width - 30, 104), 18, fill=(60, 40, 100, 60))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(12)))
        d.rounded_rectangle((30, 26, im.width - 30, 96), 16, fill=(252, 251, 255, 245), outline=(225, 222, 235, 255), width=2)
        d.text((60, 61 - f.size * 0.6), pl["text"], font=f, fill=(40, 40, 48))
        paste_c(frame, im, W / 2, pl.get("y", 300), max(0.01, 0.85 + 0.15 * e), clamp(min(e * 2, 1 - xo)))

def draw_dimlines(frame, t):
    for dl in CFG.get("dimlines", []):
        if not (dl["t0"] <= t < dl["t1"] + 0.3): continue
        g = ease_io(clamp((t - dl["t0"]) / 0.7)); xo = clamp((t - dl["t1"]) / 0.3); a = int(255 * (1 - xo))
        x0, x1, y = dl["x0"], dl["x1"], dl["y"]; cx = (x0 + x1) / 2; hw = (x1 - x0) / 2 * g
        d = ImageDraw.Draw(frame); col = (50, 50, 60, a)
        d.line([(cx - hw, y), (cx + hw, y)], fill=col, width=4)
        for xx in (cx - hw, cx + hw): d.line([(xx, y - 18), (xx, y + 18)], fill=col, width=4)
        if g > 0.6:
            f = font(INTER["600SemiBold"], dl.get("size", 44)); tw = f.getlength(dl["text"]); ta = int(a * clamp((g - 0.6) / 0.4))
            d.text((cx - tw / 2, y + 18), dl["text"], font=f, fill=(40, 40, 48, ta))

def draw_labels(frame, t):
    for lb in CFG.get("labels", []):
        if not (lb["t0"] <= t < lb["t1"] + 0.3): continue
        e = back(clamp((t - lb["t0"]) / 0.5), 1.2); xo = clamp((t - lb["t1"]) / 0.3); al = clamp(min(e * 2, 1 - xo))
        x, y, w, h = lb["x"], lb["y"], lb.get("w", 520), lb.get("h", 230)
        if lb.get("anchor"):
            ax, ay = lb["anchor"]; ln = ease_out(clamp((t - lb["t0"]) / 0.4))
            d = ImageDraw.Draw(frame); d.line([(ax, ay), (ax, ay + (y - ay) * ln)], fill=(40, 40, 50, int(230 * al)), width=4); d.ellipse((ax - 8, ay - 8, ax + 8, ay + 8), fill=(40, 40, 50, int(230 * al)))
        region = frame.crop((int(x), int(y), int(x + w), int(y + h))).filter(ImageFilter.GaussianBlur(18))
        card = Image.new("RGBA", (w, h), (0, 0, 0, 0)); card.alpha_composite(region.convert("RGBA")); card.alpha_composite(Image.new("RGBA", (w, h), (250, 249, 255, 150)))
        dd = ImageDraw.Draw(card); dd.rectangle((0, 0, w - 1, h - 1), outline=(255, 255, 255, 240), width=3)
        dd.text((28, 24), lb["title"], font=font(INTER["600SemiBold"], lb.get("size", 42)), fill=(30, 30, 38))
        if lb.get("sub"): dd.text((28, 24 + lb.get("size", 42) * 1.35), lb["sub"], font=font(INTER["400Regular"], 30), fill=(110, 110, 125))
        paste_c(frame, card, x + w / 2, y + h / 2 + (1 - clamp(e)) * 40, max(0.01, 0.9 + 0.1 * e), al)

# ---------------- Rendern ----------------
TEST = sys.argv[1] == "test"
if TEST:
    frames_to_do = [int(float(x) * FPS) for x in sys.argv[2:]]
else:
    frames_to_do = range(NF)
    bgp = subprocess.Popen(["ffmpeg", "-v", "error", "-i", f"{D}/bg3d.mp4", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
out = sys.argv[1]
ff = None if TEST else subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                                          "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out], stdin=subprocess.PIPE)
HEAD = CFG["headlines"]; COUNTS = CFG.get("counts", []); CARDS = CFG.get("cards", []); EMO = CFG.get("emojis", [])
MARKS = CFG.get("marks", []); CAPMAP = CFG.get("capmap", {})
last = None
for fi in frames_to_do:
    t = fi / FPS
    if TEST:
        cands = {float(os.path.basename(f)[5:-4]): f for f in glob.glob(f"{D}/test_*.jpg")}
        frame = Image.open(cands[min(cands, key=lambda x: abs(x - t))]).convert("RGBA")
    else:
        buf = bgp.stdout.read(W * H * 3)
        if len(buf) == W * H * 3: last = buf
        frame = Image.frombytes("RGB", (W, H), last).convert("RGBA")

    # Filter: weicher Rosa-Verlauf + Unschärfe am Anfang, Tiefenunschärfe bei Close-ups
    FL = CFG.get("filter")
    fk = 0.0
    if FL: fk = 1 - clamp((t - FL["t1"]) / FL.get("fade", 0.8))
    ph0, _ = shot_at(t)
    dof = clamp((ph0 - SHOT["full"][0]) / (SHOT["close"][0] - SHOT["full"][0])) * CFG.get("dof_blur", 7)
    blur = max(dof, fk * (FL or {}).get("blur", 9))
    if blur > 0.4: frame = frame.filter(ImageFilter.GaussianBlur(blur))
    if fk > 0.01: frame.alpha_composite(TINT if fk > 0.99 else Image.blend(Image.new("RGBA", (W, H), (0, 0, 0, 0)), TINT, fk))

    draw_particles(frame, t)
    draw_dimlines(frame, t)
    draw_labels(frame, t)
    for c in CARDS:
        if c["t0"] <= t < c["t1"] + 0.35: draw_card(frame, c, t)
    draw_banner(frame, t)
    draw_pills_top(frame, t)

    # Headlines (1–2 Zeilen, Pop-in mit Überschwingen, raus nach oben)
    for h in HEAD:
        if h["t0"] <= t < h["t1"] + 0.25:
            e = back(clamp((t - h["t0"]) / 0.4), 1.4); xo = clamp((t - h["t1"]) / 0.25)
            lines = h["text"].split("\n"); size = h.get("size", 118); y = h.get("y", 330)
            for li, ln in enumerate(lines):
                le = back(clamp((t - h["t0"] - li * 0.12) / 0.4), 1.4)
                im = text_img(ln, ANTON, size, COL[h.get("color", "black")] if li == 0 or not h.get("color2") else COL[h["color2"]])
                sc = max(0.01, le) * (1 - 0.4 * ease_out(xo))
                if im.width * sc > 980: sc *= 980 / (im.width * sc)
                paste_c(frame, im, W / 2, y + li * size * 1.12 - ease_out(xo) * 140, sc, clamp(le * 3) * (1 - xo))

    # große Zahl
    for c in COUNTS:
        if c["t0"] <= t < c["t1"] + 0.25:
            p = ease_out(clamp((t - c["t0"]) / c.get("dur", 1.2))); xo = clamp((t - c["t1"]) / 0.25)
            v = c["from"] + (c["to"] - c["from"]) * p
            s = c.get("prefix", "") + (("+ " if c["to"] >= 0 else "− ") if c.get("sign", True) else "") + fmt_num(v, c.get("dec", 1)) + c.get("suffix", "")
            e = back(clamp((t - c["t0"]) / 0.45), 1.6)
            paste_c(frame, text_img(s, ANTON, c.get("size", 150), COL[c.get("color", "green")]), W / 2, c.get("y", 560), max(0.01, e) * (1 - 0.4 * xo), 1 - xo)
            if c.get("sub"):
                se = clamp((t - c.get("sub_t", c["t0"] + 0.5)) / 0.3)
                paste_c(frame, text_img(c["sub"], ANTON, 54, COL["lgrey"]), W / 2, c.get("y", 560) + c.get("size", 150) * 0.78, 0.7 + 0.3 * back(se), se * (1 - xo))

    # Charakter
    ph, foot = shot_at(t)
    hist = [(st, n) for st, n in POSES if t >= st]; pst, pn = hist[-1]
    mo = mouth[min(fi, NF - 1)]
    br = 1 + 0.010 * math.sin(2 * math.pi * t / 2.4)
    prevkey, mix = None, 0.0
    if len(hist) > 1 and t - pst < 0.2:
        u = (t - pst) / 0.2; u = u * u * (3 - 2 * u)
        prevkey, mix = (hist[-2][1], mo), 1 - u
        hop = math.sin(u * math.pi) * 18
    else: hop = 0
    enter = spring(clamp(t / 0.8)); yoff = (1 - enter) * 900 - hop
    s = ph / BASE_H
    g = glow.resize((max(1, int(1000 * s * 1.1)), max(1, int(240 * s * 1.1))))
    frame.alpha_composite(g, (int(W / 2 - g.width / 2), int(foot - g.height * 0.55 + yoff)))
    place_sprite(frame, (pn, mo), ph * br, W / 2, foot + yoff, 1.0 * math.sin(2 * math.pi * t / 3.6), prevkey, mix)
    head_y = foot - ph * br - 30 + yoff

    # Einzelwort über dem Kopf (+ Betonungsstriche)
    cy = min(max(head_y, 760), 1700)
    for i, w in enumerate(words):
        nxt = words[i + 1]["start"] if i + 1 < len(words) else DUR
        if w["start"] <= t < min(nxt, w["end"] + 0.45):
            txt = CAPMAP.get(w["text"].strip("?.,:!"), w["text"].strip("?.,:!")).upper()
            pe = clamp((t - w["start"]) / 0.08)
            paste_c(frame, text_img(txt, MONT, 54, COL["yellow"], 7, (20, 20, 26)), W / 2, cy, 0.85 + 0.15 * pe)
            break
    for mt in MARKS:
        dd = t - mt
        if 0 <= dd < 0.7:
            a = clamp(min(dd / 0.08, (0.7 - dd) / 0.2)); L = 34 * ease_out(clamp(dd / 0.15))
            dm = ImageDraw.Draw(frame)
            for ang in (-50, 0, 50):
                rad = math.radians(ang - 90); r0 = 70
                x0_, y0_ = W / 2 + math.cos(rad) * r0 * 1.9, cy - 20 + math.sin(rad) * r0
                dm.line([(x0_, y0_), (x0_ + math.cos(rad) * L, y0_ + math.sin(rad) * L)], fill=(20, 20, 26, int(255 * a)), width=9)

    # Sticker-Emojis
    for e_ in EMO:
        if e_["t0"] <= t < e_["t1"]:
            p = back(clamp((t - e_["t0"]) / 0.45), 1.8); xo = clamp((t - e_["t1"] + 0.25) / 0.25)
            bob = math.sin((t - e_["t0"]) * 4) * 8
            paste_c(frame, emoji(e_["code"], e_.get("size", 150)), e_["x"], e_["y"] + bob, max(0.01, p * (1 - xo)), 1.0, math.sin((t - e_["t0"]) * 3) * 7)

    frame.alpha_composite(TOPBAR, (0, CFG.get("topbar_y", 110)))
    rgb = frame.convert("RGB")
    z = 0
    for a in CFG.get("accents", []):
        dd = t - a
        if 0 <= dd < 0.4: z = max(z, math.sin(dd / 0.4 * math.pi) * 0.02)
    if z > 0.001:
        cw, ch = int(W / (1 + z)), int(H / (1 + z))
        rgb = rgb.crop(((W - cw) // 2, (H - ch) // 2, (W - cw) // 2 + cw, (H - ch) // 2 + ch)).resize((W, H), Image.BILINEAR)
    for fl in CFG.get("flashes", []):  # [t, dauer, stärke] weicher Weißblitz (z. B. beim Flug ins Gebäude)
        dd = t - fl[0]; du = fl[1]
        if -du / 2 <= dd < du / 2:
            a = (1 - abs(dd) / (du / 2)) * (fl[2] if len(fl) > 2 else 1.0)
            rgb = Image.blend(rgb, Image.new("RGB", (W, H), (255, 255, 255)), clamp(a))
    if TEST:
        rgb.save(f"{D}/ct_{t:.2f}.jpg"); continue
    ff.stdin.write(rgb.tobytes())
    if fi % 600 == 0: print("frame", fi, NF, flush=True)
if ff: ff.stdin.close(); ff.wait()
print("done", NF)
