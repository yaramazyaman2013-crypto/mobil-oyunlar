class_name Track
extends Node3D
## Kontrol noktalarından kapalı bir spline pist üretir: asfalt yol mesh'i,
## bariyerler, kanyon kayalıkları ve zemin. Yol boyunca örnekleme fonksiyonları sağlar.

const DS := 2.0                 # örnek aralığı (m)
const HALF := 9.0               # yol yarı genişliği (4 şerit × 4.5 m)
const SHOULDER := 3.0
const LANES := [-6.75, -2.25, 2.25, 6.75]

var pos := PackedVector3Array()
var tan := PackedVector3Array()
var right := PackedVector3Array()
var curv := PackedFloat32Array()   # işaretli eğrilik (1/m), + = sağa dönüş
var length := 0.0
var _grid := {}                    # yol noktaları için uzaysal hash (çakışma kontrolü)
# Arazi yükseklik ızgarası
var _h := PackedFloat32Array()
var _hw := 0
var _hh := 0
var _horigin := Vector2.ZERO
const HCELL := 6.0
const PLANTS := {
	"didelta": "res://assets/real/plants/didelta_spinosa/didelta_spinosa.gltf",
	"othonna": "res://assets/real/plants/othonna_cerarioides/othonna_cerarioides.gltf",
	"succulent": "res://assets/real/plants/cheiridopsis_succulent/cheiridopsis_succulent.gltf",
	"quiver": "res://assets/real/plants/dead_quiver_branch_01/dead_quiver_branch_01.gltf",
	"branches": "res://assets/real/plants/dry_branches_medium_01/dry_branches_medium_01.gltf",
}

const ROCKS := {
	"cliff1": "res://assets/real/rocks/namaqualand_cliff_01/namaqualand_cliff_01.gltf",
	"cliff2": "res://assets/real/rocks/namaqualand_cliff_02/namaqualand_cliff_02.gltf",
	"face1": "res://assets/real/rocks/rock_face_01/rock_face_01.gltf",
	"face2": "res://assets/real/rocks/rock_face_02/rock_face_02.gltf",
	"mountain": "res://assets/real/rocks/mountainside/mountainside.gltf",
	"boulder": "res://assets/real/rocks/namaqualand_boulder_02/namaqualand_boulder_02.gltf",
	"boulders": "res://assets/real/rocks/namaqualand_boulders_01/namaqualand_boulders_01.gltf",
	"stones": "res://assets/real/rocks/namaqualand_rocks_01/namaqualand_rocks_01.gltf",
}


func build(points: Array, seed_value: int) -> void:
	seed(seed_value)
	_sample_spline(points)
	_build_road()
	_build_rails()
	_build_ground()
	_build_terrain()
	_build_rocks()
	_build_plants()
	_build_gantry()
	_build_poles()


# ---------------------------------------------------------------- spline

func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _sample_spline(points: Array) -> void:
	var cp: Array[Vector3] = []
	for p in points: cp.append(Vector3(p.x, 0, p.y))
	var n := cp.size()
	var dense: Array[Vector3] = []
	for i in n:
		for k in 60:
			dense.append(_catmull(cp[(i - 1 + n) % n], cp[i], cp[(i + 1) % n], cp[(i + 2) % n], k / 60.0))
	# Yay uzunluğuna göre DS aralıkla yeniden örnekle
	var acc := PackedFloat32Array([0.0])
	for i in range(1, dense.size() + 1):
		acc.append(acc[i - 1] + dense[i - 1].distance_to(dense[i % dense.size()]))
	var total: float = acc[acc.size() - 1]
	var count := int(total / DS)
	length = count * DS
	pos.clear()
	var j := 0
	for i in count:
		var d := i * total / count
		while acc[j + 1] < d: j += 1
		var t := (d - acc[j]) / maxf(acc[j + 1] - acc[j], 0.0001)
		pos.append(dense[j].lerp(dense[(j + 1) % dense.size()], t))
	tan.resize(count)
	right.resize(count)
	curv.resize(count)
	for i in count:
		var tv := (pos[(i + 1) % count] - pos[(i - 1 + count) % count]).normalized()
		tan[i] = tv
		right[i] = tv.cross(Vector3.UP).normalized()
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var a := tan[i]
		var b := tan[(i + 1) % count]
		raw[i] = -a.signed_angle_to(b, Vector3.UP) / DS
	for i in count:
		var s := 0.0
		for k in range(-4, 5): s += raw[(i + k + count) % count]
		curv[i] = s / 9.0
	_grid.clear()
	for i in count:
		var key := Vector2i(floori(pos[i].x / 20.0), floori(pos[i].z / 20.0))
		if not _grid.has(key): _grid[key] = []
		_grid[key].append(i)


