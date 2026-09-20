#!/usr/bin/env python3
"""Read-only byte reproduction of all nine current UI core icon PNGs.

Preserved ui_core_icons_source_v02.png is 1254x1254 RGBA, a 3x3 grid of
418x418 cells. Current core icons were produced by whole-cell 418->32
NEAREST resizing followed by unoptimized PIL PNG encoding. No alpha cutoff,
bounding-box crop, padding, canvas compositing or transparency cleanup occurs.

This pipeline is DIFFERENT from the 18 skill icons' 28px-padded derivation.
Never overwrite source, production PNGs, provenance manifest or old backups.
"""

from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path

from PIL import Image

from audit_ui_core9_attribution import CORE9, SOURCE, SOURCE_HASH


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = SOURCE.parent / "ui_skill_icon_v02_derivation_manifest.json"
CELL_SIDE = 418
OUTPUT_SIDE = 32


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def derive_bytes(source: Image.Image, index: int) -> tuple[bytes, list[int]]:
    """Pure in-memory derivation: no output filesystem writes."""
    row, col = divmod(index, 3)
    box = [col * CELL_SIDE, row * CELL_SIDE,
           (col + 1) * CELL_SIDE, (row + 1) * CELL_SIDE]
    resized = source.crop(box).resize((OUTPUT_SIDE, OUTPUT_SIDE), Image.Resampling.NEAREST)
    stream = io.BytesIO()
    resized.save(stream, format="PNG", optimize=False)
    return stream.getvalue(), box


def verify() -> list[dict]:
    if not SOURCE.is_file() or sha256(SOURCE.read_bytes()) != SOURCE_HASH:
        raise ValueError("Preserved core9 source bytes missing or SHA-256 changed")
    with Image.open(SOURCE) as original:
        if original.size != (1254, 1254) or original.mode != "RGBA":
            raise ValueError("Preserved core9 source must be 1254x1254 RGBA")
        source = original.copy()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = manifest["core9_preserved"]
    if len(records) != len(CORE9) or len(CORE9) != 9:
        raise ValueError("Core9 mapping/manifest count changed")
    results: list[dict] = []
    for index, (name, relpath, expected_hash) in enumerate(CORE9):
        record = records[index]
        actual_path = ROOT / "assets/art/ui" / relpath
        if not actual_path.is_file():
            raise ValueError(f"Missing production icon: {actual_path}")
        actual_bytes = actual_path.read_bytes()
        reproduced_bytes, crop = derive_bytes(source, index)
        expected_res_path = "res://assets/art/ui/" + relpath.replace("\\", "/")
        if record["asset_id"] != f"ui_{name}_v01":
            raise ValueError(f"Unexpected manifest semantic ID at cell {index}")
        if record["cell_index"] != index or record["cell_rect"] != crop:
            raise ValueError(f"Unexpected source crop for {name}")
        if record["source_sha256"] != SOURCE_HASH or record["output"] != expected_res_path:
            raise ValueError(f"Source/output attribution changed for {name}")
        if sha256(actual_bytes) != expected_hash or record["output_sha256"] != expected_hash:
            raise ValueError(f"Current production icon/manifest SHA mismatch for {name}")
        if record["historical_backup_sha256"] == expected_hash:
            raise ValueError(f"Obsolete backup was conflated with current icon: {name}")
        if reproduced_bytes != actual_bytes:
            raise ValueError(
                f"Exact PNG byte reproduction FAILED for {name}; "
                f"current={expected_hash}, derived={sha256(reproduced_bytes)}"
            )
        with Image.open(io.BytesIO(actual_bytes)) as icon:
            if icon.size != (OUTPUT_SIDE, OUTPUT_SIDE) or icon.mode != "RGBA":
                raise ValueError(f"Unexpected production icon geometry: {name}")
        results.append({
            "asset_id": name,
            "source_cell_index": index,
            "source_crop_xyxy": crop,
            "output": expected_res_path,
            "exact_png_sha256": expected_hash,
            "byte_identical": True,
        })
    return results


def main() -> None:
    results = verify()
    for result in results:
        print("PASS EXACT CORE9", result["asset_id"], result["source_crop_xyxy"],
              result["exact_png_sha256"])
    print("CORE9 EXACT BYTE DERIVATION PASS: 9/9, pure read-only, no production writes")
    print("RECIPE: source row-major 3x3 full 418x418 crop -> direct RGBA NEAREST 32x32 -> PIL PNG optimize=False")
    print("Manifest verification flags are recorded separately; this verifier never rewrites PNG or manifest bytes")


if __name__ == "__main__":
    main()
