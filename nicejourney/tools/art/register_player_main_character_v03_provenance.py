from __future__ import annotations

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
PROVENANCE_PATH = ROOT / "docs" / "ASSET_PROVENANCE_MANIFEST.json"
DERIVATION_PATH = (
    ROOT
    / "assets"
    / "art"
    / "generated_sources"
    / "imagegen"
    / "player"
    / "main_character_batches_v03"
    / "player_main_character_v03_derivation_manifest.json"
)
SOURCE_PREFIX = "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/"
PLAYER_SHEET_PATTERN = re.compile(r"^res://assets/art/player/animations/player_body_(.+)_sheet_v0[23]\.png$")


def title_for(animation: str) -> str:
    return animation.replace("_", " ").title()


def main() -> None:
    provenance = json.loads(PROVENANCE_PATH.read_text(encoding="utf-8"))
    derivation = json.loads(DERIVATION_PATH.read_text(encoding="utf-8"))
    assets = provenance.get("assets")
    if not isinstance(assets, list):
        raise RuntimeError("provenance manifest assets must be a list")

    animations = derivation["animations"]
    sources = derivation["sources"]
    replaced: set[str] = set()

    for index, entry in enumerate(assets):
        if not isinstance(entry, dict):
            continue
        project_path = str(entry.get("project_path", ""))
        match = PLAYER_SHEET_PATTERN.match(project_path)
        if not match:
            continue
        animation = match.group(1)
        if animation not in animations:
            continue
        record = animations[animation]
        source_file = record["source_file"]
        source_hash = sources[source_file]["sha256"]
        frame_count = int(record["frame_count"])
        assets[index] = {
            "asset_name": f"Player Body {title_for(animation)} Sheet v03",
            "project_path": f"res://assets/art/player/animations/player_body_{animation}_sheet_v03.png",
            "source": SOURCE_PREFIX + source_file,
            "creator_source": (
                f"User-provided generated main-character batch member {source_file} / SHA-256 {source_hash}; "
                "animation identity was assigned from direct visual inspection of the rendered poses rather than the ZIP member name."
            ),
            "license_category": "ai_generated_terms_permit",
            "license_text": (
                "User supplied this generated-art batch for Nice Journey integration; recorded under the project AI-generated-use category "
                "for prototype production. Final release rights review remains required."
            ),
            "attribution_text": "",
            "modifications": (
                "Exact source preserved; visually classified row segmented into individual poses, alpha-cropped, aspect-preserving LANCZOS-reduced "
                "into 32x32 bottom-centered gameplay cells, then packed in source motion order. No replacement pose was procedurally redrawn."
            ),
            "date_imported": "2026-09-15",
            "responsible_agent": "OpenAI ChatGPT",
            "kind": "pixel_art",
            "pixel_metadata": {
                "dimensions": f"{frame_count * 32}x32 px",
                "palette_material_ramp": "Inherited from the exact user-provided generated source; no recoloring in the V03 derivation.",
                "pivot_ground_anchor": "Bottom-center body placement in each 32x32 production cell.",
                "frame_order_timing": (
                    f"{frame_count} x 32x32 visually classified frames; authored total timing is preserved in the inspector-editable AnimationLibrary."
                ),
                "transparent_bounds": "Transparent PNG derived from the exact source alpha.",
                "intended_render_layers": ["actor_body"],
            },
        }
        replaced.add(animation)

    missing = sorted(set(animations.keys()) - replaced)
    if missing:
        raise RuntimeError(f"could not update player-body provenance entries: {missing}")

    PROVENANCE_PATH.write_text(json.dumps(provenance, indent=4) + "\n", encoding="utf-8")
    print(f"updated {len(replaced)} player-body provenance entries with V03 records")


if __name__ == "__main__":
    main()
