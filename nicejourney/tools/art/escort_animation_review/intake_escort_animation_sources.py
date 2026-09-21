#!/usr/bin/env python3
"""Immutable intake for a *future* original Escort ImageGen ZIP.

Fail closed: validate exact source bytes, source geometry, anchor and review
atlas, and reproducible ten-frame nearest-crop derivation BEFORE any writes.
Never binds production resources, accepts artwork, or fabricates a crop recipe.

Usage (from the Godot project directory):
  python tools/art/escort_animation_review/intake_escort_animation_sources.py
      --zip /absolute/path/escort_animation_intake_candidate_20260921.zip
      --recipe tools/art/escort_animation_review/source_crop_recipe_v01.json

Exact original two PNG strips: 2172x724 RGBA; idle 4x543px wide,
walk 6x362px wide. Local alpha>=24 bboxes are pinned in the recipe.
The body crop is scaled to source-specific height idle 595 / walk 478,
target 26 using Python round and Pillow NEAREST; alpha<24 becomes RGBA0
AFTER resize. Alpha-composite at x=14-round(width/2), y=31-height in
each 32x32 atlas cell, idle frames 0..3 then walk 4..9. Full RGBA atlas
pixels must match the hash-pinned review atlas BEFORE preserving sources.
Original ZIP is not presumed transferred to the Windows workspace.
"""
from __future__ import annotations

import argparse
from io import BytesIO
import hashlib
import json
from pathlib import Path
import sys
import zipfile

from PIL import Image, UnidentifiedImageError

PROJECT = Path(__file__).resolve().parents[3]
TOOL_DIR = Path(__file__).resolve().parent
ARCHIVE_DIR = PROJECT / "assets/art/generated_sources/imagegen/npc/escort_animation_v01/originals"
EVIDENCE = TOOL_DIR / "source_intake_verified.json"
ATLAS = PROJECT / "assets/art/generated_sources/imagegen/npc/review/escort_idle_walk_320x32_review_20260921.png"
ANCHOR = PROJECT / "assets/art/npc/escort_anchor_v01.png"
EXPECTED_ZIP_NAME = "escort_animation_intake_candidate_20260921.zip"
EXPECTED_ZIP_SIZE = 1_348_574
EXPECTED_ZIP_SHA256 = "83e47ae896201c05f417808278e0db5349998ae9e249846b1eeda9ed6e06e9bf"
EXPECTED_ANCHOR_SHA256 = "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e"
EXPECTED_ATLAS_SHA256 = "184ef03d9b91f1f1d5b31361a02d22da6e4c5162a0d66c528a9326113c923054"
SOURCES = {
    "idle": {
        "sha256": "c5277c8808795b1e04976abceafd5f2d13d7060d74d824dbc86ed8a3870b2535",
        "archive_name": "escort_idle_original.png",
    },
    "walk": {
        "sha256": "fdac1a8dc4987fea6ff039f238151a6ce9230ef526df9e96b696715b3df03c70",
        "archive_name": "escort_walk_original.png",
    },
}
SOURCE_SIZE = (2172, 724)
ATLAS_SIZE = (320, 32)
CELL = (32, 32)
MAX_UNCOMPRESSED = 12_000_000
NORMALIZATION = {
    "source_heights": {"idle": 595, "walk": 478},
    "source_strides": {"idle": 543, "walk": 362},
    "target_body_height": 26,
    "bbox_alpha_at_least": 24,
    "resampler": "nearest",
    "rounding": "python_round_ties_to_even",
    "alpha_below": 24,
    "transparent_pixel_rgba": [0, 0, 0, 0],
    "horizontal_center_x": 14,
    "ground_baseline_y": 31,
    "cell": [32, 32],
    "composite": "Pillow Image.alpha_composite",
    "png_optimize": False,
}
EXPECTED_LOCAL_BOXES = [
    [197, 74, 499, 666],
    [137, 71, 449, 666],
    [80, 91, 387, 665],
    [15, 74, 319, 665],
    [81, 125, 331, 603],
    [73, 125, 313, 600],
    [65, 125, 294, 600],
    [44, 125, 287, 600],
    [40, 125, 288, 603],
    [45, 125, 279, 600],
]


class IntakeBlocked(ValueError):
    """Explicit, non-destructive source-integrity gate."""


