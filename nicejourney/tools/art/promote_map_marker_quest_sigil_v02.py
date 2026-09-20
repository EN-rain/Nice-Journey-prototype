#!/usr/bin/env python3
"""Promote the exact source-backed four-glyph sheet after live UI acceptance.

Never alter the accepted core9 icons, the review candidate, or the V01
placeholder. The output is deterministically reproduced from immutable sources.
"""
from __future__ import annotations

import argparse
import json

from build_map_marker_quest_sigil_candidate import digest, produce, ROOT, OUTPUT

DESTINATION = ROOT / "assets/art/ui/markers/map_marker_quest_sigil_v02.png"
PROVENANCE = ROOT / "assets/art/ui/markers/map_marker_quest_sigil_v02.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="create production derivative once; never replace")
    args = parser.parse_args()
    image, candidate = produce()
    if OUTPUT.read_bytes() != image:
        raise ValueError("review candidate changed from immutable accepted image source")
    expected = {
        "status": "ACCEPTED_GLYPH_SHEET_READ_ONLY_MAP_LEGEND",
        "asset_record": "asset:ui/markers/map_marker_sheet",
        "imagegen_source": candidate["source"],
        "imagegen_source_sha256": candidate["source_sha256"],
        "production": "res://" + DESTINATION.relative_to(ROOT).as_posix(),
        "production_sha256": digest(image),
        "review_candidate": candidate["candidate"],
        "review_candidate_sha256": candidate["candidate_sha256"],
        "dimensions": [128, 32],
        "cell_dimensions": [32, 32],
        "cells": candidate["cells"],
        "derivation": candidate["derivation"],
        "acceptance_scope": "Read-only four-glyph legend in live MapMenu; quest locations and map travel are not authored or enabled",
        "superseded_placeholder_preserved": "res://assets/art/ui/markers/map_marker_sheet_v01.png",
    }
    data = json.dumps(expected, indent=2, ensure_ascii=False) + "\n"
    if args.apply:
        if DESTINATION.exists() or PROVENANCE.exists():
            raise ValueError("production output exists; run verifier, do not overwrite")
        DESTINATION.write_bytes(image)
        PROVENANCE.write_text(data, encoding="utf-8")
    else:
        if not DESTINATION.is_file() or not PROVENANCE.is_file():
            raise ValueError("production derivative missing; run once with --apply")
        if DESTINATION.read_bytes() != image or PROVENANCE.read_text(encoding="utf-8") != data:
            raise ValueError("production derivative or provenance differs from accepted source")
    print("MAP MARKER PRODUCTION GLYPHS PASS: 4 source-exact cells, 128x32, SHA-256=" + digest(image))


if __name__ == "__main__":
    main()
