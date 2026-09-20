#!/usr/bin/env python3
"""Register Region 3 functional-building V02 derivatives in provenance manifest."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROVENANCE = ROOT / "docs/ASSET_PROVENANCE_MANIFEST.json"
DERIVATION = ROOT / "assets/art/generated_sources/imagegen/region3/buildings/region3_building_v02_derivation_manifest.json"

DISPLAY_NAMES = {
    "central_tower": "Region 3 Central Tower Exterior v02",
    "quest_hall": "Region 3 Quest Hall Exterior v02",
    "blacksmith": "Region 3 Blacksmith Exterior v02",
    "general_merchant": "Region 3 General Merchant Exterior v02",
    "inn_rest_house": "Region 3 Inn / Rest House Exterior v02",
    "storage_house": "Region 3 Storage House Exterior v02",
    "training_hall": "Region 3 Training Hall Exterior v02",
    "clinic_apothecary": "Region 3 Clinic / Apothecary Exterior v02",
}


def main() -> int:
    manifest = json.loads(PROVENANCE.read_text(encoding="utf-8-sig"))
    derivation = json.loads(DERIVATION.read_text(encoding="utf-8"))
    assets = manifest.get("assets")
    if not isinstance(assets, list):
        raise RuntimeError("provenance assets must be an array")

    target_paths = {
        data["derivative"]
        for data in derivation["buildings"].values()
    }
    replaced_v01_paths = {
        "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_quest_hall_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_blacksmith_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_merchant_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_inn_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_storage_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_training_exterior_v01.png",
        "res://assets/art/environments/region3/functional_buildings/region3_clinic_exterior_v01.png",
    }
    assets[:] = [
        entry for entry in assets
        if entry.get("project_path") not in target_paths
        and entry.get("project_path") not in replaced_v01_paths
    ]

    for role_id, data in derivation["buildings"].items():
        raw_name = Path(data["raw_exact_source"]).name
        dimensions = data["derivative_size"]
        assets.append({
            "asset_name": DISPLAY_NAMES[role_id],
            "project_path": data["derivative"],
            "source": data["raw_exact_source"],
            "creator_source": f"ChatGPT generated source {raw_name} / SHA-256 {data['raw_exact_sha256']}",
            "license_category": "ai_generated_terms_permit",
            "license_text": "Generated for this Nice Journey project through OpenAI image generation; project release rights remain subject to normal project review.",
            "attribution_text": "",
            "modifications": "Exact generated source preserved byte-for-byte. Deterministic derivative adds transparent source padding where needed, crops visible alpha, reduces with nearest-neighbor sampling, binarizes low alpha at threshold 24, and bottom-centers on the documented gameplay canvas; no repainting or substitute art.",
            "date_imported": "2026-09-15",
            "responsible_agent": "OpenAI ChatGPT",
            "kind": "pixel_art",
            "pixel_metadata": {
                "dimensions": f"{dimensions[0]}x{dimensions[1]} px",
                "palette_material_ramp": "Inherited from the accepted Region 3 generated building batch: dark slate roofs, warm stone/timber walls, restrained gold trim; no recolor in V02 derivation.",
                "pivot_ground_anchor": "Bottom-centered derivative; final scene offset/scale remains inspector-authored in Region3FunctionalBuildingVisualProfile.",
                "frame_order_timing": "Static environment sprite; no runtime frame stepping.",
                "transparent_bounds": "RGBA derivative with deterministic transparent padding/crop and alpha cleanup.",
                "intended_render_layers": ["region3_functional_building"],
            },
        })

    assets.sort(key=lambda entry: str(entry.get("asset_name", "")).casefold())
    PROVENANCE.write_text(json.dumps(manifest, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"registered {len(target_paths)} Region 3 V02 building assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