func idx(s: float) -> int:
	return int(fposmod(s, length) / DS) % pos.size()


## s mesafesi ve x yanal ofsetindeki dünya konumu
func point(s: float, x := 0.0) -> Vector3:
	s = fposmod(s, length)
	var i := int(s / DS) % pos.size()
	var j := (i + 1) % pos.size()
	var t := (s - i * DS) / DS
	return pos[i].lerp(pos[j], t) + right[i].lerp(right[j], t) * x


func tangent(s: float) -> Vector3:
	s = fposmod(s, length)
	var i := int(s / DS) % pos.size()
	var j := (i + 1) % pos.size()
	return tan[i].lerp(tan[j], (s - i * DS) / DS).normalized()


func curvature(s: float) -> float:
	return curv[idx(s)]


## En yakın yol noktasına uzaklık (dekor yerleşimi için)
func road_distance(p: Vector3) -> float:
	var best := INF
	var c := Vector2i(floori(p.x / 20.0), floori(p.z / 20.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for i in _grid.get(c + Vector2i(dx, dz), []):
				best = minf(best, Vector2(pos[i].x - p.x, pos[i].z - p.z).length())
	return best


# ---------------------------------------------------------------- yol

func _tex(path: String) -> Texture2D:
	return load(path)


func _build_road() -> void:
	var cols := [-HALF - SHOULDER, -HALF, -4.5, 0.0, 4.5, HALF, HALF + SHOULDER]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pos.size()
	for i in n + 1:
		var k := i % n
		for x in cols:
			st.set_uv(Vector2(x, i * DS))
			st.set_normal(Vector3.UP)
			st.add_vertex(pos[k] + right[k] * x + Vector3(0, 0.02, 0))
	var w := cols.size()
	for i in n:
		for c in w - 1:
			var a := i * w + c
			var b := a + w
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/road.gdshader")
	mat.set_shader_parameter("albedo_tex", _tex("res://assets/real/textures/asphalt_02/albedo.jpg"))
	mat.set_shader_parameter("normal_tex", _tex("res://assets/real/textures/asphalt_02/normal.jpg"))
	mat.set_shader_parameter("rough_tex", _tex("res://assets/real/textures/asphalt_02/rough.jpg"))
	mat.set_shader_parameter("sand_tex", _tex("res://assets/real/textures/red_sand/albedo.jpg"))
	mat.set_shader_parameter("half_width", HALF)
	mat.set_shader_parameter("track_length", length)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_rails() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.77, 0.8)
	metal.metallic = 0.9
	metal.roughness = 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pos.size()
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, 0.8, 0.12)
	post_mesh.material = metal
	posts.mesh = post_mesh
	var post_xf: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var x: float = side * (HALF + 0.9)
		for i in n:
			var k := (i + 1) % n
			var a: Vector3 = pos[i] + right[i] * x
			var b: Vector3 = pos[k] + right[k] * x
			var nrm: Vector3 = -right[i] * side
			for q in [[0.5, 0.8]]:
				var y0: float = q[0]
				var y1: float = q[1]
				var v := [a + Vector3(0, y0, 0), b + Vector3(0, y0, 0), b + Vector3(0, y1, 0), a + Vector3(0, y1, 0)]
				for tri in [[0, 1, 2], [0, 2, 3]]:
					for t in tri:
						st.set_normal(nrm)
						st.add_vertex(v[t])
			if i % 2 == 0:
				post_xf.append(Transform3D(Basis.looking_at(tan[i]), a + Vector3(0, 0.4, 0)))
	var rail := MeshInstance3D.new()
	rail.mesh = st.commit()
	metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	rail.material_override = metal
	add_child(rail)
	posts.instance_count = post_xf.size()
	for i in post_xf.size(): posts.set_instance_transform(i, post_xf[i])
	var pm := MultiMeshInstance3D.new()
	pm.multimesh = posts
	add_child(pm)


