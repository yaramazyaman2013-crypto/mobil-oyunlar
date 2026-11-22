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
var jumps: Array = []               # tepe noktalarının indeksleri
var _grid := {}                    # yol noktaları için uzaysal hash (çakışma kontrolü)
# Arazi yükseklik ızgarası
var _h := PackedFloat32Array()
var _hw := 0
var _hh := 0
var _horigin := Vector2.ZERO
var HCELL := 6.0



func build(points: Array, seed_value: int) -> void:
	seed(seed_value)
	_sample_spline(points)
	_build_road()
	_build_walls()
	_build_rails()
	_build_ground()
	_build_terrain()
	_build_env()
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
		var a := Vector3(tan[i].x, 0, tan[i].z).normalized()
		var b := Vector3(tan[(i + 1) % count].x, 0, tan[(i + 1) % count].z).normalized()
		raw[i] = -a.signed_angle_to(b, Vector3.UP) / DS
	for i in count:
		var s := 0.0
		for k in range(-4, 5): s += raw[(i + k + count) % count]
		curv[i] = s / 9.0
	_apply_elevation()
	_build_safe_speed()
	_grid.clear()
	for i in count:
		var key := Vector2i(floori(pos[i].x / 20.0), floori(pos[i].z / 20.0))
		if not _grid.has(key): _grid[key] = []
		_grid[key].append(i)


## Pist boyunca yokuş/iniş profili (kapalı döngüde periyodik) ve düzlüklerde iki küçük tepe.
func _apply_elevation() -> void:
	var n := pos.size()
	var L := length
	var hs := PackedFloat32Array()
	hs.resize(n)
	for i in n:
		var s := i * DS
		var h := 10.0 * sin(TAU * 2.0 * s / L + 0.6) + 4.0 * sin(TAU * 5.0 * s / L + 1.9) + 1.5 * sin(TAU * 9.0 * s / L + 0.3)
		hs[i] = h - 10.0 * sin(0.6) - 4.0 * sin(1.9) - 1.5 * sin(0.3)   # başlangıç çizgisi 0 m
	# Düzlüklerde zıplatan tepeler
	jumps.clear()
	var best: Array = []
	for i in range(60, n - 60, 10):
		var straight := true
		for k in range(-35, 36, 5):
			if absf(curv[(i + k) % n]) > 0.0015: straight = false
		if straight: best.append(i)
	for cand in best:
		if jumps.size() >= 2: break
		var far := true
		for jj in jumps:
			if absi(cand - jj) < n / 4: far = false
		if far: jumps.append(cand)
	for jj in jumps:
		for k in range(-30, 31):
			var d := k * DS
			hs[(jj + k + n) % n] += 1.7 * exp(-(d * d) / (22.0 * 22.0))
	for i in n:
		pos[i].y = hs[i]
	for i in n:
		var tv := (pos[(i + 1) % n] - pos[(i - 1 + n) % n]).normalized()
		tan[i] = tv
		right[i] = Vector3(tv.x, 0, tv.z).cross(Vector3.UP).normalized()


## Yapay zekâ için güvenli hız tablosu: viraj hızı + 14 m/s² ile frenleme mesafesi (a_lat=1 için)
var _vsafe := PackedFloat32Array()
func _build_safe_speed() -> void:
	var n := pos.size()
	_vsafe.resize(n)
	for i in n: _vsafe[i] = 1.0 / sqrt(maxf(absf(curv[i]), 0.0001))   # a_lat=1 için viraj hızı
	# Geriye doğru iki tur: v(i) <= sqrt(v(i+1)² + 2·a·DS) — a_lat ölçeklemesi safe_speed'de yapılır
	for pass_i in 2:
		for j in range(n - 1, -1, -1):
			var nx := (j + 1) % n
			_vsafe[j] = minf(_vsafe[j], sqrt(_vsafe[nx] * _vsafe[nx] + 2.0 * (14.0 / 20.0) * DS))


func safe_speed(s: float, a_lat: float) -> float:
	return _vsafe[idx(s)] * sqrt(a_lat)


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
			st.add_vertex(pos[k] + right[k] * x + Vector3(0, 0.02, 0))
	var w := cols.size()
	for i in n:
		for c in w - 1:
			var a := i * w + c
			var b := a + w
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_add_collision(mi.mesh)
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


## Gerçek çarpışma yüzeyi (fizik katmanı 1)
func _add_collision(mesh: Mesh) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


