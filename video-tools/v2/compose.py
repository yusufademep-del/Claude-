"""Börsenlehre v2 compositor: 3D background video + penguin + karaoke captions + spring labels + punch zoom + sfx mix."""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

D = os.path.dirname(os.path.abspath(__file__))
SP = os.path.dirname(D)
W, H, FPS = 1080, 1920, 60
MONT = f"{SP}/pkgs/expo-google-fonts-montserrat-0.2.3/package/Montserrat_900Black.ttf"
ANTON = f"{SP}/pkgs/expo-google-fonts-anton-0.2.3/package/Anton_400Regular.ttf"
CFG = json.load(open(f"{D}/compose.json"))
YEL, RED, GREEN, BLUE, NAVY = (255, 214, 10), (225, 35, 45), (22, 163, 74), (37, 99, 235), (14, 27, 56)

words = [w for w in json.load(open(f"{D}/words.json"))["words"] if w["type"] == "word" and w["text"] not in "–-"]
DUR = CFG["dur"]
NF = int(round(DUR * FPS))

# ---------------- penguin sprites ----------------
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
    bb = im.getbbox()
    bx = bb if bx is None else (min(bx[0], bb[0]), min(bx[1], bb[1]), max(bx[2], bb[2]), max(bx[3], bb[3]))
PH = CFG.get("peng_h", 760)
k = PH / (bx[3] - bx[1])
SPR = {kk: im.crop(bx).resize((int((bx[2] - bx[0]) * k), PH), Image.LANCZOS) for kk, im in raw.items()}
SPW = next(iter(SPR.values())).width
FOOT = H - 110

