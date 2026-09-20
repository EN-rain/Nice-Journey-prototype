#!/usr/bin/env python3
"""Check translucent 32px review glyphs against real 640x360 Godot pixels."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from build_map_marker_quest_sigil_candidate import OUTPUT, digest, produce


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/evidence/renderer/map-marker-quest-sigil-candidate-native.json"


def main() -> None:
    source_bytes, record = produce()
    if OUTPUT.read_bytes() != source_bytes:
        raise ValueError("rendered candidate differs from accepted core9 source")
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if evidence["status"] != "REVIEW_ONLY_NOT_ACCEPTED" or evidence["candidate_sha256"] != digest(source_bytes):
        raise ValueError("native capture misidentifies its candidate")
    if evidence["size"] != [640, 360] or len(evidence["cells"]) != 4:
        raise ValueError("native viewport or semantic cell set changed")
    screenshot_path = ROOT / evidence["image"].removeprefix("res://")
    with Image.open(OUTPUT) as input_image, Image.open(screenshot_path) as frame_image:
        source = input_image.convert("RGBA")
        screenshot = frame_image.convert("RGBA")
    if screenshot.size != (640, 360):
        raise ValueError("real renderer capture must be 640x360")
    total = 0
    matched_total = 0
    background_rgb = (32, 35, 48)  # GL review ColorRect #202330
    for index, cell in enumerate(evidence["cells"]):
        rect = cell["native_screen_xyxy"]
        original = cell["source_xyxy"]
        if rect != [80 + index * 144, 128, 112 + index * 144, 160]:
            raise ValueError("unexpected native glyph rectangle")
        if original != [index * 32, 0, (index + 1) * 32, 32]:
            raise ValueError("unexpected original crop")
        sampled = 0
        matched = 0
        worst_deviation = 0
        for y in range(32):
            for x in range(32):
                pixel = source.getpixel((index * 32 + x, y))
                # The accepted ImageGen core9 icons have no fully opaque pixels:
                # their real per-cell alpha maximum is 253. Compare their strong
                # strokes after compositing over the actual known backdrop.
                if pixel[3] < 192:
                    continue
                sampled += 1
                observed = screenshot.getpixel((rect[0] + x, rect[1] + y))
                expected = tuple(round((pixel[c] * pixel[3]
                                        + background_rgb[c] * (255 - pixel[3])) / 255)
                                 for c in range(3))
                deviation = max(abs(expected[c] - observed[c]) for c in range(3))
                worst_deviation = max(worst_deviation, deviation)
                if observed[3] == 255 and deviation <= 3:
                    matched += 1
        if sampled == 0 or matched != sampled:
            raise ValueError(f"native glyph {index} differs: blended strong-alpha {matched}/{sampled}, maximum RGB deviation {worst_deviation}")
        total += sampled
        matched_total += matched
        print(f"PASS native {cell['semantic']}: blended alpha>=192 {matched}/{sampled}, max RGB deviation {worst_deviation}")
    print(f"MAP MARKER CANDIDATE NATIVE PASS: 4/4, blended strong-alpha {matched_total}/{total}; review only")


if __name__ == "__main__":
    main()
