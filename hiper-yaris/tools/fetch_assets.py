"""Gerçekçi varlıkları indirir (Poly Haven CC0, Khronos CarConcept CC BY 4.0).
Çalıştır: python3 tools/fetch_assets.py"""
import json, os, urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "real")
SRC_ROOT = os.path.join(os.path.dirname(__file__), "..", "assets_src", "real")
API = "https://api.polyhaven.com/files/"
MODELS = ["namaqualand_boulder_02", "namaqualand_boulders_01", "namaqualand_rocks_01"]
PLANTS = ["othonna_cerarioides", "cheiridopsis_succulent", "dead_quiver_branch_01", "dry_branches_medium_01"]
# Doku -> gereken haritalar
TEXTURES = {"asphalt_02": ["Diffuse", "nor_gl", "Rough"], "red_sand": ["Diffuse", "nor_gl", "Rough"],
            "rocky_terrain_02": ["Diffuse"], "cliff_side": ["Diffuse", "nor_gl"]}
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
    d = os.path.join(SRC_ROOT, "rocks", m)
    get(g["url"], os.path.join(d, m + ".gltf"))
    for rel, info in g.get("include", {}).items():
        get(info["url"], os.path.join(d, rel))

for m in PLANTS:
    g = files(m)["gltf"][RES_MODEL]["gltf"]
    d = os.path.join(SRC_ROOT, "plants", m)
    get(g["url"], os.path.join(d, m + ".gltf"))
    for rel, info in g.get("include", {}).items():
        get(info["url"], os.path.join(d, rel))

NAMES = {"Diffuse": "albedo", "nor_gl": "normal", "Rough": "rough"}
for t, maps in TEXTURES.items():
    f = files(t)
    for key in maps:
        name = NAMES[key]
        if key in f and RES_TEX in f[key]:
            get(f[key][RES_TEX]["jpg"]["url"], os.path.join(ROOT, "textures", t, name + ".jpg"))

get(files(HDRI)["hdri"]["1k"]["hdr"]["url"], os.path.join(ROOT, "sky", HDRI + ".hdr"))
# Sketchfab araçları (API anahtarı gerekir; ortamın proxy'si ekler):
#   V12 Goblin 0a20e49ad5774d778567cb5c3f345786,
#   Generic Sport Car 7ad3bfb2bd7449c19698fc7d0592a601, Sport Car 5d1253a7eddc4c52a57805c515738902,
#   Saba V12 3ab977050c334c13b6abb5de078b4957, Cheetah 84 c967ab4abbc54ae4b7933fd81a86c99c,
#   Exterminator 00 857f048c4bbb40b4be4fb0b765a52116  ->  /v3/models/<uid>/download (glb)
# Kaya/bitki kaynakları assets_src/ altına iner; sonra: python3 tools/optimize_env.py
get("https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CarConcept/glTF-Binary/CarConcept.glb",
    os.path.join(ROOT, "cars", "CarConcept.glb"))

# Kurgusal/markasız araçlar (CC BY 4.0) Sketchfab indirme API'siyle alındı
# (SKETCHFAB_TOKEN gerekir; glb biçimi) -> assets/real/cars/<ad>.glb
CARS = {
    "mohawk": "2c5ea0d5f73246549c0b9b68f53627e9", "patriot": "d87ddc3e30134ff2990d8ee4d2586bdd",
    "wulf": "5fa828a6a9d34c1b85835164191790a8", "velocita": "1696b756b09644bf924d31559287b70f",
    "daimyo": "dd7c144e3ae64eeb9e65ba6e512fd559", "kralz": "61502e501b85485dae3fa5a2cbb6aa7b",
    "gourami": "bf29aca039c447ab913608e3f6818875", "azura": "2e1a3699de7e4f688d328dc005ef1aac",
}