## Görünmez bariyer duvarları: bariyer hizasında 1 m kalın, 4 m yüksek kutular (delinmez)
func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.15
	pm.bounce = 0.1
	body.physics_material_override = pm
	var n := pos.size()
	var seg := 2   # 2 örnek = 4 m
	for side in [-1.0, 1.0]:
		for i in range(0, n, seg):
			var k := (i + seg) % n
			var a: Vector3 = pos[i] + right[i] * side * (HALF + 1.45)
			var b: Vector3 = pos[k] + right[k] * side * (HALF + 1.45)
			var mid := (a + b) * 0.5
			var dir := b - a
			var length := dir.length() + 0.6
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, 9.0, length)
			var cs := CollisionShape3D.new()
			cs.shape = box
			var fwd := dir.normalized()
			var basis := Basis.looking_at(fwd, Vector3.UP)
			cs.transform = Transform3D(basis, mid + Vector3(0, 3.5, 0))
			body.add_child(cs)
	add_child(body)


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
	g.position.y = -60.0   # arazinin altında kalsın (pist yer yer sıfırın altına iniyor)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


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
	HCELL = 9.0 if env_quality < 0.5 else 6.0
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
	var near := PackedInt32Array()
	near.resize(total)
	near.fill(0)
	for pi in pos.size():
		var p := pos[pi]
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
				if d < dist[k]:
					dist[k] = d
					near[k] = pi
	var c1 := HCELL
	var c2 := HCELL * 1.4142
	for z in _hh:
		for x in _hw:
			var k := z * _hw + x
			if x > 0:
				if dist[k - 1] + c1 < dist[k]:
					dist[k] = dist[k - 1] + c1
					near[k] = near[k - 1]
			if z > 0:
				if dist[k - _hw] + c1 < dist[k]:
					dist[k] = dist[k - _hw] + c1
					near[k] = near[k - _hw]
				if x > 0:
					if dist[k - _hw - 1] + c2 < dist[k]:
						dist[k] = dist[k - _hw - 1] + c2
						near[k] = near[k - _hw - 1]
				if x < _hw - 1:
					if dist[k - _hw + 1] + c2 < dist[k]:
						dist[k] = dist[k - _hw + 1] + c2
						near[k] = near[k - _hw + 1]
	for z in range(_hh - 1, -1, -1):
		for x in range(_hw - 1, -1, -1):
			var k := z * _hw + x
			if x < _hw - 1:
				if dist[k + 1] + c1 < dist[k]:
					dist[k] = dist[k + 1] + c1
					near[k] = near[k + 1]
			if z < _hh - 1:
				if dist[k + _hw] + c1 < dist[k]:
					dist[k] = dist[k + _hw] + c1
					near[k] = near[k + _hw]
				if x < _hw - 1:
					if dist[k + _hw + 1] + c2 < dist[k]:
						dist[k] = dist[k + _hw + 1] + c2
						near[k] = near[k + _hw + 1]
				if x > 0:
					if dist[k + _hw - 1] + c2 < dist[k]:
						dist[k] = dist[k + _hw - 1] + c2
						near[k] = near[k + _hw - 1]
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
			var base: float = pos[near[k]].y
			var h := wall * rise + det.get_noise_2d(wx, wz) * 7.0 * rise
			h += maxf(de - 80.0, 0.0) * 0.05 * (big.get_noise_2d(wx * 2.0, wz * 2.0) + 0.6)
			if de < 4.0: h = -0.16 + det.get_noise_2d(wx, wz) * 0.15 * clampf(de, 0, 4) / 4.0
			# Dış sınırda zemine doğru alçal (kenarda boşluk kalmasın)
			var edge_d: float = minf(minf(x, _hw - 1 - x), minf(z, _hh - 1 - z)) * HCELL
			var fall := smoothstep(0.0, 60.0, edge_d)
			_h[k] = lerpf(-60.0, h + base, fall)
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
	mat.set_shader_parameter("hq", env_quality > 0.5)
	mi.material_override = mat
	add_child(mi)


# ---------------------------------------------------------------- dekor (kaya ve bitkiler)
# Sadeleştirilmiş modeller (tools/optimize_env.py) bölge bölge MultiMesh ile çizilir:
# her bölge ayrı görünürlük mesafesine sahip, uzaktakiler hiç çizilmez.

const CHUNK := 320.0
var env_quality := 1.0          # 0.4 mobil düşük .. 1.0 yüksek: yerleşim yoğunluğu
var _env := {}                  # çeşit adı -> {mesh, size}
var _buckets := {}              # "çeşit|bölge" -> {xf: Array[Transform3D], cfg}


