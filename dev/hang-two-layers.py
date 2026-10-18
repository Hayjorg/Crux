"""Outfit layers and colour variants for climb/climb-hang-two (the two-hand hang), built by script, no image model.

Needs the (local, untracked) dev/outfit toolchain and a Python with numpy, scipy and Pillow:
    python3 -m venv v && v/bin/pip install pillow numpy scipy
    v/bin/python dev/hang-two-layers.py [--write]        # without --write: only dev/outfit/out/hang_two/ (nothing in assets/)

What it makes, all for the one frame `climb/climb-hang-two` (640x960), reusing the existing pipelines (the gates are the ones the other
climb frames use, tuned for this pose):
  shoes     blue panel recolour (shoes.py recolor) -> delta layer -> assets/outfit/blue/climb/
  chalkbag  teal recolour (chalkbag.py process)    -> delta layer -> assets/outfit/teal/climb/
  shirt     neutral grey layer (shirt_shorts/build.py, gain from build_params.json) -> assets/outfit/shirt/climb/
  shorts    same                                                             -> assets/outfit/shorts/climb/
  headband  teal knit band (headband5.py, pose override)                     -> assets/outfit/teal-knit/climb/
  headlamp  headlamp (hats3_pilot.py, pose override)                         -> assets/outfit/headlamp/climb/
  variants  slate / sandstone / moss (variants3.py + compress3.py, overrides3.json entry 'climb/climb-hang-two')
            -> assets/mascot/climber/variants/<id>/climb/
The painted beanie has no back-view art: `climb/climb-hang-two` is in BEANIE_SKIP in crux.html (the original head shows).
"""
import sys, os, json, shutil
HERE = '/Users/hayden/crux-work'
O = HERE + '/dev/outfit'
for p in (O, O + '/lib', O + '/variants', O + '/shirt_shorts'):
    sys.path.insert(0, p)
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

N = 'climb/climb-hang-two'
SRC = HERE + '/assets/mascot/climber/default'
OUTD = O + '/out/hang_two'
WRITE = '--write' in sys.argv
os.makedirs(OUTD, exist_ok=True)
POSE = dict(cx=318, cy=261, rx=151, ry=139, roll=0.0, yaw=0.0)   # the head in this frame: upright, level, as wide as the other climb frames' heads


def delta(o, r):
    """delta layer: alpha 0 except changed pixels; source-over onto o gives r (same maths as dev/outfit/export_layers.py)"""
    ch = (o[..., :3] != r[..., :3]).any(-1) & (o[..., 3] > 0)
    La = np.where(ch, o[..., 3], 0).astype(np.float32) / 255
    La = np.where(ch & (o[..., 3] >= 250), 1.0, La)
    Oa = o[..., 3].astype(np.float32) / 255
    oa = La + Oa * (1 - La)
    R_ = r[..., :3].astype(np.float32); O_ = o[..., :3].astype(np.float32)
    L = (R_ * oa[..., None] - O_ * (Oa * (1 - La))[..., None]) / np.maximum(La, 1e-6)[..., None]
    out = np.zeros(o.shape, np.uint8)
    out[..., :3] = np.where(ch[..., None], np.round(np.clip(L, 0, 255)), 0).astype(np.uint8)
    out[..., 3] = np.round(La * 255).astype(np.uint8)
    return out


