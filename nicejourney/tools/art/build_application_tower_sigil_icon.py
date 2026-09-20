#!/usr/bin/env python3
"""Create or verify the 128px application icon from the accepted Tower Sigil.

The accepted 32x32 ImageGen-derived source is immutable; this recipe applies
only 4x nearest-neighbor scaling. The legacy Godot icon.svg is preserved.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/ui/markers/tower_sigil_icon_v01.png"
OUTPUT = ROOT / "assets/art/ui/application/application_icon_tower_sigil_v02.png"
EVIDENCE = OUTPUT.with_suffix(".json")
EXPECTED_SOURCE_SHA = "1dfeea179a0df7320388fcfadba55e715d367656be4e6585a756b14b99a70b39"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def expected() -> tuple[bytes, str]:
    source_hash = sha(SOURCE.read_bytes())
    if source_hash != EXPECTED_SOURCE_SHA:
        raise ValueError("Tower Sigil accepted ImageGen derivative was altered")
    with Image.open(SOURCE) as source:
        if source.mode != "RGBA" or source.size != (32, 32):
            raise ValueError("expected untouched 32x32 RGBA Tower Sigil")
        icon = source.resize((128, 128), resample=Image.Resampling.NEAREST)
        if icon.getchannel("A").getextrema() != (0, 255):
            raise ValueError("source transparency was lost")
        import io
        buffer = io.BytesIO()
        icon.save(buffer, format="PNG", optimize=False)
        return buffer.getvalue(), source_hash


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="create the derivative only if absent")
    opts = parser.parse_args()
    png, source_hash = expected()
    manifest = {
        "status": "ACCEPTED_SOURCE_DERIVATIVE_PROTOTYPE_PROJECT_ICON",
        "stable_asset_id": "application.icon",
        "accepted_source": "res://assets/art/ui/markers/tower_sigil_icon_v01.png",
        "accepted_source_sha256": source_hash,
        "derivative": "res://assets/art/ui/application/application_icon_tower_sigil_v02.png",
        "derivative_sha256": sha(png),
        "output_dimensions": [128, 128],
        "mode": "RGBA",
        "recipe": "Exact 32x32 accepted Tower Sigil RGBA -> 128x128 4x nearest-neighbor; no recolor, crop, new figure, typographic overlay or invented emblem",
        "godot_binding": "res://project.godot [application] config/icon",
        "legacy_default_svg_preserved": "res://icon.svg",
        "acceptance_scope": "Source-backed prototype project icon; no new branded title/logo, platform ICO, release export or packaged app icon verified",
    }
    body = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    if opts.apply:
        if OUTPUT.exists() or EVIDENCE.exists():
            raise ValueError("app icon or provenance already exists; verify, do not overwrite")
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(png)
        EVIDENCE.write_text(body, encoding="utf-8")
    elif not OUTPUT.is_file() or not EVIDENCE.is_file() or OUTPUT.read_bytes() != png or EVIDENCE.read_text(encoding="utf-8") != body:
        raise ValueError("production icon/provenance missing or not reproducible")
    print(f"APPLICATION ICON SOURCE PASS: accepted Tower Sigil -> 128x128 RGBA SHA-256={sha(png)}")


if __name__ == "__main__":
    main()
