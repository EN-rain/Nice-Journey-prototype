from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw
import sys

sys.path.append(str(Path(__file__).resolve().parent))
import generate_pixel_asset_batches as base

ROOT = base.ROOT
ART = base.ART
P = base.P


def ensure_dirs():
    for archetype in [
        "skirmisher", "assassin", "mobile_ranged", "caster", "support",
        "summoner", "flying_harrier", "controller_disruptor", "boss_tenth_warden"
    ]:
        (ART / "enemies" / archetype).mkdir(parents=True, exist_ok=True)
    for p in [
        ART / "environments" / "region3" / "roads",
        ART / "environments" / "region3" / "ruins",
        ART / "environments" / "region3" / "risk_zone",
        ART / "environments" / "region3" / "signs",
        ART / "environments" / "tower" / "rooms",
        ART / "environments" / "tower" / "boss_room",
        ART / "ui" / "quests",
        ART / "ui" / "status",
        ART / "ui" / "classes",
        ART / "ui" / "equipment",
    ]:
        p.mkdir(parents=True, exist_ok=True)


def enemy_palette(kind: str):
    data = {
        "skirmisher": (P["cloth"], P["teal"], P["paper"]),
        "assassin": (P["hair_dark"], P["danger_dark"], P["stone_light"]),
        "mobile_ranged": (P["cloth_dark"], P["gold_dark"], P["paper"]),
        "caster": (P["arcane"], P["cloth_dark"], P["arcane_light"]),
        "support": (P["paper"], P["teal_dark"], P["gold"]),
        "summoner": (P["shadow"], P["arcane"], P["danger"]),
        "flying_harrier": (P["stone_mid"], P["teal_dark"], P["paper"]),
        "controller_disruptor": (P["danger_dark"], P["arcane"], P["gold"]),
    }
    return data[kind]


def draw_role_enemy(kind: str, pose: str, phase: int) -> Image.Image:
    im = base.image(48, 48)
    d = ImageDraw.Draw(im)
    body, accent, bright = enemy_palette(kind)
    x, ground = 23, 43
    y = 29
    if pose == "move":
        x += [0, 2, 1, -1, -2, 0][phase % 6]
    if pose == "windup":
        y += 1
    if pose == "release":
        x += 2
    if pose == "hit":
        x -= 2
    if pose == "death":
        base.rect(d, (7, 36, 40, 44), P["outline0"])
        base.rect(d, (10, 37, 31, 41), body)
        base.rect(d, (30, 34, 39, 40), accent)
        return im

    # flying harrier is deliberately airborne.
    airborne = kind == "flying_harrier"
    if airborne:
        ground = 35
        y = 21
        # wings
        base.poly(d, [(x-4,y-8),(x-18,y-16),(x-14,y-3),(x-4,y+1)], P["outline0"])
        base.poly(d, [(x-5,y-7),(x-15,y-13),(x-12,y-4),(x-5,y-1)], accent)
        base.poly(d, [(x+4,y-8),(x+18,y-16),(x+14,y-3),(x+4,y+1)], P["outline0"])
        base.poly(d, [(x+5,y-7),(x+15,y-13),(x+12,y-4),(x+5,y-1)], accent)

    # legs/body
    if not airborne:
        base.thick_pixel_line(d, (x-2,y+4), (x-6,ground), P["outline0"], P["shadow"], 4)
        base.thick_pixel_line(d, (x+3,y+4), (x+7,ground), P["outline0"], P["stone_dark"], 4)
        base.rect(d, (x-8,ground-1,x-2,ground+1), P["outline0"])
        base.rect(d, (x+4,ground-1,x+10,ground+1), P["outline0"])
    else:
        base.thick_pixel_line(d, (x-2,y+4), (x-6,ground), P["outline0"], P["shadow"], 3)
        base.thick_pixel_line(d, (x+3,y+4), (x+7,ground), P["outline0"], P["stone_dark"], 3)

    base.poly(d, [(x-7,y-10),(x+7,y-10),(x+6,y+5),(x-6,y+5)], P["outline0"])
    base.poly(d, [(x-5,y-8),(x+5,y-8),(x+4,y+3),(x-4,y+3)], body)
    base.rect(d, (x-2,y-7,x+2,y+3), accent)
    # head/hood
    base.rect(d, (x-5,y-18,x+5,y-8), P["outline0"])
    base.rect(d, (x-3,y-16,x+4,y-10), body if kind in ("assassin","summoner") else P["paper"])
    base.rect(d, (x+3,y-13,x+4,y-12), bright)

    if kind == "skirmisher":
        # short spear + backstep silhouette
        base.thick_pixel_line(d, (x+4,y-4), (x+18,y-8 if pose=="windup" else y-2), P["outline0"], bright, 3)
        base.poly(d, [(x+18,y-5),(x+22,y-2),(x+18,y+1)], bright)
    elif kind == "assassin":
        # twin daggers / low profile.
        base.thick_pixel_line(d, (x+3,y-3), (x+13,y-9), P["outline0"], bright, 2)
        base.thick_pixel_line(d, (x-2,y-2), (x+7,y+4), P["outline0"], bright, 2)
        if pose == "release":
            base.line(d, [(x+9,y-10),(x+18,y-13)], P["danger"], 1)
    elif kind == "mobile_ranged":
        bx=x+12; by=y-5
        base.line(d, [(bx,by-9),(bx+3,by),(bx,by+9)], P["outline0"], 3)
        base.line(d, [(bx,by-9),(bx,by+9)], P["paper"], 1)
        if pose == "release":
            base.line(d, [(bx+3,by),(bx+17,by)], bright, 1)
    elif kind == "caster":
        # staff + orb
        base.thick_pixel_line(d, (x+4,y+2), (x+13,y-14), P["outline0"], P["brown_light"], 3)
        d.ellipse((x+9,y-18,x+17,y-10), fill=bright)
        if pose in ("windup","release"):
            d.ellipse((x+17,y-12,x+25,y-4), outline=P["white"], width=1)
    elif kind == "support":
        # banner/ward staff, soft gold aura on release
        base.thick_pixel_line(d, (x+5,y+2), (x+9,y-15), P["outline0"], P["brown_light"], 3)
        base.poly(d, [(x+9,y-15),(x+18,y-12),(x+9,y-7)], accent)
        if pose == "release": d.ellipse((x-12,y-22,x+18,y+9), outline=P["gold"], width=1)
    elif kind == "summoner":
        base.thick_pixel_line(d, (x+4,y+2), (x+12,y-14), P["outline0"], P["arcane_light"], 3)
        if pose in ("windup","release"):
            for ox,oy in [(-10,-8),(14,-6),(-4,-18)]:
                base.rect(d,(x+ox,y+oy,x+ox+2,y+oy+2),P["arcane_light"])
    elif kind == "flying_harrier":
        # talon / beak emphasis
        base.poly(d, [(x+5,y-12),(x+11,y-10),(x+5,y-8)], bright)
        if pose == "release":
            base.line(d, [(x+5,y+4),(x+15,y+10)], P["danger"], 2)
    elif kind == "controller_disruptor":
        # forked control focus / chain arc.
        base.thick_pixel_line(d, (x+4,y+2), (x+11,y-11), P["outline0"], P["gold_dark"], 3)
        base.line(d, [(x+11,y-11),(x+17,y-16)], bright, 2)
        base.line(d, [(x+11,y-11),(x+18,y-7)], bright, 2)
        if pose == "release":
            base.line(d, [(x+18,y-12),(x+26,y-16),(x+29,y-8)], P["arcane_light"], 1)

    if pose == "hit":
        base.rect(d, (x+10,y-16,x+13,y-13), P["danger"])
    return im


