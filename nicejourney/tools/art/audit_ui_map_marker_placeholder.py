#!/usr/bin/env python3
"""Read-only evidence gate for the provisional four-cell map marker sheet.

This script proves only the current asset/profile state. It intentionally does
not assign invented marker semantics or mark the placeholder production-ready.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "assets/art/ui/markers/map_marker_sheet_v01.png"
PROFILE = ROOT / "src/ui/presentation/profiles/map_marker_sheet.tres"
CATALOG = ROOT / "src/ui/presentation/ui_icon_catalog.tres"
EXPECTED_SHA256 = "7c3c5f62fc5bcd370ea4fe1d0515e177908236396f1131062fa0842437e1a859"


def audit() -> dict:
    if not SHEET.is_file():
        raise ValueError("map marker placeholder PNG is missing")
    sha = hashlib.sha256(SHEET.read_bytes()).hexdigest()
    if sha != EXPECTED_SHA256:
        raise ValueError("map marker sheet changed; re-audit before using this classification")
    with Image.open(SHEET) as source:
        if source.size != (128, 32):
            raise ValueError("map marker sheet is no longer four 32x32 cells")
        image = source.convert("RGBA")
    alpha_shapes: list[bytes] = []
    visible_colors: list[list[list[int]]] = []
    for index in range(4):
        tile = image.crop((index * 32, 0, (index + 1) * 32, 32))
        alpha = tile.getchannel("A")
        if alpha.getbbox() is None:
            raise ValueError(f"map marker cell {index} is empty")
        alpha_shapes.append(alpha.tobytes())
        unique_fills = sorted({pixel for pixel in tile.getdata()
                               if pixel[3] > 0 and pixel[:3] != (22, 21, 31)})
        if len(unique_fills) != 1:
            raise ValueError(f"map marker cell {index} color grammar changed")
        visible_colors.append([list(pixel) for pixel in unique_fills])
    if len(set(alpha_shapes)) != 1:
        raise ValueError("map marker cell silhouettes changed; do not report identical glyphs")
    if len({str(color) for color in visible_colors}) != 4:
        raise ValueError("map marker cells are no longer four recolors")
    if not PROFILE.is_file() or not CATALOG.is_file():
        raise ValueError("map marker Inspector profile/catalog missing")
    profile_text = PROFILE.read_text(encoding="utf-8")
    catalog_text = CATALOG.read_text(encoding="utf-8")
    if ("map_marker_sheet_v01.png" not in profile_text
            or 'icon_id = &"map_marker_sheet"' not in profile_text
            or "minimum_size = Vector2(32, 32)" not in profile_text
            or "profiles/map_marker_sheet.tres" not in catalog_text):
        raise ValueError("map marker profile/catalog binding changed; re-audit")
    # No claim about all possible runtime calls: this targeted search covers
    # the canonical Godot UI/world source surfaces that own map presentation.
    consumer_mentions: list[str] = []
    for subtree in (ROOT / "src/ui", ROOT / "src/world"):
        for path in subtree.rglob("*"):
            if path.suffix not in (".gd", ".tres", ".tscn") or path in (PROFILE, CATALOG):
                continue
            content = path.read_text(encoding="utf-8")
            if "map_marker_sheet" in content or "map_marker_sheet_v01.png" in content:
                consumer_mentions.append("res://" + path.relative_to(ROOT).as_posix())
    return {
        "asset_id": "asset:ui/markers/map_marker_sheet",
        "classification": "PLACEHOLDER",
        "sha256": sha,
        "dimensions": [128, 32],
        "cell_count": 4,
        "cell_dimensions": [32, 32],
        "cell_rects": [[i * 32, 0, (i + 1) * 32, 32] for i in range(4)],
        "all_four_alpha_silhouettes_identical": True,
        "cell_fill_colors_rgba": visible_colors,
        "inspector_profile_and_catalog_present": True,
        "other_ui_world_consumer_mentions": sorted(consumer_mentions),
        "semantic_cell_mapping_verified": False,
        "status": "existing_recolored_procedural_placeholder_no_verified_semantic_cell_mapping",
        "generation_performed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit machine-readable diagnostic")
    args = parser.parse_args()
    try:
        result = audit()
    except (ValueError, OSError, UnicodeError) as exc:
        print(f"MAP MARKER PLACEHOLDER AUDIT FAIL: {exc}")
        return 1
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("MAP MARKER PLACEHOLDER AUDIT PASS: four 32x32 recolors of the "
              "same silhouette; generic catalog profile present; other UI/world "
              f"consumer mentions={result['other_ui_world_consumer_mentions']}; "
              "cell semantics UNVERIFIED; no files written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