def save(layer, art, palette=False):
    """layer RGBA ndarray -> out/hang_two/<art>.png and (with --write) assets/outfit/<art>/climb/climb-hang-two.png"""
    im = Image.fromarray(layer, 'RGBA')
    im.save(f'{OUTD}/{art}.png', optimize=True)
    if WRITE:
        d = f'{HERE}/assets/outfit/{art}/climb'; os.makedirs(d, exist_ok=True)
        if palette: im.quantize(128, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(f'{d}/climb-hang-two.png', 'PNG', optimize=True)
        else: im.save(f'{d}/climb-hang-two.png', optimize=True)


def shoes_and_bag(o):
    import shoes as S, chalkbag as CB
    # ---- shoes: vivid orange upper in a box round each foot, grown over its anti-aliased pink rim ----
    H, Sa, V = S.hsv(o[..., :3])
    box = np.zeros(o.shape[:2], bool)
    for x0, y0, x1, y1 in [(225, 760, 320, 910), (325, 760, 420, 910)]: box[y0:y1, x0:x1] = True
    core = box & (o[..., 3] > 200) & (H > 10) & (H < 42) & (Sa > 0.72) & (V > 0.45)
    core = ndi.binary_opening(core, np.ones((2, 2))) | (core & ndi.binary_dilation(ndi.binary_erosion(core)))
    lab, k = ndi.label(core, np.ones((3, 3))); sz = ndi.sum(core, lab, range(1, k + 1)); core = np.isin(lab, [i + 1 for i, s in enumerate(sz) if s >= 25])
    m = core.copy()
    for _ in range(3):
        m |= ndi.binary_dilation(m, np.ones((3, 3))) & ~m & box & (o[..., 3] > 200) & (H > 8) & (H < 45) & (Sa > 0.5) & (V > 0.28)
    for _ in range(8):
        m |= ndi.binary_dilation(m, np.ones((3, 3))) & ~m & box & (o[..., 3] > 200) & (H > 8) & (H < 42) & (Sa > 0.62) & (V > 0.50) & (o[..., 0] > 1.9 * o[..., 2])
    for _ in range(14):
        m |= ndi.binary_dilation(m, np.ones((3, 3))) & ~m & box & (o[..., 3] > 200) & (H > 3) & (H < 34) & (Sa > 0.76) & (V > 0.40) & (o[..., 0] > 2.0 * o[..., 2])
    for _ in range(5):   # pink / salmon anti-aliased rim of the orange panel (semi-transparent edge pixels)
        m |= ndi.binary_dilation(m, np.ones((3, 3))) & ~m & box & (o[..., 3] > 20) & ((H < 40) | (H > 340)) & (Sa > 0.36) & (V > 0.55) & (o[..., 0] > 1.5 * o[..., 2])
    m = ndi.binary_closing(m, np.ones((3, 3))) & (o[..., 3] > 200) & (H > 5) & (H < 48) & (Sa > 0.35) | m
    rc = S.recolor(o, m.astype(np.float32)); r = o.copy(); r[m, :3] = np.round(rc[m]).astype(np.uint8)
    sh = delta(o, r)
    # ---- chalk bag: chalkbag.py's luminance-ramp teal, plus the orange bits it leaves on the rim ----
    a0, w0, _ = CB.process(SRC + '/idle/idle-01.png', 'idle/idle-01', ramp_only=True)
    rgb = a0[..., :3].astype(float); Y0 = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255
    CB.RAMP_Y = np.maximum.accumulate(np.percentile(Y0[w0 > 0.9], [2, 25, 50, 75, 98]) + np.arange(5) * 1e-4)
    CB.ROI[N] = (360, 480, 450, 630)
    ob, w, sel = CB.process(f'{SRC}/{N}.png', N)
    Hb, Sb, Vb = CB.hsv(o[..., :3])
    body = ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(w > 0.5, iterations=4)), iterations=3); body[:, :372] = False
    extra = body & (w < 0.9) & (o[..., 3] > 20) & ((Hb < 42) | (Hb > 340)) & (Sb > 0.48) & (Vb > 0.33) & (o[..., 0] > 1.7 * o[..., 2])
    w = np.maximum(w, extra.astype(np.float32)); ob = CB.recolor(o, w)
    bg = delta(o, ob)
    for item, art, lay in (('shoes', 'blue', sh), ('chalkbag', 'teal', bg)):
        save(lay, art)
        # the segmenter protects the shoe and bag pixels through these (dev/outfit/export/<item>/...)
        p = f'{O}/export/{item}/climb/climb-hang-two.png'; os.makedirs(os.path.dirname(p), exist_ok=True); Image.fromarray(lay, 'RGBA').save(p, optimize=True)
    print('shoes px', int(m.sum()), 'bag px', int((w > 0).sum()))


def shirt_shorts():
    import seg3, build
    # masks (after the shoe / bag layers above exist, so the segmenter can protect them)
    s = seg3.segment3(N); h = s['hard']; d = s['dbg']
    os.makedirs(build.MK, exist_ok=True)
    np.savez_compressed(f"{build.MK}/{N.replace('/', '__')}.npz", shirt=h['shirt'], shorts=h['shorts'], head=h['head'], skin=h['skin'], rope=h['rope'],
        keep=h['keep'], belt=d['belt'], bag=d['bag'], shoes=d['shoes'], dust=d['dust'], eye=s['eye'], shirt_w=s['shirt'], shorts_w=s['shorts'])
    P = json.load(open(O + '/out/shirt_shorts/build_params.json'))
    for item in ('shirt', 'shorts'):
        a, m, other, Y, core, al = build.make_layer(item, N)
        g = build.to_grey(Y, P[item]['gain'])
        lay = build.finish(a, m, other, al, g)
        save(lay, item, palette=True)
        print(item, 'px', int(m.sum()), 'mean grey', round(float(g[core].mean()), 1) if core.any() else None)


def headwear():
    import headband5 as hb, hats_pilot as hp, hats3_pilot as h3
    hb.OUT = OUTD + '/hb5'; os.makedirs(hb.OUT, exist_ok=True)
    pose, res, comp, layer, info = hb.run(N, overrides=POSE)
    save(np.asarray(layer), 'teal-knit')
    hp.POSE_OVR[N] = dict(POSE, yaw=180.0)   # seen from behind
    h3.OUT = OUTD + '/hats3'; os.makedirs(h3.OUT, exist_ok=True)
    pose, comp, layer, t = h3.run('headlamp', N)
    save(np.asarray(layer), 'headlamp', palette=True)
    print('headlamp conf', round(float(pose['conf']), 2))


def variants():
    os.system(f'cd {O}/variants && {sys.executable} variants3.py {N} && {sys.executable} compress3.py {N}')
    if WRITE:
        for v in ('slate', 'sandstone', 'moss'):
            d = f'{HERE}/assets/mascot/climber/variants/{v}/climb'; os.makedirs(d, exist_ok=True)
            shutil.copy(f'{O}/out/variants3_assets/{v}/climb/climb-hang-two.png', f'{d}/climb-hang-two.png')


if __name__ == '__main__':
    o = np.array(Image.open(f'{SRC}/{N}.png').convert('RGBA'))
    shoes_and_bag(o)
    shirt_shorts()
    headwear()
    variants()
    print('done', 'WROTE assets' if WRITE else '(dry run: nothing in assets/)')
