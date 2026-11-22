"""Börsenlehre v3 compositor (reference style): headline, count-up numbers, glass cards, camera shots on penguin,
single-word captions, emojis, punch zoom. Reads 3D background video, writes video without audio."""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

D = os.path.dirname(os.path.abspath(__file__))
SP = os.path.dirname(D)
W, H = 1080, 1920
CFG = json.load(open(f"{D}/compose3.json"))
FPS = CFG["fps"]
DUR = CFG["dur"]
NF = int(round(DUR * FPS))
MONT = f"{SP}/pkgs/expo-google-fonts-montserrat-0.2.3/package/Montserrat_900Black.ttf"
MONT8 = f"{SP}/pkgs/expo-google-fonts-montserrat-0.2.3/package/Montserrat_800ExtraBold.ttf"
ANTON = f"{SP}/pkgs/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
COL = {"red": (220, 38, 38), "green": (22, 163, 74), "blue": (37, 99, 235), "yellow": (255, 214, 10), "black": (17, 19, 26), "grey": (110, 116, 130), "white": (255, 255, 255)}
NAVY = (14, 27, 56)

words = [w for w in json.load(open(f"{D}/words.json"))["words"] if w["type"] == "word" and w["text"] not in "–-"]

def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease_out(x): return 1 - (1 - x) ** 3
def ease_io(x): return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2
def spring(x):
    if x <= 0: return 0.0
    return 1 - math.exp(-6 * x) * math.cos(11 * x)

# ---------------- penguin ----------------
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
raw = {(n, m): key_green(f"{D}/m_{n}_{m}.png") for n in ["base", "q", "shock", "explain"] for m in MOUTHS}
bx = None
for im in raw.values():
    bb = im.getbbox(); bx = bb if bx is None else (min(bx[0], bb[0]), min(bx[1], bb[1]), max(bx[2], bb[2]), max(bx[3], bb[3]))
BASE_H = 1100  # sprites stored at the largest shot size
k = BASE_H / (bx[3] - bx[1])
SPR = {kk: im.crop(bx).resize((int((bx[2] - bx[0]) * k), BASE_H), Image.LANCZOS) for kk, im in raw.items()}
SPW = next(iter(SPR.values())).width

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
SHOTS = CFG["shots"]  # [t, height, foot_y]
def shot_at(t):
    prev = SHOTS[0]
    for s in SHOTS:
        if t >= s[0]: prev = s
    idx = SHOTS.index(prev)
    if idx == 0: return prev[1], prev[2]
    u = ease_io(clamp((t - prev[0]) / 0.35))
    p0 = SHOTS[idx - 1]
    return p0[1] + (prev[1] - p0[1]) * u, p0[2] + (prev[2] - p0[2]) * u

glow = Image.new("RGBA", (1000, 240), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((170, 80, 830, 180), fill=(0, 0, 0, 110)); glow = glow.filter(ImageFilter.GaussianBlur(30))

# ---------------- text helpers ----------------
_fc = {}
def font(p, s):
    if (p, s) not in _fc: _fc[(p, s)] = ImageFont.truetype(p, s)
    return _fc[(p, s)]
_tc = {}
def text_img(txt, path, size, fill, stroke=0, sfill=(255, 255, 255)):
    key = (txt, path, size, fill, stroke, sfill)
    if key in _tc: return _tc[key]
    f = font(path, size); bb = f.getbbox(txt, stroke_width=stroke)
    im = Image.new("RGBA", (bb[2] - bb[0] + 20, bb[3] - bb[1] + 20), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((10 - bb[0], 10 - bb[1]), txt, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill)
    _tc[key] = im; return im
def paste_c(frame, im, cx, cy, sc=1.0, alpha=1.0):
    if sc <= 0.01 or alpha <= 0.01: return
    if abs(sc - 1) > 0.005: im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.BILINEAR)
    if alpha < 0.99:
        im = im.copy(); im.putalpha(im.split()[3].point(lambda v: int(v * alpha)))
    frame.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))

def emoji(code, size):
    return Image.open(f"{SP}/icons/{code}.png").convert("RGBA").resize((size, size), Image.LANCZOS)

