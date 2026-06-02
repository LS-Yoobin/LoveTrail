import numpy as np
from PIL import Image
from scipy import ndimage

def clean(arr, black_thresh=60, pad=6, erode=1):
    arr = arr.astype(np.int32)
    h, w = arr.shape[:2]
    lum = arr[:, :, :3].max(axis=2)
    dark = lum <= black_thresh
    lbl, n = ndimage.label(dark)
    border = set(lbl[0, :]).union(lbl[-1, :]).union(lbl[:, 0]).union(lbl[:, -1])
    border.discard(0)
    background = np.isin(lbl, list(border))
    subject = ~background
    slbl, sn = ndimage.label(subject)
    if sn > 1:
        sizes = ndimage.sum(np.ones_like(slbl), slbl, index=range(1, sn + 1))
        subject = slbl == (int(np.argmax(sizes)) + 1)
    # Erode 1px to drop the dark anti-aliased rim left against the black bg.
    if erode > 0:
        subject = ndimage.binary_erosion(subject, iterations=erode)
    out = arr.copy()
    out[~subject, 3] = 0
    ys, xs = np.where(subject)
    y0, y1 = max(0, ys.min()-pad), min(h, ys.max()+1+pad)
    x0, x1 = max(0, xs.min()-pad), min(w, xs.max()+1+pad)
    return out[y0:y1, x0:x1].astype(np.uint8), sn-1

def clean_file(path):
    arr = np.array(Image.open(path).convert("RGBA"))
    res, dropped = clean(arr)
    Image.fromarray(res, "RGBA").save(path)
    return res.shape[1], res.shape[0], dropped

def extract_paw(master_path, out_path):
    master = np.array(Image.open(master_path).convert("RGBA"))
    H, W = master.shape[:2]
    ch, cw = H // 2, W // 4
    cell = master[0:ch, 0:cw]            # row 0, col 0 = paw-forward pose
    res, _ = clean(cell)
    Image.fromarray(res, "RGBA").save(out_path)
    return res.shape[1], res.shape[0]

import os
for atlas in ["calico.atlas", "cowcat.atlas"]:
    base = f"BabyTown/{atlas}"
    for f in ["highFive_0", "up_0", "down_0", "sayHi_0", "spin_0", "spin_1"]:
        w, h, d = clean_file(f"{base}/{f}.png")
        print(f"{atlas}/{f}: {w}x{h} (dropped {d})")
    # paw: extract clean paw pose from the master sheet before deleting it
    w, h = extract_paw(f"{base}/spin_2.png", f"{base}/paw_0.png")
    print(f"{atlas}/paw_0: {w}x{h} (from master cell 0,0)")
    os.remove(f"{base}/spin_2.png")
    print(f"{atlas}/spin_2.png: deleted")
