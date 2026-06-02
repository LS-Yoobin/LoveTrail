from PIL import Image, ImageDraw
for atlas, f in [("calico.atlas","eat_0"),("cowcat.atlas","eat_1")]:
    img = Image.open(f"BabyTown/{atlas}/{f}.png").convert("RGBA")
    w,h = img.size
    d = ImageDraw.Draw(img)
    for i in range(1,10):
        d.line([(w*i/10,0),(w*i/10,h)], fill=(255,0,0,160), width=1)
        d.line([(0,h*i/10),(w,h*i/10)], fill=(0,0,255,160), width=1)
    img.save(f".derivedData/trickclean/{f}_grid.png")
    print(atlas, f, w, h)
