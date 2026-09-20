"""Read-only source segmentation diagnostics for the player V04 body-only sheets."""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/generated_sources/imagegen/player/body_only_v04"


def report(name, rows):
    image = np.asarray(Image.open(SOURCE / name).convert("RGBA"))
    print(name, image.shape)
    for label, (y0, y1, positions) in rows.items():
        print(" ROW", label, y0, y1)
        row_mask = image[y0:y1, :, 3] >= 24
        row_components, row_count = ndimage.label(row_mask, structure=np.ones((3, 3), dtype=bool))
        row_objects = ndimage.find_objects(row_components)
        row_sizes = np.bincount(row_components.ravel(), minlength=row_count + 1)
        print(" GLOBAL", [(int(row_sizes[k]), (s[1].start, s[0].start + y0, s[1].stop, s[0].stop + y0)) for k, s in enumerate(row_objects, 1) if s is not None and row_sizes[k] > 100])
        for i, (x0, x1) in enumerate(positions):
            a = image[y0:y1, x0:x1, 3] >= 24
            connected, count = ndimage.label(a, structure=np.ones((3, 3), dtype=bool))
            objects = ndimage.find_objects(connected)
            sizes = np.bincount(connected.ravel(), minlength=count + 1)
            ranked = sorted(range(1, count + 1), key=lambda k: -sizes[k])[:7]
            print(" ", i, "cell", (x0, x1), "components", count)
            for k in ranked:
                sy, sx = objects[k - 1]
                print("    ", sizes[k], (sx.start + x0, sy.start + y0, sx.stop + x0, sy.stop + y0))


def equal(w, n):
    return [(round(w * i / n), round(w * (i + 1) / n)) for i in range(n)]


if __name__ == "__main__":
    report("player_attack_body_only_source.png", {"attack": (0, 724, equal(2171, 6))})
    report("player_heavy_attack_body_only_source.png", {"heavy": (0, 724, equal(2171, 6))})
    report("player_block_body_only_source.png", {"block": (0, 724, equal(2171, 7))})
    report("player_parry_cast_hit_body_only_source.png", {
        "parry": (0, 362, [(35, 214), (271, 450), (494, 677), (744, 928), (981, 1158), (1202, 1374)]),
        "cast": (362, 724, [(23, 188), (217, 398), (422, 588), (618, 802), (830, 1001), (1058, 1230), (1250, 1412)]),
        "hit": (724, 1086, [(24, 230), (257, 461), (485, 704), (748, 941), (979, 1161), (1206, 1375)]),
    })