func _build_ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("res://assets/real/textures/red_sand/albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = _tex("res://assets/real/textures/red_sand/normal.jpg")
	m.roughness_texture = _tex("res://assets/real/textures/red_sand/rough.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.08, 0.08, 0.08)
	m.albedo_color = Color(0.95, 0.85, 0.75)
	g.material_override = m
	g.position.y = -0.03
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


func _rock(id: String, p: Vector3, scale: float, yaw: float) -> void:
	var r: Node3D = load(ROCKS[id]).instantiate()
	r.position = p
	r.scale = Vector3.ONE * scale
	r.rotation.y = yaw
	add_child(r)


func _build_rocks() -> void:
	# Kanyon tabanına kayalar ve yol kenarı taşları (duvarı arazi oluşturur)
	var n := pos.size()
	var i := 0
	while i < n:
		for side in [-1.0, 1.0]:
			if randf() < 0.35:
				var d: float = HALF + SHOULDER + randf_range(8.0, 16.0)
				var p: Vector3 = pos[i] + right[i] * side * d
				if road_distance(p) > HALF + SHOULDER + 6.0:
					p.y = height_at(p.x, p.z) - 0.5
					_rock(["face1", "face2", "cliff1", "boulder"].pick_random(), p, randf_range(1.5, 3.0), randf() * TAU)
			if randf() < 0.45:
				var q: Vector3 = pos[i] + right[i] * side * (HALF + SHOULDER + randf_range(1.0, 5.0)) + tan[i] * randf_range(-5, 5)
				if road_distance(q) > HALF + SHOULDER + 0.5:
					q.y = height_at(q.x, q.z)
					_rock(["boulder", "boulders", "stones"].pick_random(), q, randf_range(1.2, 3.0), randf() * TAU)
		i += randi_range(5, 9)


func _build_gantry() -> void:
	# Başlangıç/bitiş kapısı
	var root := Node3D.new()
	root.position = pos[0]
	root.basis = Basis.looking_at(tan[0])
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.16)
	mat.metallic = 0.6
	mat.roughness = 0.4
	for x in [-HALF - 1.6, HALF + 1.6]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 8.0, 0.8)
		post.mesh = bm
		post.material_override = mat
		post.position = Vector3(x, 4.0, 0)
		root.add_child(post)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(HALF * 2 + 4.0, 1.8, 0.6)
	beam.mesh = bb
	beam.material_override = mat
	beam.position = Vector3(0, 7.6, 0)
	root.add_child(beam)
	for zs in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "HİPER YARIŞ  •  START / FINISH"
		label.font_size = 96
		label.pixel_size = 0.012
		label.modulate = Color(1.0, 0.82, 0.2)
		label.outline_size = 0
		label.position = Vector3(0, 7.6, zs * 0.32)
		if zs < 0: label.rotation.y = PI
		root.add_child(label)


func _build_poles() -> void:
	# Yol kenarı sokak lambaları (MultiMesh ile ucuz)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.57, 0.6)
	metal.metallic = 0.8
	metal.roughness = 0.4
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.95, 0.85)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.9, 0.7)
	lamp.emission_energy_multiplier = 2.0
	var pole := CylinderMesh.new()
	pole.top_radius = 0.09
	pole.bottom_radius = 0.14
	pole.height = 9.0
	pole.radial_segments = 8
	pole.material = metal
	var arm := BoxMesh.new()
	arm.size = Vector3(2.6, 0.12, 0.12)
	arm.material = metal
	var head := BoxMesh.new()
	head.size = Vector3(0.9, 0.12, 0.35)
	head.material = lamp
	var xf := {"pole": [], "arm": [], "head": []}
	var n := pos.size()
	var step := 30   # 60 m'de bir
	for i in range(0, n, step):
		var side := 1.0 if (i / step) % 2 == 0 else -1.0
		var base := pos[i] + right[i] * side * (HALF + 2.0)
		var inward := -right[i] * side
		xf.pole.append(Transform3D(Basis(), base + Vector3(0, 4.5, 0)))
		var arm_basis := Basis(Vector3.UP, atan2(inward.x, inward.z) - PI / 2.0)
		xf.arm.append(Transform3D(arm_basis, base + inward * 1.2 + Vector3(0, 8.9, 0)))
		xf.head.append(Transform3D(arm_basis, base + inward * 2.3 + Vector3(0, 8.8, 0)))
	for k in xf:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = {"pole": pole, "arm": arm, "head": head}[k]
		mm.instance_count = xf[k].size()
		for j in xf[k].size(): mm.set_instance_transform(j, xf[k][j])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		add_child(mi)


