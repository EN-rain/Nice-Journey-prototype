#!/usr/bin/env python3
"""Register accepted Region 3 decorative-building V02 derivatives in provenance."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROVENANCE = ROOT / "docs/ASSET_PROVENANCE_MANIFEST.json"
DERIVATION = ROOT / "assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_building_v02_derivation_manifest.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--remove-replaced-v01",
        action="store_true",
        help="Remove V01 provenance entries only for decorative indices that already have derived V02 entries.",
    )
    args = parser.parse_args()

    manifest = json.loads(PROVENANCE.read_text(encoding="utf-8-sig"))
    derivation = json.loads(DERIVATION.read_text(encoding="utf-8"))
    assets = manifest.get("assets")
    if not isinstance(assets, list):
        raise RuntimeError("provenance assets must be an array")

    buildings = derivation.get("buildings", {})
    if not isinstance(buildings, dict) or not buildings:
        raise RuntimeError("derivation manifest contains no decorative buildings")

    target_paths = {data["derivative"] for data in buildings.values()}
    replaced_v01_paths = {
        f"res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_{int(data['index']):02d}_v01.png"
        for data in buildings.values()
    }
    assets[:] = [
        entry for entry in assets
        if entry.get("project_path") not in target_paths
        and (not args.remove_replaced_v01 or entry.get("project_path") not in replaced_v01_paths)
    ]

    for stable_id, data in sorted(buildings.items(), key=lambda item: int(item[1]["index"])):
        index = int(data["index"])
        dimensions = data["derivative_size"]
        assets.append({
            "asset_name": f"Region3 Decorative Building {index:02d} V02",
            "project_path": data["derivative"],
            "source": data["exact_source"],
            "creator_source": (
                f"ChatGPT generated source {Path(data['exact_source']).name} / "
                f"SHA-256 {data['exact_source_sha256']}"
            ),
            "license_category": "ai_generated_terms_permit",
            "license_text": "Generated for this Nice Journey project through OpenAI image generation; project release rights remain subject to normal project review.",
            "attribution_text": "",
            "modifications": (
                "Exact generated source preserved byte-for-byte. Deterministic derivative adds transparent "
                "source padding, crops visible alpha, reduces with nearest-neighbor sampling, binarizes low "
                "alpha at threshold 24, and bottom-centers on a 160x160 gameplay canvas; no repainting or substitute art."
            ),
            "date_imported": "2026-09-15",
            "responsible_agent": "OpenAI ChatGPT",
            "kind": "pixel_art",
            "pixel_metadata": {
                "dimensions": f"{dimensions[0]}x{dimensions[1]} px",
                "palette_material_ramp": "Accepted Region 3 V02 stone/timber/red-roof architectural family; no recolor in deterministic derivation.",
                "pivot_ground_anchor": "Bottom-centered derivative; final placement remains inspector-authored by Region3DecorativeBuildingVisualProfile.",
                "frame_order_timing": "Static environment sprite; no runtime frame stepping.",
                "transparent_bounds": "RGBA derivative with deterministic transparent padding/crop and alpha cleanup.",
                "intended_render_layers": ["region3_decorative_building"],
            },
            "stable_id": stable_id,
        })

    assets.sort(key=lambda entry: str(entry.get("asset_name", "")).casefold())
    PROVENANCE.write_text(json.dumps(manifest, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"registered {len(buildings)} Region 3 decorative V02 assets")
    if args.remove_replaced_v01:
        print(f"removed {len(replaced_v01_paths)} replaced V01 provenance entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
