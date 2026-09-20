#!/usr/bin/env python3
"""Read-only fail-closed check of real player projectile viewport captures.

Unlike a scene-resource assertion, this inspects the screenshots' actual RGB
pixels for the distinct, high-opacity blue source pixels at the launch point.
It does not claim full art acceptance from a match alone: other gameplay-scale
visibility, movement and occlusion review must still be performed.

The original capture test places the player at (250,180), starts both basic
and Q at ACTIVE, and takes a 1280x720 root viewport image. A follow-up
immediate capture logs the projectile's canvas origin as (250,180). Probe
1x and 2x viewport mapping and allow finite travel/camera displacement.
No images or manifests are written, including in --self-test mode.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / "artifacts/combat"
TEST = ROOT / "tests/test_player_projectile_sprite_presentation.gd"
BACKGROUND = np.array([23, 24, 27], dtype=np.int32)
PIXEL_TOLERANCE = 18
MIN_SOURCE_MATCH_FRACTION = 0.9
CONFIG = {
    "ranged": {
        "source": ROOT / "assets/art/player/weapons/arrow_projectile_v02.png",
        "source_sha256": "c860c37bb98562a6080e81a172d63e1880486d99dc9f011693093d64c097d25a",
        "sprite_offset_y": -4,
    },
    "mage": {
        "source": ROOT / "assets/art/player/weapons/arcane_projectile_v02.png",
        "source_sha256": "5ef936c9b85ccfc190a72fabd55e8d1a78683bf7c2cd696433888e28f48cef30",
        "sprite_offset_y": -1,
    },
}


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _source_samples(source: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    # Alpha multiplication can reach 255 * 255; int16 would overflow.
    alpha = source[:, :, 3].astype(np.int32)
    rgb = source[:, :, :3].astype(np.int32)
    distinctive = (alpha >= 230) & (rgb[:, :, 2] >= 210) & (rgb[:, :, 2] - rgb[:, :, 0] >= 65)
    y, x = np.where(distinctive)
    if len(x) < 10:
        raise ValueError("source lost its distinctive high-opacity blue pixels")
    weights = alpha[y, x, None]
    expected = (rgb[y, x] * weights + BACKGROUND[None, :] * (255 - weights) + 127) // 255
    return x, y, expected


def _best_match(image: np.ndarray, samples: tuple[np.ndarray, np.ndarray, np.ndarray],
                offset_y: int, expected_canvas: tuple[float, float] = (250, 180),
                travel_px: int = 50) -> dict:
    sx, sy, expected = samples
    best = {"matched_source_pixels": -1, "source_distinctive_pixels": len(sx),
            "viewport_scale": None, "offset_px": None}
    for scale in (1, 2):
        # Test scene root is at the logged canvas position, but the old
        # captures awaited additional frames and can contain projectile travel.
        x0 = round(expected_canvas[0] * scale) - 16 * scale
        y0 = round(expected_canvas[1] * scale) + (-8 + offset_y) * scale
        for dx in range(-travel_px * scale, travel_px * scale + 1):
            xx = x0 + dx + sx * scale
            if xx.min() < 0 or xx.max() >= image.shape[1]:
                continue
            for dy in range(-min(travel_px, 35) * scale, min(travel_px, 35) * scale + 1):
                yy = y0 + dy + sy * scale
                if yy.min() < 0 or yy.max() >= image.shape[0]:
                    continue
                actual = image[yy, xx].astype(np.int16)
                count = int(np.count_nonzero(np.max(np.abs(actual - expected), axis=1) <= PIXEL_TOLERANCE))
                if count > best["matched_source_pixels"]:
                    best = {"matched_source_pixels": count, "source_distinctive_pixels": len(sx),
                            "viewport_scale": scale, "offset_px": [dx, dy]}
    best["matched_fraction"] = round(best["matched_source_pixels"] / len(sx), 4)
    best["sufficient_source_pixel_evidence"] = best["matched_fraction"] >= MIN_SOURCE_MATCH_FRACTION
    return best


def audit() -> dict:
    test_code = TEST.read_text(encoding="utf-8")
    if ("game.player.global_position = Vector2(250, 180)" not in test_code
            or "visual.get_global_transform_with_canvas().origin" not in test_code):
        raise ValueError("capture coordinates changed; manually reauthor search anchors")
    results: dict = {}
    for class_id, config in CONFIG.items():
        source_path = config["source"]
        if _sha(source_path) != config["source_sha256"]:
            raise ValueError(f"accepted {class_id} source SHA changed")
        with Image.open(source_path) as opened:
            source = np.asarray(opened.convert("RGBA"))
        if source.shape != (16, 32, 4):
            raise ValueError(f"accepted {class_id} source dimensions changed")
        samples = _source_samples(source)
        reports: list[dict] = []
        static_verified = False
        live_verified = False
        hud_hidden_verified = False
        for suffix in ("renderer_evidence", "immediate_renderer_evidence",
                       "static_renderer_evidence", "stable_live_renderer_evidence",
                       "test_hud_panel_hidden_evidence"):
            path = CAPTURES / f"player_projectile_{class_id}_v02_{suffix}.png"
            if not path.is_file():
                reports.append({"path": f"res://artifacts/combat/{path.name}",
                                "status": "missing_capture", "sufficient_source_pixel_evidence": False})
                continue
            with Image.open(path) as opened:
                screen = np.asarray(opened.convert("RGB"))
            if screen.shape != (720, 1280, 3):
                raise ValueError(f"unexpected {class_id} screenshot dimensions: {screen.shape}")
            origins: list[tuple[float, float]] = [(250.0, 180.0)]
            radius = 50
            if suffix == "static_renderer_evidence":
                radius = 1
            if suffix in ("stable_live_renderer_evidence", "test_hud_panel_hidden_evidence"):
                positions = CAPTURES / f"player_projectile_{class_id}_v02_stable_live_positions.json"
                if not positions.is_file():
                    raise ValueError(f"stable live {class_id} screenshot lacks matching recorded canvas origins")
                payload = json.loads(positions.read_text(encoding="utf-8"))
                stable_capture = f"res://artifacts/combat/player_projectile_{class_id}_v02_stable_live_renderer_evidence.png"
                if (payload.get("class_id") != class_id
                        or payload.get("capture") != stable_capture
                        or payload.get("framebuffer_size") != [1280, 720]):
                    raise ValueError(f"stable live {class_id} screenshot origin metadata mismatch")
                origins = [tuple(float(v) for v in origin)
                           for origin in payload["projectile_canvas_origins"]]
                if not origins or any(len(origin) != 2 for origin in origins):
                    raise ValueError(f"stable live {class_id} screenshot has no valid origins")
                radius = 1
            matches = [_best_match(screen, samples, config["sprite_offset_y"],
                                   expected_canvas=origin, travel_px=radius)
                       for origin in origins]
            match = max(matches, key=lambda result: result["matched_source_pixels"])
            if suffix == "static_renderer_evidence":
                static_verified = match["sufficient_source_pixel_evidence"]
            if suffix == "stable_live_renderer_evidence":
                live_verified = match["sufficient_source_pixel_evidence"]
            if suffix == "test_hud_panel_hidden_evidence":
                hud_hidden_verified = match["sufficient_source_pixel_evidence"]
            reports.append({"path": f"res://artifacts/combat/{path.name}", "sha256": _sha(path),
                            "dimensions": [1280, 720], "measured_canvas_origins": origins, **match})
        results[class_id] = {
            "source_sha256": config["source_sha256"],
            "capture_scene_canvas_launch_origin": [250, 180],
            "screenshots": reports,
            "static_exact_source_pixel_evidence": static_verified,
            "live_exact_source_pixel_evidence": live_verified,
            "test_only_hud_hidden_exact_source_pixel_evidence": hud_hidden_verified,
            "live_visual_blocker": ("CombatHUD/Root/Panel CanvasLayer 20 overlays projectile corridor"
                                    if hud_hidden_verified and not live_verified else None),
        }
        # The normal gameplay HUD may hide the launch, but accepted art should
        # still be provably visible during actual basic AND equipped Q travel.
        # Do not count an artificially hidden HUD as normal-live acceptance.
        normal_path = CAPTURES / f"player_projectile_{class_id}_v02_normal_hud_clear_renderer_evidence.png"
        normal_metadata = CAPTURES / f"player_projectile_{class_id}_v02_normal_hud_clear_positions.json"
        normal_reports: list[dict] = []
        if normal_path.is_file() and normal_metadata.is_file():
            payload = json.loads(normal_metadata.read_text(encoding="utf-8"))
            expected_path = f"res://artifacts/combat/{normal_path.name}"
            if (payload.get("class_id") != class_id or payload.get("capture") != expected_path
                    or payload.get("framebuffer_size") != [1280, 720]
                    or payload.get("normal_hud_panel_visible") is not True
                    or payload.get("normal_hud_panel_rect") != [8, 8, 340, 236]):
                raise ValueError(f"{class_id} normal HUD evidence metadata mismatch")
            shots = payload.get("projectiles", [])
            if (len(shots) != 2
                    or len({int(shot["action_instance_id"]) for shot in shots}) != 2):
                raise ValueError(f"{class_id} normal HUD capture must contain distinct basic and Q")
            with Image.open(normal_path) as opened:
                normal_image = np.asarray(opened.convert("RGB"))
            if normal_image.shape != (720, 1280, 3):
                raise ValueError(f"{class_id} normal HUD screenshot dimensions changed")
            for shot in shots:
                origin = tuple(float(v) for v in shot["canvas_origin"])
                if (len(origin) != 2 or not 365 <= origin[0] <= 615
                        or abs(origin[1] - 180) >= 8
                        or float(shot["traveled"]) >= float(shot["range"])
                        or int(shot["remaining"]) <= 0):
                    raise ValueError(f"{class_id} normal HUD projectile cannot be accepted before expiry")
                normal_reports.append({
                    "action_instance_id": int(shot["action_instance_id"]),
                    "measured_canvas_origin": origin,
                    "traveled": float(shot["traveled"]),
                    "authored_range": float(shot["range"]),
                    "remaining_ticks": int(shot["remaining"]),
                    **_best_match(normal_image, samples, config["sprite_offset_y"],
                                  expected_canvas=origin, travel_px=1),
                })
        normal_both = len(normal_reports) == 2 and all(
            report["sufficient_source_pixel_evidence"] for report in normal_reports)
        results[class_id]["normal_hud_clear_both_basic_and_Q_verified"] = normal_both
        results[class_id]["normal_hud_clear_evidence"] = {
            "path": f"res://artifacts/combat/{normal_path.name}",
            "sha256": _sha(normal_path) if normal_path.is_file() else None,
            "hud_panel_visible": True if normal_reports else None,
            "projectiles": normal_reports,
        }
        results[class_id]["classification_eligibility"] = (
            "ACCEPTED_DO_NOT_REGENERATE" if static_verified and normal_both
            else "integrated_pending_visual_review"
        )
    return results


def self_test() -> None:
    for class_id, config in CONFIG.items():
        with Image.open(config["source"]) as opened:
            source = np.asarray(opened.convert("RGBA"))
        samples = _source_samples(source)
        # Synthetic positive proves that our exact-pixel detector can match
        # the unchanged source alpha-composited over the measured background.
        for scale in (1, 2):
            screenshot = np.empty((720, 1280, 3), dtype=np.uint8)
            screenshot[:] = BACKGROUND
            sx, sy, expected = samples
            xx = (250 - 16) * scale + sx * scale
            yy = (180 - 8 + config["sprite_offset_y"]) * scale + sy * scale
            screenshot[yy, xx] = expected
            result = _best_match(screenshot, samples, config["sprite_offset_y"])
            if not result["sufficient_source_pixel_evidence"]:
                raise AssertionError(f"self-test cannot recover {class_id} {scale}x source")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        results = audit()
    except (OSError, ValueError, AssertionError) as exc:
        print(f"PROJECTILE RENDERER EVIDENCE AUDIT FAIL: {exc}")
        return 1
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        if args.self_test:
            print("SOURCE PIXEL MATCHER POSITIVE CONTROL PASS (1x and 2x, both sources)")
        for class_id, result in results.items():
            for screenshot in result["screenshots"]:
                print(f"{class_id} {screenshot['path']}: "
                      f"{screenshot.get('matched_source_pixels', 0)}/"
                      f"{screenshot.get('source_distinctive_pixels', 'unknown')} "
                      "distinctive source pixels matched")
            for shot in result["normal_hud_clear_evidence"]["projectiles"]:
                print(f"{class_id} normal HUD intact basic/Q action {shot['action_instance_id']} "
                      f"x={shot['measured_canvas_origin'][0]:.3f}: "
                      f"{shot['matched_source_pixels']}/{shot['source_distinctive_pixels']} "
                      "distinctive source pixels matched")
            print(f"{class_id}: {result['classification_eligibility']}")
        print("No screenshots, source images, scenes, or manifests modified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
