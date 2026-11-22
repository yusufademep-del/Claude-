"""Baut die Pinguin-Sprites m_<pose>_<mund>.png (Greenscreen) aus website/assets/pinguin-hero.png.
Entfernt den weißen Sticker-Rand und erzeugt drei Mundstellungen (closed/mid/open)."""
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
D = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(D))
im = Image.open(f"{ROOT}/website/assets/pinguin-hero.png").convert("RGBA")
im = im.resize((im.width * 2, im.height * 2), Image.LANCZOS)
a = np.asarray(im).astype(np.int16)
r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
# Sticker-Rand: weiße Pixel, die mit dem transparenten Außenbereich verbunden sind
white = (r > 215) & (g > 215) & (b > 215) & (al > 0)
outside = al < 40
rim = ndimage.binary_propagation(outside, mask=outside | white) & ~outside
alpha = np.where(rim | outside, 0, al).astype(np.uint8)
alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7)))
base = np.dstack([a[..., :3].astype(np.uint8), alpha])
# Mundinnenraum
H, W = alpha.shape
yy, xx = np.mgrid[0:H, 0:W]
box = (xx > 420) & (xx < 640) & (yy > 400) & (yy < 500)
inner = box & (r > 55) & (r - g > 35) & (b > 0.6 * g)
inner = ndimage.binary_closing(inner, iterations=2)
inner = ndimage.binary_fill_holes(inner)
lab, n = ndimage.label(inner); sizes = ndimage.sum(inner, lab, range(1, n + 1)); inner = lab == (np.argmax(sizes) + 1)
ORANGE = (243, 164, 52); LINE = (24, 22, 30)
def variant(frac):
    out = base.copy()
    cols = np.where(inner.any(axis=0))[0]
    lip = []
    for x in cols:
        ys = np.where(inner[:, x])[0]; y0, y1 = ys.min(), ys.max()
        keep = y0 + int((y1 - y0) * frac)
        for y in ys:
            if y > keep: out[y, x, :3] = ORANGE
        lip.append((x, keep))
    img = Image.fromarray(out, "RGBA"); d = ImageDraw.Draw(img)
    if frac < 0.99:
        d.line(lip, fill=LINE + (255,), width=5)
    if frac == 0:
        top = [(x, np.where(inner[:, x])[0].min()) for x in cols]
        d.line(top, fill=LINE + (255,), width=5)
    return img
for mname, frac in [("closed", 0.0), ("mid", 0.5), ("open", 1.0)]:
    v = variant(frac)
    for pose in ["base", "q", "shock", "explain"]:
        gs = Image.new("RGBA", v.size, (0, 255, 0, 255)); gs.alpha_composite(v)
        gs.convert("RGB").save(f"{D}/m_{pose}_{mname}.png")
print("ok", inner.sum())
