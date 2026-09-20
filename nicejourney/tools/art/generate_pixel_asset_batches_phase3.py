from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw
import sys

sys.path.append(str(Path(__file__).resolve().parent))
import generate_pixel_asset_batches as base

ART = base.ART
P = base.P


def ensure_dirs() -> None:
    for path in [
        ART / "environments" / "region3" / "interiors",
        ART / "environments" / "tower" / "hazards",
        ART / "environments" / "tower" / "boss_room",
        ART / "items" / "equipment",
        ART / "items" / "consumables",
        ART / "items" / "materials",
        ART / "ui" / "hud",
        ART / "ui" / "inventory",
        ART / "ui" / "services",
        ART / "ui" / "objectives",
    ]:
        path.mkdir(parents=True, exist_ok=True)


def save_icon(path: Path, glyph: str, color, secondary=None) -> Path:
    im = base.image(32, 32)
    d = ImageDraw.Draw(im)
    base.rect(d, (2, 2, 29, 29), P["outline0"])
    base.rect(d, (4, 4, 27, 27), P["shadow"])
    secondary = secondary or P["highlight"]
    if glyph == "heart":
        d.ellipse((7, 8, 16, 17), fill=color)
        d.ellipse((15, 8, 24, 17), fill=color)
        base.poly(d, [(7, 13), (24, 13), (16, 26)], color)
    elif glyph == "bolt":
        base.poly(d, [(18, 5), (10, 17), (15, 17), (12, 27), (23, 13), (18, 13)], color)
    elif glyph == "orb":
        d.ellipse((8, 8, 24, 24), fill=color)
        d.ellipse((12, 10, 18, 16), fill=secondary)
    elif glyph == "shield":
        base.poly(d, [(16, 5), (25, 9), (23, 23), (16, 28), (9, 23), (7, 9)], color)
        base.line(d, [(16, 8), (16, 24)], secondary, 2)
    elif glyph == "sword":
        base.line(d, [(8, 24), (23, 7)], secondary, 3)
        base.poly(d, [(22, 5), (27, 6), (24, 11)], secondary)
        base.line(d, [(9, 20), (15, 26)], color, 2)
    elif glyph == "armor":
        base.poly(d, [(9, 7), (14, 5), (16, 9), (18, 5), (23, 7), (26, 16), (22, 27), (10, 27), (6, 16)], color)
        base.rect(d, (14, 10, 18, 24), secondary)
    elif glyph == "ring":
        d.ellipse((8, 8, 24, 24), outline=color, width=4)
        base.poly(d, [(16, 5), (20, 9), (16, 12), (12, 9)], secondary)
    elif glyph == "flask":
        base.rect(d, (13, 5, 19, 10), secondary)
        base.poly(d, [(12, 10), (20, 10), (25, 24), (22, 28), (10, 28), (7, 24)], P["outline0"])
        base.poly(d, [(12, 13), (20, 13), (22, 23), (20, 25), (12, 25), (10, 23)], color)
    elif glyph == "material":
        base.poly(d, [(16, 5), (25, 12), (22, 25), (10, 27), (6, 15)], color)
        base.line(d, [(11, 12), (19, 21)], secondary, 2)
        base.line(d, [(20, 10), (12, 22)], secondary, 1)
    elif glyph == "coin":
        d.ellipse((7, 7, 25, 25), fill=P["gold_dark"], outline=P["outline0"], width=2)
        d.ellipse((10, 9, 22, 22), outline=P["gold"], width=2)
        base.rect(d, (15, 11, 17, 21), secondary)
    elif glyph == "interact":
        d.ellipse((8, 6, 24, 22), outline=color, width=2)
        base.rect(d, (14, 10, 17, 16), color)
        base.rect(d, (14, 19, 17, 22), color)
    elif glyph == "checkpoint":
        base.line(d, [(16, 5), (16, 27)], secondary, 2)
        base.poly(d, [(16, 6), (26, 10), (16, 15)], color)
        d.ellipse((10, 24, 22, 28), fill=color)
    elif glyph == "target":
        for r in (10, 6, 2):
            d.ellipse((16-r, 16-r, 16+r, 16+r), outline=color if r != 2 else secondary, width=2)
    elif glyph == "person":
        d.ellipse((12, 6, 20, 14), fill=color)
        base.poly(d, [(9, 25), (12, 15), (20, 15), (23, 25)], color)
    elif glyph == "tower":
        base.rect(d, (10, 8, 22, 27), color)
        base.poly(d, [(8, 9), (16, 3), (24, 9)], secondary)
        base.rect(d, (14, 18, 18, 27), P["outline0"])
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    return path


