from pathlib import Path
from PIL import Image, ImageDraw
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "player"
OUT.mkdir(parents=True, exist_ok=True)
BASE = Image.open(OUT / "player_side_idle_ref_v01.png").convert("RGBA")

ANIMS = {
    "idle": [(0,0),(0,0),(0,-1),(0,0)],
    "walk": [(-1,0),(0,-1),(1,0),(1,0),(0,-1),(-1,0)],
    "run": [(-2,0),(-1,-1),(2,0),(2,0),(1,-1),(-2,0)],
    "attack": [(0,0),(0,0),(1,0),(2,0),(1,0),(0,0)],
    "heavy_attack": [(-1,0),(-1,-1),(0,-1),(1,0),(2,0),(2,0),(1,0),(0,0)],
    "dash": [(1,1),(2,1),(3,1),(1,0)],
    "dodge": [(-1,1),(0,2),(2,2),(1,1)],
    "block": [(0,0),(0,-1),(0,-1)],
    "parry": [(-1,0),(0,-1),(1,-1),(2,0),(0,0)],
    "cast": [(0,0),(0,-1),(0,-2),(0,-2),(0,-1),(0,0)],
    "hit": [(1,0),(-2,1),(-1,1),(0,0)],
    "death": [(0,0),(-1,1),(-2,2),(-3,3),(0,0),(0,0),(0,0),(0,0)],
    "interact": [(0,0),(1,0),(2,0),(0,0)],
    "pickup": [(0,0),(0,1),(0,2),(0,1)],
    "use_item": [(0,0),(0,-1),(0,-2),(0,0)],
    "climb": [(0,0),(0,-1),(0,0),(0,-1),(0,0),(0,-1)],
    "sleep": [(0,0),(0,0),(0,1),(0,0)],
}
SPEEDS = {
    "idle":5.0,"walk":8.0,"run":10.0,"attack":12.0,"heavy_attack":10.0,
    "dash":12.0,"dodge":12.0,"block":8.0,"parry":12.0,"cast":10.0,
    "hit":12.0,"death":8.0,"interact":8.0,"pickup":8.0,"use_item":8.0,
    "climb":8.0,"sleep":4.0,
}
LOOPS = {"idle","walk","run","block","climb","sleep"}


def shift_image(img, dx, dy):
    out = Image.new("RGBA", (32,32), (0,0,0,0))
    out.alpha_composite(img, (dx,dy))
    return out


def frame_for(name, index, offset):
    dx, dy = offset
    if name == "death" and index >= 4:
        prone = BASE.transpose(Image.Transpose.ROTATE_90)
        return shift_image(prone, -2, 5)
    if name == "sleep":
        prone = BASE.transpose(Image.Transpose.ROTATE_90)
        return shift_image(prone, -2, 4 + (1 if index == 2 else 0))
    img = shift_image(BASE, dx, dy)
    if name in {"dash","dodge"}:
        # Keep integer-pixel silhouette trail; no blurred interpolation.
        trail = Image.new("RGBA", (32,32), (0,0,0,0))
        alpha = BASE.getchannel("A").point(lambda v: 70 if v else 0)
        ghost = BASE.copy(); ghost.putalpha(alpha)
        trail.alpha_composite(ghost, (-2, dy))
        trail.alpha_composite(img)
        img = trail
    return img


def make_sheet():
    order = list(ANIMS.keys())
    max_frames = max(len(v) for v in ANIMS.values())
    sheet = Image.new("RGBA", (max_frames*32, len(order)*32), (0,0,0,0))
    meta = {}
    for row, name in enumerate(order):
        frames = []
        for col, offset in enumerate(ANIMS[name]):
            frame = frame_for(name, col, offset)
            sheet.alpha_composite(frame, (col*32, row*32))
            frames.append({"x":col*32,"y":row*32,"w":32,"h":32})
        meta[name] = {"row":row,"frames":frames,"speed":SPEEDS[name],"loop":name in LOOPS}
    sheet.save(OUT / "player_body_sheet_v01.png")
    (OUT / "player_body_sheet_v01.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return order, meta


def make_weapon(name, painter):
    im = Image.new("RGBA", (32,32), (0,0,0,0))
    painter(ImageDraw.Draw(im))
    im.save(OUT / name)


def make_weapons():
    outline="#16151F"; outline2="#282637"; paper="#D8D2C4"; gold="#D6A84C"; gold_d="#8F6A2D"; cloth="#4E6A7F"; teal="#35B7A7"; arcane="#8D6CCF"
    make_weapon("weapon_sword_v01.png", lambda d: (d.line([(13,16),(29,16)], fill=outline, width=3), d.line([(15,16),(28,16)], fill=paper, width=1), d.rectangle([12,14,14,18], fill=gold_d), d.rectangle([9,15,12,17], fill=gold)))
    def shield(d):
        d.polygon([(16,10),(23,11),(26,16),(23,22),(16,23),(14,16)], fill=outline)
        d.polygon([(17,11),(22,12),(24,16),(22,20),(17,22),(15,16)], fill=cloth)
        d.line([(17,12),(17,21)], fill=teal, width=1)
    make_weapon("shield_v01.png", shield)
    def bow(d):
        d.arc([15,5,29,27], 270, 90, fill=gold, width=2)
        d.line([(22,6),(22,26)], fill=paper, width=1)
        d.line([(15,16),(28,16)], fill=outline2, width=1)
    make_weapon("weapon_bow_v01.png", bow)
    def staff(d):
        d.line([(10,16),(29,16)], fill=outline, width=3)
        d.line([(11,16),(27,16)], fill=gold_d, width=1)
        d.rectangle([27,13,30,19], fill=outline)
        d.rectangle([28,14,30,18], fill=arcane)
        d.point((29,15), fill=paper)
    make_weapon("weapon_staff_v01.png", staff)
    shadow = Image.new("RGBA", (16,8), (0,0,0,0))
    ImageDraw.Draw(shadow).ellipse([1,2,14,6], fill=(22,21,31,110))
    shadow.save(OUT / "player_contact_shadow_v01.png")


def make_spriteframes(order, meta):
    sub = []
    anim_blocks = []
    sid = 1
    for row, name in enumerate(order):
        ids = []
        for col in range(len(ANIMS[name])):
            rid = f"AtlasTexture_{sid}"
            sub.append(f'[sub_resource type="AtlasTexture" id="{rid}"]\natlas = ExtResource("1_sheet")\nregion = Rect2({col*32}, {row*32}, 32, 32)\n')
            ids.append(rid); sid += 1
        frames = ", ".join('{"duration": 1.0, "texture": SubResource("%s")}' % rid for rid in ids)
        anim_blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (frames, str(name in LOOPS).lower(), name, SPEEDS[name]))
    text = '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (sid + 1)
    text += '[ext_resource type="Texture2D" path="res://assets/art/player/player_body_sheet_v01.png" id="1_sheet"]\n\n'
    text += "\n".join(sub)
    text += '\n[resource]\nanimations = [%s]\n' % (",\n".join(anim_blocks))
    (OUT / "player_body_frames_v01.tres").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    order, meta = make_sheet()
    make_weapons()
    make_spriteframes(order, meta)
    print(f"generated {sum(len(v) for v in ANIMS.values())} body frames across {len(order)} animations")
