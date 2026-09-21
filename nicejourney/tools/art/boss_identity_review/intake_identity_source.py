#!/usr/bin/env python3
"""Read-only mechanical intake of ONE Tenth Warden identity PNG source.

No transfer, extraction, approval, source overwrite, or gameplay binding is
performed. A green result only permits manual evaluation of the actual image.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError


ROOT = Path(__file__).resolve().parents[3]
V01_ART = ROOT / "assets/art/enemies/boss_tenth_warden"
TARGET_ID = "asset:enemies/boss_tenth_warden/tenth_warden_idle"
ALPHA_THRESHOLD = 24  # A threshold for visible pixels, not a baked cleanup.


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def inspect(source: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "schema": "nicejourney.boss_identity_source_intake/v01",
        "stable_asset_id": TARGET_ID,
        "status": "REVIEW_ONLY_NO_SOURCE_ACCEPTANCE_NO_LIVE_BINDING",
        "source": str(source.resolve()),
        "mechanically_reviewable": False,
        "visually_approved": False,
        "production_bound": False,
        "errors": [],
        "manual_review_required": [
            "single isolated whole body and visible feet; no extra figure, sheet, UI or scene",
            "no painted checkerboard / fake transparency / external contamination",
            "correct side-biased 3/4 game view, clear boss identity and weapon direction",
            "readable at derived 96x96 and native Godot zoom; foot baseline/pivot reviewed",
            "no invented lore, faction, weak-point placement, telegraph or move geometry",
        ],
    }
    errors: list[str] = result["errors"]
    if not source.is_file():
        errors.append("source file does not exist; no source was transferred")
        return result
    if source.suffix.lower() != ".png":
        errors.append("source must be an immutable original PNG, not a JPEG or renamed sheet")
        return result

    digest = sha256(source)
    result["sha256"] = digest
    if expected_sha256 is not None and digest != expected_sha256.lower():
        errors.append("original source SHA-256 does not match expected bytes")
    for v01 in sorted(V01_ART.glob("tenth_warden_*_v01.png")):
        if digest == sha256(v01):
            errors.append(f"source is byte-identical to procedural placeholder {v01.name}")
            break

    try:
        with Image.open(source) as im:
            result["png_format"] = im.format
            result["source_mode"] = im.mode
            result["source_dimensions"] = [im.width, im.height]
            if im.format != "PNG":
                errors.append("source file bytes are not PNG")
                return result
            if im.mode != "RGBA":
                errors.append("actual transparent RGBA source required; RGB/palette conversion cannot establish original alpha")
                return result
            if im.width < 96 or im.height < 96:
                errors.append("source cannot contain a full 96x96 gameplay-frame candidate")
                return result
            im.load()  # Force full PNG decode; do not modify source bytes.
            alpha = im.getchannel("A")
            extrema = alpha.getextrema()
            result["alpha_extrema"] = list(extrema)
            result["fully_transparent_pixels"] = alpha.histogram()[0]
            if extrema[0] != 0:
                errors.append("source lacks fully transparent background pixels")
            visible = alpha.point(lambda a: 255 if a >= ALPHA_THRESHOLD else 0)
            bbox = visible.getbbox()
            result["visible_alpha_threshold"] = ALPHA_THRESHOLD
            result["visible_bbox_exclusive"] = list(bbox) if bbox else None
            if bbox is None:
                errors.append("no visible figure pixels at review alpha threshold")
            else:
                left, top, right, bottom = bbox
                margins = [left, top, im.width - right, im.height - bottom]
                result["source_margins_ltrb"] = margins
                if min(margins) == 0:
                    errors.append("visible pixels touch source boundary; figure may be cropped")
    except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
        errors.append(f"source PNG could not be safely decoded: {type(exc).__name__}")

    result["mechanically_reviewable"] = not errors
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="exact original generated PNG, never a derived sprite or V01 placeholder")
    parser.add_argument("--expected-sha256", help="optional 64-character original source SHA-256 for re-verification")
    args = parser.parse_args()
    if args.expected_sha256 is not None and (
        len(args.expected_sha256) != 64
        or any(c not in "0123456789abcdefABCDEF" for c in args.expected_sha256)
    ):
        parser.error("--expected-sha256 must contain exactly 64 hex characters")
    report = inspect(args.source, args.expected_sha256)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["mechanically_reviewable"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