def save_remaining_enemies() -> list[Path]:
    outputs=[]
    poses=["idle","move","windup","release","hit","death"]
    for kind in ["skirmisher","assassin","mobile_ranged","caster","support","summoner","flying_harrier","controller_disruptor"]:
        target=ART/"enemies"/kind
        sheet=base.image(48*len(poses),48)
        for i,pose in enumerate(poses):
            frame=draw_role_enemy(kind,pose,i)
            fp=target/f"enemy_{kind}_{pose}_v01.png"
            frame.save(fp,optimize=True); outputs.append(fp)
            sheet.alpha_composite(frame,(i*48,0))
        sp=target/f"enemy_{kind}_core_sheet_v01.png"
        sheet.save(sp,optimize=True); outputs.append(sp)
    return outputs


def draw_warden(pose: str, phase: int) -> Image.Image:
    im=base.image(96,96); d=ImageDraw.Draw(im)
    x=48; ground=86; y=56
    if pose=="death":
        base.rect(d,(18,70,78,86),P["outline0"]); base.rect(d,(22,72,66,82),P["stone_dark"]); base.rect(d,(62,67,78,78),P["danger_dark"]); return im
    phase_two = pose in ("crescent_sweep","punishing_step","phase_two")
    armor=P["shadow"] if not phase_two else P["danger_dark"]
    glow=P["teal_light"] if not phase_two else P["arcane_light"]
    # cloak/back mass
    base.poly(d,[(x-18,y-24),(x+12,y-26),(x+20,y+10),(x-16,y+16)],P["outline0"])
    base.poly(d,[(x-15,y-21),(x+9,y-23),(x+16,y+8),(x-13,y+12)],armor)
    # legs
    base.thick_pixel_line(d,(x-8,y+8),(x-15,ground),P["outline0"],P["stone_mid"],6)
    base.thick_pixel_line(d,(x+8,y+8),(x+15,ground),P["outline0"],P["stone_light"],6)
    # torso
    base.poly(d,[(x-15,y-18),(x+15,y-18),(x+13,y+12),(x-13,y+12)],P["outline0"])
    base.poly(d,[(x-12,y-15),(x+12,y-15),(x+10,y+9),(x-10,y+9)],armor)
    base.rect(d,(x-3,y-14,x+3,y+7),glow)
    # helm
    base.poly(d,[(x-10,y-32),(x+10,y-32),(x+14,y-22),(x+7,y-15),(x-7,y-15),(x-14,y-22)],P["outline0"])
    base.poly(d,[(x-7,y-29),(x+7,y-29),(x+10,y-22),(x+5,y-18),(x-5,y-18),(x-10,y-22)],P["stone_mid"])
    base.rect(d,(x-7,y-23,x+7,y-21),glow)
    # twin swords
    left_end=(x-30,y+4); right_end=(x+30,y+4)
    if pose=="twin_cut": left_end=(x-33,y-16); right_end=(x+33,y+16)
    if pose=="warden_lunge": right_end=(x+40,y-6)
    if pose=="crescent_sweep": left_end=(x-38,y-4); right_end=(x+38,y-4)
    base.thick_pixel_line(d,(x-8,y-4),left_end,P["outline0"],P["highlight"],4)
    base.thick_pixel_line(d,(x+8,y-4),right_end,P["outline0"],P["highlight"],4)
    if pose=="arc_volley":
        for ox,oy in [(-26,-34),(-10,-42),(10,-42),(26,-34)]:
            d.ellipse((x+ox-4,y+oy-4,x+ox+4,y+oy+4),fill=P["arcane"])
            base.rect(d,(x+ox,y+oy,x+ox,y+oy),P["white"])
    if pose=="punishing_step":
        for r in (10,18,26): d.arc((x-r,ground-r,x+r,ground+r),200,340,fill=P["danger"],width=2)
    if pose=="hit": base.rect(d,(x+18,y-28,x+23,y-23),P["danger"])
    return im


