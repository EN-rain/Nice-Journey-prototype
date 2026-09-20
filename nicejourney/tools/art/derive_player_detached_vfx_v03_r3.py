"""Isolate two disconnected, genuine V03 generated-source effects for review.

This is a NON-PRODUCTION candidate. R2 body candidates, source PNGs, live V03
textures and external AnimationLibrary remain byte-for-byte untouched. Only
the explicitly reviewed interaction spark and use-item particles are moved;
the connected dodge swoosh and all other states are deliberately excluded.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


PROJECT = Path(__file__).resolve().parents[2]
R2 = PROJECT / "assets/art/player/animations"
R2_MANIFEST = PROJECT / "assets/art/generated_sources/imagegen/player/main_character_batches_v03/player_remaining_v03_r2_candidate_manifest.json"
OUTPUT = PROJECT / "assets/art/player/animations/review_r3"
MANIFEST = OUTPUT / "player_detached_vfx_v03_r3_candidate_manifest.json"
CELL = 32
ALPHA = 24

# Expected component sizes and locations are from the immutable R2 generated-
# source derivatives, not a guessed color threshold or freehand repaint.
SPEC = {
    "interact": {
        "frame": 2,
        "sizes": [4, 3, 3],
        "bounds": [[26, 7, 28, 10], [27, 10, 30, 12], [27, 13, 30, 15]],
        "visual": "three detached orange interaction spark components",
    },
    "use_item": {
        "frame": 5,
        "sizes": [5, 5],
        "bounds": [[25, 7, 28, 10], [23, 11, 26, 14]],
        "visual": "two detached cyan item particle components",
    },
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def encode(image: Image.Image) -> bytes:
    data = io.BytesIO()
    image.save(data, format="PNG", optimize=False)
    return data.getvalue()


def derive() -> tuple[dict[str, bytes], list[dict]]:
    r2_records = {rec["state"]: rec for rec in json.loads(R2_MANIFEST.read_text(encoding="utf-8"))["records"]}
    outputs: dict[str, bytes] = {}
    records = []
    for state, spec in SPEC.items():
        record = r2_records[state]
        origin = PROJECT / record["source"].removeprefix("res://")
        if sha(origin.read_bytes()) != record["source_sha256"]:
            raise ValueError(f"immutable generated V03 source changed for {state}")
        r2_source = PROJECT / record["output"].removeprefix("res://")
        r2_bytes = r2_source.read_bytes()
        if sha(r2_bytes) != record["output_sha256"]:
            raise ValueError(f"immutable V03 R2 derivative changed for {state}")
        src = np.asarray(Image.open(io.BytesIO(r2_bytes)).convert("RGBA")).copy()
        if src.shape[0] != CELL or src.shape[1] != record["output_dimensions"][0] or src.shape[1] % CELL:
            raise ValueError("R2 source sheet not 32px frame-aligned")
        body = src.copy()
        fx = np.zeros_like(src)
        detached = []
        for frame in range(src.shape[1] // CELL):
            xoff = frame * CELL
            patch = src[:, xoff:xoff + CELL]
            foreground = patch[:, :, 3] >= ALPHA
            labels, n = ndimage.label(foreground, structure=np.ones((3, 3), dtype=bool))
            areas = np.bincount(labels.ravel(), minlength=n + 1)
            objects = ndimage.find_objects(labels)
            large = [k for k in range(1, n + 1) if areas[k] >= 200]
            small = sorted((int(areas[k]), [objects[k - 1][1].start, objects[k - 1][0].start,
                                                   objects[k - 1][1].stop, objects[k - 1][0].stop], k)
                           for k in range(1, n + 1) if 2 <= areas[k] < 200)
            if len(large) != 1 or int(areas[large[0]]) < 200:
                raise ValueError(f"{state} frame {frame}: one complete body required")
            if np.any((patch[:, :, 3] > 0) & (patch[:, :, 3] < ALPHA)):
                raise ValueError(f"{state} frame {frame}: low-alpha halo needs separate visual review")
            if frame != spec["frame"]:
                if small or np.any((labels > 0) & (labels != large[0])):
                    raise ValueError(f"{state} frame {frame}: unexpected non-body fragments")
                continue
            expected = sorted(zip(spec["sizes"], spec["bounds"]))
            if [(area, bounds) for area, bounds, _ in small] != expected:
                raise ValueError(f"{state}: detached source component sizes/positions changed: {small}")
            selected = np.isin(labels, [key for _, _, key in small])
            if int(np.count_nonzero(selected)) != 10:
                raise ValueError(f"{state}: expected exactly 10 detached source pixels")
            if np.any(ndimage.binary_dilation(selected) & (labels == large[0])):
                raise ValueError(f"{state}: detached pixels now touch the actor silhouette")
            if np.any(~selected & (labels > 0) & (labels != large[0])):
                raise ValueError(f"{state}: additional unreviewed source fragments")
            fx[:, xoff:xoff + CELL][selected] = patch[selected]
            body[:, xoff:xoff + CELL][selected] = 0
            detached.append({"frame": frame, "source_component_sizes": spec["sizes"],
                             "source_component_bounds": spec["bounds"], "pixels": 10,
                             "visual": spec["visual"]})
        if len(detached) != 1 or np.any((body[:, :, 3] > 0) & (fx[:, :, 3] > 0)):
            raise ValueError(f"{state}: source pixel ownership is not disjoint")
        composed = body.copy()
        composed[fx[:, :, 3] > 0] = fx[fx[:, :, 3] > 0]
        if not np.array_equal(composed, src):
            raise ValueError(f"{state}: body/effect recomposition is not exact RGBA source")
        for role, image in (("body", body), ("vfx", fx)):
            output_name = f"player_{state}_{role}_v03_r3_detached_candidate.png"
            outputs[output_name] = encode(Image.fromarray(image))
        records.append({
            "state": state,
            "source_original": record["source"],
            "source_original_sha256": record["source_sha256"],
            "source_r2": record["output"],
            "source_r2_sha256": record["output_sha256"],
            "frame_count": src.shape[1] // CELL,
            "canvas": [src.shape[1], CELL],
            "body_candidate": "res://assets/art/player/animations/review_r3/player_" + state + "_body_v03_r3_detached_candidate.png",
            "body_candidate_sha256": sha(outputs[f"player_{state}_body_v03_r3_detached_candidate.png"]),
            "vfx_candidate": "res://assets/art/player/animations/review_r3/player_" + state + "_vfx_v03_r3_detached_candidate.png",
            "vfx_candidate_sha256": sha(outputs[f"player_{state}_vfx_v03_r3_detached_candidate.png"]),
            "detached_components": detached,
            "pixel_accounting": "All original RGBA pixel values preserved; body and effect ownership disjoint; source == body OR effect at each location",
            "status": "NON_PRODUCTION_REVIEW_ONLY_PENDING_ART_APPROVAL_TIMING_AND_LIVE_GODOT_INTEGRATION",
        })
    manifest = {
        "schema": "player-detached-vfx-v03-r3-candidate/v1",
        "acceptance": "CANDIDATE_ONLY_SOURCE_EXACT_NOT_RUNTIME_BOUND",
        "script": "res://tools/art/derive_player_detached_vfx_v03_r3.py",
        "bounds": "Only two existing separate effects; no dodge connected swoosh or any unknown action touched",
        "reference_accepted_player_identity": "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md",
        "records": records,
    }
    outputs[MANIFEST.name] = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    return outputs, records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify exact candidate bytes, never modify")
    args = parser.parse_args()
    outputs, records = derive()
    if not args.check:
        OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, data in outputs.items():
        path = OUTPUT / filename
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                raise ValueError(f"missing or non-reproducible R3 review: {path}")
        elif path.exists():
            if path.read_bytes() != data:
                raise FileExistsError(f"refusing to overwrite existing review source: {path}")
        else:
            path.write_bytes(data)
        print(f"{'PASS' if args.check else 'STAGED'} {path.relative_to(PROJECT)} sha256={sha(data)}")
    for rec in records:
        print(f"{rec['state']}: original pixel-perfect body + detached effect, "
              f"{rec['frame_count']} preserved frames, 10 isolated VFX pixels, NOT runtime bound")


if __name__ == "__main__":
    main()
