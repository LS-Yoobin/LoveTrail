import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def clean(in_path, out_path, black_thresh=60, pad=6):
    img = Image.open(in_path).convert("RGBA")
    arr = np.array(img).astype(np.int32)
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3]
    # "dark" = near black background
    luminance = rgb.max(axis=2)
    dark = luminance <= black_thresh  # True where black-ish

    # Flood from borders: background = dark pixels connected to the image edge.
    # Label connected dark regions; any region touching the border is background.
    lbl, n = ndimage.label(dark)
    border_labels = set(lbl[0, :]).union(lbl[-1, :]).union(lbl[:, 0]).union(lbl[:, -1])
    border_labels.discard(0)
    background = np.isin(lbl, list(border_labels))

    # Opaque subject mask = not background
    subject = ~background
    # Keep only the largest connected subject component (drops neighbor bleed).
    slbl, sn = ndimage.label(subject)
    if sn > 1:
        sizes = ndimage.sum(np.ones_like(slbl), slbl, index=range(1, sn + 1))
        keep = int(np.argmax(sizes)) + 1
        subject = slbl == keep

    out = arr.copy()
    out[~subject, 3] = 0  # transparent background + dropped fragments

    # Crop to subject bbox with small padding
    ys, xs = np.where(subject)
    y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + 1 + pad)
    cropped = out[y0:y1, x0:x1].astype(np.uint8)
    Image.fromarray(cropped, "RGBA").save(out_path)
    print(f"{in_path}: {w}x{h} -> {x1-x0}x{y1-y0} (components dropped: {sn-1})")

if __name__ == "__main__":
    clean(sys.argv[1], sys.argv[2])
