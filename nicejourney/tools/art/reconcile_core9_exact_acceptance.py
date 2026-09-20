"""Correct nine core UI icon source, derivation, inventory and provenance records.

Never regenerate current icon PNGs. The recovered exact recipe is distinct from
the eighteen V02 skill-icon pipeline. The 3x3 generated source is immutable.
This script has a read-only default; --apply changes metadata only.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image

from audit_ui_core9_attribution import SOURCE, SOURCE_HASH, CORE9
from verify_ui_core9_exact_derivation import verify
from reconcile_current_ui_icon_inventory import corrected_counts, replace_object
from reconcile_region3_decorative_11_12_acceptance import digest


PROJECT = Path(__file__).resolve().parents[2]
MANIFEST = PROJECT / "assets/art/generated_sources/imagegen/ui/ui_skill_icon_v02_derivation_manifest.json"
PROVENANCE = PROJECT / "docs/ASSET_PROVENANCE_MANIFEST.json"
INVENTORIES = (PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
SHOWCASE = PROJECT / "artifacts/ui/ui_icon_catalog_showcase_v02.png"
DERIVATION_RESOURCE = "res://assets/art/generated_sources/imagegen/ui/ui_skill_icon_v02_derivation_manifest.json"
RECIPE = "full 418x418 cell -> direct RGBA PIL NEAREST 32x32 -> PNG optimize=False; no alpha cutoff/bbox/padding/compositing"


def target_id(name: str) -> str:
    if name.startswith("class_"):
        return "asset:ui/classes/" + name + "_icon"
    if name.startswith("quest_family_"):
        return "asset:ui/quests/" + name
    if name.startswith("status_"):
        return "asset:ui/status/" + name
    if name == "tower_sigil":
        return "asset:ui/markers/tower_sigil_icon"
    raise ValueError(f"unknown icon semantic: {name}")


def metadata() -> tuple[dict, str, list[dict]]:
    proof = verify()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = manifest["core9_preserved"]
    with Image.open(SHOWCASE) as review:
        if review.size != (1280, 720):
            raise ValueError("28-profile real renderer showcase missing/wrong canvas")
    screenshot_sha = digest(SHOWCASE)
    for item, result in zip(entries, proof):
        name = result["asset_id"]
        if item["asset_id"] != "ui_" + name + "_v01" or item["output"] != result["output"]:
            raise ValueError("source/cell/semantic mismatch")
        profile = PROJECT / "src/ui/presentation/profiles" / (name + ".tres")
        if result["output"] not in profile.read_text(encoding="utf-8"):
            raise ValueError(f"core icon not actually Inspector-bound: {name}")
        item.update({
            "attribution_status": "exact_source_cell_byte_derivation_verified",
            "exact_derivation_verified": True,
            "exact_derivation_recipe": RECIPE,
            "exact_derivation_verifier": "res://tools/art/verify_ui_core9_exact_derivation.py",
            "status": "preserved_existing_core9_exact_derivation_verified",
        })
    return manifest, screenshot_sha, proof


def save_or_preview(path: Path, before: bytes, after: str, apply: bool) -> None:
    json.loads(after)
    if apply:
        if path.read_bytes() != before:
            raise ValueError(f"concurrent metadata edit: {path}")
        temp = path.with_name(path.name + ".core9-tmp")
        temp.write_bytes(after.encode("utf-8"))
        os.replace(temp, path)
    print(("UPDATED " if apply else "READY ") + str(path))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    opts = parser.parse_args()
    manifest, screenshot_sha, proof = metadata()
    records_by_id = {target_id(result["asset_id"]): result for result in proof}
    if len(records_by_id) != 9:
        raise ValueError("nine unique semantic icons required")
    old_manifest = MANIFEST.read_bytes()
    new_manifest = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"

    inventory_changes = {}
    for inventory in INVENTORIES:
        original = inventory.read_bytes()
        text = original.decode("utf-8")
        assets = {item["stable_asset_id"]: item for item in json.loads(text)["assets"]}
        for asset_id, result in records_by_id.items():
            item = assets[asset_id].copy()
            if item["classification"] not in ("EXISTS_NEEDS_REVISION", "ACCEPTED_DO_NOT_REGENERATE"):
                raise ValueError(f"unsafe icon classification: {asset_id}")
            if item["current_existing_asset"] != result["output"]:
                raise ValueError(f"wrong production icon: {asset_id}")
            item["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
            item["generation_revision_requirement"] = "NONE: preserve exact source and current byte-reproducible PNG; no regeneration required"
            item["current_implementation_status"] = "Exact generated cell-to-icon bytes reproduced 9/9; source preserved and UI Inspector/catalog renderer validated"
            item["acceptance_scope"] = "32x32 source-derived icon artwork and 28-entry UI catalog; real per-screen layouts remain independently tested"
            item["verified_evidence"] = {
                "source": f"res://{SOURCE.relative_to(PROJECT).as_posix()}",
                "source_sha256": SOURCE_HASH,
                "source_file_exists": True,
                "source_dimensions": [1254, 1254],
                "source_crop_xyxy": result["source_crop_xyxy"],
                "source_cell_index": result["source_cell_index"],
                "exact_derivation_recipe": RECIPE,
                "exact_derivation_verified": True,
                "output": result["output"],
                "output_sha256": result["exact_png_sha256"],
                "output_dimensions": [32, 32],
                "derivation_manifest": DERIVATION_RESOURCE,
                "byte_derivation_verifier": "res://tools/art/verify_ui_core9_exact_derivation.py",
                "godot_catalog_renderer": "res://artifacts/ui/ui_icon_catalog_showcase_v02.png",
                "godot_catalog_renderer_sha256": screenshot_sha,
            }
            item["issues"] = []
            text = replace_object(text, asset_id, item)
        text, counts = corrected_counts(text)
        inventory_changes[inventory] = (original, text, counts)

    old_provenance = PROVENANCE.read_bytes()
    provenance_text = old_provenance.decode("utf-8")
    data = json.loads(provenance_text)
    by_path = {item["project_path"]: item for item in data["assets"]}
    for result in proof:
        target = result["output"]
        item = by_path[target].copy()
        if item["project_path"] != target:
            raise ValueError("wrong provenance record")
        item.update({
            "source": f"res://{SOURCE.relative_to(PROJECT).as_posix()}",
            "creator_source": f"Built-in image generator; model version not exposed. Exact preserved source SHA-256 {SOURCE_HASH}",
            "license_category": "ai_generated_terms_permit",
            "license_text": "Generated for Nice Journey under the project's AI-generated-use category; not an independent legal review of generator terms.",
            "modifications": RECIPE,
            "source_sha256": SOURCE_HASH,
            "output_sha256": result["exact_png_sha256"],
            "derivation_manifest": DERIVATION_RESOURCE,
            "acceptance_status": "exact_source_byte_derivation_and_renderer_catalog_reviewed",
        })
        provenance_text = _replace_provenance(provenance_text, target, item)

    # Validate all three new documents before the first actual write.
    json.loads(new_manifest)
    json.loads(provenance_text)
    for _path, (_old, body, _counts) in inventory_changes.items():
        json.loads(body)

    save_or_preview(MANIFEST, old_manifest, new_manifest, opts.apply)
    save_or_preview(PROVENANCE, old_provenance, provenance_text, opts.apply)
    for path, (original, text, counts) in inventory_changes.items():
        save_or_preview(path, original, text, opts.apply)
        print(f"9/9 core icons accepted; totals={counts}")


def _replace_provenance(text: str, path: str, replacement: dict) -> str:
    token = f'"project_path": "{path}"'
    if text.count(token) != 1:
        raise ValueError(f"expected exactly one provenance record: {path}")
    point = text.index(token)
    start = text.rfind("{", 0, point)
    prior, size = json.JSONDecoder().raw_decode(text[start:])
    if prior.get("project_path") != path:
        raise ValueError(f"corrupt provenance record boundary: {path}")
    margin = len(text[text.rfind("\n", 0, start) + 1:start])
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = json.dumps(replacement, ensure_ascii=False, indent=2).splitlines()
    content = newline.join([lines[0]] + [" " * margin + line for line in lines[1:]])
    return text[:start] + content + text[start + size:]


if __name__ == "__main__":
    main()
