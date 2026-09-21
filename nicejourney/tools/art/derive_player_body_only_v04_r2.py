"""Derive isolated player V04 body-only review candidates from preserved PNGs.

This script deliberately does not modify V03, existing V04, runtime resources, or
accepted provenance. Run from any cwd; ``--check`` reproduces and byte-compares
all six candidates and their manifest without writing anything.

The rejected V04 deriver cut equal-width columns and resized each resulting
alpha bounding box to 30px tall. Neighboring body fragments could cross a
column boundary, while crouches became as tall as standing poses. Here we
segment complete 8-connected bodies across a full row, assign them left to
right, and use one constant nearest-neighbor scale per source image.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


PROJECT = Path(__file__).resolve().parents[2]
INTAKE = PROJECT / "assets/art/generated_sources/imagegen/player/body_only_v04"
OUTPUT = PROJECT / "assets/art/player/animations"
MANIFEST = INTAKE / "player_body_only_v04_r2_candidate_manifest.json"
EXPECTED = {
    "player_attack_body_only_source.png": "07da238fa35537841cfc7f6ae2b014b90261329e8f605a2b1de92e3648564fb7",
    "player_heavy_attack_body_only_source.png": "af670f93bfc622ed45d76e96227b8710662a17380ed69346171151f5e5abe3df",
    "player_block_body_only_source.png": "6aa6886811226d155c1a088f328ee2b07ceb9f551f95b9b546865189974887bf",
    "player_parry_cast_hit_body_only_source.png": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
}

# Calibration is from the source's upright head-to-boot height, not each
# pose's silhouette height. Parry, cast and hit share the same exact source
# image and therefore share one scale, even for crouched hit reactions.
# All four upright exemplars are recorded in this manifest.
CONFIG = [
    ("attack", "player_attack_body_only_source.png", 0, 724, 6, list(range(6)), 306, 0),
    ("heavy_attack", "player_heavy_attack_body_only_source.png", 0, 724, 6, list(range(6)), 307, 0),
    ("block", "player_block_body_only_source.png", 0, 724, 7, [2, 3, 4], 289, 0),
    ("parry", "player_parry_cast_hit_body_only_source.png", 0, 362, 6, list(range(6)), 216, None),
    ("cast", "player_parry_cast_hit_body_only_source.png", 362, 724, 7, list(range(7)), 216, 0),
    ("hit", "player_parry_cast_hit_body_only_source.png", 724, 1086, 6, [1, 2, 3, 4, 5], 216, None),
]

ALPHA_THRESHOLD = 24
TARGET_UPRIGHT_HEIGHT = 28
GROUND_LAST_OPAQUE_Y = 29
CELL = 32


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_path(name):
    return "res://assets/art/generated_sources/imagegen/player/body_only_v04/" + name


def get_sources():
    images = {}
    for name, required_hash in EXPECTED.items():
        path = INTAKE / name
        actual_hash = digest(path.read_bytes())
        if actual_hash != required_hash:
            raise ValueError(f"source changed: {path}: {actual_hash} != {required_hash}")
        images[name] = np.asarray(Image.open(path).convert("RGBA"))
        if images[name].shape[2] != 4:
            raise ValueError(f"source must be RGBA: {name}")
    return images


def split_row(pixels, y0, y1, expected_count):
    """Return complete, separate components, independently of arbitrary cells."""
    mask = pixels[y0:y1, :, 3] >= ALPHA_THRESHOLD
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=bool))
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    objects = ndimage.find_objects(labels)
    # A source image that grows extra sizeable parts must fail review instead
    # of silently selecting an arbitrary number of bodies.
    major = [k for k in range(1, count + 1) if areas[k] >= 1000]
    if len(major) != expected_count:
        raise ValueError(f"expected {expected_count} whole bodies, found {len(major)} major components")
    major.sort(key=lambda k: objects[k - 1][1].start)
    pieces = []
    for key in major:
        ys, xs = objects[key - 1]
        if ys.start == 0 or ys.stop == y1 - y0 or xs.start == 0 or xs.stop == pixels.shape[1]:
            raise ValueError(f"source body touches outer source edge: {(xs, ys)}")
        selection = labels[ys, xs] == key
        rgba = np.copy(pixels[y0 + ys.start:y0 + ys.stop, xs.start:xs.stop])
        rgba[~selection] = 0
        # Also clear any subthreshold alpha outside selected body; retain exact
        # source pixel colors/alpha for pixels belonging to the body itself.
        pieces.append({
            "rgba": rgba,
            "crop": [xs.start, y0 + ys.start, xs.stop, y0 + ys.stop],
            "source_pixels": int(areas[key]),
        })
    stray_pixels = int(mask.sum() - sum(p["source_pixels"] for p in pieces))
    if stray_pixels > 50:
        raise ValueError(f"unexpected disconnected source fragments: {stray_pixels} pixels")
    return pieces, stray_pixels


def make_frame(piece, calibration_height):
    crop = Image.fromarray(piece["rgba"])
    # Single source-wide nearest-neighbor scale; a crouch stays a crouch.
    width = max(1, round(crop.width * TARGET_UPRIGHT_HEIGHT / calibration_height))
    height = max(1, round(crop.height * TARGET_UPRIGHT_HEIGHT / calibration_height))
    if width > CELL or height > CELL:
        raise ValueError(f"frame exceeds {CELL}x{CELL}: {piece['crop']} -> {(width, height)}")
    resized = crop.resize((width, height), resample=Image.Resampling.NEAREST)
    box = resized.getchannel("A").getbbox()
    if box != (0, 0, width, height):
        raise ValueError(f"downsample unexpectedly lost a component edge: {box}")
    x = (CELL - width) // 2
    y = GROUND_LAST_OPAQUE_Y + 1 - height
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.paste(resized, (x, y))
    return cell, {
        "alpha_crop_xyxy": piece["crop"],
        "source_component_pixels": piece["source_pixels"],
        "scaled_size": [width, height],
        "paste_xy": [x, y],
        "output_alpha_bbox_xyxy": list(cell.getchannel("A").getbbox()),
    }


def encode_png(im):
    sink = io.BytesIO()
    im.save(sink, format="PNG")
    return sink.getvalue()


def assemble():
    originals = get_sources()
    rows = {}
    records = []
    outputs = {}
    for state, source, y0, y1, source_count, selection, calibration, exemplar in CONFIG:
        row_key = (source, y0, y1)
        if row_key not in rows:
            rows[row_key] = split_row(originals[source], y0, y1, source_count)
        all_pieces, stray = rows[row_key]
        if exemplar is not None and all_pieces[exemplar]["crop"][3] - all_pieces[exemplar]["crop"][1] != calibration:
            raise ValueError(f"upright calibration mismatch for {state}")
        sheet = Image.new("RGBA", (CELL * len(selection), CELL), (0, 0, 0, 0))
        frames = []
        for output_index, source_index in enumerate(selection):
            cell, details = make_frame(all_pieces[source_index], calibration)
            sheet.paste(cell, (CELL * output_index, 0))
            frames.append({"output_frame": output_index, "source_frame": source_index, **details})
        name = f"player_body_{state}_sheet_v04_r2_candidate.png"
        data = encode_png(sheet)
        outputs[name] = data
        records.append({
            "state": state,
            "stage": "DERIVED_CANDIDATE_PENDING_NATIVE_RENDERER_AND_WEAPON_REVIEW",
            "source": source_path(source),
            "source_sha256": EXPECTED[source],
            "source_dimensions": list(Image.fromarray(originals[source]).size),
            "source_row_y0_y1": [y0, y1],
            "source_frame_count": source_count,
            "selected_source_frames": selection,
            "discarded_disconnected_threshold_pixels": stray,
            "selection": "left-to-right complete 8-connected body components across full source row",
            "alpha_component_threshold": ALPHA_THRESHOLD,
            "calibration": {
                "source_upright_frame_index": exemplar,
                "source_upright_reference": "cast frame 0 of shared source" if exemplar is None else f"{state} frame {exemplar}",
                "source_upright_height_px": calibration,
                "target_upright_height_px": TARGET_UPRIGHT_HEIGHT,
                "uniform_scale_fraction": [TARGET_UPRIGHT_HEIGHT, calibration],
            },
            "pixel_processing": "component-isolated RGBA; nearest-neighbor once at common scale; transparent RGB zero outside body",
            "frame_canvas": [CELL, CELL],
            "ground_anchor": [16, GROUND_LAST_OPAQUE_Y],
            "output": "res://assets/art/player/animations/" + name,
            "output_sha256": digest(data),
            "output_dimensions": list(sheet.size),
            "frames": frames,
        })
    manifest = {
        "schema": "player-body-only-v04-r2-candidate/v1",
        "acceptance": "CANDIDATE_ONLY_SOURCE_REVIEWED_DERIVATIVE_UNACCEPTED_NOT_RUNTIME_BOUND",
        "script": "res://tools/art/derive_player_body_only_v04_r2.py",
        "method": "whole-row connected body selection prevents neighbors leaking at artificial cell cuts; shared per-source uniform pixel scale retains crouch and windup pose heights",
        "records": records,
    }
    outputs[MANIFEST.name] = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    return outputs, records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="recompute and byte-compare without writing")
    args = parser.parse_args()
    outputs, records = assemble()
    targets = [(MANIFEST if name == MANIFEST.name else OUTPUT / name, data)
               for name, data in outputs.items()]
    # Validate every existing review target before creating any output: a
    # changed algorithm must never silently replace preserved candidate PNGs
    # or leave a partially updated set when a later path conflicts.
    if not args.check:
        for path, data in targets:
            if path.exists() and path.read_bytes() != data:
                raise FileExistsError(f"refusing to overwrite existing V04 R2 candidate: {path}")
    for path, data in targets:
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError(f"missing or non-reproducible: {path}")
            status = "BYTE_IDENTICAL"
        elif path.exists():
            status = "EXISTING_IDENTICAL"
        else:
            path.write_bytes(data)
            status = "WROTE"
        print(f"{status}: {path.relative_to(PROJECT)} sha256={digest(data)}")
    for record in records:
        print(f"{record['state']}: {len(record['frames'])} frames, source scale "
              f"{TARGET_UPRIGHT_HEIGHT}/{record['calibration']['source_upright_height_px']}; "
              f"stray={record['discarded_disconnected_threshold_pixels']}; "
              f"frame_sizes={[f['scaled_size'] for f in record['frames']]}")


if __name__ == "__main__":
    main()
