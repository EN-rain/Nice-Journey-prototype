"""Safely synchronize the current 18 skill icons and nine core UI records.

The handoff already records the 18 reviewed V02 skill icons; the older live
production inventory still lists their V01 placeholders. Core9 remain revision
records because pixel-correlated origins do not prove historical derivation.
No PNG, skill profile, or animation resource is regenerated or rewritten.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image

from audit_ui_core9_attribution import audit_core9
from verify_ui_core9_exact_derivation import verify as verify_core9_exact
from reconcile_region3_decorative_11_12_acceptance import digest, actual_path


PROJECT = Path(__file__).resolve().parents[2]
HANDOFF = PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json"
PRODUCTION = PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json"
DERIVATION = PROJECT / "assets/art/generated_sources/imagegen/ui/ui_skill_icon_v02_derivation_manifest.json"
SHOWCASE = PROJECT / "artifacts/ui/ui_icon_catalog_showcase_v02.png"


def validate_art() -> tuple[dict, dict]:
    manifest = json.loads(DERIVATION.read_text(encoding="utf-8"))
    recorded = manifest["skill_source_batches"]
    if len(recorded) != 18 or len({x["skill_id"] for x in recorded}) != 18:
        raise ValueError("expected 18 distinct current skill icons")
    skill_records = {}
    for entry in recorded:
        name = entry["skill_id"]
        if digest(actual_path(entry["source"])) != entry["source_sha256"]:
            raise ValueError(f"changed skill source: {name}")
        image = actual_path(entry["output"])
        if digest(image) != entry["output_sha256"]:
            raise ValueError(f"changed skill icon: {name}")
        with Image.open(image) as graphic:
            if graphic.size != (32, 32) or graphic.mode != "RGBA":
                raise ValueError(f"invalid skill icon canvas: {name}")
        profile = PROJECT / f"src/ui/presentation/profiles/skill_{name}.tres"
        if entry["output"] not in profile.read_text(encoding="utf-8"):
            raise ValueError(f"skill icon not in its Inspector profile: {name}")
        skill_records[f"asset:ui/skills/skill_{name}"] = entry
    if not SHOWCASE.is_file():
        raise ValueError("missing reviewed 28-icon renderer showcase")
    with Image.open(SHOWCASE) as screenshot:
        if screenshot.size != (1280, 720):
            raise ValueError("wrong UI renderer showcase size")
    core = audit_core9()
    exact = verify_core9_exact()
    if len(core) != 9:
        raise ValueError("expected nine pixel-correlated core icons")
    core_records = {}
    for entry, reproduced, saved in zip(core, exact, manifest["core9_preserved"]):
        if not saved.get("exact_derivation_verified") or saved["output_sha256"] != reproduced["exact_png_sha256"]:
            raise ValueError("core icon exact derivation metadata reverted")
        asset_id = entry["asset_id"].removeprefix("ui_").removesuffix("_v01")
        if asset_id.startswith("class_"):
            key = "asset:ui/classes/" + asset_id + "_icon"
        elif asset_id.startswith("quest_family_"):
            key = "asset:ui/quests/" + asset_id
        elif asset_id.startswith("status_"):
            key = "asset:ui/status/" + asset_id
        elif asset_id == "tower_sigil":
            key = "asset:ui/markers/tower_sigil_icon"
        else:
            raise ValueError(f"unknown core9 semantic ID: {asset_id}")
        core_records[key] = entry
    return skill_records, core_records


def replace_object(raw: str, asset_id: str, replacement: dict) -> str:
    token = f'"stable_asset_id": "{asset_id}"'
    if raw.count(token) != 1:
        raise ValueError(f"ambiguous record {asset_id}")
    position = raw.index(token)
    begin = raw.rfind("{", 0, position)
    old, length = json.JSONDecoder().raw_decode(raw[begin:])
    if old.get("stable_asset_id") != asset_id:
        raise ValueError(f"bad record boundary: {asset_id}")
    margin = len(raw[raw.rfind("\n", 0, begin) + 1:begin])
    newline = "\r\n" if "\r\n" in raw else "\n"
    lines = json.dumps(replacement, indent=2, ensure_ascii=False).splitlines()
    new = newline.join([lines[0]] + [" " * margin + line for line in lines[1:]])
    return raw[:begin] + new + raw[begin + length:]


def corrected_counts(text: str) -> tuple[str, dict]:
    parsed = json.loads(text)
    actual = {}
    for asset in parsed["assets"]:
        actual[asset["classification"]] = actual.get(asset["classification"], 0) + 1
    if len(parsed["assets"]) != 223:
        raise ValueError("lost an inventory record")
    first = text.index('"classification_counts": {')
    last = text.index("}", first) + 1
    old = text[first:last]
    for key, count in parsed["classification_counts"].items():
        old_token = f'"{key}": {count}'
        if old.count(old_token) != 1:
            raise ValueError(f"unexpected classification count token: {key}")
        old = old.replace(old_token, f'"{key}": {actual[key]}', 1)
    text = text[:first] + old + text[last:]
    if json.loads(text)["classification_counts"] != actual:
        raise ValueError("classification summary mismatch")
    return text, actual


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    opts = parser.parse_args()
    skills, core = validate_art()
    base = json.loads(HANDOFF.read_text(encoding="utf-8"))
    canonical = {x["stable_asset_id"]: x for x in base["assets"]}
    target_ids = sorted([*skills, *core])
    changes = {}
    for asset_id in target_ids:
        exemplar = canonical[asset_id].copy()
        if asset_id in skills:
            if exemplar["classification"] != "ACCEPTED_DO_NOT_REGENERATE":
                raise ValueError(f"skill not accepted in verified handoff: {asset_id}")
            if exemplar["current_existing_asset"] != skills[asset_id]["output"]:
                raise ValueError(f"skill output mismatch: {asset_id}")
            if exemplar["verified_evidence"]["output_sha256"] != skills[asset_id]["output_sha256"]:
                raise ValueError(f"stale skill acceptance evidence: {asset_id}")
        else:
            if exemplar["classification"] != "ACCEPTED_DO_NOT_REGENERATE":
                raise ValueError(f"core icon exact derivation/acceptance regressed: {asset_id}")
            proof = core[asset_id]
            if exemplar["current_existing_asset"] != proof["output"]:
                raise ValueError(f"core output mismatch: {asset_id}")
            if not exemplar["verified_evidence"].get("exact_derivation_verified") or exemplar["verified_evidence"]["output_sha256"] != proof["output_sha256"]:
                raise ValueError(f"core icon byte provenance no longer verified: {asset_id}")
        changes[asset_id] = exemplar
    for inventory in (HANDOFF, PRODUCTION):
        before = inventory.read_bytes()
        text = before.decode("utf-8")
        for asset_id, item in changes.items():
            text = replace_object(text, asset_id, item)
        text, counts = corrected_counts(text)
        if opts.apply:
            if inventory.read_bytes() != before:
                raise ValueError(f"concurrent inventory edit: {inventory}")
            temporary = inventory.with_name(inventory.name + ".ui-sync-tmp")
            temporary.write_bytes(text.encode("utf-8"))
            os.replace(temporary, inventory)
        print(f"{'UPDATED' if opts.apply else 'READY'} {inventory}: skills=18 accepted, core=9 exact-byte accepted, counts={counts}")


if __name__ == "__main__":
    main()
