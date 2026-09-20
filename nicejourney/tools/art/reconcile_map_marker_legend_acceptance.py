#!/usr/bin/env python3
"""Accept only the four source-backed map glyphs and their live read-only legend.

Does not author quest coordinates, grant Tower Sigil travel, or accept any other
open asset. Read-only by default; --apply changes two inventories and provenance.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image

from promote_map_marker_quest_sigil_v02 import DESTINATION, PROVENANCE, ROOT, digest, produce
from reconcile_current_ui_icon_inventory import corrected_counts, replace_object
from verify_map_marker_live_menu_native import main as verify_native

ASSET_ID = "asset:ui/markers/map_marker_sheet"
ASSET_PATH = "res://assets/art/ui/markers/map_marker_quest_sigil_v02.png"
SCENE = "res://src/ui/map_menu.tscn"
PROFILE = "res://src/ui/presentation/profiles/map_marker_sheet.tres"
NATIVE = "res://docs/evidence/renderer/map-marker-live-menu-native.png"
EVIDENCE = "res://docs/evidence/renderer/map-marker-live-menu-native.json"
INVENTORIES = (ROOT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               ROOT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
PROJECT_PROVENANCE = ROOT / "docs/ASSET_PROVENANCE_MANIFEST.json"


def validate() -> dict:
    expected, source = produce()
    if DESTINATION.read_bytes() != expected:
        raise ValueError("production sheet is not byte-for-byte reproducible")
    sidecar = json.loads(PROVENANCE.read_text(encoding="utf-8"))
    if sidecar["production_sha256"] != digest(expected) or sidecar["imagegen_source_sha256"] != source["source_sha256"]:
        raise ValueError("production sidecar lost the accepted source chain")
    if not (ROOT / "assets/art/ui/markers/map_marker_sheet_v01.png").is_file():
        raise ValueError("preserved V01 placeholder missing")
    profile = (ROOT / PROFILE.removeprefix("res://")).read_text(encoding="utf-8")
    scene = (ROOT / SCENE.removeprefix("res://")).read_text(encoding="utf-8")
    if ASSET_PATH not in profile or ASSET_PATH not in scene:
        raise ValueError("production marker sheet not Inspector-bound in both consumers")
    for index, name in enumerate(("escort", "defense", "annihilation", "sigil")):
        if f"AtlasTexture_{name}" not in scene or f"Rect2({index * 32}, 0, 32, 32)" not in scene:
            raise ValueError(f"missing exact semantic cell binding: {name}")
    if "locations unauthored; map travel unavailable" not in scene or "MarkerLegend" not in scene:
        raise ValueError("map legend no longer disclaims unauthored state")
    with Image.open(DESTINATION) as image:
        if image.mode != "RGBA" or image.size != (128, 32) or image.getchannel("A").getextrema()[0] != 0:
            raise ValueError("unexpected production PNG dimensions or transparency")
    verify_native()
    capture = json.loads((ROOT / EVIDENCE.removeprefix("res://")).read_text(encoding="utf-8"))
    if capture["production_sheet"] != ASSET_PATH or capture["actual_quest_marker_count"] != 0:
        raise ValueError("map renderer evidence is not the bounded live legend")
    return {
        "sha256": digest(expected),
        "dimensions": [128, 32],
        "mode": "RGBA",
        "source": source["source"],
        "source_sha256": source["source_sha256"],
        "source_file_exists": True,
        "exact_source_cell_derivation": source["derivation"],
        "derivation_manifest": "res://assets/art/ui/markers/map_marker_quest_sigil_v02.json",
        "cell_semantics": [entry["semantic_id"] for entry in source["cells"]],
        "live_map_menu": SCENE,
        "inspector_icon_profile": PROFILE,
        "native_renderer_capture": NATIVE,
        "native_renderer_sha256": digest((ROOT / NATIVE.removeprefix("res://")).read_bytes()),
        "native_renderer_evidence": EVIDENCE,
        "native_near_opaque_source_pixels_matching": 1515,
        "map_quest_coordinates_authored": False,
        "map_travel_action_added": False,
    }


def provenance_entry(proof: dict) -> dict:
    return {
        "asset_name": "Map Marker Quest and Sigil Glyph Sheet V02",
        "project_path": ASSET_PATH,
        "source": proof["source"],
        "creator_source": "Exact accepted original Nice Journey ImageGen core9 source; SHA-256 " + proof["source_sha256"],
        "license_category": "ai_generated_terms_permit",
        "license_text": "Generated for Nice Journey under the project's AI-generated-use category; release terms require normal project review.",
        "attribution_text": "",
        "modifications": proof["exact_source_cell_derivation"],
        "date_imported": "2026-09-20",
        "responsible_agent": "OpenAI ChatGPT",
        "kind": "pixel_art",
        "pixel_metadata": {
            "dimensions": "128x32 px; four individually addressable 32x32 glyphs",
            "palette_material_ramp": "Exact unaltered four accepted core9 icon palettes and silhouettes",
            "pivot_ground_anchor": "Each static glyph uses its own 32x32 AtlasTexture region; no world geometry or character anchor",
            "frame_order_timing": "Escort, Tower Defense, Annihilation, Tower Sigil; no animation",
            "transparent_bounds": "RGBA source alpha preserved without recoloring, padding or filtering",
            "intended_render_layers": ["map_menu_read_only_symbol_legend", "ui_icon_catalog"],
        },
        "source_sha256": proof["source_sha256"],
        "output_sha256": proof["sha256"],
        "derivation_manifest": proof["derivation_manifest"],
        "acceptance_scope": "Four-glyph read-only MapMenu key only; quest marker location authoring and travel remain separately unavailable",
    }


def prepare_inventory(path: Path, proof: dict) -> tuple[bytes, str, dict]:
    before = path.read_bytes()
    text = before.decode("utf-8")
    matching = [x for x in json.loads(text)["assets"] if x["stable_asset_id"] == ASSET_ID]
    if len(matching) != 1:
        raise ValueError("map-sheet record missing or duplicated")
    entry = matching[0].copy()
    if entry["classification"] not in ("PLACEHOLDER", "ACCEPTED_DO_NOT_REGENERATE"):
        raise ValueError("unexpected map-sheet classification")
    if entry["classification"] == "PLACEHOLDER":
        if entry["current_existing_asset"] != "res://assets/art/ui/markers/map_marker_sheet_v01.png":
            raise ValueError("the old placeholder has changed without review")
        entry["prior_audit_snapshot"] = {
            "previous_asset": entry["current_existing_asset"],
            "previous_verified_evidence": entry["verified_evidence"],
        }
    entry["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
    entry["subject"] = "Map Marker Quest and Sigil Glyph Sheet V02"
    entry["current_existing_asset"] = ASSET_PATH
    entry["reference_assets"] = [proof["source"]]
    entry["target_godot_resource_scene"] = [PROFILE, SCENE]
    entry["generation_revision_requirement"] = "NONE for accepted glyph sheet and actual read-only map legend; world quest coordinates remain independent future authoring"
    entry["current_implementation_status"] = "Four byte-reproducible accepted ImageGen icon cells are Inspector-bound in the live MapMenu legend and UI catalog; no quest marker locations or travel actions invented"
    entry["acceptance_scope"] = "Exact four 32px symbols, source/derivation, actual live read-only map-menu legend and native GL renderer only; not geographic quest marker placement or map travel"
    entry["verified_evidence"] = proof
    entry["issues"] = []
    text = replace_object(text, ASSET_ID, entry)
    text, counts = corrected_counts(text)
    if counts["ACCEPTED_DO_NOT_REGENERATE"] != 177 or counts["PLACEHOLDER"] != 19:
        raise ValueError("the reconciliation changed unexpected asset counts")
    return before, text, counts


def prepare_provenance(proof: dict) -> tuple[bytes, str]:
    before = PROJECT_PROVENANCE.read_bytes()
    text = before.decode("utf-8")
    entries = json.loads(text)["assets"]
    if any(item["project_path"] == ASSET_PATH for item in entries):
        return before, text
    anchor = '"project_path": "res://assets/art/ui/markers/map_marker_sheet_v01.png"'
    if text.count(anchor) != 1:
        raise ValueError("could not locate preserved V01 provenance")
    point = text.rfind("{", 0, text.index(anchor))
    newline = "\r\n" if "\r\n" in text else "\n"
    item_lines = json.dumps(provenance_entry(proof), indent=4, ensure_ascii=False).splitlines()
    serialized = newline.join([item_lines[0]] + ["        " + line for line in item_lines[1:]])
    text = text[:point] + serialized + "," + newline + "        " + text[point:]
    parsed = json.loads(text)
    if len([x for x in parsed["assets"] if x["project_path"] == ASSET_PATH]) != 1:
        raise ValueError("new provenance is missing or duplicated")
    return before, text


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    options = parser.parse_args()
    proof = validate()
    inventories = {path: prepare_inventory(path, proof) for path in INVENTORIES}
    old_provenance, updated_provenance = prepare_provenance(proof)
    if options.apply:
        for path, (before, updated, counts) in inventories.items():
            if path.read_bytes() != before:
                raise ValueError(f"concurrent edit: {path}")
            temporary = path.with_name(path.name + ".map-marker-tmp")
            temporary.write_bytes(updated.encode("utf-8"))
            os.replace(temporary, path)
            print(f"UPDATED {path}: {counts}")
        if PROJECT_PROVENANCE.read_bytes() != old_provenance:
            raise ValueError("concurrent provenance edit")
        temporary = PROJECT_PROVENANCE.with_name(PROJECT_PROVENANCE.name + ".map-marker-tmp")
        temporary.write_bytes(updated_provenance.encode("utf-8"))
        os.replace(temporary, PROJECT_PROVENANCE)
    else:
        print("MAP MARKER LEGEND ACCEPTANCE READY: 1 exact source-backed glyph sheet, 4 live cells, 1515 verified pixels")


if __name__ == "__main__":
    main()
