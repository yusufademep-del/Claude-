"""Baut die Pinguin-Sprites m_<pose>_<mund>.png (Greenscreen) für compose3.py.
Quelle: pinguin/mundbewegung/ (Repo-Wurzel) pinguin_<pose>_mund_<zu|halb|offen>.png (4 Posen × 3 Mundstellungen).
Entfernt den weißen Sticker-Rand und richtet alle Posen an den Füßen mittig aus."""
import os, numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
D = os.path.dirname(os.path.abspath(__file__))
POSES = {"base": "neutral", "q": "fragend", "shock": "geschockt", "explain": "erklaerend"}
MOUTH = {"closed": "zu", "mid": "halb", "open": "offen"}
def unrim(im):
    a = np.asarray(im.convert("RGBA")).astype(np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    white = (r > 215) & (g > 215) & (b > 215) & (al > 0)
    outside = al < 40
    rim = ndimage.binary_propagation(outside, mask=outside | white) & ~outside
    alpha = np.where(rim | outside, 0, al).astype(np.uint8)
    alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7)))
    return Image.fromarray(np.dstack([a[..., :3].astype(np.uint8), alpha]), "RGBA")
def feet_x(im):
    al = np.asarray(im.split()[3]); h = al.shape[0]
    cols = np.where((al[int(h * 0.88):] > 128).any(axis=0))[0]
    return (cols.min() + cols.max()) / 2
src = {(p, m): unrim(Image.open(f"{os.path.dirname(os.path.dirname(D))}/pinguin/mundbewegung/pinguin_{POSES[p]}_mund_{MOUTH[m]}.png")) for p in POSES for m in MOUTH}
CW = 900; H = max(im.height for im in src.values())
for (p, m), im in src.items():
    cv = Image.new("RGBA", (CW, H), (0, 255, 0, 255))
    cv.alpha_composite(im, (int(CW / 2 - feet_x(im)), H - im.height))
    cv.convert("RGB").save(f"{D}/m_{p}_{m}.png")
print("ok", len(src))