# soft glow under penguin
glow = Image.new("RGBA", (900, 220), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((150, 70, 750, 170), fill=(0, 0, 0, 150))
glow = glow.filter(ImageFilter.GaussianBlur(28))

# ---------------- audio envelope -> mouth ----------------
pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", f"{D}/voice.wav", "-ac", "1", "-ar", "48000", "-f", "f32le", "-"], capture_output=True).stdout
A = np.frombuffer(pcm, dtype=np.float32)
hop = 48000 // FPS
env = np.array([np.sqrt(np.mean(A[i * hop:(i + 1) * hop + hop] ** 2)) if i * hop < len(A) else 0 for i in range(NF)])
env = env / (np.percentile(env[env > 0], 92) + 1e-9)
env = np.convolve(env, np.ones(3) / 3, mode="same")
mouth, cur, hold = [], 0, 0
for i in range(NF):
    t = i / FPS
    inw = any(w["start"] - 0.03 <= t <= w["end"] + 0.03 for w in words)
    want = 0 if (not inw or env[i] < 0.2) else (1 if env[i] < 0.55 else 2)
    if want != cur and hold <= 0:
        cur, hold = want, 4
    hold -= 1
    mouth.append(MOUTHS[cur])
POSES = CFG["poses"]

# ---------------- helpers ----------------
def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def ease_out(x): return 1 - (1 - x) ** 3
def ease_back(x):
    c1 = 1.70158; c3 = c1 + 1
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2
def spring(x):  # damped overshoot 0->1
    if x <= 0: return 0.0
    return 1 - math.exp(-6 * x) * math.cos(11 * x)

def pill(text, fg=(255, 255, 255), bg=RED, size=56, sub=None):
    f = ImageFont.truetype(MONT, size)
    bb = f.getbbox(text); tw, th = bb[2] - bb[0], bb[3] - bb[1]
    sh = 0
    if sub:
        fs = ImageFont.truetype(MONT, int(size * 0.42)); sb = fs.getbbox(sub); sh = sb[3] - sb[1] + 14
    w, h = tw + 70, th + 40 + sh
    im = Image.new("RGBA", (w + 30, h + 34), (0, 0, 0, 0))
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((15, 22, w + 15, h + 22), 22, fill=(0, 0, 0, 120))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((15, 10, w + 15, h + 10), 22, fill=bg, outline=(255, 255, 255), width=5)
    d.text((15 + 35 - bb[0], 10 + 20 - bb[1]), text, font=f, fill=fg)
    if sub:
        d.text((15 + w / 2, 10 + 20 + th + 12), sub, font=fs, fill=fg, anchor="mt")
    return im

# ---------------- captions (karaoke groups) ----------------
CAPMAP = CFG.get("capmap", {})
def disp(w): return CAPMAP.get(w["text"].strip("?.,:!"), w["text"].strip("?.,:!")).upper()
groups, gcur = [], []
for i, w in enumerate(words):
    gcur.append(i)
    if len(gcur) >= 3 or w["text"][-1] in ".,:!?" or (i + 1 < len(words) and words[i + 1]["start"] - w["end"] > 0.35):
        groups.append(gcur); gcur = []
if gcur: groups.append(gcur)
CF = ImageFont.truetype(MONT, 74)
_capcache = {}
def caption_img(gi, active):
    key = (gi, active)
    if key in _capcache: return _capcache[key]
    toks = [disp(words[i]) for i in groups[gi]]
    widths = [CF.getbbox(tk)[2] - CF.getbbox(tk)[0] for tk in toks]
    gap = 22; tw = sum(widths) + gap * (len(toks) - 1)
    scale = min(1.0, 1000 / tw) if tw else 1
    im = Image.new("RGBA", (int(tw + 60), 140), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    x = 30
    for j, tk in enumerate(toks):
        col = YEL if groups[gi][j] == active else (255, 255, 255)
        d.text((x, 70), tk, font=CF, fill=col, stroke_width=9, stroke_fill=(8, 12, 30), anchor="lm")
        x += widths[j] + gap
    if scale < 1: im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    _capcache[key] = im
    return im

# ---------------- 2D labels ----------------
LABELS = []
for L in CFG["labels"]:
    bgc = {"red": RED, "green": GREEN, "blue": BLUE, "yellow": YEL, "white": (255, 255, 255)}[L.get("color", "red")]
    fg = NAVY if L.get("color") in ("yellow", "white") else (255, 255, 255)
    LABELS.append((L["t0"], L["t1"], pill(L["text"], fg, bgc, L.get("size", 56), L.get("sub")), L.get("y", 965), L.get("from", "left")))

badge = pill("BÖRSEN-NEWS · " + CFG["date"], NAVY, YEL, 34)
tick = Image.open(f"{SP}/icons/1f514.png").convert("RGBA").resize((64, 64), Image.LANCZOS)

ACC = CFG["accents"]
SEGS = CFG["segments"]

# ---------------- render ----------------
bgp = subprocess.Popen(["ffmpeg", "-v", "error", "-i", f"{D}/bg3d.mp4", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
out = sys.argv[1]
ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                       "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out], stdin=subprocess.PIPE)
last_bg = None
for fi in range(NF):
    t = fi / FPS
    buf = bgp.stdout.read(W * H * 3)
    if len(buf) == W * H * 3: last_bg = buf
    frame = Image.frombytes("RGB", (W, H), last_bg).convert("RGBA")

    # penguin: slide-in, crossfade, breathing, sway
    hist = [(st, n) for st, n in POSES if t >= st]
    pst, pn = hist[-1]
    mo = mouth[fi]
    spr = SPR[(pn, mo)]
    if len(hist) > 1 and t - pst < 0.22:
        u = (t - pst) / 0.22; u = u * u * (3 - 2 * u)
        spr = Image.blend(SPR[(hist[-2][1], mo)], spr, u)
    br = 1 + 0.012 * math.sin(2 * math.pi * t / 2.2)
    sp = spr.resize((int(SPW * (2 - br) ** 0.5), int(PH * br)), Image.BILINEAR)
    sway = 1.2 * math.sin(2 * math.pi * t / 3.4)
    sp = sp.rotate(sway, Image.BICUBIC, expand=True)
    enter = spring(clamp(t / 0.9)) if t < 0.9 else 1
    yoff = (1 - enter) * 700
    frame.alpha_composite(glow, (W // 2 - 450, FOOT - 120))
    px, py = W // 2 - sp.width // 2, int(FOOT - sp.height + yoff)
    frame.alpha_composite(sp, (px, py))

    # labels (spring slide)
    for t0, t1, img, y, frm in LABELS:
        if t0 <= t < t1 + 0.3:
            e = spring(clamp((t - t0) / 0.7))
            x_out = clamp((t - t1) / 0.3)
            dirn = -1 if frm == "left" else 1
            cx = W / 2 + dirn * (1 - e) * 900 - dirn * ease_out(x_out) * -1100
            rot = dirn * (1 - clamp((t - t0) / 0.35)) * 8
            im = img.rotate(rot, Image.BICUBIC, expand=True) if abs(rot) > 0.2 else img
            frame.alpha_composite(im, (int(cx - im.width / 2), int(y - im.height / 2)))

    # captions
    head_y = FOOT - PH - 55
    for gi, g in enumerate(groups):
        g0 = words[g[0]]["start"]
        g1 = words[groups[gi + 1][0]]["start"] if gi + 1 < len(groups) else DUR
        g1 = min(g1, words[g[-1]]["end"] + 0.6)
        if g0 <= t < g1:
            act = g[0]
            for i in g:
                if words[i]["start"] <= t: act = i
            im = caption_img(gi, act)
            p = spring(clamp((t - g0) / 0.35))
            s = 0.75 + 0.25 * p
            if s != 1: im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.BILINEAR)
            frame.alpha_composite(im, (int(W / 2 - im.width / 2), int(head_y - im.height / 2)))
            break

    # top badge + progress bar
    be = spring(clamp((t - 0.15) / 0.8))
    frame.alpha_composite(badge, (int(-badge.width + be * (badge.width + 24)), 70))
    d = ImageDraw.Draw(frame)
    d.rectangle((0, 0, W, 10), fill=(255, 255, 255, 40))
    d.rectangle((0, 0, int(W * t / DUR), 10), fill=YEL)

    # punch zoom on accents
    z = 0
    for a in ACC:
        dd = t - a
        if 0 <= dd < 0.5: z = max(z, math.sin(dd / 0.5 * math.pi) * 0.035)
    rgb = frame.convert("RGB")
    if z > 0.001:
        cw, ch = int(W / (1 + z)), int(H / (1 + z))
        rgb = rgb.crop(((W - cw) // 2, (H - ch) // 2, (W - cw) // 2 + cw, (H - ch) // 2 + ch)).resize((W, H), Image.BILINEAR)
    # flash on segment cuts
    for a in SEGS:
        dd = t - a
        if 0 <= dd < 0.12:
            rgb = Image.blend(rgb, Image.new("RGB", (W, H), (255, 255, 255)), 0.16 * (1 - dd / 0.12))
    ff.stdin.write(rgb.tobytes())
    if fi % 300 == 0: print("frame", fi, NF, flush=True)
ff.stdin.close(); ff.wait()
print("done", NF)
