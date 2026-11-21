"""Gerçekçi varlıkları indirir (Poly Haven CC0, Khronos CarConcept CC BY 4.0).
Çalıştır: python3 tools/fetch_assets.py"""
import json, os, urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "real")
API = "https://api.polyhaven.com/files/"
MODELS = ["namaqualand_cliff_01", "namaqualand_cliff_02", "namaqualand_boulder_02", "namaqualand_boulders_01",
          "rock_face_01", "rock_face_02", "mountainside", "namaqualand_rocks_01"]
PLANTS = ["didelta_spinosa", "othonna_cerarioides", "cheiridopsis_succulent", "dead_quiver_branch_01", "dry_branches_medium_01"]
TEXTURES = ["asphalt_02", "red_sand", "rocky_terrain_02", "cliff_side"]
HDRI = "kloofendal_48d_partly_cloudy_puresky"
RES_MODEL, RES_TEX = "1k", "2k"

def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and os.path.getsize(path) > 0: return
    req = urllib.request.Request(url, headers={"User-Agent": "godot-asset-fetch"})
    with urllib.request.urlopen(req) as r, open(path, "wb") as f: f.write(r.read())
    print("indirildi", os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")

def files(asset):
    req = urllib.request.Request(API + asset, headers={"User-Agent": "godot-asset-fetch"})
    return json.load(urllib.request.urlopen(req))

for m in MODELS:
    g = files(m)["gltf"][RES_MODEL]["gltf"]
    d = os.path.join(ROOT, "rocks", m)
    get(g["url"], os.path.join(d, m + ".gltf"))
    for rel, info in g.get("include", {}).items():
        get(info["url"], os.path.join(d, rel))

for m in PLANTS:
    g = files(m)["gltf"][RES_MODEL]["gltf"]
    d = os.path.join(ROOT, "plants", m)
    get(g["url"], os.path.join(d, m + ".gltf"))
    for rel, info in g.get("include", {}).items():
        get(info["url"], os.path.join(d, rel))

for t in TEXTURES:
    f = files(t)
    for key, name in [("Diffuse", "albedo"), ("nor_gl", "normal"), ("Rough", "rough"), ("arm", "arm")]:
        if key in f and RES_TEX in f[key]:
            get(f[key][RES_TEX]["jpg"]["url"], os.path.join(ROOT, "textures", t, name + ".jpg"))

get(files(HDRI)["hdri"]["2k"]["hdr"]["url"], os.path.join(ROOT, "sky", HDRI + ".hdr"))
# Sketchfab araçları (API anahtarı gerekir; ortamın proxy'si ekler):
#   V12 Goblin 0a20e49ad5774d778567cb5c3f345786, Rayback Mohawk 2c5ea0d5f73246549c0b9b68f53627e9,
#   Generic Sport Car 7ad3bfb2bd7449c19698fc7d0592a601  ->  /v3/models/<uid>/download (glb)
get("https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CarConcept/glTF-Binary/CarConcept.glb",
    os.path.join(ROOT, "cars", "CarConcept.glb"))
