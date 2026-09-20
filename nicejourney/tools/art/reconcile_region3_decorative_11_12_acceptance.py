"""Reconcile the two source-reviewed Region3 V02 decorative visual records.

Checks actual immutable sources, current derivatives, Inspector-bound textures,
provenance entries and native Godot capture evidence before changing the two
specific records in both existing production inventories. No image is written.
The old corrupt Batch2 ZIP remains historical evidence, not a live dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[2]
WORKSPACE = PROJECT.parent
DERIVATION = PROJECT / "assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_building_v02_derivation_manifest.json"
PROVENANCE = PROJECT / "docs/ASSET_PROVENANCE_MANIFEST.json"
CAPTURES = PROJECT / "docs/evidence/renderer/region3-decorative-11-12-current.json"
INVENTORIES = (WORKSPACE / "Nice_Journey_Asset_Handoff_Manifest.json",
               PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def actual_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"not a project resource path: {res_path}")
    return PROJECT / res_path.removeprefix("res://")


def evidence() -> dict:
    derivation = json.loads(DERIVATION.read_text(encoding="utf-8"))["buildings"]
    provenance = json.loads(PROVENANCE.read_text(encoding="utf-8"))["assets"]
    captures = json.loads(CAPTURES.read_text(encoding="utf-8"))["records"]
    result = {}
    for index in (11, 12):
        identifier = f"r3:decorative:{index}"
        source = derivation[identifier]
        original = actual_path(source["exact_source"])
        derivative = actual_path(source["derivative"])
        if digest(original) != source["exact_source_sha256"]:
            raise ValueError(f"changed original source: {identifier}")
        if digest(derivative) != source["derivative_sha256"]:
            raise ValueError(f"changed production derivative: {identifier}")
        with Image.open(derivative) as sprite:
            if sprite.mode != "RGBA" or sprite.size != (160, 160) or sprite.getchannel("A").getextrema() != (0, 255):
                raise ValueError(f"invalid production pixels: {identifier}")
        profile = PROJECT / f"src/world/region3/presentation/profiles/decorative_{index:02d}_visual_profile.tres"
        if source["derivative"] not in profile.read_text(encoding="utf-8"):
            raise ValueError(f"unbound V02 visual: {identifier}")
        entry = [x for x in provenance if x.get("project_path") == source["derivative"]]
        if len(entry) != 1 or entry[0].get("source") != source["exact_source"]:
            raise ValueError(f"missing source provenance: {identifier}")
        capture = [x for x in captures if x["building_id"] == index]
        if len(capture) != 1 or capture[0]["production_sha256"] != source["derivative_sha256"]:
            raise ValueError(f"renderer/source mismatch: {identifier}")
        screenshot = actual_path(capture[0]["image"])
        with Image.open(screenshot) as review:
            if review.size != (640, 360):
                raise ValueError(f"not a native canvas capture: {identifier}")
        result[identifier] = {
            "source": source["exact_source"],
            "source_sha256": source["exact_source_sha256"],
            "production_sha256": source["derivative_sha256"],
            "screenshot": capture[0]["image"],
            "screenshot_sha256": digest(screenshot),
        }
    return result


def replace_record(text: str, asset_id: str, verified: dict) -> str:
    needle = f'"stable_asset_id": "{asset_id}"'
    if text.count(needle) != 1:
        raise ValueError(f"expected one inventory record: {asset_id}")
    index = text.index(needle)
    start = text.rfind("{", 0, index)
    item, size = json.JSONDecoder().raw_decode(text[start:])
    if item.get("stable_asset_id") != asset_id:
        raise ValueError(f"record boundary mismatch: {asset_id}")
    if item["classification"] not in ("EXISTS_NEEDS_REVISION", "ACCEPTED_DO_NOT_REGENERATE"):
        raise ValueError(f"unexpected classification: {asset_id}")
    old_evidence = item.get("verified_evidence", {}).copy()
    if old_evidence.get("sha256") not in (None, verified["production_sha256"]):
        item["prior_audit_snapshot"] = {"previous_dimensions_and_sha": old_evidence,
                                        "previous_issues": item.get("issues", [])}
    item["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
    item["generation_revision_requirement"] = "NONE: preserve reviewed replacement exact source and current 160x160 V02 derivative"
    item["current_implementation_status"] = "Current V02 source-derived art and Inspector texture are live; native-canvas Godot review captured; regional route coverage is a separate test"
    item["acceptance_scope"] = "Source preservation, deterministic V02 derivative, Inspector consumer and native renderer evidence for this decorative identity; not all-region acceptance"
    item["verified_evidence"] = {
        "sha256": verified["production_sha256"],
        "dimensions": [160, 160],
        "mode": "RGBA",
        "alpha_extrema": [0, 255],
        "source": verified["source"],
        "source_sha256": verified["source_sha256"],
        "source_file_exists": True,
        "native_renderer_capture": verified["screenshot"],
        "native_renderer_sha256": verified["screenshot_sha256"],
    }
    item["issues"] = []
    if isinstance(item.get("production_progress"), dict):
        item["production_progress"]["final_acceptance"] = "accepted decorative identity visual; region-wide QA separate"
        item["production_progress"]["renderer_review"] = "previous gameplay review passed; fresh native 640x360 capture: " + verified["screenshot"]
    indent = len(text[text.rfind("\n", 0, start) + 1:start])
    newline = "\r\n" if "\r\n" in text else "\n"
    serialized = json.dumps(item, ensure_ascii=False, indent=2)
    lines = serialized.splitlines()
    serialized = newline.join([lines[0]] + [" " * indent + line for line in lines[1:]])
    return text[:start] + serialized + text[start + size:]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="change only the two verified records and count fields")
    options = parser.parse_args()
    verified = evidence()
    for inventory in INVENTORIES:
        before = inventory.read_bytes()
        text = before.decode("utf-8")
        for asset_id, proof in verified.items():
            text = replace_record(text, asset_id, proof)
        document = json.loads(text)
        counts = {}
        for item in document["assets"]:
            counts[item["classification"]] = counts.get(item["classification"], 0) + 1
        if sum(counts.values()) != len(document["assets"]):
            raise ValueError(f"invalid inventory counts: {inventory}")
        if len(document["assets"]) != 223:
            raise ValueError("changed number of asset records")
        original_counts = document["classification_counts"]
        for classification in original_counts:
            if classification not in counts:
                raise ValueError(f"missing classification {classification}")
            old = f'"{classification}": {original_counts[classification]}'
            new = f'"{classification}": {counts[classification]}'
            if text.count(old) < 1:
                raise ValueError(f"count field not uniquely locatable: {classification}")
            # Only replace the first occurrence: the top-level count object.
            text = text.replace(old, new, 1)
        if options.apply:
            if inventory.read_bytes() != before:
                raise ValueError(f"concurrent inventory edit: {inventory}")
            temporary = inventory.with_name(inventory.name + ".reconcile-tmp")
            temporary.write_bytes(text.encode("utf-8"))
            os.replace(temporary, inventory)
        print(f"{'UPDATED' if options.apply else 'READY'}: {inventory}, records=223, ACCEPTED={counts['ACCEPTED_DO_NOT_REGENERATE']}, REVISION={counts['EXISTS_NEEDS_REVISION']}")


if __name__ == "__main__":
    main()
