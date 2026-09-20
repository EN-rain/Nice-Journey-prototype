"""Derive the six NPC 32px anchor review cells from the accepted 3x2 source sheet.

Only deterministic crop, NEAREST reduction, alpha canonicalization, and integer
translation to the shared (16,29) presentation anchor are performed.
"""
from pathlib import Path
from PIL import Image

SOURCE = Path("assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png")
OUTPUT = Path("assets/art/generated_sources/imagegen/npc/review")
ROLES = ("coordinator", "merchant", "blacksmith", "lore_elder", "variable_quest", "escort")
CELL_SIZE = 512
FRAME_SIZE = 32
GROUND_ANCHOR = (16, 29)


def derive() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (1536, 1024):
        raise ValueError(f"expected 1536x1024 source, got {source.size}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, role in enumerate(ROLES):
        col, row = index % 3, index // 3
        frame = source.crop((col * CELL_SIZE, row * CELL_SIZE,
                             (col + 1) * CELL_SIZE, (row + 1) * CELL_SIZE))
        frame = frame.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)
        bbox = frame.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"{role} has no visible pixels")
        center_x = (bbox[0] + bbox[2] - 1) / 2
        bottom_y = bbox[3] - 1
        translated = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
        translated.alpha_composite(frame, (round(GROUND_ANCHOR[0] - center_x),
                                            round((GROUND_ANCHOR[1] + 1) - bottom_y)))
        pixels = translated.load()
        for y in range(FRAME_SIZE):
            for x in range(FRAME_SIZE):
                if pixels[x, y][3] == 0:
                    pixels[x, y] = (0, 0, 0, 0)
        translated.save(OUTPUT / f"npc_{role}_anchor_v01.png")


if __name__ == "__main__":
    derive()