def _require(condition: bool, explanation: str) -> None:
    if not condition:
        raise IntakeBlocked(explanation)


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _verified_project_image(path: Path, expected_sha: str, expected_size: tuple[int, int]) -> Image.Image:
    _require(path.is_file(), f"Missing project authority: {path}")
    raw = path.read_bytes()
    _require(_sha(raw) == expected_sha, f"Project authority SHA mismatch: {path}")
    try:
        with Image.open(BytesIO(raw)) as opened:
            opened.load()
            _require(opened.format == "PNG" and opened.mode == "RGBA" and opened.size == expected_size,
                     f"Project authority must be exact RGBA PNG {expected_size}: {path}")
            return opened.copy()
    except (UnidentifiedImageError, OSError) as exc:
        raise IntakeBlocked(f"Unreadable authority PNG: {path}: {exc}") from exc


def _extract_sources(zip_path: Path) -> tuple[dict[str, bytes], dict[str, Image.Image], dict[str, str]]:
    _require(zip_path.name == EXPECTED_ZIP_NAME, f"Expected explicitly named bundle {EXPECTED_ZIP_NAME}")
    _require(zip_path.is_file(), f"Original ImageGen ZIP not available: {zip_path}")
    _require(zip_path.stat().st_size == EXPECTED_ZIP_SIZE,
             f"Original bundle byte count does not match {EXPECTED_ZIP_SIZE}")
    zip_bytes = zip_path.read_bytes()
    _require(_sha(zip_bytes) == EXPECTED_ZIP_SHA256, "Original bundle SHA256 mismatch")
    sources: dict[str, bytes] = {}
    images: dict[str, Image.Image] = {}
    members: dict[str, str] = {}
    try:
        with zipfile.ZipFile(BytesIO(zip_bytes)) as bundle:
            entries = bundle.infolist()
            _require(sum(entry.file_size for entry in entries) <= MAX_UNCOMPRESSED, "ZIP unpacked size exceeds intake limit")
            _require(not bundle.testzip(), "ZIP entry CRC mismatch")
            seen_names: set[str] = set()
            for entry in entries:
                name = entry.filename
                parts = name.replace("\\", "/").rstrip("/").split("/")
                _require(not name.startswith(("/", "\\")) and not parts[0].endswith(":")
                         and parts[0] != "" and all(part not in ("", ".", "..") for part in parts),
                         f"Unsafe ZIP member path: {name}")
                key = name.casefold()
                _require(key not in seen_names, f"Duplicate ZIP member path: {name}")
                seen_names.add(key)
                _require((entry.external_attr >> 16) & 0o170000 != 0o120000, "ZIP symlinks not allowed")
                if entry.is_dir():
                    continue
                if not name.lower().endswith(".png"):
                    continue
                raw = bundle.read(entry)
                matching = [kind for kind, info in SOURCES.items() if _sha(raw) == info["sha256"]]
                _require(len(matching) == 1, f"Unexpected PNG or incorrect original SHA: {name}")
                kind = matching[0]
                _require(kind not in sources, f"Repeated original source for {kind}")
                try:
                    with Image.open(BytesIO(raw)) as opened:
                        opened.load()
                        _require(opened.format == "PNG" and opened.mode == "RGBA" and opened.size == SOURCE_SIZE,
                                 f"Original {kind} must be {SOURCE_SIZE} RGBA PNG")
                        images[kind] = opened.copy()
                except (UnidentifiedImageError, OSError) as exc:
                    raise IntakeBlocked(f"Cannot decode original {kind}: {exc}") from exc
                sources[kind] = raw
                members[kind] = name
    except (zipfile.BadZipFile, RuntimeError, OSError) as exc:
        raise IntakeBlocked(f"Original ZIP unreadable: {exc}") from exc
    _require(set(sources) == set(SOURCES), "ZIP must contain exactly one hash-matched original idle and walk PNG")
    return sources, images, members


