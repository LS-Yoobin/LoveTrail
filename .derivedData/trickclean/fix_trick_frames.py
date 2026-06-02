"""Regenerate confused_0 and snack_0 with safer cropping."""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ASSETS = "/Users/justinseo/.cursor/projects/Users-justinseo-Desktop-BabyTown/assets"
MAX_H = 512
PAD = 24


def remove_black_background(arr: np.ndarray, black_thresh: int = 32, pad: int = PAD) -> np.ndarray:
    """Remove near-black background; white margin keeps dark fur off the image edge."""
    arr = arr.astype(np.int32)
    margin = 48
    h, w = arr.shape[:2]
    padded = np.full((h + 2 * margin, w + 2 * margin, 4), 255, dtype=np.int32)
    padded[margin : margin + h, margin : margin + w] = arr
    rgb = padded[:, :, :3]
    lum = rgb.max(axis=2)
    dark = lum <= black_thresh
    lbl, n = ndimage.label(dark)
    border = set(lbl[0, :]).union(lbl[-1, :]).union(lbl[:, 0]).union(lbl[:, -1])
    border.discard(0)
    background = np.isin(lbl, list(border))
    subject = ~background
    slbl, sn = ndimage.label(subject)
    if sn > 1:
        sizes = ndimage.sum(np.ones_like(slbl), slbl, index=range(1, sn + 1))
        largest = float(np.max(sizes))
        keep = {i + 1 for i, s in enumerate(sizes) if s >= largest * 0.02}
        subject = np.isin(slbl, list(keep))
    subject = ndimage.binary_dilation(subject, iterations=2)
    out = padded.copy()
    out[~subject, 3] = 0
    out = out[margin : margin + h, margin : margin + w]
    ys, xs = np.where(subject[margin : margin + h, margin : margin + w])
    y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + 1 + pad)
    return out[y0:y1, x0:x1].astype(np.uint8)


def scale_to_max_height(img: Image.Image, max_h: int = MAX_H) -> Image.Image:
    w, h = img.size
    if h <= max_h:
        return img
    s = max_h / h
    return img.resize((max(1, int(w * s)), max_h), Image.LANCZOS)


def finalize_rgba(arr: np.ndarray) -> Image.Image:
    return scale_to_max_height(Image.fromarray(arr, "RGBA"))


def keep_significant_components(alpha: np.ndarray, min_fraction: float = 0.04) -> np.ndarray:
    """Keep all opaque blobs large enough to be cat parts (head + body after bowl erase)."""
    lbl, n = ndimage.label(alpha)
    if n <= 1:
        return alpha
    sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n + 1))
    largest = float(np.max(sizes))
    keep_labels = {i + 1 for i, s in enumerate(sizes) if s >= largest * min_fraction}
    return np.isin(lbl, list(keep_labels))


def crop_opaque(arr: np.ndarray, pad: int = 10) -> np.ndarray:
    alpha = arr[:, :, 3] > 8
    ys, xs = np.where(alpha)
    if len(ys) == 0:
        return arr
    h, w = arr.shape[:2]
    y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + 1 + pad)
    return arr[y0:y1, x0:x1]


def erase_bowl_only(arr: np.ndarray, floor_rect) -> np.ndarray:
    """Remove only bright bowl pixels — food shares colors with fur and erases the face."""
    arr = arr.copy()
    h, w = arr.shape[:2]
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    a = arr[:, :, 3]

    fx0, fy0, fx1, fy1 = floor_rect
    floor = np.zeros((h, w), bool)
    floor[int(h * fy0) : int(h * fy1), int(w * fx0) : int(w * fx1)] = True
    lum = np.maximum(np.maximum(r, g), b)
    bowl = floor & (lum > 185) & (a > 0) & (np.abs(r.astype(int) - g.astype(int)) < 25)
    arr[bowl, 3] = 0
    return arr


def make_cowcat_snack(in_path, out_path):
    """Flip eat_1 so the cat faces right; bowl removal clips the muzzle, so keep eat art."""
    out = Image.open(in_path).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    finalize_rgba(np.array(out)).save(out_path)
    print(f"snack (cowcat) -> {out_path} ({Image.open(out_path).size})")


def make_calico_snack(in_path, out_path, pad=10):
    """Calico eat_0: bowl on the right; flip after erase."""
    arr = np.array(Image.open(in_path).convert("RGBA"))
    arr = erase_bowl_only(arr, floor_rect=(0.62, 0.88, 1.0, 1.0))
    arr = crop_opaque(arr, pad)
    out = Image.fromarray(arr.astype(np.uint8), "RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    finalize_rgba(np.array(out)).save(out_path)
    print(f"snack (calico) -> {out_path} ({Image.open(out_path).size})")


def make_snack(in_path, out_path, ellipses, brown_box, food_box, pad=10, flip=False):
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    arr = np.array(img).astype(np.int32)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    for cx, cy, rx, ry in ellipses:
        md.ellipse([(w * (cx - rx), h * (cy - ry)), (w * (cx + rx), h * (cy + ry))], fill=255)
    geom = np.array(mask) > 0
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    mx = np.maximum(np.maximum(r, g), b)

    def box(bx):
        x0, y0, x1, y1 = bx
        reg = np.zeros((h, w), bool)
        reg[int(h * y0) : int(h * y1), int(w * x0) : int(w * x1)] = True
        return reg

    dark = (
        (r < 180)
        & (g < 140)
        & (b < 120)
        & (r - b > 22)
        & (r >= g - 5)
        & box(brown_box)
    )
    light = (r - b > 45) & (g - b > 12) & (mx < 238) & (b < 165) & box(food_box)
    arr[geom | dark | light, 3] = 0

    alpha = arr[:, :, 3] > 8
    alpha = keep_significant_components(alpha)
    arr[~alpha, 3] = 0
    ys, xs = np.where(alpha)
    y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + 1 + pad)
    out = Image.fromarray(arr[y0:y1, x0:x1].astype(np.uint8), "RGBA")
    if flip:
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    finalize_rgba(np.array(out)).save(out_path)
    print(f"snack -> {out_path} ({Image.open(out_path).size})")


def confused_from_source(src, dst):
    arr = np.array(Image.open(src).convert("RGBA"))
    cleaned = remove_black_background(arr)
    finalize_rgba(cleaned).save(dst)
    print(f"confused -> {dst} ({Image.open(dst).size})")


if __name__ == "__main__":
    confused_from_source(
        f"{ASSETS}/trick_confused_0-177b5344-2ee4-446d-b1bb-bd134c6b11d5.png",
        "BabyTown/calico.atlas/confused_0.png",
    )
    confused_from_source(
        f"{ASSETS}/trick_confused_1-90b29fe1-2b1e-4b8c-b119-c7958c757528.png",
        "BabyTown/cowcat.atlas/confused_0.png",
    )

    make_calico_snack(
        "BabyTown/calico.atlas/eat_0.png",
        "BabyTown/calico.atlas/snack_0.png",
    )

    make_cowcat_snack(
        "BabyTown/cowcat.atlas/eat_1.png",
        "BabyTown/cowcat.atlas/snack_0.png",
    )
