"""Deterministic offline comparison, never a claim of Godot renderer acceptance."""

import argparse
import hashlib
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art/player/animations"
DEST = ART / "player_remaining_v03_r2_comparison_candidate.png"
STATES = ("interact", "use_item", "death", "dodge")
ZOOM = 4
LEFT = 150
WIDTH = LEFT + 7 * 32 * ZOOM + 16
ROW = 286


def checker(w, h):
    image = Image.new("RGBA", (w, h), (54, 54, 54, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=(99, 99, 99, 255))
    return image


def render():
    board = Image.new("RGBA", (WIDTH, 42 + ROW * len(STATES)), (24, 24, 24, 255))
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    draw.text((12, 10), "PLAYER V03 remaining: original LANCZOS vs candidate NEAREST/common scale", fill="white", font=font)
    for i, state in enumerate(STATES):
        for j, (note, suffix) in enumerate((("live V03", "_v03.png"), ("R2 review candidate", "_v03_r2_candidate.png"))):
            strip = Image.open(ART / f"player_body_{state}_sheet{suffix}").convert("RGBA")
            if strip.height != 32 or strip.width % 32:
                raise ValueError(state)
            y = 42 + i * ROW + j * 140
            draw.text((12, y + 38), f"{state}\n{note}\n{strip.width // 32} frames", fill="white", font=font, spacing=3)
            background = checker(7 * 32 * ZOOM, 32 * ZOOM)
            background.alpha_composite(strip.resize((strip.width * ZOOM, 32 * ZOOM), Image.Resampling.NEAREST))
            board.alpha_composite(background, (LEFT, y))
        draw.line((0, 42 + (i + 1) * ROW - 1, WIDTH, 42 + (i + 1) * ROW - 1), fill=(140, 140, 140))
    buffer = io.BytesIO()
    board.save(buffer, format="PNG")
    return buffer.getvalue()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = render()
    if args.check:
        if not DEST.exists() or DEST.read_bytes() != data:
            raise ValueError(f"comparison not reproducible: {DEST}")
    else:
        if DEST.exists() and DEST.read_bytes() != data:
            raise FileExistsError(f"refuse to overwrite existing comparison: {DEST}")
        if not DEST.exists():
            DEST.write_bytes(data)
    print(f"{'BYTE_IDENTICAL' if args.check else 'WROTE_OR_IDENTICAL'} "
          f"{DEST.relative_to(ROOT)} sha256={hashlib.sha256(data).hexdigest()} size={Image.open(io.BytesIO(data)).size}")
