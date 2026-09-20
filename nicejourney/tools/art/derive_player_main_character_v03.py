from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "assets" / "art" / "generated_sources" / "imagegen" / "player" / "main_character_batches_v03"
EXACT_DIR = SOURCE_ROOT / "exact_sources"
RAW_ZIP = SOURCE_ROOT / "raw_batch" / "nice_journey_main_character_sprite_batches_transparent.zip"
OUT_DIR = ROOT / "assets" / "art" / "player" / "animations"
EVIDENCE_DIR = ROOT / "docs" / "evidence" / "art"
MANIFEST_PATH = SOURCE_ROOT / "player_main_character_v03_derivation_manifest.json"

EXPECTED_ZIP_SHA256 = "ed4140616a6bfe1bbbc252eae7927ff124db55baee09a818ca11abddca8cd1b0"
EXPECTED_SOURCE_SHA256 = {
    "01_idle_walk_run_dash.png": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
    "02_dodge_attack_heavy_block.png": "04821bcbf1f6805ab1ca17f9f34a77e205f3cd4ae3371b1720c308ba631ccc51",
    "03_parry_cast_hit.png": "900014457b6334bc1536a74beffe17c9223abbd66d01075cd5079bdc4ca0573d",
    "04_interact_pickup_use_item.png": "ed20954b4a208024da52cfce195d0298558a4f7d26d985155bceaa134067368c",
    "05_climb_sleep_death.png": "020580789050e784d4dbe389d7bd93bb3041e7948cccef209a259b2f150410e7",
}

# The ZIP member names are explicitly NOT trusted as semantic authority. These
# assignments were made by visually inspecting the rendered poses in each row.
# This is intentional because three source filenames materially misdescribe the
# animation rows they contain.
VISUALLY_CLASSIFIED_ROWS: dict[str, list[tuple[str, int]]] = {
    "01_idle_walk_run_dash.png": [
        ("idle", 4),
        ("walk", 6),
        ("run", 6),
        ("dash", 4),
    ],
    "02_dodge_attack_heavy_block.png": [
        ("interact", 5),
        ("pickup", 5),
        ("use_item", 7),
    ],
    "03_parry_cast_hit.png": [
        ("parry", 6),
        ("cast", 7),
        ("hit", 6),
    ],
    "04_interact_pickup_use_item.png": [
        ("climb", 6),
        ("sleep", 4),
        ("death", 6),
    ],
    "05_climb_sleep_death.png": [
        ("dodge", 4),
        ("attack", 6),
        ("heavy_attack", 6),
        ("block", 7),
    ],
}

