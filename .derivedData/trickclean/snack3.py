import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

def make_snack(in_path, out_path, ellipses, brown_box, food_box, pad=6, flip=False):
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    arr = np.array(img).astype(np.int32)
    mask = Image.new("L", (w, h), 0); md = ImageDraw.Draw(mask)
    for cx, cy, rx, ry in ellipses:
        md.ellipse([(w*(cx-rx), h*(cy-ry)), (w*(cx+rx), h*(cy+ry))], fill=255)
    geom = np.array(mask) > 0
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    mx = np.maximum(np.maximum(r, g), b)
    def box(bx):
        x0,y0,x1,y1 = bx; reg = np.zeros((h,w), bool)
        reg[int(h*y0):int(h*y1), int(w*x0):int(w*x1)] = True; return reg
    # dark brown food near the mouth
    dark = (r < 180) & (g < 140) & (b < 120) & (r - b > 22) & (r >= g - 5) & box(brown_box)
    # lighter orange-brown food mound on the white chest (no fur there)
    light = (r - b > 45) & (g - b > 12) & (mx < 238) & (b < 165) & box(food_box)
    arr[geom | dark | light, 3] = 0
    alpha = arr[:,:,3] > 8
    lbl, n = ndimage.label(alpha)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n+1))
        alpha = lbl == (int(np.argmax(sizes)) + 1); arr[~alpha, 3] = 0
    ys, xs = np.where(alpha)
    y0, y1 = max(0, ys.min()-pad), min(h, ys.max()+1+pad)
    x0, x1 = max(0, xs.min()-pad), min(w, xs.max()+1+pad)
    out = Image.fromarray(arr[y0:y1, x0:x1].astype(np.uint8), "RGBA")
    if flip:
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    out.save(out_path)
    print(f"{out_path}: {x1-x0}x{y1-y0}")

make_snack("BabyTown/calico.atlas/eat_0.png", ".derivedData/trickclean/snack_calico_test.png",
           [(0.79,0.90,0.21,0.14),(0.70,0.82,0.13,0.10)],
           brown_box=(0.58,0.72,0.86,0.95), food_box=(0.62,0.79,0.92,0.98), flip=True)
make_snack("BabyTown/cowcat.atlas/eat_1.png", ".derivedData/trickclean/snack_cowcat_test.png",
           [(0.24,0.91,0.21,0.13),(0.32,0.82,0.13,0.10)],
           brown_box=(0.12,0.72,0.44,0.95), food_box=(0.10,0.79,0.40,0.98))

# Finalize: write into both atlases as snack_0.png, downscaled to height<=512
def finalize(src_test, dst):
    img = Image.open(src_test).convert("RGBA")
    w, h = img.size
    if h > 512:
        s = 512 / h
        img = img.resize((max(1,int(w*s)), 512), Image.LANCZOS)
    img.save(dst)
    print(f"{dst}: {img.size[0]}x{img.size[1]}")

finalize(".derivedData/trickclean/snack_calico_test.png", "BabyTown/calico.atlas/snack_0.png")
finalize(".derivedData/trickclean/snack_cowcat_test.png", "BabyTown/cowcat.atlas/snack_0.png")
