import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

def make_snack(in_path, out_path, ellipses, brown_box, pad=6):
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    arr = np.array(img).astype(np.int32)
    # 1) Geometric erase of the bowl bulk (safe bottom-corner region).
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    for cx, cy, rx, ry in ellipses:
        md.ellipse([(w*(cx-rx), h*(cy-ry)), (w*(cx+rx), h*(cy+ry))], fill=255)
    geom = np.array(mask) > 0
    # 2) Brown-food removal inside a mouth bounding box only.
    x0b, y0b, x1b, y1b = brown_box
    bx0, by0, bx1, by1 = int(w*x0b), int(h*y0b), int(w*x1b), int(h*y1b)
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    brownish = (r < 180) & (g < 140) & (b < 120) & (r - b > 22) & (r >= g - 5)
    region = np.zeros((h, w), bool)
    region[by0:by1, bx0:bx1] = True
    brown = brownish & region
    erase = geom | brown
    arr[erase, 3] = 0
    # 3) Largest opaque component + tight crop.
    alpha = arr[:,:,3] > 8
    lbl, n = ndimage.label(alpha)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n+1))
        alpha = lbl == (int(np.argmax(sizes)) + 1)
        arr[~alpha, 3] = 0
    ys, xs = np.where(alpha)
    y0, y1 = max(0, ys.min()-pad), min(h, ys.max()+1+pad)
    x0, x1 = max(0, xs.min()-pad), min(w, xs.max()+1+pad)
    Image.fromarray(arr[y0:y1, x0:x1].astype(np.uint8), "RGBA").save(out_path)
    print(f"{out_path}: {x1-x0}x{y1-y0}")

make_snack("BabyTown/calico.atlas/eat_0.png", ".derivedData/trickclean/snack_calico_test.png",
           [(0.79, 0.90, 0.21, 0.14), (0.70, 0.82, 0.13, 0.10)],
           brown_box=(0.58, 0.72, 0.86, 0.95))
make_snack("BabyTown/cowcat.atlas/eat_1.png", ".derivedData/trickclean/snack_cowcat_test.png",
           [(0.24, 0.91, 0.21, 0.13), (0.32, 0.82, 0.13, 0.10)],
           brown_box=(0.12, 0.72, 0.44, 0.95))
