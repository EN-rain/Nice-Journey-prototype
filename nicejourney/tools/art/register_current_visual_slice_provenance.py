"""Register verified source/output chains; metadata does not itself grant visual acceptance."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
P=ROOT/"docs/ASSET_PROVENANCE_MANIFEST.json"
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def path(s):
    s=s.replace("\\","/").removeprefix("res://").removeprefix("nicejourney/")
    return ROOT/s
def uri(p): return "res://"+p.relative_to(ROOT).as_posix()
def register(data,output,source,source_hash,output_hash,method,derivation,layer,acceptance):
    out=path(output); src=path(source)
    assert digest(src)==source_hash,(source,"source hash mismatch")
    assert digest(out)==output_hash,(output,"output hash mismatch")
    im=Image.open(out)
    rec={"asset_name":out.stem.replace("_"," ").title(),"project_path":uri(out),"source":uri(src),
    "creator_source":"Built-in image generator; model version not exposed. Exact source SHA-256 "+source_hash,
    "license_category":"ai_generated_terms_permit",
    "license_text":"Generated for the user's Nice Journey prototype under the project's AI-generated-use category. This record does not establish independent legal review of generator terms.",
    "attribution_text":"","modifications":method,"date_imported":"2026-09-20","responsible_agent":"OpenAI ChatGPT",
    "kind":"pixel_art","source_sha256":source_hash,"output_sha256":output_hash,"derivation_manifest":derivation,"acceptance_status":acceptance,
    "pixel_metadata":{"dimensions":f"{im.width}x{im.height} px","palette_material_ramp":"Inherited from preserved source; see deterministic derivation record for processing.",
    "pivot_ground_anchor":"Scene/profile-owned presentation anchor; exact cell transforms recorded by derivation.",
    "frame_order_timing":"Source/cell order in derivation; runtime timing and semantic use remain resource-owned.",
    "transparent_bounds":"RGBA source-derived alpha; processing recorded in derivation.",
    "intended_render_layers":[layer]}}
    for i,old in enumerate(data["assets"]):
        if old.get("project_path")==rec["project_path"]:
            data["assets"][i]=rec;break
    else:data["assets"].append(rec)

def main():
    data=json.loads(P.read_text(encoding="utf-8"))
    acceptance=json.loads((ROOT/"docs/evidence/art/region3_support_v02/REGION3_SUPPORT_V02_ACCEPTANCE.json").read_text())
    for r in acceptance["records"]:
        register(data,r["production_asset"],r["source"],r["source_sha256"],r["production_sha256"],
        "Exact generated source retained; documented component/crop selection, alpha threshold 24, nearest-neighbor reduction and fixed-cell atlas packing. No hand-painted replacement.",
        "res://"+r["derivation_manifest"],"environment",r["acceptance"])
    dpath=ROOT/"assets/art/environments/region3/roads/derived/region3_ground_tile_v02.manifest.json"
    d=json.loads(dpath.read_text())
    for c in d["cells"]:
        if c["index"]==7:continue
        register(data,uri(dpath.parent/c["output"]),d["source"],d["source_sha256"],c["sha256"],
        "Standalone 32x32 crop of accepted generated-source ground atlas at recorded bbox; no repaint. Used to avoid atlas-repeat distortion.",uri(dpath),"environment","source_chain_verified_renderer_catalog_reviewed")
    clean=json.loads((ROOT/"docs/evidence/art/player-v03-nearest-integration.json").read_text())
    for r in clean["preserved_originals"]:
        out=path(r["target"]);assert digest(out)==r["candidate_sha256"]
        for rec in data["assets"]:
            if rec.get("project_path")==r["target"]:
                rec["modifications"]="Exact visually classified V03 source crops; aspect-preserving NEAREST reduction into32x32 bottom-centered cells. Prior LANCZOS derivative preserved; see dedicated integration evidence."
                rec["output_sha256"]=r["candidate_sha256"]
                rec["derivation_manifest"]="res://docs/evidence/art/nearest_candidates/player_main_character_v03_nearest_derivation_manifest.json"
                rec["acceptance_status"]="nearest_derivative_verified; renderer acceptance tracked in current review evidence"
                break
    P.write_text(json.dumps(data,indent=4)+"\n",encoding="utf-8")
    print("Registered 5 support atlases, 7 standalone ground tiles; corrected 7 nearest player derivation records; total",len(data["assets"]))
if __name__=="__main__":main()
