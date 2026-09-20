#!/usr/bin/env python3
"""Mechanical intake report for Region 3 functional-building source images.

This tool does not approve visual quality. It records exact source identity and catches
obvious publication defects (wrong file type, empty alpha, fully opaque fake-alpha when
alpha is required, or subject pixels touching the source boundary).

Run it with D:/nicejourney/tools/sprite-gen/.venv/Scripts/python.exe so Pillow comes
from the pinned sprite-gen environment.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROLE_IDS = {
    "central_tower",
    "quest_hall",
    "blacksmith",
    "general_merchant",
    "inn_rest_house",
    "storage_house",
    "training_hall",
    "clinic_apothecary",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _build_report(role_id: str, source: Path, require_alpha: bool) -> dict[str, Any]:
    report: dict[str, Any] = {
        "schema": "nice-journey-region3-building-source-intake/v1",
        "role_id": role_id,
        "source": str(source.resolve()),
        "accepted_mechanically": False,
        "errors": [],
        "warnings": [],
    }

    errors: list[str] = report["errors"]
    warnings: list[str] = report["warnings"]

    if role_id not in ROLE_IDS:
        errors.append(f"unknown role_id: {role_id}")
        return report
    if not source.is_file():
        errors.append("source file does not exist")
        return report
    if source.suffix.lower() != ".png":
        errors.append("accepted source must be PNG")
        return report

    report["sha256"] = _sha256(source)
    with Image.open(source) as loaded:
        report["source_mode"] = loaded.mode
        report["width"] = loaded.width
        report["height"] = loaded.height
        if loaded.width <= 0 or loaded.height <= 0:
            errors.append("source dimensions must be positive")
            return report

        rgba = loaded.convert("RGBA")
        alpha = rgba.getchannel("A")
        alpha_values = list(alpha.tobytes())
        total = len(alpha_values)
        alpha_zero = sum(value == 0 for value in alpha_values)
        alpha_partial = sum(0 < value < 255 for value in alpha_values)
        bbox = alpha.getbbox()

        report["alpha"] = {
            "has_alpha_channel": "A" in loaded.getbands(),
            "zero_fraction": alpha_zero / total,
            "partial_fraction": alpha_partial / total,
            "opaque_fraction": sum(value == 255 for value in alpha_values) / total,
        }
        report["opaque_bbox"] = list(bbox) if bbox is not None else None

        if bbox is None:
            errors.append("source contains no visible pixels")
            return report

        if require_alpha and alpha_zero == 0:
            errors.append("required transparent source has no fully transparent pixels")

        left, top, right, bottom = bbox
        touches = {
            "left": left <= 0,
            "top": top <= 0,
            "right": right >= loaded.width,
            "bottom": bottom >= loaded.height,
        }
        report["touches_source_edge"] = touches
        if any(touches.values()):
            errors.append("visible subject touches source boundary; regenerate/crop with safe margin")

        margin_px = min(left, top, loaded.width - right, loaded.height - bottom)
        report["minimum_transparent_margin_px"] = margin_px
        if margin_px < 8:
            warnings.append("source margin is under 8 px; deterministic cleanup/crop may be fragile")

    report["accepted_mechanically"] = not errors
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", required=True, choices=sorted(ROLE_IDS))
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--require-alpha", action="store_true")
    args = parser.parse_args()

    report = _build_report(args.role, args.source, args.require_alpha)
    payload = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(payload, encoding="utf-8")
    print(payload, end="")
    return 0 if report["accepted_mechanically"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