# ---------------------------------------------------------------- konum bulma

## Dünya konumunu pist koordinatına çevirir: [indeks, yanal ofset, pist mesafesi]
func project(p: Vector3, hint: int) -> Array:
	var n := pos.size()
	var best := hint
	var bd := INF
	for k in range(-14, 15):
		var j := (hint + k + n) % n
		var d := Vector2(pos[j].x - p.x, pos[j].z - p.z).length_squared()
		if d < bd:
			bd = d
			best = j
	if bd > 900.0:
		# İpucu yanlışsa (ışınlanma vb.) tüm pistte ara
		for j in n:
			var d := Vector2(pos[j].x - p.x, pos[j].z - p.z).length_squared()
			if d < bd:
				bd = d
				best = j
	var rel := p - pos[best]
	var along := rel.dot(tan[best])
	return [best, rel.dot(right[best]), best * DS + along]


# ---------------------------------------------------------------- arazi

func height_at(x: float, z: float) -> float:
	if _hw == 0: return 0.0
	var gx := (x - _horigin.x) / HCELL
	var gz := (z - _horigin.y) / HCELL
	var ix := clampi(int(gx), 0, _hw - 2)
	var iz := clampi(int(gz), 0, _hh - 2)
	var fx := clampf(gx - ix, 0, 1)
	var fz := clampf(gz - iz, 0, 1)
	var a := lerpf(_h[iz * _hw + ix], _h[iz * _hw + ix + 1], fx)
	var b := lerpf(_h[(iz + 1) * _hw + ix], _h[(iz + 1) * _hw + ix + 1], fx)
	return lerpf(a, b, fz)


