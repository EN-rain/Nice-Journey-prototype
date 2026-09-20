#!/usr/bin/env python3
"""Assemble a review-only four-cell map glyph candidate from accepted core9 art.

The UI visual bible names three quest-family symbols and the Tower Sigil. Their
existing 32px icons have exact immutable ImageGen source attribution. This tool
reuses those pixels without implying discovered quest coordinates, travel, or
replacement of the live procedural map_marker_sheet_v01.png.

Run with --apply once to write only the review output, then without flags to
verify its bytes and per-cell identities. Never touches accepted production art.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

from audit_ui_core9_attribution import CORE9, SOURCE, SOURCE_HASH
from verify_ui_core9_exact_derivation import verify as verify_core9


ROOT = Path(__file__).resolve().parents[2]
REVIEW_DIR = ROOT / "assets/art/ui/markers/review"
OUTPUT = REVIEW_DIR / "map_marker_quest_sigil_v02_candidate.png"
RECORD = REVIEW_DIR / "map_marker_quest_sigil_v02_candidate.json"
CELL_NAMES = (
    "quest_family_escort",
    "quest_family_tower_defense",
    "quest_family_annihilation",
    "tower_sigil",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def produce() -> tuple[bytes, dict]:
    verified = verify_core9()
    if digest(SOURCE.read_bytes()) != SOURCE_HASH:
        raise ValueError("preserved ImageGen source changed")
    lookup = {item["asset_id"]: item for item in verified}
    icons = {name: (index, rel, expected)
             for index, (name, rel, expected) in enumerate(CORE9)}
    sheet = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    cells = []
    masks = []
    for cell_index, name in enumerate(CELL_NAMES):
        source_index, relative_path, expected_sha = icons[name]
        path = ROOT / "assets/art/ui" / relative_path
        data = path.read_bytes()
        if digest(data) != expected_sha or lookup[name]["exact_png_sha256"] != expected_sha:
            raise ValueError(f"accepted icon no longer matches its source: {name}")
        with Image.open(io.BytesIO(data)) as opened:
            icon = opened.convert("RGBA")
        if icon.size != (32, 32) or icon.getchannel("A").getbbox() is None:
            raise ValueError(f"invalid accepted icon cell: {name}")
        # Shape-first readability: distinct binary silhouettes are required,
        # not merely different alpha strengths or recolors of one outline.
        masks.append(bytes(1 if a >= 32 else 0 for a in icon.getchannel("A").getdata()))
        sheet.paste(icon, (cell_index * 32, 0))
        cells.append({
            "cell_index": cell_index,
            "semantic_id": name,
            "cell_xyxy": [cell_index * 32, 0, (cell_index + 1) * 32, 32],
            "accepted_icon": "res://assets/art/ui/" + relative_path,
            "accepted_icon_sha256": expected_sha,
            "imagegen_source_cell_index": source_index,
            "imagegen_source_crop_xyxy": lookup[name]["source_crop_xyxy"],
        })
    if len(set(masks)) != 4:
        raise ValueError("quest and Sigil icons do not have four different visible silhouettes")
    stream = io.BytesIO()
    sheet.save(stream, format="PNG", optimize=False)
    png = stream.getvalue()
    metadata = {
        "status": "REVIEW_ONLY_NOT_ACCEPTED",
        "asset_record": "asset:ui/markers/map_marker_sheet",
        "source": "res://" + SOURCE.relative_to(ROOT).as_posix(),
        "source_sha256": SOURCE_HASH,
        "candidate": "res://" + OUTPUT.relative_to(ROOT).as_posix(),
        "candidate_sha256": digest(png),
        "dimensions": [128, 32],
        "cell_dimensions": [32, 32],
        "derivation": "four byte-verified accepted 32px RGBA core9 icon cells, pasted unchanged left-to-right, PNG optimize=False",
        "cells": cells,
        "unresolved": [
            "quest marker coordinates and discovery are not currently authored",
            "the Tower Sigil symbol cannot imply that map travel is available",
            "no real map canvas consumes these proposed four semantic cells",
            "requires live Godot renderer/accessibility acceptance before production binding",
        ],
    }
    return png, metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write review output once; never overwrite")
    args = parser.parse_args()
    png, metadata = produce()
    serialized = json.dumps(metadata, indent=2, ensure_ascii=False) + "\n"
    if args.apply:
        REVIEW_DIR.mkdir(parents=True, exist_ok=True)
        if OUTPUT.exists() or RECORD.exists():
            raise ValueError("review output already exists; verify it rather than overwriting")
        OUTPUT.write_bytes(png)
        RECORD.write_text(serialized, encoding="utf-8")
        print("MAP MARKER REVIEW CANDIDATE WRITTEN: 4 exact accepted distinct glyphs")
    else:
        if not OUTPUT.is_file() or not RECORD.is_file():
            raise ValueError("candidate missing; run once with --apply")
        if OUTPUT.read_bytes() != png or RECORD.read_text(encoding="utf-8") != serialized:
            raise ValueError("candidate PNG or metadata differs from accepted immutable source")
        print("MAP MARKER REVIEW CANDIDATE PASS: 4/4 exact accepted icons, "
              f"128x32 RGBA, sha256={digest(png)}; not a production consumer")


if __name__ == "__main__":
    main()
