"""Make a deterministic checkerboard comparison of rejected V04 and R2 candidates.

Diagnostic only: it never touches existing source/runtime textures or manifests.
The R2 candidates use common-source scaling and complete row components.
"""

import argparse
import hashlib
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / "assets/art/player/animations"
DEST = ROOT / "player_body_v04_r2_comparison_candidate.png"
STATES = ["attack", "heavy_attack", "block", "parry", "cast", "hit"]
SCALE = 4
LEFT = 134
WIDTH = LEFT + 7 * 32 * SCALE + 24
ROW_H = 292


def checkerboard(width, height):
    tile = 8
    image = Image.new("RGBA", (width, height), (57, 57, 57, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(95, 95, 95, 255))
    return image


def render():
    canvas = Image.new("RGBA", (WIDTH, ROW_H * len(STATES) + 48), (24, 24, 24, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.text((12, 13), "PLAYER V04: REJECTED DERIVATION vs R2 BODY COMPONENT + UNIFORM SCALE", fill="white", font=font)
    for index, state in enumerate(STATES):
        y = 48 + index * ROW_H
        old_suffix = "_v04_staged.png" if state == "block" else "_v04.png"
        old = Image.open(ROOT / f"player_body_{state}_sheet{old_suffix}").convert("RGBA")
        new = Image.open(ROOT / f"player_body_{state}_sheet_v04_r2_candidate.png").convert("RGBA")
        if old.height != 32 or new.height != 32:
            raise ValueError(f"wrong canvas height: {state}")
        for offset, (title, strip) in enumerate((("rejected V04", old), ("R2 candidate", new))):
            strip_y = y + 16 + offset * 138
            draw.text((12, strip_y + 38), f"{state}\n{title}\n{strip.width // 32} frames", fill="white", font=font, spacing=3)
            backdrop = checkerboard(7 * 32 * SCALE, 32 * SCALE)
            backdrop.alpha_composite(strip.resize((strip.width * SCALE, 32 * SCALE), Image.Resampling.NEAREST))
            canvas.alpha_composite(backdrop, (LEFT, strip_y))
        draw.line((0, y + ROW_H - 1, WIDTH, y + ROW_H - 1), fill=(160, 160, 160), width=1)
    file = io.BytesIO()
    canvas.save(file, format="PNG")
    return file.getvalue()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = render()
    if args.check:
        if not DEST.is_file() or DEST.read_bytes() != data:
            raise ValueError(f"diagnostic missing or changed: {DEST}")
    else:
        DEST.write_bytes(data)
    print(f"{'BYTE_IDENTICAL' if args.check else 'WROTE'} {DEST.relative_to(PROJECT)} "
          f"sha256={hashlib.sha256(data).hexdigest()} size={Image.open(io.BytesIO(data)).size}")