func _build_terrain() -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pos:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
	var margin := 520.0
	_horigin = mn - Vector2(margin, margin)
	_hw = int((mx.x - mn.x + margin * 2) / HCELL) + 1
	_hh = int((mx.y - mn.y + margin * 2) / HCELL) + 1
	var total := _hw * _hh
	# Mesafe alanı: yol noktalarından uzaklık (chamfer dönüşümü)
	var dist := PackedFloat32Array()
	dist.resize(total)
	dist.fill(1e9)
	for p in pos:
		var cx := int((p.x - _horigin.x) / HCELL)
		var cz := int((p.z - _horigin.y) / HCELL)
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var x := cx + dx
				var z := cz + dz
				if x < 0 or z < 0 or x >= _hw or z >= _hh: continue
				var wx := _horigin.x + x * HCELL
				var wz := _horigin.y + z * HCELL
				var d := Vector2(wx - p.x, wz - p.z).length()
				var k := z * _hw + x
				if d < dist[k]: dist[k] = d
	var c1 := HCELL
	var c2 := HCELL * 1.4142
	for z in _hh:
		for x in _hw:
			var k := z * _hw + x
			var v := dist[k]
			if x > 0: v = minf(v, dist[k - 1] + c1)
			if z > 0:
				v = minf(v, dist[k - _hw] + c1)
				if x > 0: v = minf(v, dist[k - _hw - 1] + c2)
				if x < _hw - 1: v = minf(v, dist[k - _hw + 1] + c2)
			dist[k] = v
	for z in range(_hh - 1, -1, -1):
		for x in range(_hw - 1, -1, -1):
			var k := z * _hw + x
			var v := dist[k]
			if x < _hw - 1: v = minf(v, dist[k + 1] + c1)
			if z < _hh - 1:
				v = minf(v, dist[k + _hw] + c1)
				if x < _hw - 1: v = minf(v, dist[k + _hw + 1] + c2)
				if x > 0: v = minf(v, dist[k + _hw - 1] + c2)
			dist[k] = v
	# Yükseklik: yolun yanında düz taban, sonra yükselen kanyon duvarı ve plato
	var big := FastNoiseLite.new()
	big.seed = randi()
	big.frequency = 0.0025
	var det := FastNoiseLite.new()
	det.seed = randi()
	det.frequency = 0.02
	det.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	det.fractal_octaves = 4
	_h.resize(total)
	var edge := HALF + SHOULDER
	for z in _hh:
		for x in _hw:
			var k := z * _hw + x
			var wx := _horigin.x + x * HCELL
			var wz := _horigin.y + z * HCELL
			var de := dist[k] - edge
			var wall := 18.0 + 42.0 * (big.get_noise_2d(wx, wz) * 0.5 + 0.5)
			var rise := smoothstep(4.0, 26.0 + wall * 0.4, de)
			var h := wall * rise + det.get_noise_2d(wx, wz) * 7.0 * rise
			h += maxf(de - 80.0, 0.0) * 0.05 * (big.get_noise_2d(wx * 2.0, wz * 2.0) + 0.6)
			if de < 4.0: h = -0.06 + det.get_noise_2d(wx, wz) * 0.15 * clampf(de, 0, 4) / 4.0 - 0.1
			_h[k] = h
	# Mesh
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(total)
	norms.resize(total)
	for z in _hh:
		for x in _hw:
			var k := z * _hw + x
			verts[k] = Vector3(_horigin.x + x * HCELL, _h[k], _horigin.y + z * HCELL)
			var hl := _h[k - 1] if x > 0 else _h[k]
			var hr := _h[k + 1] if x < _hw - 1 else _h[k]
			var hd := _h[k - _hw] if z > 0 else _h[k]
			var hu := _h[k + _hw] if z < _hh - 1 else _h[k]
			norms[k] = Vector3(hl - hr, 2.0 * HCELL, hd - hu).normalized()
	var idxs := PackedInt32Array()
	idxs.resize((_hw - 1) * (_hh - 1) * 6)
	var t := 0
	for z in _hh - 1:
		for x in _hw - 1:
			var a := z * _hw + x
			var b := a + _hw
			idxs[t] = a; idxs[t + 1] = a + 1; idxs[t + 2] = b
			idxs[t + 3] = a + 1; idxs[t + 4] = b + 1; idxs[t + 5] = b
			t += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/terrain.gdshader")
	mat.set_shader_parameter("rock_tex", _tex("res://assets/real/textures/cliff_side/albedo.jpg"))
	mat.set_shader_parameter("rock_nrm", _tex("res://assets/real/textures/cliff_side/normal.jpg"))
	mat.set_shader_parameter("sand_tex", _tex("res://assets/real/textures/red_sand/albedo.jpg"))
	mat.set_shader_parameter("sand_nrm", _tex("res://assets/real/textures/red_sand/normal.jpg"))
	mat.set_shader_parameter("gravel_tex", _tex("res://assets/real/textures/rocky_terrain_02/albedo.jpg"))
	mi.material_override = mat
	add_child(mi)


func _build_plants() -> void:
	var n := pos.size()
	for k in 420:
		var i := randi() % n
		var side := -1.0 if randf() < 0.5 else 1.0
		var d := HALF + SHOULDER + randf_range(1.5, 30.0)
		var p: Vector3 = pos[i] + right[i] * side * d + tan[i] * randf_range(-4, 4)
		if road_distance(p) < HALF + SHOULDER + 1.0: continue
		p.y = height_at(p.x, p.z)
		var id: String = ["didelta", "didelta", "succulent", "othonna", "quiver", "branches"].pick_random()
		var r: Node3D = load(PLANTS[id]).instantiate()
		r.position = p
		r.rotation.y = randf() * TAU
		r.scale = Vector3.ONE * randf_range(1.2, 2.6) * (2.0 if id == "othonna" else 1.0)
		add_child(r)