def draw_interior(role: str, index: int) -> Image.Image:
    im = base.image(128, 96)
    d = ImageDraw.Draw(im)
    # dark wall / wood-stone floor
    base.rect(d, (0, 0, 127, 95), P["outline0"])
    base.rect(d, (4, 4, 123, 91), P["stone_dark"])
    base.rect(d, (8, 26, 119, 87), P["brown_dark"] if index % 2 else P["stone_mid"])
    for x in range(8, 120, 16):
        base.line(d, [(x, 27), (x, 86)], P["shadow"], 1)
    for y in range(28, 88, 12):
        base.line(d, [(9, y), (118, y)], P["shadow"], 1)
    # back wall service counter / fixture
    base.rect(d, (28, 15, 100, 31), P["outline0"])
    base.rect(d, (31, 17, 97, 29), P["paper"])
    # role symbols/props
    if role == "quest_hall":
        base.rect(d, (58, 8, 70, 27), P["danger_dark"])
        base.poly(d, [(64, 10), (68, 16), (64, 22), (60, 16)], P["gold"])
        for px in (22, 106): base.rect(d, (px, 50, px+10, 64), P["brown"])
    elif role == "blacksmith":
        base.rect(d, (18, 48, 42, 67), P["stone_dark"])
        base.poly(d, [(20, 48), (40, 48), (34, 42), (26, 42)], P["stone_light"])
        base.rect(d, (88, 42, 104, 66), P["outline0"])
        base.rect(d, (91, 45, 101, 63), P["danger"])
    elif role == "merchant":
        for px in (20, 44, 84): base.rect(d, (px, 51, px+18, 65), P["brown"])
        base.line(d, [(18, 49), (106, 49)], P["gold_dark"], 2)
    elif role == "inn":
        for px in (20, 78):
            base.rect(d, (px, 50, px+30, 70), P["outline0"])
            base.rect(d, (px+2, 52, px+28, 68), P["cloth_dark"])
            base.rect(d, (px+3, 53, px+12, 57), P["paper"])
    elif role == "storage":
        for px,py in [(18,48),(35,56),(82,48),(99,57)]:
            base.rect(d, (px, py, px+14, py+14), P["brown"])
            base.line(d, [(px,py),(px+14,py+14)], P["brown_light"], 1)
            base.line(d, [(px+14,py),(px,py+14)], P["brown_light"], 1)
    elif role == "training":
        for px in (28,64,96):
            base.line(d, [(px, 44), (px, 70)], P["brown_light"], 3)
            base.line(d, [(px-7, 50), (px+7, 50)], P["brown_light"], 3)
            base.rect(d, (px-5, 42, px+5, 50), P["paper"])
    elif role == "clinic":
        base.rect(d, (58, 7, 70, 27), P["paper"])
        base.rect(d, (62, 10, 66, 24), P["danger"])
        base.rect(d, (59, 15, 69, 19), P["danger"])
        for px in (22, 95):
            base.rect(d, (px, 50, px+8, 62), P["green"])
            base.rect(d, (px+2, 47, px+6, 50), P["paper"])
    elif role == "central_tower":
        d.ellipse((38, 40, 90, 82), outline=P["arcane_light"], width=3)
        d.ellipse((47, 49, 81, 73), outline=P["teal_light"], width=2)
        base.poly(d, [(64, 40), (72, 61), (64, 81), (56, 61)], P["arcane"])
    return im


def generate_interiors() -> list[Path]:
    outputs=[]
    target=ART/"environments"/"region3"/"interiors"
    roles=["central_tower","quest_hall","blacksmith","merchant","inn","storage","training","clinic"]
    for i,role in enumerate(roles):
        im=draw_interior(role,i)
        path=target/f"region3_{role}_interior_v01.png"
        im.save(path,optimize=True); outputs.append(path)
    return outputs


def generate_item_icons() -> list[Path]:
    outputs=[]
    eq=ART/"items"/"equipment"
    for filename,glyph,color in [
        ("equipment_weapon_icon_v01.png","sword",P["danger"]),
        ("equipment_armor_icon_v01.png","armor",P["stone_light"]),
        ("equipment_offhand_icon_v01.png","shield",P["teal"]),
        ("equipment_accessory_icon_v01.png","ring",P["gold"]),
    ]:
        outputs.append(save_icon(eq/filename,glyph,color))
    con=ART/"items"/"consumables"
    outputs.append(save_icon(con/"consumable_healing_icon_v01.png","flask",P["danger"],P["paper"]))
    outputs.append(save_icon(con/"consumable_utility_icon_v01.png","flask",P["teal"],P["paper"]))
    mat=ART/"items"/"materials"
    outputs.append(save_icon(mat/"upgrade_material_icon_v01.png","material",P["stone_light"],P["gold"]))
    outputs.append(save_icon(mat/"gold_icon_v01.png","coin",P["gold"],P["highlight"]))
    return outputs


