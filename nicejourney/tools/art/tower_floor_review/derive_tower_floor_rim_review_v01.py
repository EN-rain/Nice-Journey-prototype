#!/usr/bin/env python3
"""Review-only, pixel-exact rim reduction from the preserved tower V01 atlas.

The authored 4x4 TileSet and its source remain untouched. Only the INNER
1-pixel part of the first-row floor tiles' two-pixel dark rims is changed.
No new colors or floor variants are authored by this transformation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[3]
SOURCE = PROJECT / "assets/art/environments/tower/tiles/tower_common_tileset_v01.png"
OUTPUT = Path(__file__).resolve().parent / "tower_common_tileset_floor_rim_review_v01.png"
EVIDENCE = OUTPUT.with_suffix(".json")
SOURCE_SHA256 = "b4851c0ba3a7b674c730fcdd756c8e21f256094b651a3958f6130dc525193129"
TILE_SIZE = 32


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def derive() -> tuple[Image.Image, dict]:
    if sha256(SOURCE) != SOURCE_SHA256:
        raise ValueError("the preserved tower V01 source hash changed")
    with Image.open(SOURCE) as source:
        if source.size != (128, 128) or source.mode != "RGBA":
            raise ValueError("expected the exact 128x128 RGBA V01 atlas")
        original = source.copy()
    result = original.copy()
    changed_per_cell = []
    for col in range(4):
        left = col * TILE_SIZE
        original_cell = original.crop((left, 0, left + TILE_SIZE, TILE_SIZE))
        revised_cell = original_cell.copy()
        for y in range(1, TILE_SIZE - 1):
            for x in range(1, TILE_SIZE - 1):
                if x in (1, TILE_SIZE - 2) or y in (1, TILE_SIZE - 2):
                    interior_x = max(2, min(TILE_SIZE - 3, x))
                    interior_y = max(2, min(TILE_SIZE - 3, y))
                    revised_cell.putpixel((x, y), original_cell.getpixel((interior_x, interior_y)))
        core = (2, 2, 30, 30)
        if original_cell.crop(core).tobytes() != revised_cell.crop(core).tobytes():
            raise ValueError(f"tile {col} changed its protected 28x28 core")
        for offset in range(TILE_SIZE):
            if any(
                original_cell.getpixel(point) != revised_cell.getpixel(point)
                for point in ((0, offset), (31, offset), (offset, 0), (offset, 31))
            ):
                raise ValueError(f"tile {col} changed its original outer edge")
            if (
                revised_cell.getpixel((0, offset)) != revised_cell.getpixel((31, offset))
                or revised_cell.getpixel((offset, 0)) != revised_cell.getpixel((offset, 31))
            ):
                raise ValueError(f"tile {col} breaks opposite-edge continuity")
        if not set(revised_cell.getdata()).issubset(set(original_cell.getdata())):
            raise ValueError(f"tile {col} introduced an unauthorized color")
        changed = sum(a != b for a, b in zip(original_cell.getdata(), revised_cell.getdata()))
        if changed != 116:
            raise ValueError(f"tile {col} changed {changed} pixels instead of 116")
        changed_per_cell.append(changed)
        result.paste(revised_cell, (left, 0))

    if result.crop((0, 32, 128, 128)).tobytes() != original.crop((0, 32, 128, 128)).tobytes():
        raise ValueError("non-floor atlas rows were modified")
    for col in range(4):
        right = (col + 1) % 4
        for y in range(TILE_SIZE):
            if result.getpixel((col * 32 + 31, y)) != result.getpixel((right * 32, y)):
                raise ValueError(f"tile {col} does not meet tile {right} on horizontal floor routes")
    metadata = {
        "schema": "nicejourney.tower_floor_rim_review/v01",
        "status": "REVIEW_ONLY_NOT_ACCEPTED_NOT_BOUND",
        "source": "res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png",
        "source_sha256": SOURCE_SHA256,
        "output": "res://tools/art/tower_floor_review/tower_common_tileset_floor_rim_review_v01.png",
        "atlas_size": [128, 128],
        "cell_size": [32, 32],
        "edited_cell_coords": [[0, 0], [1, 0], [2, 0], [3, 0]],
        "source_transform": "copy inner dark rim pixels at x/y=1 or 30 from original nearest 28x28 core (clamp source coordinates to 2..29); preserve 1px outer edge",
        "changed_pixels_per_cell": changed_per_cell,
        "core_pixels_identical": True,
        "all_outer_edges_identical": True,
        "cross_variant_edges_match": True,
        "other_12_cells_identical": True,
        "acceptance_limit": "Two unique procedural floors remain; no final generated material source or production binding is claimed.",
    }
    return result, metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="create only the versioned review PNG and adjacent evidence JSON")
    args = parser.parse_args()
    candidate, metadata = derive()
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        candidate.save(OUTPUT, optimize=False)
        metadata["output_sha256"] = sha256(OUTPUT)
        EVIDENCE.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    else:
        if not OUTPUT.is_file() or not EVIDENCE.is_file():
            raise ValueError("review output missing; run --write first")
        with Image.open(OUTPUT) as output:
            if output.mode != "RGBA" or output.size != candidate.size or output.tobytes() != candidate.tobytes():
                raise ValueError("review PNG no longer matches deterministic derivation")
        if json.loads(EVIDENCE.read_text(encoding="utf-8")) != {**metadata, "output_sha256": sha256(OUTPUT)}:
            raise ValueError("review evidence no longer matches exact source/output hashes")
    print("TOWER FLOOR RIM REVIEW PASS: 4x116 inner-rim pixels only; 28x28 cores and 12 other cells identical; 32/32 edges match")


if __name__ == "__main__":
    main()