def fmt_num(v, dec, thousands=False):
    s = f"{abs(v):,.{dec}f}" if thousands else f"{abs(v):.{dec}f}"
    if thousands: s = s.replace(",", "X").replace(".", ",").replace("X", ".")
    else: s = s.replace(".", ",")
    return s

# ---------------- glass card ----------------
def glass(frame, box, alpha):
    x0, y0, x1, y1 = box
    region = frame.crop(box).filter(ImageFilter.GaussianBlur(16))
    card = Image.new("RGBA", region.size, (255, 255, 255, 0))
    card.alpha_composite(region)
    over = Image.new("RGBA", region.size, (255, 255, 255, int(150)))
    card.alpha_composite(over)
    mask = Image.new("L", region.size, 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, region.width - 1, region.height - 1), 36, fill=int(255 * alpha))
    sh = Image.new("RGBA", (region.width + 80, region.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((40, 52, region.width + 40, region.height + 52), 36, fill=(30, 30, 60, int(60 * alpha)))
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    frame.alpha_composite(sh, (x0 - 40, y0 - 40))
    frame.paste(card, (x0, y0), mask)
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle(box, 36, outline=(255, 255, 255, int(220 * alpha)), width=3)

# ---------------- render ----------------
TEST = sys.argv[1] == "test"
if TEST:
    TT = [float(x) for x in sys.argv[2:]]
    frames_to_do = [int(x * FPS) for x in TT]
else:
    frames_to_do = range(NF)
    bgp = subprocess.Popen(["ffmpeg", "-v", "error", "-i", f"{D}/bg3d.mp4", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
out = sys.argv[1]
ff = None if TEST else subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                       "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out], stdin=subprocess.PIPE)
HEAD = CFG["headlines"]; COUNTS = CFG["counts"]; CARDS = CFG["cards"]; EMO = CFG["emojis"]; PILLS = CFG.get("pills", [])
CAPMAP = CFG.get("capmap", {})
badge = None
last = None
for fi in frames_to_do:
    t = fi / FPS
    if TEST:
        import glob
        cands = {float(os.path.basename(f)[5:-4]): f for f in glob.glob(f"{D}/test_*.jpg")}
        near = min(cands, key=lambda x: abs(x - t))
        frame = Image.open(cands[near]).convert("RGBA")
    else:
        buf = bgp.stdout.read(W * H * 3)
        if len(buf) == W * H * 3: last = buf
        frame = Image.frombytes("RGB", (W, H), last).convert("RGBA")

    # glass cards (behind penguin, over 3D)
    for c in CARDS:
        if c["t0"] <= t < c["t1"] + 0.3:
            e = spring(clamp((t - c["t0"]) / 0.6)); xo = clamp((t - c["t1"]) / 0.3)
            dy = (1 - e) * 120 + ease_out(xo) * 80; alpha = clamp(min(e * 1.4, 1 - xo))
            rows = c["rows"]; rh = 96
            x0, y0 = 90, int(c.get("y", 470) + dy); h = 120 + rh * len(rows)
            glass(frame, (x0, y0, W - 90, y0 + h), alpha)
            paste_c(frame, text_img(c["title"], MONT, 40, COL["black"]), x0 + 40 + text_img(c["title"], MONT, 40, COL["black"]).width / 2, y0 + 58, 1, alpha)
            for i, r in enumerate(rows):
                re_ = spring(clamp((t - r["t"]) / 0.45))
                if re_ <= 0: continue
                ry = y0 + 130 + i * rh
                xs = (1 - re_) * 60
                if r.get("emoji"):
                    paste_c(frame, emoji(r["emoji"], 62), x0 + 70 + xs, ry, 1, alpha * clamp(re_ * 2))
                    lx = x0 + 120
                else: lx = x0 + 40
                li = text_img(r["label"], MONT8, 44, COL["black"])
                paste_c(frame, li, lx + li.width / 2 + xs, ry, 1, alpha * clamp(re_ * 2))
                if r.get("value"):
                    vi = text_img(r["value"], MONT, 50, COL[r.get("color", "red")])
                    paste_c(frame, vi, W - 90 - 40 - vi.width / 2 - xs, ry, 0.6 + 0.4 * clamp(re_), alpha * clamp(re_ * 2))

    # line-chart cards (drawn progressively)
    for c in CFG.get("charts", []):
        if c["t0"] <= t < c["t1"] + 0.3:
            e = spring(clamp((t - c["t0"]) / 0.6)); xo = clamp((t - c["t1"]) / 0.3)
            dy = (1 - e) * 120 + ease_out(xo) * 80; alpha = clamp(min(e * 1.4, 1 - xo))
            x0, y0 = 90, int(c.get("y", 440) + dy); x1, y1 = W - 90, y0 + 560
            glass(frame, (x0, y0, x1, y1), alpha)
            ti = text_img(c["title"], MONT, 38, COL["black"]); paste_c(frame, ti, x0 + 40 + ti.width / 2, y0 + 55, 1, alpha)
            if c.get("sub"):
                si = text_img(c["sub"], MONT8, 26, COL["grey"]); paste_c(frame, si, x0 + 40 + si.width / 2, y0 + 95, 1, alpha)
            # badge
            bt = c.get("badge", ""); bi = text_img(bt, MONT, 34, COL["white"])
            bw, bh = bi.width + 30, bi.height + 6
            bx0, by0 = x1 - 40 - bw, y0 + 32
            ImageDraw.Draw(frame).rounded_rectangle((bx0, by0, bx0 + bw, by0 + bh), 10, fill=COL[c.get("badge_color", "red")] + (int(255 * alpha),))
            paste_c(frame, bi, bx0 + bw / 2, by0 + bh / 2, 1, alpha)
            # several lines (optional): [{"points":[..], "color":"green", "label":"..."}]
            if c.get("lines"):
                px0, px1, py0, py1 = x0 + 50, x1 - 200, y0 + 150, y1 - 60
                for ln in c["lines"]:
                    pts = ln["points"]; n = len(pts); col = COL[ln.get("color", "red")]
                    P = [(px0 + (px1 - px0) * i / (n - 1), py1 - (py1 - py0) * v) for i, v in enumerate(pts)]
                    f = ease_io(clamp((t - ln["draw"][0]) / (ln["draw"][1] - ln["draw"][0]))) * (n - 1)
                    k = int(f); fr = f - k
                    seg = P[:k + 1] + ([(P[k][0] + (P[k + 1][0] - P[k][0]) * fr, P[k][1] + (P[k + 1][1] - P[k][1]) * fr)] if k + 1 < n else [])
                    if len(seg) < 2: continue
                    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dl = ImageDraw.Draw(lay)
                    dl.polygon(seg + [(seg[-1][0], py1), (seg[0][0], py1)], fill=col + (int(30 * alpha),))
                    dl.line(seg, fill=col + (int(255 * alpha),), width=8, joint="curve")
                    frame.alpha_composite(lay)
                    ex, ey = seg[-1]; ImageDraw.Draw(frame).ellipse((ex - 11, ey - 11, ex + 11, ey + 11), fill=col + (255,), outline=(255, 255, 255, 255), width=3)
                    if f >= n - 1.01:
                        el = text_img(ln["label"], MONT, 36, col); paste_c(frame, el, ex + 24 + el.width / 2, ey, 1, alpha)
                        if ln.get("name"):
                            nm = text_img(ln["name"], MONT8, 22, COL["grey"]); paste_c(frame, nm, ex + 24 + nm.width / 2, ey + 34, 1, alpha)
                continue
            # line
            pts = c["points"]; n = len(pts)
            px0, px1, py0, py1 = x0 + 50, x1 - 70, y0 + 150, y1 - 60
            P = [(px0 + (px1 - px0) * i / (n - 1), py1 - (py1 - py0) * v) for i, v in enumerate(pts)]
            f = ease_io(clamp((t - c["draw"][0]) / (c["draw"][1] - c["draw"][0]))) * (n - 1)
            k = int(f); fr = f - k
            seg = P[:k + 1] + ([(P[k][0] + (P[k + 1][0] - P[k][0]) * fr, P[k][1] + (P[k + 1][1] - P[k][1]) * fr)] if k + 1 < n else [])
            if len(seg) >= 2:
                lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dl = ImageDraw.Draw(lay)
                dl.polygon(seg + [(seg[-1][0], py1), (seg[0][0], py1)], fill=(220, 38, 38, int(38 * alpha)))
                ri = c.get("record_idx", -1)
                for j in range(len(seg) - 1):
                    col = (22, 163, 74) if (ri >= 0 and j < ri) else (220, 38, 38)
                    dl.line([seg[j], seg[j + 1]], fill=col + (int(255 * alpha),), width=7)
                frame.alpha_composite(lay)
                d0 = ImageDraw.Draw(frame)
                if 0 <= ri < len(seg):
                    rx, ry = P[ri]; d0.ellipse((rx - 11, ry - 11, rx + 11, ry + 11), fill=(22, 163, 74, 255), outline=(255, 255, 255, 255), width=3)
                    rl = text_img("Rekord", MONT8, 26, COL["green"]); paste_c(frame, rl, rx, ry - 34, 1, alpha)
                ex, ey = seg[-1]; d0.ellipse((ex - 10, ey - 10, ex + 10, ey + 10), fill=(220, 38, 38, 255), outline=(255, 255, 255, 255), width=3)
                if f >= n - 1.01 and c.get("end_label"):
                    el = text_img(c["end_label"], MONT, 34, COL["red"]); paste_c(frame, el, ex - el.width / 2 + 10, ey + 34, 1, alpha)

    # headline
    for h in HEAD:
        if h["t0"] <= t < h["t1"]:
            e = clamp((t - h["t0"]) / 0.25); sc = 1.25 - 0.25 * ease_out(e)
            im = text_img(h["text"], ANTON, h.get("size", 128), COL[h.get("color", "black")])
            if im.width * sc > 1000: sc *= 1000 / (im.width * sc)
            paste_c(frame, im, W / 2, h.get("y", 270), sc, ease_out(e))

    # count-up numbers
    for c in COUNTS:
        if c["t0"] <= t < c["t1"]:
            p = ease_out(clamp((t - c["t0"]) / c.get("dur", 1.0)))
            v = c["from"] + (c["to"] - c["from"]) * p
            sign = "+" if c["to"] > 0 else "−"
            s = c.get("prefix", "") + (sign + " " if c.get("sign", True) else "") + fmt_num(v, c.get("dec", 1), c.get("thousands", False)) + c.get("suffix", "")
            e = spring(clamp((t - c["t0"]) / 0.5))
            im = text_img(s, ANTON, c.get("size", 150), COL[c.get("color", "red")], 6, (255, 255, 255))
            paste_c(frame, im, W / 2, c.get("y", 520), 0.6 + 0.4 * e)
            if c.get("sub"):
                se = clamp((t - c.get("sub_t", c["t0"] + 0.4)) / 0.3)
                paste_c(frame, text_img(c["sub"], ANTON, 54, COL["grey"], 4, (255, 255, 255)), W / 2, c.get("y", 520) + 115, 1, ease_out(se))

    # penguin with camera shots
    ph, foot = shot_at(t)
    hist = [(st, n) for st, n in POSES if t >= st]; pst, pn = hist[-1]
    mo = mouth[fi]; spr = SPR[(pn, mo)]
    if len(hist) > 1 and t - pst < 0.22:
        u = (t - pst) / 0.22; u = u * u * (3 - 2 * u); spr = Image.blend(SPR[(hist[-2][1], mo)], spr, u)
    br = 1 + 0.012 * math.sin(2 * math.pi * t / 2.2)
    s = ph / BASE_H
    sp = spr.resize((max(1, int(SPW * s * (2 - br) ** 0.5)), max(1, int(ph * br))), Image.BILINEAR)
    sp = sp.rotate(1.2 * math.sin(2 * math.pi * t / 3.4), Image.BICUBIC, expand=True)
    enter = spring(clamp(t / 0.9)); yoff = (1 - enter) * 800
    g = glow.resize((int(1000 * s * 1.3), int(240 * s * 1.3)))
    frame.alpha_composite(g, (int(W / 2 - g.width / 2), int(foot - g.height * 0.55 + yoff)))
    frame.alpha_composite(sp, (int(W / 2 - sp.width / 2), int(foot - sp.height + yoff)))
    head_y = foot - ph - 40 + yoff

    # single-word caption above head
    for i, w in enumerate(words):
        nxt = words[i + 1]["start"] if i + 1 < len(words) else DUR
        if w["start"] <= t < min(nxt, w["end"] + 0.5):
            txt = CAPMAP.get(w["text"].strip("?.,:!"), w["text"].strip("?.,:!")).upper()
            im = text_img(txt, MONT, 60, COL["yellow"], 8, (12, 16, 30))
            pe = clamp((t - w["start"]) / 0.1)
            paste_c(frame, im, W / 2, max(head_y, 700), 0.8 + 0.2 * pe)
            break

    # emojis
    for e_ in EMO:
        if e_["t0"] <= t < e_["t1"]:
            p = spring(clamp((t - e_["t0"]) / 0.5)); xo = clamp((t - e_["t1"] + 0.25) / 0.25)
            bob = math.sin((t - e_["t0"]) * 4) * 8
            paste_c(frame, emoji(e_["code"], e_.get("size", 150)), e_["x"], e_["y"] + bob, max(0.01, p * (1 - xo)))

    # pills
    for pl in PILLS:
        if pl["t0"] <= t < pl["t1"]:
            p = spring(clamp((t - pl["t0"]) / 0.6))
            f = font(MONT, pl.get("size", 70)); bb = f.getbbox(pl["text"])
            im = Image.new("RGBA", (bb[2] - bb[0] + 90, bb[3] - bb[1] + 60), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            d.rounded_rectangle((5, 5, im.width - 5, im.height - 5), 26, fill=COL[pl.get("color", "red")], outline=(255, 255, 255), width=5)
            d.text((45 - bb[0], 30 - bb[1]), pl["text"], font=f, fill=(255, 255, 255))
            paste_c(frame, im, W / 2 + (1 - p) * 700, pl.get("y", 560))

    # badge + progress
    if badge is None:
        f = font(MONT, 30); txt = CFG.get("badge_prefix", "BÖRSEN-NEWS") + " · " + CFG["date"]; bb = f.getbbox(txt)
        badge = Image.new("RGBA", (bb[2] - bb[0] + 50, bb[3] - bb[1] + 30), (0, 0, 0, 0))
        ImageDraw.Draw(badge).rounded_rectangle((0, 0, badge.width - 1, badge.height - 1), 16, fill=COL["yellow"])
        ImageDraw.Draw(badge).text((25 - bb[0], 15 - bb[1]), txt, font=f, fill=NAVY)
    be = spring(clamp((t - 0.15) / 0.8))
    frame.alpha_composite(badge, (int(-badge.width + be * (badge.width + 28)), 60))
    d = ImageDraw.Draw(frame); d.rectangle((0, 0, W, 10), fill=(0, 0, 0, 25)); d.rectangle((0, 0, int(W * t / DUR), 10), fill=COL["yellow"])

    rgb = frame.convert("RGB")
    z = 0
    for a in CFG["accents"]:
        dd = t - a
        if 0 <= dd < 0.45: z = max(z, math.sin(dd / 0.45 * math.pi) * 0.03)
    if z > 0.001:
        cw, ch = int(W / (1 + z)), int(H / (1 + z))
        rgb = rgb.crop(((W - cw) // 2, (H - ch) // 2, (W - cw) // 2 + cw, (H - ch) // 2 + ch)).resize((W, H), Image.BILINEAR)
    for a in CFG["segments"]:
        dd = t - a
        if 0 <= dd < 0.1: rgb = Image.blend(rgb, Image.new("RGB", (W, H), (255, 255, 255)), 0.22 * (1 - dd / 0.1))
    if TEST:
        rgb.save(f"{D}/ct_{t:.2f}.jpg"); continue
    ff.stdin.write(rgb.tobytes())
    if fi % 600 == 0: print("frame", fi, NF, flush=True)
if ff: ff.stdin.close(); ff.wait()
print("done", NF)
