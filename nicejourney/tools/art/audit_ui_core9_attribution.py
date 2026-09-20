#!/usr/bin/env python3
"""Read-only, pixel-backed attribution of the nine existing core UI icons.

The preserved 1254px source has nine 418px cells. Pixel silhouette matching
establishes the cell-to-output association, but DOES NOT establish the original
crop, resize, alpha cleanup or PNG encoding that produced the 32px outputs.
Never write or replace image files here. Run this audit before recording an
attribution in derive_ui_skill_icons_v02.py.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
BACKUP_DIR = SOURCE.parent / "v01_backup_core9"
SOURCE_HASH = "bd0cb8c1895eeb855b53a79ca0676c17222737c62fe0f74915d0b07a9290465c"
CELL_SIZE = 418
OUTPUT_SIZE = 32

# Row-major order is asserted against *all nine current images* below; names
# alone or the v01_backup_core9 directory are not mapping authority.
CORE9 = (
    ("class_melee", "classes/class_melee_icon_v01.png", "91847cb8e61f08fb34152d80b49cb65cc50f399b4821760b5d809bf1102d2760"),
    ("class_ranged", "classes/class_ranged_icon_v01.png", "d28eff12bb99b6fda68d0704dcc7b98a1cdaa9499a053751da971f26f1d3170d"),
    ("class_mage", "classes/class_mage_icon_v01.png", "4792731d5cb615fcc77c59e8fb1ac06fc6fc4f8d5054f3f27fe911c6568c3349"),
    ("quest_family_escort", "quests/quest_family_escort_v01.png", "61f1ba431b144619d1142ac6d2e7398c227573e4e1aad026ff7afd169db257b6"),
    ("quest_family_tower_defense", "quests/quest_family_tower_defense_v01.png", "c882411d7ed0aa998053009457423b34a795f962860de59f26d36a695631f78f"),
    ("quest_family_annihilation", "quests/quest_family_annihilation_v01.png", "97cd83a3419073bb78218c73dab814daba989915cc41d8a9b4e89b690b443a9c"),
    ("status_burn", "status/status_burn_v01.png", "2b5d35219f8a3349c2f25ab382e653bb4dad2e0c4c66ffbba923d0459807b35b"),
    ("status_slow", "status/status_slow_v01.png", "edeab20c13f0c382dd54a223ca5a5ae861be950176ffc69b193a01fe3aa87d88"),
    ("tower_sigil", "markers/tower_sigil_icon_v01.png", "1dfeea179a0df7320388fcfadba55e715d367656be4e6585a756b14b99a70b39"),
)


def _hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def _mask_rows(image: Image.Image, threshold: int) -> tuple[int, ...]:
    alpha = image.getchannel("A")
    pixels = list(alpha.getdata())
    return tuple(
        sum(1 << x for x in range(image.width) if pixels[y * image.width + x] > threshold)
        for y in range(image.height)
    )


def _mask_bits(image: Image.Image, threshold: int = 30) -> int:
    _require(image.size == (OUTPUT_SIZE, OUTPUT_SIZE), "target mask must be 32x32")
    return sum(row << (y * OUTPUT_SIZE) for y, row in enumerate(_mask_rows(image, threshold)))


def _candidate_masks(cell: Image.Image):
    # Alpha gives a reproducible search boundary without guessing the
    # historical crop. This is an attribution comparison, not derivation.
    bbox = cell.getchannel("A").point(lambda p: 255 if p > 8 else 0).getbbox()
    _require(bbox is not None, "empty cell")
    isolated = cell.crop(bbox)
    for diameter in range(23, 33):
        factor = min(diameter / isolated.width, diameter / isolated.height)
        size = (max(1, round(isolated.width * factor)),
                max(1, round(isolated.height * factor)))
        for filter_name, resampler in (("nearest", Image.Resampling.NEAREST),
                                       ("lanczos", Image.Resampling.LANCZOS)):
            rows = _mask_rows(isolated.resize(size, resampler), 30)
            for y in range(OUTPUT_SIZE - size[1] + 1):
                base = sum(row << ((y + row_index) * OUTPUT_SIZE)
                           for row_index, row in enumerate(rows))
                for x in range(OUTPUT_SIZE - size[0] + 1):
                    yield base << x, (diameter, filter_name, x, y, size)


def _match_cell(cell: Image.Image, targets: list[int]) -> list[tuple[float, tuple | None]]:
    results = [(0.0, None) for _ in targets]
    target_counts = [mask.bit_count() for mask in targets]
    for candidate, parameters in _candidate_masks(cell):
        candidate_count = candidate.bit_count()
        for index, target in enumerate(targets):
            intersection = (candidate & target).bit_count()
            union = candidate_count + target_counts[index] - intersection
            overlap = intersection / union if union else 0.0
            if overlap > results[index][0]:
                results[index] = (overlap, parameters)
    return results


def audit_core9() -> list[dict]:
    _require(SOURCE.is_file(), f"missing preserved source: {SOURCE}")
    _require(_hash(SOURCE) == SOURCE_HASH, "core9 source SHA-256 changed")
    with Image.open(SOURCE) as original:
        _require(original.size == (1254, 1254), "core9 source grid changed")
        source = original.convert("RGBA")
    targets = []
    outputs = []
    for asset_id, relative_path, expected_hash in CORE9:
        output = ROOT / "assets/art/ui" / relative_path
        _require(output.is_file(), f"missing current output: {output}")
        output_hash = _hash(output)
        _require(output_hash == expected_hash, f"current output SHA-256 changed: {output}")
        with Image.open(output) as image:
            _require(image.size == (OUTPUT_SIZE, OUTPUT_SIZE), f"incorrect output dimensions: {output}")
            targets.append(_mask_bits(image.convert("RGBA")))
        outputs.append((asset_id, output, output_hash))
    _require(len({mask for mask in targets}) == len(CORE9), "duplicate output silhouettes")

    records = []
    for index, (asset_id, output, output_hash) in enumerate(outputs):
        row, col = divmod(index, 3)
        rect = (col * CELL_SIZE, row * CELL_SIZE,
                (col + 1) * CELL_SIZE, (row + 1) * CELL_SIZE)
        cell = source.crop(rect)
        bbox = cell.getchannel("A").point(lambda p: 255 if p > 8 else 0).getbbox()
        scores = _match_cell(cell, targets)
        best_index = max(range(len(scores)), key=lambda n: scores[n][0])
        runner_up = max(score[0] for n, score in enumerate(scores) if n != best_index)
        score = scores[index][0]
        _require(best_index == index, f"cell {index} matches {outputs[best_index][0]}, not {asset_id}")
        _require(score >= 0.82 and score - runner_up >= 0.10,
                 f"insufficient or ambiguous pixel evidence for {asset_id}: {score:.3f} vs {runner_up:.3f}")
        backup = BACKUP_DIR / output.name
        _require(backup.is_file(), f"missing old core9 backup: {backup}")
        backup_hash = _hash(backup)
        _require(backup_hash != output_hash, f"backup/current identity changed for {asset_id}")
        records.append({
            "asset_id": f"ui_{asset_id}_v01",
            "source": f"res://{SOURCE.relative_to(ROOT).as_posix()}",
            "source_sha256": SOURCE_HASH,
            "source_dimensions": [1254, 1254],
            "cell_index": index,
            "cell_rect": list(rect),
            "alpha_bbox_in_cell_over_8": list(bbox),
            "output": f"res://{output.relative_to(ROOT).as_posix()}",
            "output_sha256": output_hash,
            "output_dimensions": [OUTPUT_SIZE, OUTPUT_SIZE],
            "mapping_evidence": {
                "method": "best_aligned_alpha_mask_iou_across_all_nine_outputs",
                "matched_iou": round(score, 4),
                "next_best_iou": round(runner_up, 4),
                "source_alpha_threshold": 8,
                "target_alpha_threshold": 30,
                "search_diameter_px": [23, 32],
                "filters": ["nearest", "lanczos"],
                "best_fit_parameters_for_evidence_only": scores[index][1],
            },
            "attribution_status": "pixel_correlated_source_cell_exact_derivation_unverified",
            "exact_derivation_verified": False,
            "historical_backup": f"res://{backup.relative_to(ROOT).as_posix()}",
            "historical_backup_sha256": backup_hash,
            "status": "preserved_existing_core9",
        })
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print deterministic machine-readable attribution report")
    args = parser.parse_args()
    try:
        records = audit_core9()
    except (ValueError, OSError) as exc:
        print(f"CORE9 ATTRIBUTION FAIL: {exc}")
        return 1
    if args.json:
        print(json.dumps({"schema": "nice_journey.core9_attribution_audit.v1",
                          "source_sha256": SOURCE_HASH, "records": records}, indent=2))
    else:
        for record in records:
            evidence = record["mapping_evidence"]
            print(f"cell {record['cell_index']} {record['cell_rect']} -> {record['asset_id']} "
                  f"IoU={evidence['matched_iou']:.4f}, runner_up={evidence['next_best_iou']:.4f}, "
                  f"output_sha256={record['output_sha256']}")
        print("CORE9 ATTRIBUTION PASS: 9 unique pixel-correlated mappings; "
              "exact historical derivation UNVERIFIED; 9 backups differ from current outputs; no writes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
