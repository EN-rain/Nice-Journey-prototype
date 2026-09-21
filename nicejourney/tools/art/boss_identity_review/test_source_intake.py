#!/usr/bin/env python3
"""Offline, read-only contract tests for first Tenth Warden identity intake."""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from intake_identity_source import inspect, sha256  # noqa: E402


class IdentitySourceIntakeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def candidate(self, *, mode: str = "RGBA", edge: bool = False, suffix: str = ".png") -> Path:
        canvas = Image.new(mode, (256, 256), (0, 0, 0, 0) if mode == "RGBA" else (0, 0, 0))
        ink = (85, 98, 128, 255) if mode == "RGBA" else (85, 98, 128)
        for y in range(32, 225):
            for x in range(0 if edge else 68, 178):
                canvas.putpixel((x, y), ink)
        path = self.root / ("identity" + suffix)
        canvas.save(path, format="PNG")
        return path

    def test_valid_candidate_only_mechanically_reviewable_and_unchanged(self) -> None:
        source = self.candidate()
        original = source.read_bytes()
        result = inspect(source, hashlib.sha256(original).hexdigest())
        self.assertTrue(result["mechanically_reviewable"], result["errors"])
        self.assertFalse(result["visually_approved"])
        self.assertFalse(result["production_bound"])
        self.assertEqual(result["visible_bbox_exclusive"], [68, 32, 178, 225])
        self.assertEqual(result["source_margins_ltrb"], [68, 32, 78, 31])
        self.assertEqual(source.read_bytes(), original)

    def test_missing_file_fails_without_fabricated_source(self) -> None:
        result = inspect(self.root / "not_transferred.png")
        self.assertFalse(result["mechanically_reviewable"])
        self.assertNotIn("sha256", result)

    def test_renamed_non_png_and_rgb_are_rejected(self) -> None:
        self.assertFalse(inspect(self.candidate(suffix=".jpg"))["mechanically_reviewable"])
        self.assertFalse(inspect(self.candidate(mode="RGB"))["mechanically_reviewable"])

    def test_subject_reaching_edge_is_rejected(self) -> None:
        result = inspect(self.candidate(edge=True))
        self.assertFalse(result["mechanically_reviewable"])
        self.assertIn("visible pixels touch source boundary; figure may be cropped", result["errors"])

    def test_faint_alpha_fringe_at_edge_is_rejected(self) -> None:
        path = self.candidate()
        with Image.open(path) as loaded:
            image = loaded.copy()
        image.putpixel((0, 128), (85, 98, 128, 10))
        image.save(path)
        result = inspect(path)
        self.assertFalse(result["mechanically_reviewable"])
        self.assertEqual(result["visible_bbox_exclusive"], [68, 32, 178, 225])
        self.assertIn("visible pixels touch source boundary; figure may be cropped", result["errors"])

    def test_bad_expected_sha_is_rejected(self) -> None:
        result = inspect(self.candidate(), "0" * 64)
        self.assertFalse(result["mechanically_reviewable"])

    def test_existing_procedural_idle_is_not_a_new_source(self) -> None:
        v01 = Path(__file__).resolve().parents[3] / "assets/art/enemies/boss_tenth_warden/tenth_warden_idle_v01.png"
        result = inspect(v01, sha256(v01))
        self.assertFalse(result["mechanically_reviewable"])
        self.assertTrue(any("procedural placeholder" in message for message in result["errors"]))

    def test_fake_alpha_and_truncated_png_fail(self) -> None:
        opaque = Image.new("RGBA", (128, 128), (85, 98, 128, 255))
        path = self.root / "identity.png"
        opaque.save(path)
        self.assertFalse(inspect(path)["mechanically_reviewable"])
        path.write_bytes(path.read_bytes()[:30])
        self.assertFalse(inspect(path)["mechanically_reviewable"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
