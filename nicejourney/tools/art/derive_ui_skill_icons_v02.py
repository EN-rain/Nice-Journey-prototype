#!/usr/bin/env python3
"""Deterministically derive the 18 Region UI skill icons from preserved V02 sheets.

The source sheets and semantic order are fixed by the implemented SkillCatalog.
Each cell is alpha-bounded, padded, nearest-neighbor scaled into a 32x32 RGBA
canvas, and recorded with source/output SHA-256 hashes.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets/art/generated_sources/imagegen/ui"
OUTPUT_DIR = ROOT / "assets/art/ui/skills"
MANIFEST = SOURCE_DIR / "ui_skill_icon_v02_derivation_manifest.json"

BATCHES = [
    ("mage", "ui_mage_skills_source_v02.png", [
        "arcane_lance", "delayed_pulse", "aegis_ward",
        "mana_weave", "flow_recovery", "stable_casting",
    ]),
    ("melee", "ui_melee_skills_source_v02.png", [
        "arc_cleave", "driving_thrust", "breaker",
        "efficient_footwork", "parry_recovery", "riposte",
    ]),
    ("ranged", "ui_ranged_skills_source_v02.png", [
        "piercing_shot", "fan_shot", "backstep_shot",
        "longshot", "fleet_recovery", "expose",
    ]),
]

CORE9 = [
    ("class_mage", "class_mage_icon_v01.png", "class_mage_icon_v01.png"),
    ("class_melee", "class_melee_icon_v01.png", "class_melee_icon_v01.png"),
    ("class_ranged", "class_ranged_icon_v01.png", "class_ranged_icon_v01.png"),
    ("quest_family_annihilation", "quest_family_annihilation_v01.png", "quest_family_annihilation_v01.png"),
    ("quest_family_escort", "quest_family_escort_v01.png", "quest_family_escort_v01.png"),
    ("quest_family_tower_defense", "quest_family_tower_defense_v01.png", "quest_family_tower_defense_v01.png"),
    ("status_burn", "status_burn_v01.png", "status_burn_v01.png"),
    ("status_slow", "status_slow_v01.png", "status_slow_v01.png"),
    ("tower_sigil", "tower_sigil_icon_v01.png", "tower_sigil_icon_v01.png"),
]

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def derive_batch(class_id: str, source_name: str, names: list[str]) -> list[dict]:
    source_path = SOURCE_DIR / source_name
    image = Image.open(source_path).convert("RGBA")
    width, height = image.size
    records = []
    for index, skill_id in enumerate(names):
        col, row = index % 3, index // 3
        cell = (
            round(col * width / 3), round(row * height / 2),
            round((col + 1) * width / 3), round((row + 1) * height / 2),
        )
        cell_image = image.crop(cell)
        alpha_bbox = cell_image.getchannel("A").point(lambda p: 255 if p > 8 else 0).getbbox()
        if alpha_bbox is None:
            raise RuntimeError(f"No nontransparent pixels for {skill_id}")
        left, top, right, bottom = alpha_bbox
        padding = max(8, round(max(right - left, bottom - top) * 0.10))
        crop_box = (
            max(0, left - padding), max(0, top - padding),
            min(cell_image.width, right + padding), min(cell_image.height, bottom + padding),
        )
        crop = cell_image.crop(crop_box)
        crop.thumbnail((28, 28), Image.Resampling.NEAREST)
        output = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        output.alpha_composite(crop, ((32 - crop.width) // 2, (32 - crop.height) // 2))
        output_path = OUTPUT_DIR / f"skill_{skill_id}_v02.png"
        output.save(output_path, optimize=True)
        records.append({
            "asset_id": f"ui_skill_{skill_id}_v02",
            "class": class_id,
            "skill_id": skill_id,
            "source": f"res://assets/art/generated_sources/imagegen/ui/{source_name}",
            "source_sha256": sha256(source_path),
            "source_dimensions": [width, height],
            "cell_index": index,
            "cell_rect": list(cell),
            "alpha_bbox_in_cell": list(alpha_bbox),
            "alpha_threshold": 8,
            "padding": padding,
            "scale_filter": "nearest",
            "output": f"res://assets/art/ui/skills/skill_{skill_id}_v02.png",
            "output_dimensions": [32, 32],
            "output_sha256": sha256(output_path),
            "mapping_authority": "src/combat/skills/skill_catalog.gd",
        })
    return records

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    records = []
    for class_id, source_name, names in BATCHES:
        records.extend(derive_batch(class_id, source_name, names))
    core_records = []
    core_dir = SOURCE_DIR / "v01_backup_core9"
    for asset_id, source_name, output_name in CORE9:
        source = core_dir / source_name
        output = ROOT / "assets/art/ui/classes" / output_name if asset_id.startswith("class_") else None
        if asset_id.startswith("quest_"):
            output = ROOT / "assets/art/ui/quests" / output_name
        elif asset_id.startswith("status_"):
            output = ROOT / "assets/art/ui/status" / output_name
        elif asset_id == "tower_sigil":
            output = ROOT / "assets/art/ui/markers" / output_name
        core_records.append({
            "asset_id": f"ui_{asset_id}_v01",
            "source": f"res://assets/art/generated_sources/imagegen/ui/v01_backup_core9/{source_name}",
            "source_sha256": sha256(source),
            "source_dimensions": list(Image.open(source).size),
            "output": f"res://{output.relative_to(ROOT).as_posix()}",
            "output_sha256": sha256(output),
            "output_dimensions": list(Image.open(output).size),
            "status": "preserved_existing_core9",
        })
    manifest = {
        "schema": "nice_journey.ui_skill_icon_v02_derivation.v1",
        "tool": "tools/art/derive_ui_skill_icons_v02.py",
        "algorithm": "alpha threshold >8, 10% bbox padding with minimum 8 source pixels, nearest-neighbor thumbnail to max 28, centered on transparent 32x32 RGBA canvas",
        "skill_source_batches": records,
        "core9_preserved": core_records,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {MANIFEST}")
    print(f"derived {len(records)} skill icons; preserved {len(core_records)} core icons")

if __name__ == "__main__":
    main()
