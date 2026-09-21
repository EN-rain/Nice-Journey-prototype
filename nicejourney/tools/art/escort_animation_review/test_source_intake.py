#!/usr/bin/env python3
"""Read-only, negative-only tests: never forge an accepted ImageGen source."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

if __package__:
    from .intake_escort_animation_sources import (
        EXPECTED_LOCAL_BOXES, NORMALIZATION, IntakeBlocked, _derive, _normalized_body,
    )
else:
    from intake_escort_animation_sources import (
        EXPECTED_LOCAL_BOXES, NORMALIZATION, IntakeBlocked, _derive, _normalized_body,
    )

HERE = Path(__file__).resolve().parent
INTAKE = HERE / "intake_escort_animation_sources.py"
PROJECT = HERE.parents[2]
ARCHIVE = PROJECT / "assets/art/generated_sources/imagegen/npc/escort_animation_v01/originals"
ORIGINALS = (ARCHIVE / "escort_idle_original.png", ARCHIVE / "escort_walk_original.png")
EVIDENCE = HERE / "source_intake_verified.json"
ATLAS = PROJECT / "assets/art/generated_sources/imagegen/npc/review/escort_idle_walk_320x32_review_20260921.png"
ZIP_NAME = "escort_animation_intake_candidate_20260921.zip"


def snapshot() -> dict[str, str | None]:
    paths = (*ORIGINALS, EVIDENCE, ATLAS)
    return {
        str(path): hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        for path in paths
    }


def invoke(zip_path: Path, recipe_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-B", str(INTAKE), "--zip", str(zip_path), "--recipe", str(recipe_path)],
        capture_output=True, text=True, encoding="utf-8", timeout=20,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )


class FailClosedOriginalIntake(unittest.TestCase):
    def test_missing_original_bundle_keeps_sources_immutable(self) -> None:
        before = snapshot()
        with tempfile.TemporaryDirectory(prefix="escort-original-intake-negative-") as temporary:
            folder = Path(temporary)
            run = invoke(folder / ZIP_NAME, folder / "not-provided.json")
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("Original ImageGen ZIP not available", run.stderr)
        self.assertEqual(snapshot(), before)

    def test_wrong_bytes_with_exact_zip_size_are_rejected_before_outputs(self) -> None:
        before = snapshot()
        with tempfile.TemporaryDirectory(prefix="escort-original-intake-negative-") as temporary:
            folder = Path(temporary)
            fake_zip = folder / ZIP_NAME
            fake_zip.write_bytes(b"invalid-not-an-imagegen-bundle" + b"\x00" * (1_348_574 - 30))
            self.assertEqual(fake_zip.stat().st_size, 1_348_574)
            run = invoke(fake_zip, folder / "not-provided.json")
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("Original bundle SHA256 mismatch", run.stderr)
        self.assertEqual(snapshot(), before)


class SourceBodyNormalizationOnly(unittest.TestCase):
    # In-memory synthetic pixels test math/transparency ONLY. These images are
    # not escort source, are never passed through intake(), and cannot be art.
    def test_exact_height_rounding_center_baseline_and_postresize_alpha(self) -> None:
        synthetic = Image.new("RGBA", (30, 30), (10, 20, 30, 24))
        synthetic.putpixel((1, 0), (200, 100, 50, 23))
        body, placement = _normalized_body(synthetic, (1, 0, 14, 17), 17)
        self.assertEqual(body.size, (20, 26))  # round(13*26/17) == 20
        self.assertEqual(placement, (4, 5))   # 14-round(20/2), 31-26
        self.assertEqual(body.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(body.getpixel((19, 25)), (10, 20, 30, 24))

    def test_alpha_cutoff_rejects_empty_synthetic_body(self) -> None:
        empty = Image.new("RGBA", (30, 30), (11, 22, 33, 23))
        with self.assertRaisesRegex(IntakeBlocked, "legible body"):
            _normalized_body(empty, (1, 1, 14, 18), 17)

    def test_local_stride_bbox_and_atlas_match_with_synthetic_only_pixels(self) -> None:
        # In-memory rectangles exercise ALL pinned local bboxes and strip
        # strides, without obtaining/claiming any genuine ImageGen original.
        recipe_path = HERE / "source_crop_recipe_v01.json"
        originals = {
            "idle": Image.new("RGBA", (2172, 724), (0, 0, 0, 0)),
            "walk": Image.new("RGBA", (2172, 724), (0, 0, 0, 0)),
        }
        expected = Image.new("RGBA", (320, 32), (0, 0, 0, 0))
        for frame, box in enumerate(EXPECTED_LOCAL_BOXES):
            kind = "idle" if frame < 4 else "walk"
            state_index = frame if kind == "idle" else frame - 4
            stride = NORMALIZATION["source_strides"][kind]
            left, top, right, bottom = box
            global_box = (state_index * stride + left, top,
                          state_index * stride + right, bottom)
            body_source = Image.new("RGBA", (right - left, bottom - top),
                                    (17 * frame, 33 + frame, 70, 255))
            originals[kind].paste(body_source, global_box[:2])
            body, (x, y) = _normalized_body(originals[kind], global_box,
                                            NORMALIZATION["source_heights"][kind])
            expected.alpha_composite(body, (32 * frame + x, y))
        proof = _derive(recipe_path, originals, expected)
        self.assertTrue(proof["full_rgba_atlas_pixel_match"])
        self.assertEqual(proof["frames"][1]["global_bbox"], [680, 71, 992, 666])
        self.assertEqual(proof["frames"][5]["global_bbox"], [435, 125, 675, 600])
        expected.putpixel((0, 0), (255, 0, 0, 255))
        with self.assertRaisesRegex(IntakeBlocked, "ALL RGBA atlas pixels"):
            _derive(recipe_path, originals, expected)


if __name__ == "__main__":
    unittest.main()
