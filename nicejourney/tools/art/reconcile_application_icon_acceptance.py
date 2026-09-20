#!/usr/bin/env python3
"""Accept one source-exact, reversible Nice Journey prototype project icon.

The accepted Tower Sigil glyph is reused as the project icon without inventing
a final product logo, changing export presets, or claiming packaged-platform QA.
Read-only by default; --apply updates two 223-record inventories and provenance.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from build_application_tower_sigil_icon import EVIDENCE, OUTPUT, ROOT, SOURCE, expected, sha
from reconcile_current_ui_icon_inventory import corrected_counts, replace_object
from verify_application_icon_native import CAPTURE, REPORT, verify

ASSET_ID = "application.icon"
TARGET = "res://assets/art/ui/application/application_icon_tower_sigil_v02.png"
SOURCE_RESOURCE = "res://assets/art/ui/markers/tower_sigil_icon_v01.png"
RECIPE = "Exact 32x32 accepted Tower Sigil RGBA -> 128x128 4x nearest-neighbor; no recolor, crop, new figure, typography or invented emblem"
INVENTORIES = (ROOT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               ROOT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
PROVENANCE = ROOT / "docs/ASSET_PROVENANCE_MANIFEST.json"


def acceptance_proof() -> dict:
    rendering = verify()
    png, parent_sha = expected()
    sidecar = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if sidecar["accepted_source_sha256"] != parent_sha or sidecar["derivative_sha256"] != sha(png):
        raise ValueError("app icon source/provenance sidecar changed")
    if not (ROOT / "icon.svg").is_file():
        raise ValueError("legacy Godot icon was not retained")
    if rendering["native_opaque_source_pixels_checked"] != 5104 or rendering["maximum_rgb_delta"] > 5:
        raise ValueError("native icon rendering no longer matches the inspected source")
    return {
        "source": SOURCE_RESOURCE,
        "source_sha256": parent_sha,
        "source_file_exists": True,
        "output": TARGET,
        "output_sha256": rendering["production_sha256"],
        "output_dimensions": [128, 128],
        "output_mode": "RGBA",
        "derivation_recipe": RECIPE,
        "derivation_manifest": "res://assets/art/ui/application/application_icon_tower_sigil_v02.json",
        "actual_project_config": "res://project.godot",
        "actual_config_icon_bound": True,
        "native_renderer_capture": "res://docs/evidence/renderer/application-icon-tower-sigil-v02-native.png",
        "native_renderer_capture_sha256": rendering["native_capture_sha256"],
        "native_renderer_metadata": "res://docs/evidence/renderer/application-icon-tower-sigil-v02-native.json",
        "native_source_pixels_checked": 5104,
        "native_max_rgb_delta": rendering["maximum_rgb_delta"],
        "native_max_alpha_delta": rendering["maximum_alpha_delta"],
        "legacy_default_svg_preserved": True,
        "final_product_brand_or_packaged_platform_icon_claimed": False,
    }


def update_inventory(path: Path, proof: dict) -> tuple[bytes, str, dict]:
    before = path.read_bytes()
    text = before.decode("utf-8")
    items = [item for item in json.loads(text)["assets"] if item["stable_asset_id"] == ASSET_ID]
    if len(items) != 1:
        raise ValueError("application icon asset ID missing or repeated")
    item = items[0].copy()
    if item["classification"] not in ("PLACEHOLDER", "ACCEPTED_DO_NOT_REGENERATE"):
        raise ValueError("unexpected application icon classification")
    if item["classification"] == "PLACEHOLDER" and item["current_existing_asset"] != "res://icon.svg":
        raise ValueError("old project icon no longer matches the audited default")
    item["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
    item["subject"] = "Source-backed Tower Sigil prototype application icon"
    item["reference_assets"] = [SOURCE_RESOURCE]
    item["transparency_requirement"] = "128x128 RGBA; original Tower Sigil alpha unchanged by 4x nearest scaling"
    item["current_existing_asset"] = TARGET
    item["current_implementation_status"] = "Actual project config/icon references 128px icon derived only from accepted Tower Sigil; native GL Compatibility 128px capture verified with unchanged alpha and 5104 source pixels"
    item["generation_revision_requirement"] = "NONE for reversible source-backed prototype app icon; distinct final product branding/platform export icon requires separately authored approval"
    item["acceptance_scope"] = "Source-backed prototype Godot project icon, not a separately approved brand/logo or packaged Windows/Linux/macOS icon"
    item["issues"] = []
    item["verified_evidence"] = proof
    item["prior_audit_snapshot"] = {"previous_asset": "res://icon.svg", "reason": "Unbranded Godot default; original file preserved"}
    text = replace_object(text, ASSET_ID, item)
    text, counts = corrected_counts(text)
    if counts["ACCEPTED_DO_NOT_REGENERATE"] != 178 or counts["PLACEHOLDER"] != 18:
        raise ValueError("application icon reconciliation altered unexpected asset records")
    return before, text, counts


def provenance_record(proof: dict) -> dict:
    return {
        "asset_name": "Application Icon Tower Sigil V02 (Prototype)",
        "project_path": TARGET,
        "source": SOURCE_RESOURCE,
        "creator_source": "Exact 4x nearest reuse of an accepted Nice Journey ImageGen core9 Tower Sigil derivative; source SHA-256 " + proof["source_sha256"],
        "license_category": "ai_generated_terms_permit",
        "license_text": "Derived from existing accepted Nice Journey AI-generated art; release terms remain subject to normal project review.",
        "attribution_text": "",
        "modifications": RECIPE,
        "date_imported": "2026-09-20",
        "responsible_agent": "OpenAI ChatGPT",
        "kind": "pixel_art",
        "pixel_metadata": {
            "dimensions": "128x128 px application icon, source 32x32 px",
            "palette_material_ramp": "Exact accepted Tower Sigil dark-outline and gold/teal palette; no added symbols/colors",
            "pivot_ground_anchor": "Full centered icon canvas; no actor/world anchor",
            "frame_order_timing": "One static icon, no animation",
            "transparent_bounds": "Original Tower Sigil RGBA alpha preserved exactly under 4x pixel-nearest scaling",
            "intended_render_layers": ["godot_project_application_icon"],
        },
        "source_sha256": proof["source_sha256"],
        "output_sha256": proof["output_sha256"],
        "derivation_manifest": proof["derivation_manifest"],
        "acceptance_scope": "Godot prototype project icon only; no final brand identity/platform export promise",
    }


def provenance_text(proof: dict) -> tuple[bytes, str]:
    before = PROVENANCE.read_bytes()
    text = before.decode("utf-8")
    entries = [item for item in json.loads(text)["assets"] if item["project_path"] == TARGET]
    if len(entries) > 1:
        raise ValueError("duplicate icon provenance record")
    if entries:
        if entries[0].get("output_sha256") != proof["output_sha256"]:
            raise ValueError("icon provenance changed without review")
        return before, text
    anchor = '"project_path": "res://assets/art/ui/markers/map_marker_quest_sigil_v02.png"'
    if text.count(anchor) != 1:
        raise ValueError("missing unique accepted map-marker provenance insertion point")
    begin = text.rfind("{", 0, text.index(anchor))
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = json.dumps(provenance_record(proof), indent=4, ensure_ascii=False).splitlines()
    formatted = newline.join([lines[0]] + ["        " + part for part in lines[1:]])
    text = text[:begin] + formatted + "," + newline + "        " + text[begin:]
    if len([item for item in json.loads(text)["assets"] if item["project_path"] == TARGET]) != 1:
        raise ValueError("insertion did not produce one new provenance record")
    return before, text


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    opts = parser.parse_args()
    proof = acceptance_proof()
    prepared = {path: update_inventory(path, proof) for path in INVENTORIES}
    old_provenance, updated_provenance = provenance_text(proof)
    if opts.apply:
        for path, (before, updated, counts) in prepared.items():
            if path.read_bytes() != before:
                raise ValueError("concurrent asset manifest change")
            temporary = path.with_name(path.name + ".app-icon-tmp")
            temporary.write_bytes(updated.encode("utf-8"))
            os.replace(temporary, path)
            print(f"UPDATED {path}: {counts}")
        if PROVENANCE.read_bytes() != old_provenance:
            raise ValueError("concurrent provenance change")
        temporary = PROVENANCE.with_name(PROVENANCE.name + ".app-icon-tmp")
        temporary.write_bytes(updated_provenance.encode("utf-8"))
        os.replace(temporary, PROVENANCE)
    else:
        print("APPLICATION ICON ACCEPTANCE READY: source-exact prototype only; no release export or final brand approval")


if __name__ == "__main__":
    main()