def generate_hud_and_objective_icons() -> list[Path]:
    outputs=[]
    hud=ART/"ui"/"hud"
    outputs.append(save_icon(hud/"hud_health_icon_v01.png","heart",P["danger"]))
    outputs.append(save_icon(hud/"hud_stamina_icon_v01.png","bolt",P["gold"]))
    outputs.append(save_icon(hud/"hud_mana_icon_v01.png","orb",P["arcane"],P["white"]))

    obj=ART/"ui"/"objectives"
    outputs.append(save_icon(obj/"objective_escort_target_v01.png","person",P["teal"]))
    outputs.append(save_icon(obj/"objective_defense_target_v01.png","shield",P["gold"]))
    outputs.append(save_icon(obj/"objective_annihilation_target_v01.png","target",P["danger"]))
    outputs.append(save_icon(obj/"interaction_marker_v01.png","interact",P["paper"]))
    outputs.append(save_icon(obj/"checkpoint_marker_v01.png","checkpoint",P["teal_light"]))
    outputs.append(save_icon(obj/"tower_access_marker_v01.png","tower",P["arcane_light"]))
    return outputs


def generate_service_icons() -> list[Path]:
    outputs=[]
    target=ART/"ui"/"services"
    service_defs=[
        ("central_tower","tower",P["arcane_light"]),
        ("quest_hall","target",P["gold"]),
        ("blacksmith","sword",P["danger"]),
        ("general_merchant","coin",P["gold"]),
        ("inn","heart",P["paper"]),
        ("storage_house","material",P["brown_light"]),
        ("training_hall","sword",P["teal"]),
        ("clinic_apothecary","flask",P["green_light"]),
    ]
    for name,glyph,color in service_defs:
        outputs.append(save_icon(target/f"service_{name}_v01.png",glyph,color))
    return outputs


def generate_hazards_and_boss_arena() -> list[Path]:
    outputs=[]
    target=ART/"environments"/"tower"/"hazards"
    for name,shape,color in [
        ("spike","spike",P["stone_light"]),
        ("arcane","orb",P["arcane"]),
        ("burning","fire",P["danger"]),
    ]:
        im=base.image(32,32); d=ImageDraw.Draw(im)
        base.rect(d,(0,0,31,31),P["stone_dark"])
        if shape=="spike":
            for x in (5,12,19,26): base.poly(d,[(x,26),(x+3,10),(x+6,26)],color)
        elif shape=="orb":
            d.ellipse((7,7,25,25),outline=P["arcane_light"],width=2); d.ellipse((12,12,20,20),fill=P["arcane"])
        else:
            base.poly(d,[(16,5),(23,15),(20,27),(12,28),(8,19),(13,12)],P["danger"]); base.poly(d,[(16,12),(19,18),(16,24),(12,20)],P["gold"])
        path=target/f"tower_hazard_{name}_v01.png"; im.save(path,optimize=True); outputs.append(path)

    arena=base.image(192,192); d=ImageDraw.Draw(arena)
    base.rect(d,(0,0,191,191),P["outline0"]); base.rect(d,(6,6,185,185),P["stone_dark"])
    for x in range(16,192,32): base.line(d,[(x,7),(x,184)],P["shadow"],1)
    for y in range(16,192,32): base.line(d,[(7,y),(184,y)],P["shadow"],1)
    d.ellipse((28,28,164,164),outline=P["arcane"],width=3)
    d.ellipse((48,48,144,144),outline=P["stone_light"],width=2)
    base.poly(d,[(96,52),(116,96),(96,140),(76,96)],P["arcane"])
    # deliberately broad empty combat floor; no add sockets.
    path=ART/"environments"/"tower"/"boss_room"/"tenth_warden_arena_floor_v01.png"
    arena.save(path,optimize=True); outputs.append(path)
    return outputs


def main() -> None:
    ensure_dirs()
    outputs=[]
    outputs += generate_interiors()
    outputs += generate_item_icons()
    outputs += generate_hud_and_objective_icons()
    outputs += generate_service_icons()
    outputs += generate_hazards_and_boss_arena()
    base.record_assets(outputs)
    print(f"generated {len(outputs)} phase-3 local PNG assets")


if __name__ == "__main__":
    main()
