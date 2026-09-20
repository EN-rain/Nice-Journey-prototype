"""Audit Godot scene Label autowrap sizing and warn about container-owned labels.

Read-only audit by default; --fix adds a minimal nonzero custom minimum size
in scene Inspector data, keeping authored larger sizes unchanged.
"""
from __future__ import annotations

import argparse
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1] / "src"
NODE = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?')
SIZE = re.compile(r'^custom_minimum_size\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)')


def audit(path: pathlib.Path, fix: bool) -> tuple[int, int]:
    content = path.read_text(encoding="utf-8-sig")
    lines = content.splitlines(keepends=True)
    blocks: list[tuple[int, int, re.Match[str]]] = []
    for i, line in enumerate(lines):
        match = NODE.match(line)
        if match:
            if blocks:
                a, _, m = blocks[-1]
                blocks[-1] = (a, i, m)
            blocks.append((i, len(lines), match))
    nodes: dict[str, str] = {}
    for a, b, m in blocks:
        parent = m.group(3) or ""
        name = m.group(1)
        full_path = (parent + "/" + name).strip("./") if parent not in ("", ".") else name
        nodes[full_path] = m.group(2)
    issues = 0
    changed = 0
    for a, b, m in reversed(blocks):
        if m.group(2) != "Label":
            continue
        body = lines[a + 1:b]
        if not any(re.match(r'^autowrap_mode\s*=\s*[1-9]\d*\s*$', line.strip()) for line in body):
            continue
        parent = m.group(3) or ""
        parent_type = nodes.get(parent, "")
        if not parent_type.endswith("Container"):
            continue
        sizes = [SIZE.match(line.strip()) for line in body]
        sizes = [match for match in sizes if match]
        if sizes and any(float(match.group(1)) > 0 or float(match.group(2)) > 0 for match in sizes):
            continue
        issues += 1
        print(f"{path.relative_to(ROOT)}: {m.group(1)} (parent {parent_type} {parent}) needs minimum size")
        if fix:
            newline = "\r\n" if lines[a].endswith("\r\n") else "\n"
            lines.insert(a + 1, "custom_minimum_size = Vector2(1, 1)" + newline)
            changed += 1
    if changed:
        path.write_text("".join(lines), encoding="utf-8", newline="")
    return issues, changed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fix", action="store_true")
    args = parser.parse_args()
    issues = changed = 0
    for path in sorted(ROOT.rglob("*.tscn")):
        found, applied = audit(path, args.fix)
        issues += found
        changed += applied
    print(f"UI autowrap issues: {issues}; scene labels fixed: {changed}")
    if issues and not args.fix:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