def save_boss() -> list[Path]:
    poses=["idle","phase_two","twin_cut","warden_lunge","arc_volley","crescent_sweep","punishing_step","hit","death"]
    target=ART/"enemies"/"boss_tenth_warden"; outputs=[]
    sheet=base.image(96*len(poses),96)
    for i,pose in enumerate(poses):
        f=draw_warden(pose,i)
        fp=target/f"tenth_warden_{pose}_v01.png"; f.save(fp,optimize=True); outputs.append(fp)
        sheet.alpha_composite(f,(i*96,0))
    sp=target/"tenth_warden_core_sheet_v01.png"; sheet.save(sp,optimize=True); outputs.append(sp)
    return outputs


def save_region_modules() -> list[Path]:
    outputs=[]
    roads=ART/"environments"/"region3"/"roads"
    # 32px ground/road atlas with grass, road, plaza, dirt, stone, water edge, fence, risk ground.
    im=base.image(256,32); d=ImageDraw.Draw(im)
    tiles=[P["green"],P["brown"],P["stone_mid"],P["brown_light"],P["stone_dark"],P["cloth_dark"],P["paper"],P["danger_dark"]]
    for i,c in enumerate(tiles):
        x=i*32; base.rect(d,(x,0,x+31,31),c)
        base.line(d,[(x,15),(x+31,15)],P["shadow"],1)
        if i in (0,3):
            for px,py in [(5,7),(18,4),(25,22),(11,27)]: base.rect(d,(x+px,py,x+px,py),P["green_light"] if i==0 else P["gold_dark"])
        if i==1:
            base.line(d,[(x+4,7),(x+25,7)],P["brown_dark"],1); base.line(d,[(x+8,23),(x+28,23)],P["brown_dark"],1)
        if i==2:
            for sx in (0,16): base.line(d,[(x+sx,0),(x+sx,31)],P["shadow"],1)
        if i==6:
            for sx in (4,12,20,28): base.line(d,[(x+sx,2),(x+sx,29)],P["brown_dark"],2)
    p=roads/"region3_ground_road_tileset_v01.png"; im.save(p,optimize=True); outputs.append(p)

    ruins=ART/"environments"/"region3"/"ruins"
    im=base.image(128,96); d=ImageDraw.Draw(im)
    # broken wall, arch, column, rubble
    base.rect(d,(6,32,28,82),P["outline0"]); base.rect(d,(9,35,25,79),P["stone_mid"]); base.rect(d,(20,32,28,49),P["transparent"])
    base.rect(d,(38,25,70,82),P["outline0"]); d.ellipse((44,31,64,62),fill=P["transparent"],outline=P["stone_light"],width=4); base.rect(d,(42,54,66,82),P["transparent"])
    base.rect(d,(80,22,90,82),P["outline0"]); base.rect(d,(82,24,88,80),P["stone_light"])
    for bx,by in [(98,73),(106,67),(114,76),(121,71)]: base.rect(d,(bx,by,bx+7,by+5),P["stone_mid"])
    p=ruins/"region3_ruins_module_sheet_v01.png"; im.save(p,optimize=True); outputs.append(p)
    return outputs