VISUAL_RATIONALE = {
    "idle": "standing breathing/weight-shift poses",
    "walk": "alternating ordinary walking gait",
    "run": "forward-leaning running gait with longer stride",
    "dash": "low fast forward burst with trailing scarf/body smear",
    "interact": "standing reach/touch gesture with a small contact spark",
    "pickup": "standing-to-crouched ground reach and recovery",
    "use_item": "small blue item raised/used near the face, then recovery",
    "parry": "brief guarded deflection with a sharp blue impact arc",
    "cast": "blue orb charge, release/projectile, and recovery",
    "hit": "backward recoil, stagger/fall-to-knee, and recovery",
    "climb": "repeated upward hand/leg reaching poses",
    "sleep": "seated/resting eyes-closed poses",
    "death": "standing recoil through fall to fully prone state",
    "dodge": "compressed evasive burst with a short motion trail",
    "attack": "quick horizontal sword slash sequence",
    "heavy_attack": "overhead wind-up into forceful downward sword strike",
    "block": "sustained guarded stance with repeated blue guard arcs",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def group_indices(values: list[int], max_gap: int) -> list[tuple[int, int]]:
    if not values:
        return []
    groups: list[tuple[int, int]] = []
    start = previous = values[0]
    for value in values[1:]:
        if value - previous > max_gap:
            groups.append((start, previous))
            start = value
        previous = value
    groups.append((start, previous))
    return groups


def occupied_rows(alpha: Image.Image, threshold: int = 8) -> list[int]:
    width, height = alpha.size
    rows: list[int] = []
    pixels = alpha.load()
    for y in range(height):
        if any(pixels[x, y] > threshold for x in range(width)):
            rows.append(y)
    return rows


def column_occupancy(alpha: Image.Image, y0: int, y1: int, threshold: int = 8) -> list[int]:
    width, _ = alpha.size
    pixels = alpha.load()
    return [sum(1 for y in range(y0, y1 + 1) if pixels[x, y] > threshold) for x in range(width)]


def visible_column_groups(occupancy: list[int], max_transparent_gap: int = 5) -> list[tuple[int, int]]:
    visible = [x for x, count in enumerate(occupancy) if count > 0]
    return group_indices(visible, max_transparent_gap)


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def normalize_frame(image: Image.Image) -> Image.Image:
    bbox = alpha_bbox(image)
    if bbox is None:
        raise RuntimeError("empty frame after visual-row segmentation")
    crop = image.crop(bbox)
    width, height = crop.size
    scale = min(30.0 / max(1, width), 30.0 / max(1, height))
    out_width = max(1, int(round(width * scale)))
    out_height = max(1, int(round(height * scale)))
    reduced = crop.resize((out_width, out_height), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    x = (32 - out_width) // 2
    y = 31 - out_height
    out.alpha_composite(reduced, (x, y))
    return out


def fallback_boundaries(occupancy: list[int], xmin: int, xmax: int, count: int) -> list[int]:
    span = xmax - xmin + 1
    pitch = span / count
    boundaries = [xmin]
    previous = xmin
    for i in range(1, count):
        nominal = xmin + i * pitch
        search_radius = max(12, int(round(pitch * 0.38)))
        lo = max(previous + 8, int(round(nominal - search_radius)))
        hi = min(xmax - 8, int(round(nominal + search_radius)))
        zero_runs: list[tuple[int, int]] = []
        run_start: int | None = None
        for x in range(lo, hi + 1):
            if occupancy[x] == 0 and run_start is None:
                run_start = x
            elif occupancy[x] != 0 and run_start is not None:
                zero_runs.append((run_start, x - 1))
                run_start = None
        if run_start is not None:
            zero_runs.append((run_start, hi))
        if zero_runs:
            chosen = min(zero_runs, key=lambda run: abs(((run[0] + run[1]) / 2.0) - nominal))
            boundary = int(round((chosen[0] + chosen[1]) / 2.0))
        else:
            boundary = min(range(lo, hi + 1), key=lambda x: (occupancy[x], abs(x - nominal)))
        boundaries.append(boundary)
        previous = boundary
    boundaries.append(xmax + 1)
    return boundaries


def derive_row(image: Image.Image, row_bounds: tuple[int, int], animation: str, count: int) -> tuple[Image.Image, dict]:
    y0, y1 = row_bounds
    alpha = image.getchannel("A")
    occupancy = column_occupancy(alpha, y0, y1)
    visible = [x for x, amount in enumerate(occupancy) if amount > 0]
    if not visible:
        raise RuntimeError(f"{animation}: visually classified row contains no visible pixels")
    xmin, xmax = min(visible), max(visible)
    groups = visible_column_groups(occupancy)

    segmentation_mode = "transparent_groups"
    if len(groups) == count:
        cells = [(max(0, left - 2), min(image.width, right + 3)) for left, right in groups]
    else:
        segmentation_mode = "low_occupancy_boundaries"
        boundaries = fallback_boundaries(occupancy, xmin, xmax, count)
        cells = [(boundaries[i], boundaries[i + 1]) for i in range(count)]

    frames: list[Image.Image] = []
    cell_records: list[dict] = []
    for index, (left, right) in enumerate(cells):
        cell = image.crop((left, y0, right, y1 + 1))
        frame = normalize_frame(cell)
        frames.append(frame)
        cell_records.append({"frame": index, "source_crop": [left, y0, right, y1 + 1]})

    sheet = Image.new("RGBA", (count * 32, 32), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * 32, 0))
    return sheet, {
        "visual_role": VISUAL_RATIONALE[animation],
        "frame_count": count,
        "source_row": [y0, y1 + 1],
        "segmentation_mode": segmentation_mode,
        "source_cells": cell_records,
    }


def build_contact_sheet(animation_sheets: dict[str, Image.Image]) -> None:
    scale = 5
    label_width = 112
    row_height = 32 * scale + 10
    order = [name for rows in VISUALLY_CLASSIFIED_ROWS.values() for name, _ in rows]
    max_frames = max(animation_sheets[name].width // 32 for name in order)
    board = Image.new(
        "RGB",
        (label_width + max_frames * 32 * scale + 12, len(order) * row_height + 8),
        (235, 235, 235),
    )
    draw = ImageDraw.Draw(board)
    for row, name in enumerate(order):
        y = 8 + row * row_height
        draw.text((6, y + 6), name, fill=(20, 20, 20))
        sheet = animation_sheets[name]
        count = sheet.width // 32
        for index in range(count):
            frame = sheet.crop((index * 32, 0, (index + 1) * 32, 32))
            enlarged = frame.resize((32 * scale, 32 * scale), Image.Resampling.NEAREST)
            cell = Image.new("RGB", enlarged.size, (235, 235, 235))
            cell.paste(enlarged, mask=enlarged.getchannel("A"))
            board.paste(cell, (label_width + index * 32 * scale, y))
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    board.save(EVIDENCE_DIR / "player-main-character-v03-visual-review.png")


def main() -> None:
    if not RAW_ZIP.is_file():
        raise FileNotFoundError(RAW_ZIP)
    actual_zip_hash = sha256(RAW_ZIP)
    if actual_zip_hash != EXPECTED_ZIP_SHA256:
        raise RuntimeError(f"source ZIP hash mismatch: {actual_zip_hash}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source_records: dict[str, dict] = {}
    animation_records: dict[str, dict] = {}
    animation_sheets: dict[str, Image.Image] = {}

    for source_name, semantic_rows in VISUALLY_CLASSIFIED_ROWS.items():
        source_path = EXACT_DIR / source_name
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        source_hash = sha256(source_path)
        if source_hash != EXPECTED_SOURCE_SHA256[source_name]:
            raise RuntimeError(f"source hash mismatch for {source_name}: {source_hash}")
        image = Image.open(source_path).convert("RGBA")
        rows = group_indices(occupied_rows(image.getchannel("A")), 24)
        if len(rows) != len(semantic_rows):
            raise RuntimeError(
                f"{source_name}: expected {len(semantic_rows)} visually classified rows, detected {len(rows)}"
            )
        source_records[source_name] = {
            "sha256": source_hash,
            "dimensions": list(image.size),
            "semantic_authority": "visual_inspection_not_filename",
        }
        for row_index, (row_bounds, (animation, frame_count)) in enumerate(zip(rows, semantic_rows)):
            sheet, record = derive_row(image, row_bounds, animation, frame_count)
            output_name = f"player_body_{animation}_sheet_v03.png"
            output_path = OUT_DIR / output_name
            sheet.save(output_path)
            animation_sheets[animation] = sheet
            record.update(
                {
                    "source_file": source_name,
                    "source_row_index": row_index,
                    "output": f"res://assets/art/player/animations/{output_name}",
                    "output_sha256": sha256(output_path),
                    "output_dimensions": list(sheet.size),
                    "normalization": "alpha crop per frame, aspect-preserving LANCZOS reduction into 32x32, bottom-center anchor",
                }
            )
            animation_records[animation] = record

    if len(animation_records) != 17:
        raise RuntimeError(f"expected 17 visually classified animations, derived {len(animation_records)}")

    build_contact_sheet(animation_sheets)
    manifest = {
        "version": 1,
        "status": "derived_from_visually_classified_user_batch",
        "source_zip": {
            "path": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/raw_batch/nice_journey_main_character_sprite_batches_transparent.zip",
            "sha256": actual_zip_hash,
        },
        "classification_rule": "Animation identity is assigned from direct visual inspection of motion/poses; source ZIP filenames are retained only as provenance labels and are not semantic authority.",
        "sources": source_records,
        "animations": animation_records,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"derived {len(animation_records)} visually classified player animations")
    print(MANIFEST_PATH)


if __name__ == "__main__":
    main()
