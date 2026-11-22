"""Poly Haven kaya/bitki modellerini oyun için hazırlar.

Taranmış modeller çok yoğun (tek kaya ~98 bin üçgen) ve bir dosyada birden çok çeşit
yan yana duruyor. Bu araç:
  1. Her çeşidi (ör. sukulent a..i) ayrı ayırır, tabanını orijine taşır,
  2. Kaplama koordinatlarını koruyarak 600-2500 üçgene sadeleştirir (quadric edge collapse),
  3. assets/opt/<dosya>__<çeşit>.glb olarak yazar (malzemesiz; dokular oyunda bağlanır),
  4. assets/opt/manifest.json içine çeşitleri, boyutları ve doku yollarını yazar.

Çalıştır: python3 tools/optimize_env.py   (kaynaklar: assets_src/real/{rocks,plants})
"""
import glob, json, os, re
import numpy as np
import trimesh
import pymeshlab

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets_src", "real")
OUT = os.path.join(ROOT, "assets", "opt")
TEX_OUT = os.path.join(ROOT, "assets", "opt", "textures")
TARGET = {"rocks": 2200, "plants": 900}

os.makedirs(TEX_OUT, exist_ok=True)


def variant_key(node: str) -> str:
    k = re.sub(r"_[0-9a-f]{6}$", "", node)
    return k.replace("_LOD0", "")


def decimate(v, f, uv, target):
    if len(f) <= target:
        return v, f, uv
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=v, face_matrix=f, v_tex_coords_matrix=uv))
    ms.compute_texcoord_transfer_vertex_to_wedge()
    for _ in range(5):
        before = ms.current_mesh().face_number()
        ms.meshing_decimation_quadric_edge_collapse_with_texture(
            targetfacenum=int(target), qualitythr=0.2, preserveboundary=False, boundaryweight=0.5,
            optimalplacement=True, planarquadric=True)
        after = ms.current_mesh().face_number()
        if after <= target * 1.1 or after >= before * 0.97:
            break
    m = ms.current_mesh()
    fv = m.face_matrix()
    wuv = m.wedge_tex_coord_matrix().reshape(-1, 3, 2) if m.has_wedge_tex_coord() else None
    vv = m.vertex_matrix()
    # Kama (köşe başına) UV -> köşe başına bağımsız tepe noktaları (dikiş kaybı olmasın)
    if wuv is not None:
        nv = vv[fv.reshape(-1)]
        nuv = wuv.reshape(-1, 2)
        nf = np.arange(len(nv)).reshape(-1, 3)
        # Aynı konum+UV tepe noktalarını birleştir
        key = np.round(np.hstack([nv, nuv]), 5)
        _, idx, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
        return nv[idx], inv.reshape(-1)[nf], nuv[idx]
    return vv, fv, None


manifest = {}
for path in sorted(glob.glob(os.path.join(SRC, "rocks", "*", "*.gltf")) + glob.glob(os.path.join(SRC, "plants", "*", "*.gltf"))):
    cat = "rocks" if "/rocks/" in path else "plants"
    name = os.path.splitext(os.path.basename(path))[0]
    gj = json.load(open(path))
    mat_alpha = [m.get("alphaMode", "OPAQUE") for m in gj["materials"]]
    mat_names = [m.get("name") for m in gj["materials"]]
    # Dokuları kopyala (oyunda paylaşılır)
    tex_dir = os.path.join(os.path.dirname(path), "textures")
    texmap = {}
    for kind, suffix in (("albedo", "_diff_1k.jpg"), ("normal", "_nor_gl_1k.jpg"), ("arm", "_arm_1k.jpg")):
        src = glob.glob(os.path.join(tex_dir, "*" + suffix))
        if src:
            dst = os.path.join(TEX_OUT, os.path.basename(src[0]))
            if not os.path.exists(dst):
                open(dst, "wb").write(open(src[0], "rb").read())
            texmap[kind] = "res://assets/opt/textures/" + os.path.basename(src[0])
    scene = trimesh.load(path)
    groups = {}
    for node in scene.graph.nodes_geometry:
        T, gname = scene.graph[node]
        groups.setdefault(variant_key(node), []).append((T, scene.geometry[gname]))
    for vkey, parts in groups.items():
        total = sum(len(g.faces) for _, g in parts)
        meshes = []
        for T, g in parts:
            m = g.copy()
            m.apply_transform(T)
            mat_name = getattr(getattr(g.visual, "material", None), "name", None)
            mi = mat_names.index(mat_name) if mat_name in mat_names else 0
            meshes.append((m, mi))
        allv = np.vstack([m.vertices for m, _ in meshes])
        lo, hi = allv.min(0), allv.max(0)
        offset = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
        out_scene = trimesh.Scene()
        tris = 0
        for i, (m, mi) in enumerate(meshes):
            target = max(60, TARGET[cat] * len(m.faces) / total)
            v, f, uv = decimate(np.asarray(m.vertices - offset, dtype=np.float64), np.asarray(m.faces, dtype=np.int32),
                                np.asarray(m.visual.uv, dtype=np.float64), target)
            tm = trimesh.Trimesh(vertices=v, faces=f, process=False)
            if uv is not None:
                tm.visual = trimesh.visual.TextureVisuals(uv=uv, material=trimesh.visual.material.PBRMaterial(name="m%d" % mi))
            out_scene.add_geometry(tm, node_name="m%d_%d" % (mi, i), geom_name="m%d_%d" % (mi, i))
            tris += len(f)
        fname = "%s__%s.glb" % (name, vkey.replace(name, "").strip("_") or "a")
        out_scene.export(os.path.join(OUT, fname))
        size = (hi - lo).tolist()
        manifest.setdefault(name, {"category": cat, "textures": texmap, "alpha": mat_alpha, "variants": []})
        manifest[name]["variants"].append({"file": "res://assets/opt/" + fname, "size": [round(x, 3) for x in size], "tris": tris})
        print("%-55s %6d -> %5d üçgen  boyut %s" % (fname, total, tris, np.round(size, 2)))

json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1, ensure_ascii=False)
print("manifest yazıldı")
