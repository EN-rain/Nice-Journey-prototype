from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LIBRARY = ROOT / "src" / "player" / "presentation" / "player_body_animation_library.tres"

FRAME_COUNTS = {
    "attack": 6,
    "block": 7,
    "cast": 7,
    "climb": 6,
    "dash": 4,
    "death": 6,
    "dodge": 4,
    "heavy_attack": 6,
    "hit": 6,
    "idle": 4,
    "interact": 5,
    "parry": 6,
    "pickup": 5,
    "run": 6,
    "sleep": 4,
    "use_item": 7,
    "walk": 6,
}

ORDER = list(FRAME_COUNTS.keys())


def extract_timing(text: str) -> dict[str, tuple[float, bool]]:
    resource_pos = text.find("_data = {")
    if resource_pos < 0:
        raise RuntimeError("AnimationLibrary has no _data mapping")
    mapping = dict(re.findall(r'&"([^"]+)": SubResource\("([^"]+)"\)', text[resource_pos:]))
    blocks = {
        match.group(1): match.group(2)
        for match in re.finditer(
            r'\[sub_resource type="Animation" id="([^"]+)"\]\r?\n(.*?)(?=\r?\n\[sub_resource|\r?\n\[resource\])',
            text,
            re.S,
        )
    }
    timing: dict[str, tuple[float, bool]] = {}
    for name in FRAME_COUNTS:
        subresource_id = mapping.get(name)
        if subresource_id is None or subresource_id not in blocks:
            raise RuntimeError(f"missing existing animation metadata for {name}")
        block = blocks[subresource_id]
        length_match = re.search(r'^length = ([^\r\n]+)', block, re.M)
        length = float(length_match.group(1)) if length_match else 1.0
        loop = bool(re.search(r'^loop_mode = 1\s*$', block, re.M))
        timing[name] = (length, loop)
    return timing


def fmt_float(value: float) -> str:
    if abs(value - round(value)) < 1e-9:
        return f"{value:.1f}"
    return f"{value:.9g}"


def animation_block(name: str, count: int, length: float, loop: bool) -> str:
    times = [length * index / count for index in range(count)]
    times_text = ", ".join(fmt_float(value) for value in times)
    transitions = ", ".join("1" for _ in range(count))
    values = ", ".join(str(index) for index in range(count))
    loop_line = "loop_mode = 1\n" if loop else ""
    return f'''[sub_resource type="Animation" id="Animation_{name}"]
length = {fmt_float(length)}
{loop_line}tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("BodyVisual/Body:texture")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {{
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [ExtResource("tex_{name}")]
}}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("BodyVisual/Body:hframes")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {{
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [{count}]
}}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("BodyVisual/Body:vframes")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {{
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [1]
}}
tracks/3/type = "value"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath("BodyVisual/Body:frame")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {{
"times": PackedFloat32Array({times_text}),
"transitions": PackedFloat32Array({transitions}),
"update": 1,
"values": [{values}]
}}
'''


def main() -> None:
    existing = LIBRARY.read_text(encoding="utf-8")
    timing = extract_timing(existing)
    uid_match = re.match(r'(\[gd_resource type="AnimationLibrary" format=3(?: uid="[^"]+")?\])', existing)
    header = uid_match.group(1) if uid_match else '[gd_resource type="AnimationLibrary" format=3]'

    lines = [header, ""]
    for name in ORDER:
        lines.append(
            f'[ext_resource type="Texture2D" path="res://assets/art/player/animations/player_body_{name}_sheet_v03.png" id="tex_{name}"]'
        )
    lines.append("")
    for name in ORDER:
        length, loop = timing[name]
        lines.append(animation_block(name, FRAME_COUNTS[name], length, loop))
    lines.append("[resource]")
    lines.append("_data = {")
    for index, name in enumerate(ORDER):
        suffix = "," if index < len(ORDER) - 1 else ""
        lines.append(f'&"{name}": SubResource("Animation_{name}"){suffix}')
    lines.append("}")
    lines.append("")
    LIBRARY.write_text("\n".join(lines), encoding="utf-8")
    print("updated", LIBRARY)
    for name in ORDER:
        length, loop = timing[name]
        print(f"{name}: {FRAME_COUNTS[name]} frames, length={length}, loop={loop}")


if __name__ == "__main__":
    main()
