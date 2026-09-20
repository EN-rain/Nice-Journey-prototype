#!/usr/bin/env python3
"""Check four source-exact glyphs in the actual 640x360 Godot MapMenu capture.

The image may be rasterized on a half-pixel boundary; compare the two nearest
integer origins, never rescale or accept screenshots with a missing icon.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from promote_map_marker_quest_sigil_v02 import DESTINATION, ROOT, digest, produce


def main() -> None:
    evidence = json.loads((ROOT / "docs/evidence/renderer/map-marker-live-menu-native.json").read_text(encoding="utf-8"))
    image, _ = produce()
    if digest(DESTINATION.read_bytes()) != digest(image) or evidence["production_sha256"] != digest(image):
        raise ValueError("production glyph source or screenshot provenance changed")
    if evidence["renderer"] != "gl_compatibility" or evidence["actual_quest_marker_count"] != 0 or evidence["travel_action_in_map"]:
        raise ValueError("renderer or authored-map/travel boundaries changed")
    with Image.open(DESTINATION) as opened:
        source = opened.convert("RGBA")
    with Image.open(ROOT / "docs/evidence/renderer/map-marker-live-menu-native.png") as opened:
        screen = opened.convert("RGBA")
    if screen.size != (640, 360):
        raise ValueError("not the real 640x360 viewport")
    positions = set()
    total = 0
    for index, entry in enumerate(evidence["source_cells"]):
        rect = entry["screen_xyxy"]
        if entry["source_xyxy"] != [index * 32, 0, index * 32 + 32, 32] or rect[2] - rect[0] != 32 or rect[3] - rect[1] != 32:
            raise ValueError("AtlasTexture cell geometry or native scale changed")
        x = int(rect[0])
        y = int(rect[1])
        if (x, y) in positions or not (0 <= x <= 608 and 0 <= y <= 328):
            raise ValueError("map legend glyph overlapped or clipped")
        positions.add((x, y))
        pixels = []
        for dy in range(32):
            for dx in range(32):
                rgba = source.getpixel((index * 32 + dx, dy))
                if rgba[3] >= 245:
                    pixels.append((dx, dy, rgba))
        if len(pixels) < 100:
            raise ValueError("glyph has insufficient near-opaque source detail")
        candidates = []
        for start_y in sorted({int(rect[1]), int(rect[1] + 0.99)}):
            deviations = []
            for dx, dy, src in pixels:
                rendered = screen.getpixel((x + dx, start_y + dy))
                deviations.append(max(abs(rendered[c] - src[c]) for c in range(3)))
            candidates.append((max(deviations), sum(d <= 5 for d in deviations), start_y))
        worst, good, selected_y = min(candidates, key=lambda item: (item[0], -item[1]))
        if worst > 8 or good != len(pixels):
            raise ValueError(f"live {entry['name']} has incorrect pixels: max deviation={worst}, within5={good}/{len(pixels)}")
        total += good
        print(f"PASS live {entry['name']}: {good}/{len(pixels)} near-opaque source pixels, max deviation {worst}, y={selected_y}")
    print(f"MAP MARKER LIVE MENU NATIVE PASS: 4/4 source glyphs, {total} checked pixels, 640x360")


if __name__ == "__main__":
    main()
