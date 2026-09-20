#!/usr/bin/env python3
"""Fail-loud intake for the Region 3 decorative/support V02 generated batch.

This tool intentionally stops before gameplay derivation/integration. It preserves the
user-provided ZIP byte-for-byte, verifies either the complete 17-source filename contract
or one of the approved staged Batch-1/Batch-2 subsets from
REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json, extracts accepted exact source PNGs, and
records hashes/dimensions/alpha/visible-bound evidence.

Run with D:/nicejourney/tools/sprite-gen/.venv/Scripts/python.exe so Pillow comes from
the pinned sprite-gen environment.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
SOURCE_ROOT = ROOT / "assets/art/generated_sources/imagegen/region3/decorative_support_v02"
RAW_BATCH_ROOT = SOURCE_ROOT / "raw_batch"
DEFAULT_REPORT = ROOT / "docs/evidence/art/region3-decorative-support-v02-intake.json"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_manifest() -> dict[str, Any]:
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8-sig"))
    if data.get("schema") != "nice-journey-region3-decorative-support-v02-manifest/v1":
        raise RuntimeError("unexpected decorative/support manifest schema")
    return data


def _required_sources(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    required: dict[str, dict[str, Any]] = {}
    for entry in manifest.get("decorative_structures", []):
        source = Path(str(entry["source_v02"])).name
        required[source] = {
            "kind": "decorative_structure",
            "stable_id": entry["structure_id"],
            "master_id": entry["master_id"],
        }
    for entry in manifest.get("support_assets", []):
        source = Path(str(entry["source_v02"])).name
        required[source] = {
            "kind": "support_asset",
            "asset_id": entry["asset_id"],
        }
    if len(required) != 17:
        raise RuntimeError(f"manifest must define exactly 17 unique source filenames, got {len(required)}")
    return required


def _select_required(required: dict[str, dict[str, Any]], subset: str) -> dict[str, dict[str, Any]]:
    if subset == "full":
        return required
    if subset == "decorative_batch1":
        names = {f"region3_decorative_{index:02d}_source_v02.png" for index in range(1, 11)}
    elif subset == "decorative_batch2":
        names = {
            "region3_decorative_11_source_v02.png",
            "region3_decorative_12_source_v02.png",
            "region3_town_props_source_v02.png",
            "region3_ground_road_source_v02.png",
            "region3_ruins_modules_source_v02.png",
            "region3_outskirts_support_source_v02.png",
            "region3_risk_zone_support_source_v02.png",
        }
    else:
        raise RuntimeError(f"unknown intake subset: {subset}")
    missing = names - set(required)
    if missing:
        raise RuntimeError(f"manifest is missing subset filenames: {sorted(missing)}")
    return {name: required[name] for name in sorted(names)}


def _safe_member_name(name: str) -> str:
    normalized = PurePosixPath(name.replace("\\", "/"))
    if normalized.is_absolute() or ".." in normalized.parts:
        raise RuntimeError(f"unsafe ZIP member path: {name}")
    return normalized.name


def _inspect_png(path: Path) -> dict[str, Any]:
    record: dict[str, Any] = {
        "path": "res://" + path.relative_to(ROOT).as_posix(),
        "sha256": _sha256(path),
        "warnings": [],
        "errors": [],
    }
    with Image.open(path) as loaded:
        record["source_mode"] = loaded.mode
        record["width"] = loaded.width
        record["height"] = loaded.height
        if loaded.width <= 0 or loaded.height <= 0:
            record["errors"].append("source dimensions must be positive")
            return record

        rgba = loaded.convert("RGBA")
        alpha = rgba.getchannel("A")
        values = alpha.tobytes()
        total = len(values)
        bbox = alpha.getbbox()
        if bbox is None:
            record["errors"].append("source contains no visible pixels")
            record["visible_bbox"] = None
            return record

        zero = sum(value == 0 for value in values)
        partial = sum(0 < value < 255 for value in values)
        opaque = sum(value == 255 for value in values)
        left, top, right, bottom = bbox
        touches = {
            "left": left <= 0,
            "top": top <= 0,
            "right": right >= loaded.width,
            "bottom": bottom >= loaded.height,
        }
        margin = min(left, top, loaded.width - right, loaded.height - bottom)

        record["alpha"] = {
            "has_alpha_channel": "A" in loaded.getbands(),
            "zero_fraction": zero / total,
            "partial_fraction": partial / total,
            "opaque_fraction": opaque / total,
        }
        record["visible_bbox"] = list(bbox)
        record["touches_source_edge"] = touches
        record["minimum_transparent_margin_px"] = margin

        if zero == 0:
            record["warnings"].append(
                "source has no fully transparent pixels; visually verify genuine opaque/chroma source before cutout"
            )
        if any(touches.values()):
            record["warnings"].append(
                "visible subject touches source boundary; preserve exact source and normalize with transparent padding before derivation"
            )
        elif margin < 8:
            record["warnings"].append(
                "transparent margin is under 8 px; deterministic extraction may be fragile"
            )
    return record


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", required=True, type=Path, help="Accepted generated ZIP")
    parser.add_argument(
        "--subset",
        choices=["full", "decorative_batch1", "decorative_batch2"],
        default="full",
        help="Validate the complete 17-source ZIP or one of the approved staged delivery subsets.",
    )
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace previously extracted exact-source files with the same names. The preserved raw ZIP is never overwritten silently.",
    )
    args = parser.parse_args()

    source_zip = args.zip.resolve()
    if not source_zip.is_file():
        raise FileNotFoundError(source_zip)
    if source_zip.suffix.lower() != ".zip":
        raise RuntimeError("batch input must be a ZIP")

    manifest = _load_manifest()
    required = _select_required(_required_sources(manifest), args.subset)

    with zipfile.ZipFile(source_zip, "r") as archive:
        files = [info for info in archive.infolist() if not info.is_dir()]
        names: dict[str, zipfile.ZipInfo] = {}
        duplicate_basenames: list[str] = []
        for info in files:
            basename = _safe_member_name(info.filename)
            if basename in names:
                duplicate_basenames.append(basename)
            names[basename] = info

        missing = sorted(set(required) - set(names))
        unexpected_pngs = sorted(
            name for name in names if name.lower().endswith(".png") and name not in required
        )
        if duplicate_basenames:
            raise RuntimeError(f"duplicate ZIP basenames: {sorted(set(duplicate_basenames))}")
        if missing:
            raise RuntimeError(
                "ZIP is missing required accepted-source filenames: " + ", ".join(missing)
            )
        if unexpected_pngs:
            raise RuntimeError(
                "ZIP contains unexpected PNG sources; reject/curate before intake: " + ", ".join(unexpected_pngs)
            )

        SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
        RAW_BATCH_ROOT.mkdir(parents=True, exist_ok=True)
        preserved_zip = RAW_BATCH_ROOT / source_zip.name
        if preserved_zip.exists():
            existing_hash = _sha256(preserved_zip)
            incoming_hash = _sha256(source_zip)
            if existing_hash != incoming_hash:
                raise RuntimeError(
                    f"raw ZIP preservation collision: {preserved_zip.name} already exists with a different SHA-256"
                )
        else:
            shutil.copyfile(source_zip, preserved_zip)

        source_records: list[dict[str, Any]] = []
        for filename in sorted(required):
            destination = SOURCE_ROOT / filename
            if destination.exists() and not args.overwrite:
                raise RuntimeError(
                    f"exact source already exists: {destination}; use a new source revision or explicit --overwrite after review"
                )
            destination.write_bytes(archive.read(names[filename]))
            record = _inspect_png(destination)
            record.update(required[filename])
            record["filename"] = filename
            source_records.append(record)

    errors = [
        f"{record['filename']}: {message}"
        for record in source_records
        for message in record["errors"]
    ]
    report = {
        "schema": "nice-journey-region3-decorative-support-v02-intake/v1",
        "status": "mechanical_intake_pass" if not errors else "mechanical_intake_fail",
        "visual_acceptance": "NOT_PERFORMED_BY_THIS_TOOL",
        "integration_performed": False,
        "input_zip": str(source_zip),
        "preserved_zip": "res://" + preserved_zip.relative_to(ROOT).as_posix(),
        "zip_sha256": _sha256(preserved_zip),
        "subset": args.subset,
        "required_source_count": len(required),
        "sources": source_records,
        "errors": errors,
        "note": (
            "PASS means only that the selected staged filename contract is mechanically intact. "
            "Visual subject/style/service-readability acceptance is still mandatory before derivation or Godot integration."
        ),
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
