import json
import os
import sys

def create_contents_json(filename):
    content = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x"
            },
            {
                "idiom": "universal",
                "scale": "2x"
            },
            {
                "idiom": "universal",
                "scale": "3x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    return json.dumps(content, indent=2)

base_path = "/Users/justinseo/Desktop/BabyTown/BabyTown/Assets.xcassets"
variants = range(1, 6)

for i in variants:
    folder = os.path.join(base_path, f"cat_variant_{i}.imageset")
    json_path = os.path.join(folder, "Contents.json")
    image_filename = f"cat_variant_{i}.png"
    
    with open(json_path, "w") as f:
        f.write(create_contents_json(image_filename))
    print(f"Created {json_path}")
