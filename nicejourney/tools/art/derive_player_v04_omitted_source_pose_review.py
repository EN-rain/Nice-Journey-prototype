"""Expose generated V04 block/hit poses omitted from R2, REVIEW ONLY.

Never pads motion, paints missing anatomy, edits accepted source art, or changes
the live AnimationLibrary. Retains all exact generated source poses in their
source order to make an independent *visual* acceptance decision possible.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

from derive_player_body_only_v04_r2 import (CELL, CONFIG, MANIFEST as R2_MANIFEST,
                                            PROJECT, get_sources, make_frame, split_row)


OUT = PROJECT / "assets/art/player/animations/review_v04_full_source"
MANIFEST = OUT / "player_v04_full_source_pose_review_manifest.json"
STATES = ("block", "hit")


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def png(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def compose() -> dict[str, bytes]:
    originals = get_sources()  # source bytes validated against immutable SHAs
    previous = {record["state"]: record for record in json.loads(R2_MANIFEST.read_text(encoding="utf-8"))["records"]}
    outputs: dict[str, bytes] = {}
    records = []
    for state, source, y0, y1, count, selected, calibration, _ in CONFIG:
        if state not in STATES:
            continue
        reference = previous[state]
        old_file = PROJECT / reference["output"].removeprefix("res://")
        old_bytes = old_file.read_bytes()
        if sha(old_bytes) != reference["output_sha256"] or selected != reference["selected_source_frames"]:
            raise ValueError(f"R2 baseline mutated for {state}")
        old = np.asarray(Image.open(io.BytesIO(old_bytes)).convert("RGBA"))
        pieces, stray = split_row(originals[source], y0, y1, count)
        if len(pieces) != count:
            raise ValueError("source frame count mutated")
        sheet = Image.new("RGBA", (CELL * count, CELL), (0, 0, 0, 0))
        frame_hashes = []
        for source_index, piece in enumerate(pieces):
            frame, _ = make_frame(piece, calibration)
            rgba = np.asarray(frame)
            if rgba.shape != (CELL, CELL, 4) or np.any(rgba[0, :, 3]) or np.any(rgba[-1, :, 3]):
                raise ValueError(f"{state} source frame {source_index} exceeds review canvas")
            sheet.paste(frame, (source_index * CELL, 0))
            frame_hashes.append(sha(rgba.tobytes()))
        all_pixels = np.asarray(sheet)
        for i, original_index in enumerate(selected):
            new_cell = all_pixels[:, original_index * CELL:(original_index + 1) * CELL]
            r2_cell = old[:, i * CELL:(i + 1) * CELL]
            if not np.array_equal(new_cell, r2_cell):
                raise ValueError(f"{state}: original source frame {original_index} no longer matches R2 frame {i}")
        missing = sorted(set(range(count)) - set(selected))
        if len(missing) != count - len(selected):
            raise ValueError("omitted source indices are not valid")
        duplicates = [[i, j] for i in range(count) for j in range(i + 1, count)
                      if frame_hashes[i] == frame_hashes[j]]
        name = f"player_{state}_all_{count}_generated_poses_v04_review_only.png"
        encoded = png(sheet)
        outputs[name] = encoded
        records.append({
            "state": state,
            "original_generated_source": reference["source"],
            "original_generated_source_sha256": reference["source_sha256"],
            "source_row_y0_y1": [y0, y1],
            "r2_candidate": reference["output"],
            "r2_candidate_sha256": reference["output_sha256"],
            "r2_selected_source_indices_verified_exact": selected,
            "newly_exposed_source_indices_unapproved": missing,
            "original_source_pose_count": count,
            "frame_canvas": [CELL, CELL],
            "full_source_review": "res://assets/art/player/animations/review_v04_full_source/" + name,
            "full_source_review_sha256": sha(encoded),
            "frame_rgba_sha256": frame_hashes,
            "identical_frame_pairs": duplicates,
            "ignored_stray_source_threshold_pixels": stray,
            "status": "SOURCE_EXACT_CANDIDATE_UNREVIEWED_NOT_PRODUCTION_OR_LIVE",
        })
    if {rec["state"] for rec in records} != set(STATES):
        raise ValueError("one or more expected state source rows unavailable")
    manifest = {
        "schema": "player-v04-omitted-source-pose-review/v1",
        "acceptance": "REVIEW_ONLY_NOT_VISUALLY_ACCEPTED_NOT_RUNTIME_BOUND",
        "no_padding_or_synthetic_interpolation": True,
        "purpose": "Expose real generated-source poses omitted from R2 before any decision about art or timing",
        "records": records,
    }
    outputs[MANIFEST.name] = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify byte-identical files, no writes")
    args = parser.parse_args()
    outputs = compose()
    if not args.check:
        OUT.mkdir(parents=True, exist_ok=True)
    for name, data in outputs.items():
        path = OUT / name
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError(f"review missing or no longer reproducible: {path}")
        elif path.is_file():
            if path.read_bytes() != data:
                raise FileExistsError(f"refusing existing review overwrite: {path}")
        else:
            path.write_bytes(data)
        print(f"{'PASS' if args.check else 'STAGED'} {path.relative_to(PROJECT)} sha256={sha(data)}")
    for rec in json.loads(outputs[MANIFEST.name])["records"]:
        print(f"{rec['state']}: {rec['original_source_pose_count']} source poses, "
              f"newly exposed {rec['newly_exposed_source_indices_unapproved']}, "
              f"identical pairs {rec['identical_frame_pairs']}, NOT production")


if __name__ == "__main__":
    main()