func _env_mesh(file: String, mats: Array) -> ArrayMesh:
	var root: Node = load(file).instantiate()
	var mesh := ArrayMesh.new()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var midx := int(String(m.name).substr(1).split("_")[0])
		for si in m.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from(m.mesh, si)
			if not (m.mesh.surface_get_format(si) & Mesh.ARRAY_FORMAT_NORMAL): st.generate_normals()
			st.generate_tangents()   # normal haritası doğru ışıklansın
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[mini(midx, mats.size() - 1)])
	root.free()
	return mesh


func _load_env() -> void:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/opt/manifest.json"))
	for name in man:
		var e: Dictionary = man[name]
		var mats: Array = []
		for a in e.alpha:
			var m := ORMMaterial3D.new()
			m.albedo_texture = load(e.textures.albedo)
			if e.textures.has("normal"):
				m.normal_enabled = true
				m.normal_texture = load(e.textures.normal)
			if e.textures.has("arm"): m.orm_texture = load(e.textures.arm)
			if a != "OPAQUE":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.5
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			mats.append(m)
		for v in e.variants:
			if int(v.tris) > 6000: continue
			var key := String(v.file).get_file().get_basename()
			_env[key] = {"mesh": _env_mesh(v.file, mats), "size": v.size, "group": name}


func _variants(group: String) -> Array:
	var out: Array = []
	for k in _env:
		if _env[k].group == group: out.append(k)
	return out


func _put(key: String, p: Vector3, scale: float, yaw: float, range_end: float, shadow: bool) -> void:
	var c := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	var bk := "%s|%d|%d" % [key, c.x, c.y]
	if not _buckets.has(bk): _buckets[bk] = {"key": key, "xf": [], "range": range_end, "shadow": shadow}
	_buckets[bk].xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), p))


func _flush_env() -> void:
	for bk in _buckets:
		var b: Dictionary = _buckets[bk]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _env[b.key].mesh
		mm.instance_count = b.xf.size()
		for i in b.xf.size(): mm.set_instance_transform(i, b.xf[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.visibility_range_end = b.range
		mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if b.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_buckets.clear()


func _build_env() -> void:
	_load_env()
	var n := pos.size()
	var boulders := _variants("namaqualand_boulder_02")
	var stones := (_variants("namaqualand_boulders_01") + _variants("namaqualand_rocks_01")).slice(0, 3)
	var plants := (_variants("cheiridopsis_succulent").slice(0, 3) + _variants("othonna_cerarioides").slice(0, 2))
	var dry := _variants("dry_branches_medium_01").slice(0, 2)
	var r_far := lerpf(0.45, 1.0, env_quality)   # telefonda dekor daha yakına kadar çizilir
	var step := int(lerpf(14.0, 5.0, env_quality))
	for i in range(0, n, step):
		for side in [-1.0, 1.0]:
			# Kanyon tabanında büyük kaya blokları (gölgeli)
			if randf() < 0.3:
				var d: float = HALF + SHOULDER + randf_range(7.0, 16.0)
				var p: Vector3 = pos[i] + right[i] * side * d
				if road_distance(p) > HALF + SHOULDER + 5.0:
					p.y = minf(minf(height_at(p.x - 3, p.z), height_at(p.x + 3, p.z)), minf(height_at(p.x, p.z - 3), height_at(p.x, p.z + 3))) - 0.6
					_put(boulders.pick_random(), p, randf_range(1.3, 2.8), randf() * TAU, 380.0 * r_far, env_quality > 0.5)
			# Yol kenarı taşları
			if randf() < 0.5:
				var q: Vector3 = pos[i] + right[i] * side * (HALF + SHOULDER + randf_range(1.0, 7.0)) + tan[i] * randf_range(-5, 5)
				if road_distance(q) > HALF + SHOULDER + 0.5:
					q.y = height_at(q.x, q.z) - 0.05
					_put(stones.pick_random(), q, randf_range(2.5, 7.0), randf() * TAU, 160.0 * r_far, false)
			# Çalılar ve kuru dallar
			for k in 2:
				if randf() < 0.75:
					var r: Vector3 = pos[i] + right[i] * side * (HALF + SHOULDER + randf_range(1.5, 26.0)) + tan[i] * randf_range(-6, 6)
					if road_distance(r) > HALF + SHOULDER + 1.0:
						r.y = height_at(r.x, r.z) - 0.03
						var is_dry := randf() < 0.3
						var key: String = (dry if is_dry else plants).pick_random()
						_put(key, r, randf_range(1.6, 3.2), randf() * TAU, 130.0 * r_far, false)
	_flush_env()
