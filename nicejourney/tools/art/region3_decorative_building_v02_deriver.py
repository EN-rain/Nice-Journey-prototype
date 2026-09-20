#!/usr/bin/env python3
"""Deterministically derive Region 3 decorative-building V02 gameplay sprites.

Exact generated sources remain untouched in generated_sources/imagegen/region3/
decorative_support_v02. Sources are normalized only by transparent padding, then
cropped from visible alpha, nearest-neighbor reduced, low-alpha cleaned and
bottom-centered on a fixed decorative-building canvas. The script is incremental:
it derives whichever of the twelve accepted decorative source files are present.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "assets/art/generated_sources/imagegen/region3/decorative_support_v02"
NORMALIZED_ROOT = SOURCE_ROOT / "normalized"
OUTPUT_ROOT = ROOT / "assets/art/environments/region3/decorative_buildings"
MANIFEST_PATH = SOURCE_ROOT / "region3_decorative_building_v02_derivation_manifest.json"

PAD_PX = 32
ALPHA_THRESHOLD = 24
FINAL_MARGIN_PX = 6
CANVAS_SIZE = 160


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _res_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def _alpha_bbox(image: Image.Image, threshold: int = 0) -> tuple[int, int, int, int]:
    if threshold < 0 or threshold > 255:
        raise ValueError("alpha threshold must be in 0..255")
    alpha = image.getchannel("A")
    if threshold:
        alpha = alpha.point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("source has no visible pixels")
    return bbox


def _cleanup_alpha_for_bounds(
    image: Image.Image, threshold: int | None
) -> tuple[Image.Image, dict[str, Any]]:
    """Clear low-alpha source pixels before visible-bounds calculation.

    The exact source remains untouched on disk. The returned copy is only used
    for deterministic normalization/derivation when the opt-in threshold is
    supplied.
    """
    raw = image.convert("RGBA")
    raw_bbox = list(_alpha_bbox(raw))
    if threshold is None:
        return raw, {
            "enabled": False,
            "threshold": None,
            "raw_visible_bbox": raw_bbox,
            "cleaned_visible_bbox": raw_bbox,
            "pixels_cleared": 0,
        }
    if threshold <= 0 or threshold > 255:
        raise ValueError("alpha-bounds threshold must be in 1..255")
    cleaned = raw.copy()
    alpha = cleaned.getchannel("A")
    cleared = alpha.point(lambda value: 0 if value < threshold else value)
    pixels_cleared = sum(
        1 for before, after in zip(alpha.getdata(), cleared.getdata()) if before != after
    )
    cleaned.putalpha(cleared)
    cleaned_bbox = list(_alpha_bbox(cleaned))
    return cleaned, {
        "enabled": True,
        "threshold": threshold,
        "raw_visible_bbox": raw_bbox,
        "cleaned_visible_bbox": cleaned_bbox,
        "pixels_cleared": pixels_cleared,
    }


def _normalize_source(raw: Image.Image) -> Image.Image:
    rgba = raw.convert("RGBA")
    out = Image.new("RGBA", (rgba.width + PAD_PX * 2, rgba.height + PAD_PX * 2), (0, 0, 0, 0))
    out.alpha_composite(rgba, (PAD_PX, PAD_PX))
    return out


def _derive(normalized: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    bbox = _alpha_bbox(normalized)
    crop = normalized.crop(bbox)
    maximum = CANVAS_SIZE - FINAL_MARGIN_PX * 2
    scale = min(maximum / crop.width, maximum / crop.height)
    width = max(1, int(round(crop.width * scale)))
    height = max(1, int(round(crop.height * scale)))
    reduced = crop.resize((width, height), Image.Resampling.NEAREST)

    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in reduced.getdata():
        if alpha < ALPHA_THRESHOLD:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, 255))
    reduced.putdata(pixels)

    out = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = (CANVAS_SIZE - width) // 2
    y = CANVAS_SIZE - FINAL_MARGIN_PX - height
    out.alpha_composite(reduced, (x, y))
    return out, bbox


def _empty_manifest() -> dict[str, Any]:
    return {
        "schema": "nice-journey-region3-decorative-building-v02-derivation/v1",
        "normalization": {
            "exact_source_preserved": True,
            "transparent_padding_px": PAD_PX,
            "resample": "nearest",
            "alpha_threshold": ALPHA_THRESHOLD,
            "final_margin_px": FINAL_MARGIN_PX,
            "decorative_canvas_px": CANVAS_SIZE,
            "note": (
                "Exact accepted generated sources remain untouched. Normalized copies add transparent "
                "padding only. Gameplay derivatives crop visible alpha, reduce with nearest-neighbor "
                "sampling, binarize low alpha and bottom-center on the documented decorative canvas; "
                "no source artwork is repainted."
            ),
        },
        "buildings": {},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--indices",
        nargs="*",
        type=int,
        help="Optional decorative indices to derive. Defaults to every accepted source currently present.",
    )
    parser.add_argument(
        "--alpha-bounds-threshold",
        type=int,
        default=None,
        help="Optional alpha threshold to clear before source visible-bounds calculation; omitted preserves prior behavior.",
    )
    args = parser.parse_args()

    requested = set(args.indices or range(1, 13))
    if any(index < 1 or index > 12 for index in requested):
        raise RuntimeError("decorative indices must be in 1..12")

    NORMALIZED_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    if MANIFEST_PATH.is_file():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        if manifest.get("schema") != "nice-journey-region3-decorative-building-v02-derivation/v1":
            raise RuntimeError("unexpected existing derivation manifest schema")
    else:
        manifest = _empty_manifest()

    derived = 0
    for index in sorted(requested):
        filename = f"region3_decorative_{index:02d}_source_v02.png"
        source_path = SOURCE_ROOT / filename
        if not source_path.is_file():
            if args.indices:
                raise FileNotFoundError(source_path)
            continue

        normalized_path = NORMALIZED_ROOT / filename
        output_path = OUTPUT_ROOT / f"region3_decorative_building_{index:02d}_v02.png"

        with Image.open(source_path) as loaded:
            exact = loaded.convert("RGBA")
            exact_size = list(exact.size)
            exact_bbox = list(_alpha_bbox(exact))
            cleaned, alpha_bounds_cleanup = _cleanup_alpha_for_bounds(
                exact, args.alpha_bounds_threshold
            )
            normalized = _normalize_source(cleaned)
        normalized.save(normalized_path, format="PNG", optimize=False)
        derivative, normalized_bbox = _derive(normalized)
        derivative.save(output_path, format="PNG", optimize=False)

        stable_id = f"r3:decorative:{index:02d}"
        manifest["buildings"][stable_id] = {
            "index": index,
            "exact_source": _res_path(source_path),
            "exact_source_sha256": _sha256(source_path),
            "exact_source_size": exact_size,
            "exact_visible_bbox": exact_bbox,
            "alpha_bounds_cleanup": alpha_bounds_cleanup,
            "normalized_source": _res_path(normalized_path),
            "normalized_sha256": _sha256(normalized_path),
            "normalized_size": list(normalized.size),
            "normalized_visible_bbox": list(normalized_bbox),
            "derivative": _res_path(output_path),
            "derivative_sha256": _sha256(output_path),
            "derivative_size": list(derivative.size),
        }
        print(f"{stable_id}: {output_path.name} {derivative.size} {_sha256(output_path)}")
        derived += 1

    if derived == 0:
        raise RuntimeError("no accepted decorative sources were available to derive")
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"manifest: {MANIFEST_PATH}")
    print(f"derived: {derived}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
