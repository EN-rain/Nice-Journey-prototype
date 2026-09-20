"""Stage NEAREST/common-scale candidates for four still-LANCZOS V03 states.

The 17-state authoritative V03 batch is immutable. This reads its recorded,
visually classified source crop geometry; never runs the older 17-output
deriver (which overwrites accepted production sprites). --check is read-only.
Source drawing defects or baked-in connected effects are not repainted here.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources"
OLD_RECORDS = ROOT / "docs/evidence/art/nearest_candidates/player_main_character_v03_nearest_derivation_manifest.json"
OUTPUT = ROOT / "assets/art/player/animations"
MANIFEST = ROOT / "assets/art/generated_sources/imagegen/player/main_character_batches_v03/player_remaining_v03_r2_candidate_manifest.json"
STATES = ("interact", "use_item", "death", "dodge")
TARGET_UPRIGHT_HEIGHT = 28
THRESHOLD = 24
FRAME = 32

# Standing source-pixel heights from measured exact source crops; the same
# scale is applied to the full motion including falling/crouching poses.
# Dodge's frame 0 is 197, death frame 0 216, use_item frame 0 226,
# interact frame 0 229 pixels high at alpha threshold >=24.
UPRIGHT = {"interact": 229, "use_item": 226, "death": 216, "dodge": 197}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encode(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def one_frame(pixels, cell_xyxy, scale_height):
    x0, y0, x1, y1 = cell_xyxy
    fragment = pixels[y0:y1, x0:x1]
    visible = fragment[:, :, 3] >= THRESHOLD
    if not np.any(visible):
        raise ValueError(f"empty source cell {cell_xyxy}")
    ys, xs = np.where(visible)
    xmin, ymin, xmax, ymax = int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)
    crop = np.copy(fragment[ymin:ymax, xmin:xmax])
    # Remove only low-alpha haze; fail on extra large disconnected material
    # rather than silently deleting motion/weapon detail.
    mask = crop[:, :, 3] >= THRESHOLD
    components, total = ndimage.label(mask, structure=np.ones((3, 3), dtype=bool))
    component_areas = np.bincount(components.ravel(), minlength=total + 1)
    major = [int(v) for v in component_areas[1:] if v >= 1000]
    if len(major) != 1:
        raise ValueError(f"source cell has {len(major)} major components {cell_xyxy}: {major}")
    discarded_subthreshold = int(np.count_nonzero((crop[:, :, 3] > 0) & ~mask))
    crop[~mask] = 0
    width = max(1, round(crop.shape[1] * TARGET_UPRIGHT_HEIGHT / scale_height))
    height = max(1, round(crop.shape[0] * TARGET_UPRIGHT_HEIGHT / scale_height))
    if width > FRAME or height > FRAME:
        raise ValueError(f"frame exceeds 32x32: {cell_xyxy} -> {(width, height)}")
    reduced = Image.fromarray(crop).resize((width, height), resample=Image.Resampling.NEAREST)
    cell = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - width) // 2
    y = 30 - height  # last occupied y=29; source anchor at (16,29)
    cell.paste(reduced, (x, y))
    if cell.getchannel("A").getbbox() is None:
        raise ValueError(f"downsampled to empty output: {cell_xyxy}")
    return cell, {
        "source_cell_xyxy": cell_xyxy,
        "alpha_crop_xyxy": [x0 + xmin, y0 + ymin, x0 + xmax, y0 + ymax],
        "scaled_size": [width, height],
        "paste_xy": [x, y],
        "output_alpha_bbox_xyxy": list(cell.getchannel("A").getbbox()),
        "major_components": major,
        "discarded_subthreshold_pixels": discarded_subthreshold,
    }


def derive():
    nearest = json.loads(OLD_RECORDS.read_text(encoding="utf-8"))
    sources = nearest["sources"]
    results = {}
    records = []
    for state in STATES:
        original = nearest["animations"][state]
        name = original["source_file"]
        source = SOURCES / name
        actual = sha(source.read_bytes())
        if actual != sources[name]["sha256"]:
            raise ValueError(f"source hash mismatch: {name}: {actual}")
        rgba = np.asarray(Image.open(source).convert("RGBA"))
        if list(rgba.shape[:2][::-1]) != sources[name]["dimensions"]:
            raise ValueError(f"source dimensions changed: {name}")
        sheet = Image.new("RGBA", (FRAME * original["frame_count"], FRAME), (0, 0, 0, 0))
        frames = []
        for index, row in enumerate(original["source_cells"]):
            cell, data = one_frame(rgba, row["source_crop"], UPRIGHT[state])
            sheet.paste(cell, (index * FRAME, 0))
            frames.append({"output_frame": index, **data})
        filename = f"player_body_{state}_sheet_v03_r2_candidate.png"
        encoded = encode(sheet)
        results[filename] = encoded
        records.append({
            "state": state,
            "stage": "DERIVED_CANDIDATE_PENDING_VISUAL_SOURCE_REVIEW_AND_WEAPON_ALIGNMENT",
            "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/" + name,
            "source_sha256": actual,
            "source_dimensions": sources[name]["dimensions"],
            "recorded_source_row": original["source_row"],
            "original_v03_lanczos_sha256": sha((OUTPUT / f"player_body_{state}_sheet_v03.png").read_bytes()),
            "uniform_scale": [TARGET_UPRIGHT_HEIGHT, UPRIGHT[state]],
            "normalization": "recorded visual-classification cells; threshold24 alpha crop; same NEAREST scale across every pose; transparent padding center/baseline29",
            "output": "res://assets/art/player/animations/" + filename,
            "output_sha256": sha(encoded),
            "output_dimensions": list(sheet.size),
            "frames": frames,
        })
    manifest = {
        "schema": "player-remaining-v03-r2-candidate/v1",
        "stage": "FOUR_DERIVED_CANDIDATES_UNREVIEWED_NOT_RUNTIME_BOUND",
        "script": "res://tools/art/derive_player_remaining_v03_r2.py",
        "records": records,
    }
    results[MANIFEST.name] = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    return results, records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    outputs, records = derive()
    for filename, data in outputs.items():
        path = MANIFEST if filename == MANIFEST.name else OUTPUT / filename
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError(f"candidate not byte-identical: {path}")
            status = "BYTE_IDENTICAL"
        else:
            if path.exists():
                if path.read_bytes() == data:
                    status = "EXISTING_IDENTICAL"
                elif path == MANIFEST:
                    path.write_bytes(data)
                    status = "UPDATED_OWN_CANDIDATE_MANIFEST"
                else:
                    raise FileExistsError(f"refusing to overwrite an existing candidate: {path}")
            else:
                path.write_bytes(data)
                status = "WROTE"
        print(f"{status} {path.relative_to(ROOT)} sha256={sha(data)}")
    for record in records:
        print(f"{record['state']}: {len(record['frames'])} poses uniform_scale={record['uniform_scale']} "
              f"sizes={[f['scaled_size'] for f in record['frames']]}")


if __name__ == "__main__":
    main()