def _normalized_body(
    source_image: Image.Image,
    box: tuple[int, int, int, int],
    source_height: int,
) -> tuple[Image.Image, tuple[int, int]]:
    """Apply the source-specific normalization; never synthesize extra poses."""
    left, top, right, bottom = box
    _require(0 <= left < right <= SOURCE_SIZE[0] and 0 <= top < bottom <= SOURCE_SIZE[1],
             f"Original body crop out of source bounds: {box}")
    scale = NORMALIZATION["target_body_height"] / source_height
    body_size = (round((right - left) * scale), round((bottom - top) * scale))
    _require(0 < body_size[0] <= 32 and 0 < body_size[1] <= 32,
             f"Normalized body would clip or vanish: {box} -> {body_size}")
    body = source_image.crop(box).resize(body_size, Image.Resampling.NEAREST)
    # Do this AFTER nearest resizing. Fully transparent RGB is normalized as
    # well; otherwise hidden color noise can falsely count as source identity.
    cutoff = NORMALIZATION["alpha_below"]
    clear = tuple(NORMALIZATION["transparent_pixel_rgba"])
    body.putdata([clear if pixel[3] < cutoff else pixel for pixel in body.getdata()])
    _require(sum(pixel[3] >= cutoff for pixel in body.getdata()) >= 64,
             f"Normalized original crop has no legible body: {box}")
    x = NORMALIZATION["horizontal_center_x"] - round(body.width / 2)
    y = NORMALIZATION["ground_baseline_y"] - body.height
    _require(0 <= x and 0 <= y and x + body.width <= 32 and y + body.height <= 32,
             f"Normalized body placement clips frame: {box} -> {body_size} at {(x, y)}")
    return body, (x, y)


def _derive(recipe_path: Path, originals: dict[str, Image.Image], atlas: Image.Image) -> dict:
    _require(recipe_path.is_file(), f"Source-specific normalization recipe missing: {recipe_path}")
    try:
        recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise IntakeBlocked(f"Cannot decode derivation recipe: {exc}") from exc
    _require(isinstance(recipe, dict) and recipe.get("schema") == "escort-source-body-normalization-v1",
             "Source-specific normalization recipe schema mismatch")
    _require(recipe.get("normalization") == NORMALIZATION,
             "Source-specific stride/height/nearest/rounding/alpha/anchor/compositing changed")
    _require(recipe.get("source") == {
        "idle_sha256": SOURCES["idle"]["sha256"],
        "walk_sha256": SOURCES["walk"]["sha256"],
    } and recipe.get("atlas_sha256") == EXPECTED_ATLAS_SHA256,
             "Source-specific recipe hashes do not match original/atlas authorities")
    frames = recipe.get("frames")
    _require(isinstance(frames, list) and len(frames) == 10,
             "Recipe needs exactly four idle and six walk local source boxes")
    rebuilt = Image.new("RGBA", ATLAS_SIZE, (0, 0, 0, 0))
    normalized = []
    for expected_frame, entry in enumerate(frames):
        _require(isinstance(entry, dict) and type(entry.get("frame")) is int and entry["frame"] == expected_frame,
                 f"Recipe must own consecutive frame {expected_frame}")
        kind = "idle" if expected_frame < 4 else "walk"
        _require(entry.get("source") == kind, f"Frame {expected_frame} must come from genuine {kind} source")
        box = entry.get("local_box")
        _require(isinstance(box, list) and len(box) == 4 and all(type(value) is int for value in box),
                 f"Frame {expected_frame} requires exact integer LOCAL source bbox")
        _require(box == EXPECTED_LOCAL_BOXES[expected_frame],
                 f"Frame {expected_frame} differs from documented local alpha>=24 bbox")
        stride = NORMALIZATION["source_strides"][kind]
        index = expected_frame if kind == "idle" else expected_frame - 4
        _require(stride * (4 if kind == "idle" else 6) == SOURCE_SIZE[0],
                 f"{kind} strip cell spacing cannot cover exact 2172px width")
        left, top, right, bottom = box
        _require(0 <= left < right <= stride and 0 <= top < bottom <= SOURCE_SIZE[1],
                 f"Frame {expected_frame} local bbox outside source strip cell")
        x0 = index * stride
        source_cell = originals[kind].crop((x0, 0, x0 + stride, SOURCE_SIZE[1]))
        # Source bbox is taken BEFORE resizing with alpha>=24, per each
        # independent 543px idle or 362px walk strip cell.
        detected_box = source_cell.getchannel("A").point(
            lambda a: 255 if a >= NORMALIZATION["bbox_alpha_at_least"] else 0
        ).getbbox()
        _require(detected_box == tuple(box),
                 f"Frame {expected_frame} original local alpha bbox mismatch: "
                 f"expected {box}, got {detected_box}")
        global_box = (x0 + left, top, x0 + right, bottom)
        body, (x, y) = _normalized_body(
            originals[kind], global_box, NORMALIZATION["source_heights"][kind]
        )
        rebuilt.alpha_composite(body, (expected_frame * CELL[0] + x, y))
        normalized.append({
            "frame": expected_frame, "source": kind, "local_bbox": box,
            "global_bbox": list(global_box), "stride": stride,
            "body_size": [body.width, body.height], "cell_xy": [x, y],
        })
    _require(rebuilt.tobytes() == atlas.tobytes(),
             "Source-specific nearest/alpha/placement derivation does not reproduce ALL RGBA atlas pixels exactly")
    return {
        "schema": recipe["schema"], "normalization": NORMALIZATION, "frames": normalized,
        "recipe_sha256": _sha(recipe_path.read_bytes()), "full_rgba_atlas_pixel_match": True,
    }