def save_tower_rooms() -> list[Path]:
    outputs=[]; target=ART/"environments"/"tower"/"rooms"
    room_types=[("combat",P["danger_dark"]),("safe",P["teal_dark"]),("reward",P["gold_dark"]),("vendor",P["cloth_dark"]),("secret",P["arcane"]),("elite",P["danger"]),("objective",P["gold"]),("boss",P["arcane_light"])]
    for name,c in room_types:
        im=base.image(96,96); d=ImageDraw.Draw(im)
        base.rect(d,(5,5,90,90),P["outline0"]); base.rect(d,(9,9,86,86),P["stone_dark"])
        for x in range(16,88,16): base.line(d,[(x,10),(x,85)],P["shadow"],1)
        for y in range(16,88,16): base.line(d,[(10,y),(85,y)],P["shadow"],1)
        d.ellipse((30,30,66,66),outline=c,width=3)
        base.poly(d,[(48,24),(61,48),(48,72),(35,48)],c)
        p=target/f"tower_room_{name}_v01.png"; im.save(p,optimize=True); outputs.append(p)
    return outputs


def save_ui_phase2() -> list[Path]:
    outputs=[]
    # Class icons
    target=ART/"ui"/"classes"
    for cls,c in [("melee",P["danger_dark"]),("ranged",P["teal_dark"]),("mage",P["arcane"])]:
        im=base.image(32,32); d=ImageDraw.Draw(im); base.rect(d,(2,2,29,29),P["outline0"]); base.rect(d,(4,4,27,27),c)
        if cls=="melee":
            base.line(d,[(8,24),(23,8)],P["highlight"],3); base.line(d,[(11,20),(24,20)],P["gold"],2)
        elif cls=="ranged":
            d.arc((6,4,23,28),270,90,fill=P["highlight"],width=2); base.line(d,[(14,16),(27,16)],P["gold"],2)
        else:
            d.ellipse((9,7,23,21),fill=P["arcane_light"]); base.line(d,[(16,20),(16,27)],P["brown_light"],3)
        p=target/f"class_{cls}_icon_v01.png"; im.save(p,optimize=True); outputs.append(p)

    # Quest family icons.
    target=ART/"ui"/"quests"
    families=[("escort",P["teal"]),("tower_defense",P["gold"]),("annihilation",P["danger"])]
    for name,c in families:
        im=base.image(32,32); d=ImageDraw.Draw(im); base.rect(d,(2,2,29,29),P["outline0"]); base.rect(d,(4,4,27,27),P["shadow"])
        if name=="escort":
            d.ellipse((8,8,15,15),fill=c); d.ellipse((18,17,25,24),fill=c); base.line(d,[(13,16),(20,17)],P["paper"],1)
        elif name=="tower_defense":
            base.poly(d,[(16,5),(26,10),(24,24),(16,28),(8,24),(6,10)],c); base.rect(d,(15,10,17,23),P["paper"])
        else:
            base.line(d,[(8,8),(24,24)],c,3); base.line(d,[(24,8),(8,24)],c,3)
        p=target/f"quest_family_{name}_v01.png"; im.save(p,optimize=True); outputs.append(p)

    # Status icons.
    target=ART/"ui"/"status"
    im=base.image(32,32); d=ImageDraw.Draw(im); base.rect(d,(2,2,29,29),P["outline0"]); base.poly(d,[(16,4),(23,14),(20,26),(12,28),(8,19),(12,10)],P["danger"]); base.poly(d,[(16,10),(20,17),(17,24),(13,21),(12,16)],P["gold"]); p=target/"status_burn_v01.png"; im.save(p,optimize=True); outputs.append(p)
    im=base.image(32,32); d=ImageDraw.Draw(im); base.rect(d,(2,2,29,29),P["outline0"]); d.ellipse((6,6,26,26),outline=P["teal_light"],width=2); base.line(d,[(16,8),(16,17),(22,20)],P["teal_light"],2); base.line(d,[(6,25),(26,7)],P["paper"],1); p=target/"status_slow_v01.png"; im.save(p,optimize=True); outputs.append(p)
    return outputs


def main():
    ensure_dirs()
    outputs=[]
    outputs += save_remaining_enemies()
    outputs += save_boss()
    outputs += save_region_modules()
    outputs += save_tower_rooms()
    outputs += save_ui_phase2()
    base.record_assets(outputs)
    print(f"generated {len(outputs)} phase-2 local PNG assets")


if __name__ == "__main__":
    main()
