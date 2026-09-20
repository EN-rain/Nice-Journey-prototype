from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw
import json
import math

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
DOCS = ROOT / "docs"
MANIFEST = DOCS / "ASSET_PROVENANCE_MANIFEST.json"

P = {
    "transparent": (0, 0, 0, 0),
    "outline0": (22, 21, 31, 255),
    "outline1": (40, 38, 55, 255),
    "shadow": (52, 56, 75, 255),
    "stone_dark": (64, 70, 90, 255),
    "stone_mid": (89, 98, 119, 255),
    "stone_light": (123, 135, 156, 255),
    "paper": (216, 210, 196, 255),
    "highlight": (241, 233, 216, 255),
    "skin_shadow": (155, 96, 79, 255),
    "skin": (201, 133, 104, 255),
    "skin_light": (227, 178, 140, 255),
    "hair_dark": (36, 31, 43, 255),
    "hair": (59, 49, 66, 255),
    "cloth_dark": (49, 66, 86, 255),
    "cloth": (78, 106, 127, 255),
    "cloth_light": (114, 147, 164, 255),
    "teal_dark": (29, 116, 110, 255),
    "teal": (53, 183, 167, 255),
    "teal_light": (114, 224, 203, 255),
    "danger_dark": (138, 58, 58, 255),
    "danger": (216, 91, 82, 255),
    "gold_dark": (143, 106, 45, 255),
    "gold": (214, 168, 76, 255),
    "arcane": (141, 108, 207, 255),
    "arcane_light": (183, 159, 236, 255),
    "white": (255, 255, 255, 255),
    "black": (0, 0, 0, 255),
    "brown_dark": (78, 51, 45, 255),
    "brown": (119, 77, 57, 255),
    "brown_light": (166, 112, 71, 255),
    "green": (72, 150, 92, 255),
    "green_light": (117, 203, 123, 255),
}


def ensure_dirs() -> None:
    for p in [
        ART / "player" / "body",
        ART / "player" / "animations",
        ART / "player" / "animations" / "frames",
        ART / "player" / "weapons",
        ART / "player" / "vfx",
        ART / "vfx" / "telegraphs",
        ART / "enemies" / "duelist",
        ART / "enemies" / "bruiser",
        ART / "enemies" / "defender",
        ART / "enemies" / "marksman",
        ART / "environments" / "region3" / "functional_buildings",
        ART / "environments" / "region3" / "decorative_buildings",
        ART / "environments" / "region3" / "props",
        ART / "environments" / "region3" / "roads",
        ART / "environments" / "tower" / "tiles",
        ART / "environments" / "tower" / "rooms",
        ART / "ui" / "skills",
        ART / "ui" / "markers",
        ART / "ui" / "equipment",
    ]:
        p.mkdir(parents=True, exist_ok=True)


def image(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), P["transparent"])


def rect(d: ImageDraw.ImageDraw, xy, fill):
    d.rectangle(xy, fill=fill)


def poly(d: ImageDraw.ImageDraw, pts, fill):
    d.polygon(pts, fill=fill)


def line(d: ImageDraw.ImageDraw, pts, fill, width=1):
    d.line(pts, fill=fill, width=width)


def thick_pixel_line(d: ImageDraw.ImageDraw, a, b, outline, inner, width=3):
    line(d, [a, b], outline, width=width)
    if width >= 3:
        line(d, [a, b], inner, width=max(1, width - 2))