def _store_immutably(outputs: dict[Path, bytes]) -> None:
    # Complete every integrity/provenance/derivation check before directory creation.
    # Never overwrite an existing source or evidence JSON, even if a process races.
    for path, content in outputs.items():
        if path.exists():
            _require(path.is_file() and path.read_bytes() == content,
                     f"Existing immutable destination differs: {path}")
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    for path, content in outputs.items():
        if path.exists():
            continue
        try:
            with path.open("xb") as writer:
                writer.write(content)
        except FileExistsError as exc:
            raise IntakeBlocked(f"Concurrent immutable destination creation: {path}") from exc
    for path, content in outputs.items():
        _require(path.read_bytes() == content, f"Immutable write verification failed: {path}")


def intake(zip_path: Path, recipe_path: Path) -> dict:
    _verified_project_image(ANCHOR, EXPECTED_ANCHOR_SHA256, CELL)
    atlas = _verified_project_image(ATLAS, EXPECTED_ATLAS_SHA256, ATLAS_SIZE)
    originals, images, members = _extract_sources(zip_path)
    derivation = _derive(recipe_path, images, atlas)
    evidence = {
        "status": "REVIEW_ONLY_SOURCE_INTAKE_VERIFIED_NOT_LIVE_NOT_ART_ACCEPTED",
        "archive": EXPECTED_ZIP_NAME, "archive_size": EXPECTED_ZIP_SIZE,
        "archive_sha256": EXPECTED_ZIP_SHA256,
        "static_anchor_sha256": EXPECTED_ANCHOR_SHA256,
        "atlas_review_path": ATLAS.relative_to(PROJECT).as_posix(),
        "atlas_review_sha256": EXPECTED_ATLAS_SHA256,
        "originals": {
            kind: {
                "path": (ARCHIVE_DIR / info["archive_name"]).relative_to(PROJECT).as_posix(),
                "sha256": info["sha256"], "size": list(SOURCE_SIZE),
                "mode": "RGBA", "zip_member": members[kind],
            }
            for kind, info in SOURCES.items()
        },
        "derivation": derivation,
        "no_production_profile_or_manifest_writes": True,
    }
    encoded = (json.dumps(evidence, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    outputs = {ARCHIVE_DIR / info["archive_name"]: originals[kind] for kind, info in SOURCES.items()}
    outputs[EVIDENCE] = encoded
    _store_immutably(outputs)
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", required=True, type=Path, help="Explicit ORIGINAL ChatGPT bundle ZIP path")
    parser.add_argument("--recipe", required=True, type=Path, help="Visually approved 10-crop integer recipe JSON")
    args = parser.parse_args()
    try:
        result = intake(args.zip, args.recipe)
    except (IntakeBlocked, OSError, ValueError) as exc:
        print(f"ESCORT IMMUTABLE SOURCE INTAKE BLOCKED: {exc}", file=sys.stderr)
        return 1
    print("ESCORT IMMUTABLE SOURCE INTAKE VERIFIED: originals preserved; atlas RGBA reproduced; REVIEW ONLY")
    print("originals:", json.dumps(result["originals"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
