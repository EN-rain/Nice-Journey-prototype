#!/usr/bin/env python3
"""Deterministically normalize and derive Region 3 functional-building V02 sprites.

The exact generated PNGs are preserved under generated_sources/imagegen/region3/
functional_buildings_v02. This tool performs only deterministic source padding,
alpha cleanup, nearest-neighbor reduction and bottom-centered placement. It never
redraws source artwork.

Run with the pinned sprite-gen venv Python so Pillow is fixed by the vendored tool.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RAW_ROOT = ROOT / "assets/art/generated_sources/imagegen/region3/functional_buildings_v02"
NORMALIZED_ROOT = ROOT / "assets/art/generated_sources/imagegen/region3/buildings"
OUTPUT_ROOT = ROOT / "assets/art/environments/region3/functional_buildings"
MANIFEST_PATH = NORMALIZED_ROOT / "region3_building_v02_derivation_manifest.json"

PAD_PX = 32
ALPHA_THRESHOLD = 24
FINAL_MARGIN_PX = 6

CONFIG = {
    "central_tower": {
        "raw": "isometric_fantasy_tower_keep.png",
        "normalized": "region3_central_tower_source_v02.png",
        "output": "region3_central_tower_exterior_v02.png",
        "canvas": 224,
    },
    "quest_hall": {
        "raw": "pixel_art_adventurers_guild_hall.png",
        "normalized": "region3_quest_hall_source_v02.png",
        "output": "region3_quest_hall_exterior_v02.png",
        "canvas": 192,
    },
    "blacksmith": {
        "raw": "isometric_pixel_art_blacksmith_forge.png",
        "normalized": "region3_blacksmith_source_v02.png",
        "output": "region3_blacksmith_exterior_v02.png",
        "canvas": 192,
    },
    "general_merchant": {
        "raw": "pixel_merchant_shop_sprite.png",
        "normalized": "region3_general_merchant_source_v02.png",
        "output": "region3_merchant_exterior_v02.png",
        "canvas": 192,
    },
    "inn_rest_house": {
        "raw": "cozy_fantasy_inn_pixel_art_asset.png",
        "normalized": "region3_inn_rest_house_source_v02.png",
        "output": "region3_inn_exterior_v02.png",
        "canvas": 192,
    },
    "storage_house": {
        "raw": "isometric_fantasy_warehouse_sprite.png",
        "normalized": "region3_storage_house_source_v02.png",
        "output": "region3_storage_exterior_v02.png",
        "canvas": 192,
    },
    "training_hall": {
        "raw": "pixel_art_fantasy_training_hall.png",
        "normalized": "region3_training_hall_source_v02.png",
        "output": "region3_training_exterior_v02.png",
        "canvas": 192,
    },
    "clinic_apothecary": {
        "raw": "pixel_art_fantasy_apothecary_clinic.png",
        "normalized": "region3_clinic_apothecary_source_v02.png",
        "output": "region3_clinic_exterior_v02.png",
        "canvas": 192,
    },
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _res_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def _alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("source has no visible pixels")
    return bbox


def _normalize_source(raw: Image.Image) -> Image.Image:
    rgba = raw.convert("RGBA")
    out = Image.new(
        "RGBA",
        (rgba.width + PAD_PX * 2, rgba.height + PAD_PX * 2),
        (0, 0, 0, 0),
    )
    out.alpha_composite(rgba, (PAD_PX, PAD_PX))
    return out


def _derive(normalized: Image.Image, canvas_size: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    bbox = _alpha_bbox(normalized)
    crop = normalized.crop(bbox)
    maximum = canvas_size - FINAL_MARGIN_PX * 2
    scale = min(maximum / crop.width, maximum / crop.height)
    width = max(1, int(round(crop.width * scale)))
    height = max(1, int(round(crop.height * scale)))
    reduced = crop.resize((width, height), Image.Resampling.NEAREST)

    cleaned_pixels = []
    for red, green, blue, alpha in reduced.getdata():
        if alpha < ALPHA_THRESHOLD:
            cleaned_pixels.append((0, 0, 0, 0))
        else:
            cleaned_pixels.append((red, green, blue, 255))
    reduced.putdata(cleaned_pixels)

    out = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    x = (canvas_size - width) // 2
    y = canvas_size - FINAL_MARGIN_PX - height
    out.alpha_composite(reduced, (x, y))
    return out, bbox


def main() -> int:
    NORMALIZED_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)

    manifest = {
        "schema": "nice-journey-region3-building-v02-derivation/v1",
        "normalization": {
            "raw_exact_preserved": True,
            "transparent_padding_px": PAD_PX,
            "resample": "nearest",
            "alpha_threshold": ALPHA_THRESHOLD,
            "final_margin_px": FINAL_MARGIN_PX,
            "note": (
                "Generated sources that touched an image edge are preserved byte-for-byte. "
                "Canonical source_v02 files add transparent padding only; gameplay derivatives "
                "are cropped from visible alpha, nearest-reduced, alpha-binarized and bottom-centered. "
                "No source pixels are repainted."
            ),
        },
        "buildings": {},
    }

    for role_id, config in CONFIG.items():
        raw_path = RAW_ROOT / config["raw"]
        normalized_path = NORMALIZED_ROOT / config["normalized"]
        output_path = OUTPUT_ROOT / config["output"]
        if not raw_path.is_file():
            raise FileNotFoundError(raw_path)

        with Image.open(raw_path) as loaded:
            raw_rgba = loaded.convert("RGBA")
            raw_size = list(raw_rgba.size)
            raw_bbox = list(_alpha_bbox(raw_rgba))
            normalized = _normalize_source(raw_rgba)

        normalized.save(normalized_path, format="PNG", optimize=False)
        derivative, normalized_bbox = _derive(normalized, int(config["canvas"]))
        derivative.save(output_path, format="PNG", optimize=False)

        manifest["buildings"][role_id] = {
            "raw_exact_source": _res_path(raw_path),
            "raw_exact_sha256": _sha256(raw_path),
            "raw_exact_size": raw_size,
            "raw_visible_bbox": raw_bbox,
            "normalized_source": _res_path(normalized_path),
            "normalized_sha256": _sha256(normalized_path),
            "normalized_size": list(normalized.size),
            "normalized_visible_bbox": list(normalized_bbox),
            "derivative": _res_path(output_path),
            "derivative_sha256": _sha256(output_path),
            "derivative_size": list(derivative.size),
        }
        print(f"{role_id}: {output_path.name} {derivative.size} {_sha256(output_path)}")

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"manifest: {MANIFEST_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