def draw_player(frame: Image.Image, pose: str, phase: int, count: int) -> None:
    d = ImageDraw.Draw(frame)
    # phase normalized 0..1; most motions use authored integer offsets to stay crisp.
    t = 0.0 if count <= 1 else phase / float(count - 1)
    bob = 0
    lean = 0
    root_x = 16
    root_y = 29
    arm_front = (23, 17)
    arm_back = (13, 17)
    leg_front = (19, 28)
    leg_back = (13, 28)
    scarf = [(13, 12), (10, 12), (8, 13), (10, 14), (14, 13)]
    head_dx = 0
    head_dy = 0
    body_dx = 0
    body_dy = 0
    crouch = 0
    show_potion = False
    sleep = False
    dead = False

    if pose == "idle":
        bob = [0, 0, -1, 0, 0][phase % 5]
        scarf = [(13, 12+bob), (10, 12+bob), (8 + (phase % 2), 13+bob), (10, 14+bob), (14, 13+bob)]
    elif pose == "walk":
        steps = [-2, -1, 0, 2, 1, 0, -2]
        s = steps[phase % len(steps)]
        bob = 0 if phase % 2 == 0 else -1
        leg_front = (19 + s, 28)
        leg_back = (13 - s, 28)
        arm_front = (22 - int(s * 0.7), 17 + bob)
        arm_back = (14 + int(s * 0.7), 17 + bob)
        scarf = [(13, 12+bob), (10, 12+bob), (7, 11 + (phase % 3)), (9, 14+bob), (14, 13+bob)]
    elif pose == "run":
        strides = [-4, -2, 1, 4, 2, -1, -4]
        s = strides[phase % len(strides)]
        lean = 1
        crouch = 1
        leg_front = (20 + s, 28)
        leg_back = (12 - s, 28)
        arm_front = (22 - int(s * 0.5), 17)
        arm_back = (13 + int(s * 0.5), 16)
        scarf = [(13, 12), (10, 11), (5, 10 + (phase % 2)), (8, 13), (14, 13)]
    elif pose == "dash":
        crouch = 4
        lean = 3
        body_dx = [0, 1, 2, 3, 2][phase]
        leg_front = (22 + body_dx, 28)
        leg_back = (11 + body_dx, 28)
        arm_front = (24 + body_dx, 18)
        arm_back = (14 + body_dx, 17)
        scarf = [(13+body_dx, 15), (9+body_dx, 14), (3+body_dx, 13), (7+body_dx, 16), (14+body_dx, 16)]
    elif pose == "dodge":
        # dodge is a low lateral evade, not a roll.
        crouches = [2, 5, 6, 4, 2]
        crouch = crouches[phase]
        lean = 2
        body_dx = [0, 1, 2, 2, 1][phase]
        leg_front = (21 + body_dx, 28)
        leg_back = (12 + body_dx, 28)
        arm_front = (22 + body_dx, 18 + crouch // 2)
        scarf = [(13+body_dx, 12+crouch), (9+body_dx, 12+crouch), (5+body_dx, 10+crouch), (8+body_dx, 14+crouch), (14+body_dx, 13+crouch)]
    elif pose == "attack":
        crouch = [0, 1, 2, 2, 1, 0][phase]
        body_dx = [0, 0, 1, 2, 1, 0][phase]
        arm_front = [(22,17), (24,16), (25,17), (26,18), (24,19), (23,17)][phase]
        arm_back = [(14,17), (15,16), (16,16), (15,17), (14,18), (13,17)][phase]
    elif pose == "heavy_attack":
        crouch = [0,1,2,3,3,2,1,0][phase]
        body_dx = [0,0,0,1,2,2,1,0][phase]
        arm_front = [(22,17),(20,14),(19,12),(22,12),(27,17),(26,20),(24,19),(23,17)][phase]
        arm_back = [(14,17),(15,15),(17,14),(17,15),(16,17),(15,18),(14,18),(13,17)][phase]
    elif pose == "block":
        arm_front = [(22,17),(24,16),(24,16)][phase]
        arm_back = [(14,17),(18,16),(18,16)][phase]
        crouch = [0,1,1][phase]
    elif pose == "parry":
        arm_front = [(22,17),(24,15),(26,16),(24,18),(23,17)][phase]
        arm_back = [(14,17),(16,16),(17,17),(15,18),(14,17)][phase]
        body_dx = [0,0,1,1,0][phase]
    elif pose == "cast":
        crouch = [0,0,1,1,1,1,0,0][phase]
        arm_front = [(22,17),(23,16),(24,15),(25,15),(25,16),(24,17),(23,17),(22,17)][phase]
        arm_back = [(14,17),(15,16),(16,15),(16,15),(16,16),(15,17),(14,17),(14,17)][phase]
    elif pose == "hit":
        body_dx = [0,-1,-2,-1][phase]
        lean = [-1,-2,-2,-1][phase]
        crouch = [0,1,2,1][phase]
        arm_front = [(23,17),(21,17),(20,18),(22,18)][phase]
    elif pose == "death":
        # first half collapses, second half is prone.
        if phase < 5:
            crouch = [0,2,5,8,10][phase]
            lean = [0,-1,-2,-3,-4][phase]
            body_dx = -phase // 2
        else:
            dead = True
    elif pose == "interact":
        arm_front = [(22,17),(24,17),(26,17),(25,17),(23,17)][phase]
        crouch = [0,0,0,0,0][phase]
    elif pose == "pickup":
        crouch = [0,3,7,4,0][phase]
        arm_front = [(22,17),(23,20),(22,24),(23,20),(22,17)][phase]
    elif pose == "use_item":
        arm_front = [(22,17),(22,15),(21,12),(22,14),(22,17)][phase]
        show_potion = phase in (1,2,3)
    elif pose == "climb":
        bob = [0,-1,-2,-1,0,1,0][phase]
        arm_front = [(21,13),(22,11),(23,9),(22,12),(21,14),(22,11),(23,9)][phase]
        arm_back = [(13,16),(14,13),(15,11),(14,15),(13,17),(14,14),(15,12)][phase]
        leg_front = [(19,28),(18,27),(18,25),(20,27),(19,28),(18,27),(18,25)][phase]
        leg_back = [(13,27),(14,25),(15,27),(13,28),(13,27),(14,25),(15,27)][phase]
    elif pose == "sleep":
        sleep = True

    if sleep:
        # Compact side-lying body at ground level.
        y = 24 + (phase % 2)
        rect(d, (7, y, 25, 29), P["outline0"])
        rect(d, (9, y+1, 22, 27), P["cloth_dark"])
        rect(d, (20, y-2, 25, y+3), P["hair_dark"])
        rect(d, (21, y-1, 24, y+2), P["skin"])
        rect(d, (10, y, 15, y+1), P["teal"])
        if phase in (1,2,3):
            rect(d, (25, y-5, 25, y-5), P["teal_light"])
            rect(d, (27, y-7, 28, y-7), P["teal_light"])
        return

    if dead:
        y = 25
        rect(d, (6, y, 27, 29), P["outline0"])
        rect(d, (8, y+1, 19, 27), P["cloth"])
        rect(d, (19, y-2, 26, y+3), P["hair_dark"])
        rect(d, (20, y-1, 24, y+1), P["skin"])
        rect(d, (10, y, 14, y+1), P["teal"])
        return

    # Root positions after authored pose offsets.
    hip = (16 + body_dx, 20 + body_dy + crouch + bob)
    torso_top = (15 + body_dx + lean, 11 + body_dy + crouch + bob)
    neck = (18 + body_dx + lean, 11 + body_dy + crouch + bob)
    head = (18 + body_dx + lean + head_dx, 7 + body_dy + crouch + bob + head_dy)

    # Scarf / teal identity accent behind body.
    scarf_pts = [(x + body_dx, y + crouch + bob) for x, y in scarf]
    poly(d, scarf_pts, P["outline0"])
    inner = [(x+1 if x < 13 else x, y) for x, y in scarf_pts]
    poly(d, inner, P["teal_dark"])
    if len(inner) >= 3:
        line(d, inner[:3], P["teal"], 1)

    # Back leg, torso, front leg.
    thick_pixel_line(d, hip, leg_back, P["outline0"], P["stone_dark"], 4)
    rect(d, (leg_back[0]-2, leg_back[1]-1, leg_back[0]+2, leg_back[1]+1), P["outline0"])
    rect(d, (leg_back[0]-1, leg_back[1]-1, leg_back[0]+1, leg_back[1]), P["brown"])

    torso_poly = [
        (torso_top[0]-4, torso_top[1]),
        (torso_top[0]+4, torso_top[1]),
        (hip[0]+4, hip[1]+1),
        (hip[0]-4, hip[1]+1),
    ]
    poly(d, torso_poly, P["outline0"])
    inner_torso = [(x, y+1) for x, y in torso_poly]
    poly(d, inner_torso, P["cloth_dark"])
    rect(d, (torso_top[0]-1, torso_top[1]+2, torso_top[0]+3, hip[1]-2), P["cloth"])
    rect(d, (torso_top[0]-2, torso_top[1]+5, torso_top[0]-1, hip[1]-2), P["teal_dark"])

    thick_pixel_line(d, hip, leg_front, P["outline0"], P["stone_mid"], 4)
    rect(d, (leg_front[0]-2, leg_front[1]-1, leg_front[0]+2, leg_front[1]+1), P["outline0"])
    rect(d, (leg_front[0]-1, leg_front[1]-1, leg_front[0]+1, leg_front[1]), P["brown_light"])

    # Arms; front arm must remain weapon-free but reaches common grip region.
    shoulder_front = (torso_top[0]+3, torso_top[1]+3)
    shoulder_back = (torso_top[0]-2, torso_top[1]+4)
    thick_pixel_line(d, shoulder_back, (arm_back[0]+body_dx, arm_back[1]+crouch+bob), P["outline0"], P["stone_mid"], 3)
    thick_pixel_line(d, shoulder_front, (arm_front[0]+body_dx, arm_front[1]+crouch+bob), P["outline0"], P["skin_shadow"], 3)
    rect(d, (arm_front[0]+body_dx-1, arm_front[1]+crouch+bob-1, arm_front[0]+body_dx+1, arm_front[1]+crouch+bob+1), P["outline0"])
    rect(d, (arm_front[0]+body_dx, arm_front[1]+crouch+bob, arm_front[0]+body_dx+1, arm_front[1]+crouch+bob), P["skin"])

    # Head/face/hair.
    hx, hy = head
    rect(d, (hx-5, hy-5, hx+4, hy+4), P["outline0"])
    rect(d, (hx-3, hy-3, hx+4, hy+3), P["skin_shadow"])
    rect(d, (hx-2, hy-3, hx+4, hy+2), P["skin"])
    rect(d, (hx-5, hy-5, hx+3, hy-2), P["hair_dark"])
    rect(d, (hx-4, hy-4, hx+1, hy-1), P["hair"])
    rect(d, (hx-5, hy-2, hx-3, hy+1), P["hair_dark"])
    rect(d, (hx+4, hy, hx+4, hy), P["highlight"])
    rect(d, (hx+2, hy+1, hx+2, hy+1), P["outline0"])

    # Belt/coat detail.
    rect(d, (hip[0]-4, hip[1]-2, hip[0]+4, hip[1]-1), P["brown_dark"])
    rect(d, (hip[0]+1, hip[1]-2, hip[0]+1, hip[1]-1), P["gold_dark"])

    if show_potion:
        px, py = arm_front[0] + body_dx + 1, arm_front[1] + crouch + bob - 2
        rect(d, (px-1, py-1, px+2, py+2), P["outline0"])
        rect(d, (px, py, px+1, py+1), P["green"])
        rect(d, (px, py-2, px+1, py-1), P["paper"])

    # Small presentation-only VFX on action frames.
    if pose == "parry" and phase == 2:
        cx, cy = 27, 16 + crouch
        rect(d, (cx, cy-2, cx, cy+2), P["teal_light"])
        rect(d, (cx-2, cy, cx+2, cy), P["teal_light"])
        rect(d, (cx, cy, cx, cy), P["white"])
    if pose == "cast" and phase in (3,4,5):
        cx, cy = 27, 14 + crouch
        r = 1 + (phase - 3)
        rect(d, (cx-r, cy-r, cx+r, cy+r), P["arcane"])
        rect(d, (cx, cy, cx, cy), P["white"])
    if pose == "hit" and phase == 1:
        rect(d, (24, 10 + crouch, 26, 12 + crouch), P["danger"])


def save_animation(name: str, frames: int) -> list[Path]:
    out_dir = ART / "player" / "animations"
    frame_dir = out_dir / "frames" / name
    frame_dir.mkdir(parents=True, exist_ok=True)
    sheet = image(32 * frames, 32)
    outputs: list[Path] = []
    for i in range(frames):
        f = image(32, 32)
        draw_player(f, name, i, frames)
        sheet.alpha_composite(f, (i * 32, 0))
        fp = frame_dir / f"frame_{i:02d}.png"
        f.save(fp, optimize=True)
        outputs.append(fp)
    sp = out_dir / f"player_body_{name}_sheet_v01.png"
    sheet.save(sp, optimize=True)
    outputs.append(sp)
    return outputs


def draw_sword() -> Image.Image:
    im = image(32, 32); d = ImageDraw.Draw(im)
    # Right-pointing one-handed sword aligned around center grip.
    poly(d, [(7,17),(9,15),(24,8),(27,9),(11,18)], P["outline0"])
    poly(d, [(10,15),(24,9),(25,9),(10,17)], P["stone_light"])
    line(d, [(11,15),(24,10)], P["highlight"], 1)
    rect(d, (8,14,10,19), P["gold_dark"])
    rect(d, (5,16,8,18), P["outline0"])
    rect(d, (5,17,8,17), P["cloth"])
    return im


def draw_shield() -> Image.Image:
    im = image(32, 32); d = ImageDraw.Draw(im)
    poly(d, [(8,6),(23,6),(26,10),(24,22),(16,28),(8,22),(6,10)], P["outline0"])
    poly(d, [(9,8),(22,8),(24,11),(22,21),(16,25),(10,21),(8,11)], P["cloth_dark"])
    poly(d, [(12,10),(20,10),(21,19),(16,23),(11,19)], P["cloth"])
    rect(d, (15,11,16,21), P["gold"])
    rect(d, (12,15,20,16), P["gold"])
    return im


def draw_bow() -> Image.Image:
    im = image(32, 32); d = ImageDraw.Draw(im)
    pts = [(20,4),(23,7),(24,12),(24,20),(22,26),(19,29)]
    line(d, pts, P["outline0"], 3)
    line(d, pts, P["brown_light"], 1)
    line(d, [(20,4),(19,29)], P["paper"], 1)
    rect(d, (21,15,23,18), P["cloth"])
    return im


def draw_staff() -> Image.Image:
    im = image(48, 48); d = ImageDraw.Draw(im)
    line(d, [(18,42),(28,10)], P["outline0"], 5)
    line(d, [(18,42),(28,10)], P["brown_light"], 3)
    rect(d, (25,7,31,13), P["outline0"])
    rect(d, (26,8,30,12), P["arcane"])
    rect(d, (28,8,29,9), P["white"])
    rect(d, (22,10,24,12), P["gold_dark"])
    rect(d, (32,10,34,12), P["gold_dark"])
    return im


def draw_arrow() -> Image.Image:
    im = image(32, 16); d = ImageDraw.Draw(im)
    line(d, [(4,8),(26,8)], P["brown_light"], 2)
    poly(d, [(26,5),(31,8),(26,11)], P["stone_light"])
    poly(d, [(4,8),(1,5),(6,7)], P["paper"])
    poly(d, [(4,8),(1,11),(6,9)], P["paper"])
    return im


def draw_arcane_projectile() -> Image.Image:
    im = image(32, 32); d = ImageDraw.Draw(im)
    for r, c in [(8,P["arcane"]),(5,P["arcane_light"]),(2,P["white"])]:
        d.ellipse((16-r,16-r,16+r,16+r), fill=c)
    for x,y in [(5,14),(8,18),(11,12),(4,20)]:
        rect(d,(x,y,x+2,y+1),P["arcane"])
    return im


def save_weapons_and_vfx() -> list[Path]:
    outs=[]
    weapon_defs = {
        "starter_sword_v01.png": draw_sword(),
        "starter_shield_v01.png": draw_shield(),
        "starter_bow_v01.png": draw_bow(),
        "starter_staff_v01.png": draw_staff(),
        "arrow_projectile_v01.png": draw_arrow(),
        "arcane_projectile_v01.png": draw_arcane_projectile(),
    }
    for name, im in weapon_defs.items():
        p = ART / "player" / "weapons" / name
        im.save(p,optimize=True); outs.append(p)

    # VFX primitives.
    def slash(heavy=False):
        im=image(64,64); d=ImageDraw.Draw(im)
        w=5 if heavy else 3
        c=P["teal_light"] if not heavy else P["arcane_light"]
        for i in range(w):
            arc=[(14+i,48),(24+i,32),(37+i,20),(50+i,15)]
            line(d,arc,c,1)
        return im
    def spark(color):
        im=image(32,32); d=ImageDraw.Draw(im); cx=16; cy=16
        for dx,dy in [(0,-10),(0,10),(-10,0),(10,0),(-7,-7),(7,-7),(-7,7),(7,7)]:
            line(d,[(cx,cy),(cx+dx,cy+dy)],color,2)
        rect(d,(14,14,18,18),P["white"]); return im
    vfx = {
        "light_slash_trail_v01.png": slash(False),
        "heavy_slash_trail_v01.png": slash(True),
        "block_spark_v01.png": spark(P["gold"]),
        "parry_spark_v01.png": spark(P["teal_light"]),
        "ranged_release_flash_v01.png": spark(P["paper"]),
        "arcane_cast_burst_v01.png": spark(P["arcane_light"]),
    }
    for name, im in vfx.items():
        p=ART/"player"/"vfx"/name; im.save(p,optimize=True); outs.append(p)
    return outs


def save_telegraphs() -> list[Path]:
    out=[]; base=ART/"vfx"/"telegraphs"
    def save(name,im):
        p=base/name; im.save(p,optimize=True); out.append(p)
    # Semi-transparent red is deliberate for gameplay telegraphs.
    red=(216,91,82,120); edge=(241,233,216,235)
    im=image(32,96); d=ImageDraw.Draw(im); rect(d,(12,0,20,95),red); line(d,[(12,0),(12,95),(20,95),(20,0)],edge,1); save("telegraph_narrow_line_v01.png",im)
    im=image(64,96); d=ImageDraw.Draw(im); rect(d,(10,0,54,95),red); line(d,[(10,0),(10,95),(54,95),(54,0)],edge,1); save("telegraph_wide_line_v01.png",im)
    im=image(96,96); d=ImageDraw.Draw(im); poly(d,[(48,92),(8,12),(88,12)],red); line(d,[(48,92),(8,12),(88,12),(48,92)],edge,1); save("telegraph_cone_v01.png",im)
    im=image(64,64); d=ImageDraw.Draw(im); d.pieslice((6,6,58,58),200,340,fill=red,outline=edge,width=2); save("telegraph_short_arc_v01.png",im)
    im=image(96,96); d=ImageDraw.Draw(im); d.pieslice((4,4,92,92),190,350,fill=red,outline=edge,width=2); save("telegraph_wide_sweep_v01.png",im)
    im=image(96,96); d=ImageDraw.Draw(im); d.ellipse((8,8,88,88),fill=red,outline=edge,width=2); save("telegraph_circle_v01.png",im)
    im=image(96,96); d=ImageDraw.Draw(im); d.ellipse((8,8,88,88),fill=(216,91,82,90),outline=edge,width=2); d.ellipse((28,28,68,68),outline=edge,width=2); save("telegraph_delayed_circle_v01.png",im)
    im=image(64,96); d=ImageDraw.Draw(im); rect(d,(12,0,52,95),(216,91,82,85)); line(d,[(12,0),(12,95),(52,95),(52,0)],edge,1); [poly(d,[(32,y+8),(25,y),(39,y)],edge) for y in range(10,82,18)]; save("telegraph_projectile_lane_v01.png",im)
    im=image(96,32); d=ImageDraw.Draw(im); rect(d,(0,10,95,22),(216,91,82,65)); [poly(d,[(x+8,16),(x,11),(x,21)],edge) for x in range(8,80,18)]; save("telegraph_lunge_path_v01.png",im)
    return out


def draw_enemy(archetype: str, pose: str, phase: int, count: int, size=48) -> Image.Image:
    im=image(size,size); d=ImageDraw.Draw(im)
    ground=43
    if archetype=="duelist":
        body=P["stone_dark"]; accent=P["danger_dark"]; metal=P["stone_light"]; weapon="sword"; scale=0
    elif archetype=="bruiser":
        body=P["brown"]; accent=P["danger_dark"]; metal=P["stone_mid"]; weapon="club"; scale=3
    elif archetype=="defender":
        body=P["stone_mid"]; accent=P["danger_dark"]; metal=P["stone_light"]; weapon="shield"; scale=2
    else:
        body=P["cloth_dark"]; accent=P["danger_dark"]; metal=P["stone_light"]; weapon="bow"; scale=0

    x=23; y=29
    crouch=0; lean=0
    if pose=="move": x += [0,2,3,1,0,-1][phase%6]
    if pose=="windup": crouch=1; lean=-1
    if pose=="release": crouch=2; lean=2
    if pose=="hit": x-=2; lean=-2
    if pose=="death":
        rect(d,(8,36,39,43),P["outline0"]); rect(d,(11,37,31,41),body); rect(d,(30,33,39,40),P["outline0"]); rect(d,(32,34,38,39),accent); return im

    # legs
    thick_pixel_line(d,(x-3,y+4),(x-7,ground),P["outline0"],P["shadow"],4)
    thick_pixel_line(d,(x+3,y+4),(x+8,ground),P["outline0"],P["stone_dark"],4)
    rect(d,(x-9,ground-1,x-3,ground+1),P["outline0"]); rect(d,(x+4,ground-1,x+11,ground+1),P["outline0"])

    # torso size by archetype.
    tw=7+scale; th=12+scale
    poly(d,[(x-tw,y-th),(x+tw,y-th),(x+tw-1,y+4),(x-tw+1,y+4)],P["outline0"])
    poly(d,[(x-tw+2,y-th+2),(x+tw-2,y-th+2),(x+tw-3,y+2),(x-tw+3,y+2)],body)
    rect(d,(x-2,y-th+2,x+2,y+2),accent)

    # head
    hr=5+max(0,scale//2); hy=y-th-5
    rect(d,(x-hr,hy-hr,x+hr,hy+hr),P["outline0"])
    rect(d,(x-hr+2,hy-hr+2,x+hr-1,hy+hr-1),P["paper"] if archetype in ("duelist","defender") else P["skin_shadow"])
    rect(d,(x+hr-2,hy,x+hr-1,hy+1),P["danger"] if archetype!="marksman" else P["highlight"])

    # signature role elements.
    if weapon=="sword":
        # red scarf makes the agile silhouette unmistakable.
        poly(d,[(x-4,hy+4),(x-12,hy+2),(x-16,hy+4),(x-10,hy+6)],P["danger_dark"])
        a=(x+4,y-th+5); b=(x+18+phase*2 if pose=="release" else x+14,y-th+7)
        thick_pixel_line(d,a,b,P["outline0"],metal,3)
    elif weapon=="club":
        a=(x+5,y-th+4); b=(x+14,y-th-4 if pose=="windup" else y+4)
        thick_pixel_line(d,a,b,P["outline0"],P["brown_dark"],5)
        rect(d,(b[0]-3,b[1]-4,b[0]+4,b[1]+4),P["outline0"]); rect(d,(b[0]-2,b[1]-3,b[0]+3,b[1]+3),metal)
        for sx,sy in [(b[0]+4,b[1]),(b[0],b[1]-5),(b[0]-4,b[1]+2)]: rect(d,(sx,sy,sx,sy),P["paper"])
    elif weapon=="shield":
        sx=x+9; sy=y-th+5
        poly(d,[(sx,sy-8),(sx+8,sy-6),(sx+8,sy+9),(sx+2,sy+13),(sx-3,sy+8),(sx-3,sy-6)],P["outline0"])
        poly(d,[(sx+1,sy-6),(sx+6,sy-4),(sx+6,sy+7),(sx+2,sy+10),(sx-1,sy+6),(sx-1,sy-4)],P["paper"])
        rect(d,(sx+2,sy-2,sx+3,sy+6),P["danger_dark"])
    elif weapon=="bow":
        # hood/quiver identity.
        poly(d,[(x-6,hy-5),(x+5,hy-5),(x+7,hy+1),(x+2,hy+5),(x-5,hy+4)],P["danger_dark"])
        bx=x+12; by=y-th+5
        line(d,[(bx,by-10),(bx+3,by),(bx,by+10)],P["outline0"],3); line(d,[(bx,by-10),(bx,by+10)],P["paper"],1)
        if pose=="release":
            line(d,[(bx+3,by),(bx+16,by)],P["paper"],1); poly(d,[(bx+16,by-2),(bx+20,by),(bx+16,by+2)],metal)
    if pose=="hit":
        rect(d,(x+12,hy-3,x+15,hy),P["danger"])
    return im


def save_enemy_set(archetype: str) -> list[Path]:
    poses=["idle","move","windup","release","hit","death"]
    base=ART/"enemies"/archetype
    sheet=image(48*len(poses),48)
    outs=[]
    for i,pname in enumerate(poses):
        f=draw_enemy(archetype,pname,i,len(poses))
        fp=base/f"enemy_{archetype}_{pname}_v01.png"; f.save(fp,optimize=True); outs.append(fp)
        sheet.alpha_composite(f,(i*48,0))
    sp=base/f"enemy_{archetype}_core_sheet_v01.png"; sheet.save(sp,optimize=True); outs.append(sp)
    return outs


def draw_building(kind: str, seed: int, decorative=False) -> Image.Image:
    im=image(96,96); d=ImageDraw.Draw(im)
    # deterministic small variations from seed, no random module required.
    roof_h=18 + (seed%3)*2; body_top=36 + (seed%2)*2
    outline=P["outline0"]; wall=P["paper"] if not decorative else P["stone_light"]
    roof=P["cloth_dark"] if seed%2==0 else P["danger_dark"]
    trim=P["brown_dark"]
    # ground shadow
    d.ellipse((12,77,84,88),fill=(22,21,31,80))
    # house body and roof
    rect(d,(19,body_top,77,78),outline); rect(d,(21,body_top+2,75,76),wall)
    poly(d,[(14,body_top+2),(30,body_top-roof_h),(65,body_top-roof_h),(82,body_top+2)],outline)
    poly(d,[(18,body_top),(31,body_top-roof_h+3),(64,body_top-roof_h+3),(78,body_top)],roof)
    # door/windows
    rect(d,(42,57,54,78),outline); rect(d,(44,59,52,76),trim)
    for wx in (27,62):
        rect(d,(wx,49,wx+9,59),outline); rect(d,(wx+2,51,wx+7,57),P["cloth_light"])
    # role-specific silhouette/signature.
    if kind=="central_tower":
        im=image(96,96); d=ImageDraw.Draw(im); d.ellipse((18,80,78,89),fill=(22,21,31,80));
        rect(d,(32,18,64,80),outline); rect(d,(35,21,61,78),P["stone_mid"]); poly(d,[(28,20),(48,4),(68,20)],outline); poly(d,[(33,19),(48,8),(63,19)],roof); rect(d,(43,60,53,80),P["outline0"]); rect(d,(45,62,51,78),P["brown_dark"]); rect(d,(43,28,53,40),P["outline0"]); rect(d,(45,30,51,38),P["arcane"])
    elif kind=="quest_hall":
        poly(d,[(46,38),(50,38),(52,48),(44,48)],P["gold"])
    elif kind=="blacksmith":
        rect(d,(69,31,74,63),outline); rect(d,(70,32,73,62),P["stone_dark"]); rect(d,(72,27,76,34),P["danger"])
    elif kind=="merchant":
        rect(d,(16,69,80,76),P["outline0"]); rect(d,(18,70,78,74),P["gold_dark"])
    elif kind=="inn":
        rect(d,(44,42,53,48),P["outline0"]); rect(d,(46,43,51,46),P["gold"])
    elif kind=="storage":
        rect(d,(24,63,34,74),P["brown"]); line(d,[(24,63),(34,74)],P["outline0"]); line(d,[(34,63),(24,74)],P["outline0"])
    elif kind=="training":
        line(d,[(17,67),(27,57)],P["brown"],3); line(d,[(27,67),(17,57)],P["brown"],3)
    elif kind=="clinic":
        rect(d,(46,40,50,54),P["danger"]); rect(d,(41,45,55,49),P["danger"])
    return im


def save_region3() -> list[Path]:
    outs=[]; base=ART/"environments"/"region3"
    functional=["central_tower","quest_hall","blacksmith","merchant","inn","storage","training","clinic"]
    for i,k in enumerate(functional):
        p=base/"functional_buildings"/f"region3_{k}_exterior_v01.png"; draw_building(k,i).save(p,optimize=True); outs.append(p)
    for i in range(12):
        p=base/"decorative_buildings"/f"region3_decorative_building_{i+1:02d}_v01.png"; draw_building("decorative",i,True).save(p,optimize=True); outs.append(p)
    # compact prop sheet
    im=image(128,64); d=ImageDraw.Draw(im)
    # crate, barrel, sign, lantern, bench, shrub, fence, training dummy
    rect(d,(4,35,18,49),P["outline0"]); rect(d,(6,37,16,47),P["brown"]); line(d,[(6,37),(16,47)],P["brown_light"]); line(d,[(16,37),(6,47)],P["brown_light"])
    d.ellipse((24,34,38,49),fill=P["outline0"]); rect(d,(26,36,36,47),P["brown_dark"]); line(d,[(25,40),(37,40)],P["gold_dark"])
    line(d,[(46,30),(46,50)],P["brown_dark"],3); rect(d,(42,31,57,39),P["outline0"]); rect(d,(44,33,55,37),P["paper"])
    rect(d,(64,28,69,44),P["outline0"]); rect(d,(65,30,68,37),P["gold"])
    rect(d,(74,43,94,47),P["brown_dark"]); line(d,[(77,47),(75,53)],P["brown_dark"],3); line(d,[(91,47),(93,53)],P["brown_dark"],3)
    for cx,cy in [(104,43),(110,39),(116,44)]: d.ellipse((cx-5,cy-5,cx+5,cy+5),fill=P["green"])
    pp=base/"props"/"region3_prop_sheet_v01.png"; im.save(pp,optimize=True); outs.append(pp)
    return outs


def draw_skill_icon(skill_id: str, cls: str, index: int) -> Image.Image:
    im=image(32,32); d=ImageDraw.Draw(im)
    bg=P["danger_dark"] if cls=="melee" else P["teal_dark"] if cls=="ranged" else P["arcane"]
    rect(d,(2,2,29,29),P["outline0"]); rect(d,(4,4,27,27),bg)
    # geometric glyphs intentionally readable at 32px.
    if cls=="melee":
        if index<3:
            line(d,[(8,23),(23,8)],P["highlight"],3); poly(d,[(22,6),(27,7),(24,11)],P["highlight"])
            if index==0: d.arc((4,4,28,28),210,330,fill=P["gold"],width=2)
            if index==1: line(d,[(7,16),(25,16)],P["gold"],2)
            if index==2: rect(d,(6,6,11,11),P["teal_light"])
        else:
            d.ellipse((8,8,24,24),outline=P["gold"],width=2); rect(d,(14,6,17,26),P["highlight"])
    elif cls=="ranged":
        if index<3:
            d.arc((6,4,24,28),270,90,fill=P["highlight"],width=2); line(d,[(14,16),(27,16)],P["gold"],2); poly(d,[(27,13),(31,16),(27,19)],P["gold"])
            if index==1:
                line(d,[(14,16),(26,10)],P["gold"],1); line(d,[(14,16),(26,22)],P["gold"],1)
            if index==2: line(d,[(9,24),(5,27)],P["teal_light"],2)
        else:
            for r in (4,8): d.ellipse((16-r,16-r,16+r,16+r),outline=P["paper"],width=1)
            line(d,[(16,5),(16,27)],P["gold"],1); line(d,[(5,16),(27,16)],P["gold"],1)
    else:
        if index<3:
            d.ellipse((9,9,23,23),fill=P["arcane_light"]); rect(d,(14,6,17,26),P["white"]); rect(d,(6,14,26,17),P["white"])
            if index==1: d.ellipse((5,5,27,27),outline=P["danger"],width=2)
            if index==2: poly(d,[(16,5),(26,10),(24,23),(16,28),(8,23),(6,10)],P["paper"]); poly(d,[(16,8),(23,12),(21,21),(16,25),(11,21),(9,12)],P["arcane"])
        else:
            for off in (-5,0,5): d.arc((7+off//2,7,25+off//2,25),200,340,fill=P["arcane_light"],width=2)
    return im


def save_ui() -> list[Path]:
    outs=[]
    skills={
        "melee":["arc_cleave","driving_thrust","riposte","efficient_footwork","breaker","parry_recovery"],
        "ranged":["piercing_shot","fan_shot","backstep_shot","longshot","fleet_recovery","expose"],
        "mage":["arcane_lance","delayed_pulse","aegis_ward","mana_weave","flow_recovery","stable_casting"],
    }
    for cls,names in skills.items():
        for i,name in enumerate(names):
            p=ART/"ui"/"skills"/f"skill_{name}_v01.png"; draw_skill_icon(name,cls,i).save(p,optimize=True); outs.append(p)
    # Tower Sigil
    im=image(32,32); d=ImageDraw.Draw(im); rect(d,(2,2,29,29),P["outline0"]); d.ellipse((5,5,27,27),outline=P["gold"],width=2); d.ellipse((10,10,22,22),outline=P["arcane_light"],width=2); poly(d,[(16,5),(20,14),(27,16),(20,18),(16,27),(12,18),(5,16),(12,14)],P["teal_light"]); rect(d,(15,11,17,21),P["white"])
    p=ART/"ui"/"markers"/"tower_sigil_icon_v01.png"; im.save(p,optimize=True); outs.append(p)
    # markers sheet
    im=image(128,32); d=ImageDraw.Draw(im)
    for i,c in enumerate([P["gold"],P["teal"],P["danger"],P["arcane"]]):
        ox=i*32; poly(d,[(ox+16,3),(ox+27,14),(ox+16,29),(ox+5,14)],P["outline0"]); poly(d,[(ox+16,6),(ox+24,14),(ox+16,25),(ox+8,14)],c)
    p=ART/"ui"/"markers"/"map_marker_sheet_v01.png"; im.save(p,optimize=True); outs.append(p)
    return outs


def save_tower_tiles() -> list[Path]:
    outs=[]; base=ART/"environments"/"tower"/"tiles"
    im=image(128,128); d=ImageDraw.Draw(im)
    # 4x4 32px tile atlas: floor, cracked floor, wall, pillar, gate, hazard, safe marker, reward marker.
    for ty in range(4):
        for tx in range(4):
            x=tx*32; y=ty*32
            rect(d,(x,y,x+31,y+31),P["outline0"])
            rect(d,(x+2,y+2,x+29,y+29),P["stone_dark"] if (tx+ty)%2==0 else P["stone_mid"])
            # seams
            line(d,[(x+2,y+16),(x+29,y+16)],P["shadow"],1); line(d,[(x+16,y+2),(x+16,y+29)],P["shadow"],1)
            if ty==1: line(d,[(x+4,y+7),(x+15,y+18),(x+10,y+28)],P["outline1"],1)
            if ty==2 and tx==0: rect(d,(x+12,y+4,x+19,y+27),P["stone_light"])
            if ty==2 and tx==1: rect(d,(x+7,y+4,x+24,y+27),P["brown_dark"]); [line(d,[(x+8+i*4,y+5),(x+8+i*4,y+26)],P["gold_dark"],1) for i in range(4)]
            if ty==3 and tx==0: poly(d,[(x+16,y+5),(x+27,y+25),(x+5,y+25)],P["danger"])
            if ty==3 and tx==1: d.ellipse((x+6,y+6,x+26,y+26),outline=P["teal_light"],width=2)
            if ty==3 and tx==2: poly(d,[(x+16,y+5),(x+25,y+16),(x+16,y+27),(x+7,y+16)],P["gold"])
    p=base/"tower_common_tileset_v01.png"; im.save(p,optimize=True); outs.append(p)
    return outs


def record_assets(paths: list[Path]) -> None:
    if MANIFEST.exists():
        data=json.loads(MANIFEST.read_text(encoding="utf-8"))
    else:
        data={"schema_version":1,"policy_note":"Project-local asset provenance evidence.","assets":[]}
    existing={a.get("project_path") for a in data.get("assets",[])}
    for path in paths:
        rel=path.relative_to(ROOT).as_posix()
        project_path=f"res://{rel}"
        if project_path in existing:
            continue
        im=Image.open(path)
        w,h=im.size
        data["assets"].append({
            "asset_name": path.stem.replace("_"," ").title(),
            "project_path": project_path,
            "source": "project-local procedural pixel authoring",
            "creator_source": "Nice Journey project / OpenAI ChatGPT-assisted local authoring",
            "license_category": "free_commercial_use",
            "license_text": "Original project-local procedural pixel asset created for this prototype with no third-party source artwork incorporated; release rights remain subject to normal project review.",
            "attribution_text": "",
            "modifications": "Deterministically authored by project-local Pillow pixel generator under docs/art/ART_INTEGRATION_RULES.md constraints.",
            "date_imported": "2026-09-14",
            "responsible_agent": "OpenAI ChatGPT",
            "kind": "pixel_art",
            "pixel_metadata": {
                "dimensions": f"{w}x{h} px",
                "palette_material_ramp": "Nice Journey master palette v01 with constrained role-specific extensions",
                "pivot_ground_anchor": "Player body frames use ground anchor (16,29) and right-facing grip reference (23,17) where applicable; other assets use visual center/role-specific anchor.",
                "frame_order_timing": "Deterministic authored frame order; timing remains owned by engine animation/runtime integration.",
                "transparent_bounds": "Transparent PNG; alpha bounds intentionally asset-specific.",
                "intended_render_layers": ["gameplay_art"]
            }
        })
        existing.add(project_path)
    MANIFEST.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")


def generate_all() -> None:
    ensure_dirs()
    outputs: list[Path] = []
    # Player production queue B-D.
    anims = {
        "idle":5,"walk":7,"run":7,"dash":5,"dodge":5,
        "attack":6,"heavy_attack":8,"block":3,"parry":5,"cast":8,"hit":4,"death":10,
        "interact":5,"pickup":5,"use_item":5,"climb":7,"sleep":5,
    }
    for name,count in anims.items(): outputs += save_animation(name,count)
    outputs += save_weapons_and_vfx()
    outputs += save_telegraphs()
    for archetype in ["duelist","bruiser","defender","marksman"]: outputs += save_enemy_set(archetype)
    outputs += save_region3()
    outputs += save_ui()
    outputs += save_tower_tiles()
    record_assets(outputs)
    print(f"generated {len(outputs)} local PNG assets")


if __name__ == "__main__":
    generate_all()
