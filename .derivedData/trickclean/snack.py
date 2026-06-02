import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

def erase_and_crop(in_path, out_path, ellipses, pad=6):
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    # Build an erase mask from normalized ellipses [(cx,cy,rx,ry), ...]
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    for cx, cy, rx, ry in ellipses:
        md.ellipse([(w*(cx-rx), h*(cy-ry)), (w*(cx+rx), h*(cy+ry))], fill=255)
    arr = np.array(img)
    m = np.array(mask) > 0
    arr[m, 3] = 0
    # Crop to remaining opaque content (largest component, drops stray bits)
    alpha = arr[:, :, 3] > 8
    lbl, n = ndimage.label(alpha)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n+1))
        alpha = lbl == (int(np.argmax(sizes)) + 1)
        arr[~alpha, 3] = 0
    ys, xs = np.where(alpha)
    y0, y1 = max(0, ys.min()-pad), min(h, ys.max()+1+pad)
    x0, x1 = max(0, xs.min()-pad), min(w, xs.max()+1+pad)
    Image.fromarray(arr[y0:y1, x0:x1], "RGBA").save(out_path)
    print(f"{out_path}: {x1-x0}x{y1-y0}")

# calico: bowl bottom-right; erase bowl + food mound up toward the mouth
erase_and_crop("BabyTown/calico.atlas/eat_0.png", ".derivedData/trickclean/snack_calico_test.png",
               [(0.79, 0.90, 0.20, 0.13), (0.70, 0.80, 0.12, 0.09)])
# cowcat: bowl bottom-left
erase_and_crop("BabyTown/cowcat.atlas/eat_1.png", ".derivedData/trickclean/snack_cowcat_test.png",
               [(0.24, 0.91, 0.20, 0.12), (0.32, 0.80, 0.12, 0.09)])
