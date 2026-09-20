from __future__ import annotations

import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets/art/generated_sources/imagegen/enemy_refs/remaining8"
OUTPUT_ROOT = ROOT / "assets/art/enemies"
MANIFEST_PATH = ROOT / "assets/art/generated_sources/imagegen/enemy_v02_derivation_manifest.json"

POSES = ("idle", "move", "windup", "release", "hit", "death")
ARCHETYPES = (
    "skirmisher",
    "assassin",
    "mobile_ranged",
    "caster",
    "support",
    "summoner",
    "flying_harrier",
    "controller_disruptor",
)

TARGET_SIZE = 48
CONTENT_BOX = 46
BACKGROUND_DISTANCE = 20.0


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_path(archetype: str) -> Path:
    return SOURCE_DIR / f"{archetype}_pixel_art_sprite_sheet.png"


def bbox_gap(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> tuple[int, int]:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ar, ab = ax + aw, ay + ah
    br, bb = bx + bw, by + bh
    dx = max(0, max(ax, bx) - min(ar, br))
    dy = max(0, max(ay, by) - min(ab, bb))
    return dx, dy


def derive_pose(image: Image.Image, pose_index: int, flying: bool) -> tuple[Image.Image, list[int]]:
    rgb = np.asarray(image.convert("RGB"))
    height, width, _ = rgb.shape

    border = np.concatenate(
        [
            rgb[:20].reshape(-1, 3),
            rgb[-20:].reshape(-1, 3),
            rgb[:, :20].reshape(-1, 3),
            rgb[:, -20:].reshape(-1, 3),
        ],
        axis=0,
    )
    background = np.median(border, axis=0)
    distance = np.linalg.norm(rgb.astype(np.float32) - background.astype(np.float32), axis=2)
    full_mask = (distance > BACKGROUND_DISTANCE).astype(np.uint8)

    cell_left = round(pose_index * width / 6)
    cell_right = round((pose_index + 1) * width / 6)
    cell_width = cell_right - cell_left
    margin = max(8, round(cell_width * 0.05))
    roi_left = max(0, cell_left - margin)
    roi_right = min(width, cell_right + margin)

    roi_mask = full_mask[:, roi_left:roi_right]
    count, labels, stats, _ = cv2.connectedComponentsWithStats(roi_mask, 8)
    components: list[tuple[int, tuple[int, int, int, int], int]] = []
    for label_id in range(1, count):
        x, y, w, h, area = [int(value) for value in stats[label_id]]
        if area < 80:
            continue
        components.append((area, (x + roi_left, y, w, h), label_id))
    if not components:
        raise RuntimeError(f"No foreground component found for pose index {pose_index}")

    # The production subject is the largest connected component inside each sixth of the sheet.
    # Generated labels are smaller disconnected components below it and therefore never drive the crop.
    main = max(components, key=lambda item: item[0])
    main_area, main_bbox, _ = main
    mx, my, mw, mh = main_bbox
    main_bottom = my + mh
    max_gap = max(12, round(cell_width * 0.18))

    selected: list[tuple[int, tuple[int, int, int, int], int]] = []
    for component in components:
        area, bbox, label_id = component
        x, y, w, h = bbox
        center_x = x + w * 0.5
        # Components may be inspected in a small overlap margin, but ownership stays with the
        # original sixth. This prevents fragments of the neighboring generated pose from leaking
        # into a 48x48 gameplay derivative.
        if center_x < cell_left or center_x > cell_right:
            continue
        owned_width = max(0, min(x + w, cell_right) - max(x, cell_left))
        if component != main and owned_width < w * 0.75:
            # A mostly out-of-cell component belongs to the neighboring generated pose even
            # when a few pixels spill across the equal-width semantic partition.
            continue
        if y > main_bottom + 20 and h < 48:
            # Generated pose labels/captions sit below the character baseline.
            continue
        dx, dy = bbox_gap(main_bbox, bbox)
        if component == main or (
            area >= max(120, int(main_area * 0.015))
            and dx <= max_gap
            and dy <= max_gap
        ):
            selected.append(component)

    if not selected:
        selected = [main]

    x0 = max(0, min(item[1][0] for item in selected) - 4)
    y0 = max(0, min(item[1][1] for item in selected) - 4)
    x1 = min(width, max(item[1][0] + item[1][2] for item in selected) + 4)
    y1 = min(height, max(item[1][1] + item[1][3] for item in selected) + 4)

    selected_mask = np.zeros((height, width), dtype=np.uint8)
    for _, _, label_id in selected:
        selected_mask[:, roi_left:roi_right][labels == label_id] = 255

    rgba = np.dstack([rgb, selected_mask])
    crop = Image.fromarray(rgba[y0:y1, x0:x1], "RGBA")

    source_w, source_h = crop.size
    scale = min(CONTENT_BOX / max(1, source_w), CONTENT_BOX / max(1, source_h))
    scaled_w = max(1, round(source_w * scale))
    scaled_h = max(1, round(source_h * scale))
    crop = crop.resize((scaled_w, scaled_h), Image.Resampling.NEAREST)

    frame = Image.new("RGBA", (TARGET_SIZE, TARGET_SIZE), (0, 0, 0, 0))
    x = (TARGET_SIZE - scaled_w) // 2
    if flying:
        y = (TARGET_SIZE - scaled_h) // 2
    else:
        y = TARGET_SIZE - scaled_h - 1
    frame.alpha_composite(crop, (x, y))
    return frame, [x0, y0, x1, y1]


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8")) if MANIFEST_PATH.exists() else {}

    for archetype in ARCHETYPES:
        source = source_path(archetype)
        if not source.exists():
            raise FileNotFoundError(source)
        image = Image.open(source)
        output_dir = OUTPUT_ROOT / archetype
        output_dir.mkdir(parents=True, exist_ok=True)

        output_records: dict[str, object] = {}
        frames: list[Image.Image] = []
        for pose_index, pose in enumerate(POSES):
            frame, source_rect = derive_pose(image, pose_index, archetype == "flying_harrier")
            output_name = f"enemy_{archetype}_{pose}_v02.png"
            output_path = output_dir / output_name
            frame.save(output_path)
            frames.append(frame)
            output_records[output_name] = {
                "source_rect": source_rect,
                "sha256": sha256(output_path),
                "size": [TARGET_SIZE, TARGET_SIZE],
            }

        sheet = Image.new("RGBA", (TARGET_SIZE * len(frames), TARGET_SIZE), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            sheet.alpha_composite(frame, (index * TARGET_SIZE, 0))
        sheet_name = f"enemy_{archetype}_core_sheet_v02.png"
        sheet_path = output_dir / sheet_name
        sheet.save(sheet_path)
        output_records[sheet_name] = {
            "sha256": sha256(sheet_path),
            "size": [TARGET_SIZE * len(frames), TARGET_SIZE],
        }

        manifest[archetype] = {
            "source": source.name,
            "source_project_path": f"res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/{source.name}",
            "source_sha256": sha256(source),
            "outputs": output_records,
            "derivation_note": (
                "Accepted generated six-pose source. Deterministic per-pose connected-component extraction removes the neutral gray background and generated labels, "
                "then nearest-neighbor fits the selected subject into a 48x48 gameplay cell; ground enemies are bottom-centered and Flying Harrier is centered. "
                "No procedural redraw or substitute art."
            ),
        }

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Derived {len(ARCHETYPES)} generated enemy sets; updated {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
