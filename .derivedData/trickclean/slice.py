import numpy as np
from PIL import Image
from scipy import ndimage

def clean_arr(arr, black_thresh=60, pad=4):
    arr = arr.astype(np.int32)
    h, w = arr.shape[:2]
    luminance = arr[:, :, :3].max(axis=2)
    dark = luminance <= black_thresh
    lbl, n = ndimage.label(dark)
    border = set(lbl[0, :]).union(lbl[-1, :]).union(lbl[:, 0]).union(lbl[:, -1])
    border.discard(0)
    background = np.isin(lbl, list(border))
    subject = ~background
    slbl, sn = ndimage.label(subject)
    if sn > 1:
        sizes = ndimage.sum(np.ones_like(slbl), slbl, index=range(1, sn + 1))
        subject = slbl == (int(np.argmax(sizes)) + 1)
    out = arr.copy()
    out[~subject, 3] = 0
    ys, xs = np.where(subject)
    if len(ys) == 0: return None
    y0, y1 = max(0, ys.min()-pad), min(h, ys.max()+1+pad)
    x0, x1 = max(0, xs.min()-pad), min(w, xs.max()+1+pad)
    return out[y0:y1, x0:x1].astype(np.uint8)

master = np.array(Image.open("BabyTown/calico.atlas/spin_2.png").convert("RGBA"))
H, W = master.shape[:2]
ch, cw = H // 2, W // 4
for r in range(2):
    for c in range(4):
        cell = master[r*ch:(r+1)*ch, c*cw:(c+1)*cw]
        res = clean_arr(cell)
        if res is not None:
            Image.fromarray(res, "RGBA").save(f".derivedData/trickclean/cell_{r}_{c}.png")
            print(f"cell_{r}_{c}: {res.shape[1]}x{res.shape[0]}")
