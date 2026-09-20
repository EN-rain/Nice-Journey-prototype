#!/usr/bin/env python3
"""Read-only source, Godot binding and native 128px icon screenshot gate."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from build_application_tower_sigil_icon import OUTPUT, ROOT, expected, sha

CAPTURE = ROOT / "docs/evidence/renderer/application-icon-tower-sigil-v02-native.png"
REPORT = CAPTURE.with_suffix(".json")
PROJECT = ROOT / "project.godot"
EXPECTED_RESOURCE = "res://assets/art/ui/application/application_icon_tower_sigil_v02.png"


def verify() -> dict:
    image_bytes, source_hash = expected()
    if OUTPUT.read_bytes() != image_bytes:
        raise ValueError("icon derivative is not byte-for-byte reproducible from Tower Sigil")
    binding = f'config/icon="{EXPECTED_RESOURCE}"'
    if PROJECT.read_text(encoding="utf-8").count(binding) != 1:
        raise ValueError("actual Godot project is not configured to use production icon")
    if not (ROOT / "icon.svg").is_file():
        raise ValueError("legacy Godot placeholder icon was not preserved")
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    if (report["icon_sha256"] != sha(image_bytes)
            or report["project_config_icon"] != EXPECTED_RESOURCE
            or report["icon"] != EXPECTED_RESOURCE
            or report["renderer"] != "gl_compatibility"
            or report["release_export_performed"] is not False):
        raise ValueError("native renderer evidence is stale or overclaims export")
    with Image.open(OUTPUT) as source, Image.open(CAPTURE) as screenshot:
        if source.size != (128, 128) or screenshot.size != (128, 128):
            raise ValueError("wrong production or screenshot dimensions")
        src = source.convert("RGBA")
        screen = screenshot.convert("RGBA")
        full = list(zip(src.getdata(), screen.getdata()))
        opaque = [(s, r) for s, r in full if s[3] >= 245]
        if len(opaque) < 2000:
            raise ValueError("too few readable source icon pixels")
        maximum_alpha = max(abs(s[3] - r[3]) for s, r in full)
        if maximum_alpha > 1:
            raise ValueError("source icon silhouette/transparency differs from renderer")
        maximum_rgb = max(max(abs(s[i] - r[i]) for i in range(3)) for s, r in opaque)
        if maximum_rgb > 5:
            raise ValueError("native Godot image changed the accepted Tower Sigil pixels")
    result = {
        "production_sha256": sha(image_bytes),
        "accepted_source_sha256": source_hash,
        "native_capture_sha256": sha(CAPTURE.read_bytes()),
        "native_opaque_source_pixels_checked": len(opaque),
        "maximum_rgb_delta": maximum_rgb,
        "maximum_alpha_delta": maximum_alpha,
    }
    print("APPLICATION ICON NATIVE PASS: 128x128, %d opaque source pixels, max RGB delta %d, actual project config" % (len(opaque), maximum_rgb))
    return result


if __name__ == "__main__":
    verify()
