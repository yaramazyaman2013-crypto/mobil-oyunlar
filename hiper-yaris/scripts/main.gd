extends Node3D
## Hiper Yarış — gerçekçi grafikli, gündelik kontrollü arcade yarış.
## Gaz otomatik. Direksiyon: A/D, ←/→ veya ekrandaki oklar. Fren / drift: S/↓ (direksiyonla birlikte).
## Nitro: Boşluk/Shift. Pistten çıkarsan: R. 4 araç, 2 tur, kanyon pisti.

enum State { MENU, COUNTDOWN, RACE, FINISHED }

const LAPS := 2
const BASE_TOP := 72.0          # m/s (~260 km/sa)
const NITRO_ADD := 20.0
const GRIP := 9.0               # yanal tutuş (1/s)
const DRIFT_GRIP := 1.4
const BRAKE_DEC := 32.0
const A_LAT_AI := 40.0
const CAR_R := 1.05             # çarpışma dairesi yarıçapı (araç başına 2 daire)
const CIRCLE_OFF := 1.2
const WALL := Track.HALF + 0.9 - 1.05

const TRACK_POINTS := [
	Vector2(0, 0), Vector2(0, -300), Vector2(60, -520), Vector2(220, -640), Vector2(420, -620),
	Vector2(560, -500), Vector2(600, -300), Vector2(520, -140), Vector2(560, 40), Vector2(700, 180),
	Vector2(680, 380), Vector2(520, 480), Vector2(300, 460), Vector2(160, 340), Vector2(60, 200),
]

## yaw: modelin önünü +Z'ye çeviren açı. keep: sadece bu düğümleri göster. wheels: tekerlek düğümü deseni.
const MODELS := {
	"concept": {"path": "res://assets/real/cars/CarConcept.glb", "yaw": 0.0, "keep": [], "wheels": "Wheel*", "paint": true},
	"goblin": {"path": "res://assets/real/cars/goblin.glb", "yaw": PI, "keep": [], "wheels": "bone_rotation_*", "paint": true},
	"mohawk": {"path": "res://assets/real/cars/mohawk.glb", "yaw": 0.0, "keep": ["Car_17", "Fan1_0_011_1", "Fan2_0_012_2"], "wheels": "", "paint": false},
	"sport_a": {"path": "res://assets/real/cars/sport.glb", "yaw": -PI / 2.0, "keep": ["mc_Body_4"], "wheels": "mc-wheel*", "paint": false},
	"sport_b": {"path": "res://assets/real/cars/sport.glb", "yaw": -PI / 2.0, "keep": ["mc_Body_001_9"], "wheels": "mc-wheel*", "paint": false},
	"sport_c": {"path": "res://assets/real/cars/sport.glb", "yaw": -PI / 2.0, "keep": ["mc_Body_002_14"], "wheels": "mc-wheel*", "paint": false},
}
const GARAGE := [
	{"name": "AURORA  •  BUZ MAVİSİ", "model": "concept", "color": Color(0.05, 0.3, 0.85), "price": 0},
	{"name": "STRADA GT  •  TURUNCU", "model": "sport_b", "color": Color.WHITE, "price": 200},
	{"name": "GOBLIN V12  •  ZEHİR YEŞİLİ", "model": "goblin", "color": Color(0.2, 0.7, 0.05), "price": 350},
	{"name": "RAYBACK MOHAWK  •  YARIŞ", "model": "mohawk", "color": Color.WHITE, "price": 500},
	{"name": "STRADA GT  •  KARBON", "model": "sport_a", "color": Color.WHITE, "price": 700},
	{"name": "AURORA  •  YARIŞ KIRMIZISI", "model": "concept", "color": Color(0.75, 0.04, 0.04), "price": 900},
	{"name": "GOBLIN V12  •  GECE SİYAHI", "model": "goblin", "color": Color(0.025, 0.025, 0.03), "price": 1100},
	{"name": "STRADA GT  •  BEYAZ", "model": "sport_c", "color": Color.WHITE, "price": 1300},
]
const RIVALS := [
	{"name": "KARTAL", "model": "goblin", "color": Color(0.03, 0.03, 0.035)},
	{"name": "ŞAHİN", "model": "sport_c", "color": Color.WHITE},
	{"name": "KURT", "model": "mohawk", "color": Color.WHITE},
	{"name": "TİLKİ", "model": "concept", "color": Color(0.6, 0.05, 0.08)},
	{"name": "ŞİMŞEK", "model": "sport_b", "color": Color.WHITE},
	{"name": "BORA", "model": "goblin", "color": Color(0.9, 0.5, 0.02)},
]
const PRIZES := [300, 180, 100, 50]
const UPGRADE_COST := [200, 400, 700, 1100, 1600]

var state := State.MENU
var track: Track
var model_scenes := {}
var car_seq := 0
var cars: Array = []
var player: Dictionary
var camera: Camera3D
var cam_shake := 0.0
var cam_dir := Vector3.ZERO
var countdown := 0.0
var race_time := 0.0
var finish_order: Array = []
var menu_angle := 0.0
var sfx := {}
var engine: AudioStreamPlayer
var skid: AudioStreamPlayer

# Girdi
var touches := {}          # dokunma indeksi -> bölge adı
var zones := {}            # bölge adı -> Control
var touch_mode := false
var autopilot := false   # test botu için
var debug_log := false

# Kayıt
var save := {"level": 1, "coins": 0, "paints": [0], "paint": 0, "motor": 0, "nitro": 0}
var paint_index := 0

# Arayüz
var hud: Control
var prog_label: Label
var pos_label: Label
var time_label: Label
var lap_label: Label
var nitro_bar: ProgressBar
var speedo: Control
var big_label: Label
var popup_label: Label
var menu: Control
var paint_label: Label
var buy_button: Button
var coin_label: Label
var motor_button: Button
var nitro_button: Button
var over: Control
var over_place: Label
var over_info: Label
var next_button: Button
var controls: Control


func _ready() -> void:
	randomize()
	_load_save()
	paint_index = int(save.paint)
	touch_mode = DisplayServer.is_touchscreen_available()
	for k in MODELS: model_scenes[k] = load(MODELS[k].path)
	for s in ["coin", "click", "nitro", "beep", "go"]:
		_add_sfx(s, load("res://sounds/%s.wav" % s))
	_add_sfx("impact", load("res://assets/audio/impact.ogg"))
	engine = _looping("res://assets/audio/engine.ogg", -4.0)
	skid = _looping("res://assets/audio/skid.ogg", -60.0)
	_build_world()
	_build_ui()
	_go_menu()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tool="):
			add_child(load("res://tools/%s.gd" % arg.substr(7)).new())


func _add_sfx(id: String, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = 3
	add_child(p)
	sfx[id] = p


func _looping(path: String, db: float) -> AudioStreamPlayer:
	var st: AudioStreamOggVorbis = load(path).duplicate()
	st.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	add_child(p)
	return p


# ---------------------------------------------------------------- dünya

func _build_world() -> void:
	var env := Environment.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/real/sky/kloofendal_48d_partly_cloudy_puresky.hdr")
	sky_mat.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.72, 0.58)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -135, 0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_blur = 1.5
	add_child(sun)

	track = Track.new()
	add_child(track)
	track.build(TRACK_POINTS, 1234)
	randomize()

	camera = Camera3D.new()
	camera.fov = 68
	camera.far = 1500
	camera.near = 0.1
	add_child(camera)


# ---------------------------------------------------------------- araçlar

func _make_car(model_id: String, color: Color, is_player: bool, start_s: float, lane: float, info := {}) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var body := Node3D.new()          # süspansiyon eğimi bu düğüme uygulanır
	root.add_child(body)
	var model := _load_model(model_id, body)
	if MODELS[model_id].paint: _paint(model, color)
	_fix_glass(model)
	var wheels := _rig_wheels(model, MODELS[model_id].wheels)
	var flames: Array = []
	for x in [-0.42, 0.42]:
		var f := _make_flame()
		f.position = Vector3(x, 0.42, -2.25)
		root.add_child(f)
		flames.append(f)
	var smoke := _make_smoke()
	smoke.position = Vector3(0, 0.3, -1.5)
	root.add_child(smoke)
	var sparks := _make_sparks()
	root.add_child(sparks)
	var tag: Label3D = null
	if not is_player:
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.fixed_size = true
		tag.pixel_size = 0.0011
		tag.font_size = 30
		tag.outline_size = 10
		tag.position = Vector3(0, 2.3, 0)
		tag.render_priority = 10
		tag.outline_render_priority = 9
		root.add_child(tag)
	car_seq += 1
	var p: Vector3 = track.point(start_s, lane)
	var t: Vector3 = track.tangent(start_s)
	var car := {
		"id": car_seq, "root": root, "body": body, "model": model, "model_id": model_id, "wheels": wheels,
		"flames": flames, "smoke": smoke, "sparks": sparks, "tag": tag, "name": info.get("name", "SEN"), "player": is_player,
		"pos": p, "vel": Vector3.ZERO, "yaw": atan2(t.x, t.z), "yaw_rate": 0.0,
		"s": start_s, "x": lane, "idx": track.idx(start_s), "vf": 0.0, "vl": 0.0,
		"steer": 0.0, "throttle": 0.0, "brake": false, "drift": false,
		"top": info.get("top", BASE_TOP), "acc": info.get("acc", 15.0), "skill": info.get("skill", 1.0),
		"nitro": 0.0, "boost": false, "finished": false, "wreck": 0.0,
		"wall_cd": 0.0, "bump_cd": 0.0, "ai_nitro_cd": randf_range(4, 9), "line": lane,
		"acc_long": 0.0, "acc_lat": 0.0, "stuck": 0.0, "wrong": 0.0,
	}
	_place(car, 0.0)
	return car


## Modeli yükler, 4.5 m uzunluğa ölçekler, yere oturtur ve önünü +Z'ye çevirir.
func _load_model(model_id: String, parent: Node3D) -> Node3D:
	var spec: Dictionary = MODELS[model_id]
	var holder := Node3D.new()
	parent.add_child(holder)
	var inst: Node3D = model_scenes[model_id].instantiate()
	holder.add_child(inst)
	var keep: Array = spec.keep
	if not keep.is_empty():
		var kept: Array = []
		for k in keep:
			var node := inst.find_child(k, true, false)
			if node: kept.append(node)
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var ok := false
			for k in kept:
				if k == m or k.is_ancestor_of(m): ok = true
			if not ok: m.visible = false
	for m in inst.find_children("*shadow*", "MeshInstance3D", true, false): m.visible = false
	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		if not m.visible: continue
		var b: AABB = holder.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	var rot: Basis = Basis(Vector3.UP, spec.yaw)
	var r_aabb: AABB = _rot_aabb(aabb, rot)
	var sc: float = 4.5 / maxf(r_aabb.size.z, 0.001)
	holder.basis = rot.scaled(Vector3.ONE * sc)
	var c: Vector3 = r_aabb.get_center()
	holder.position = Vector3(-c.x, -r_aabb.position.y, -c.z) * sc
	return holder


func _rot_aabb(a: AABB, b: Basis) -> AABB:
	var out := AABB(b * a.position, Vector3.ZERO)
	for i in 8: out = out.expand(b * a.get_endpoint(i))
	return out


func _paint(model: Node3D, color: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var is_shell := m3.name.begins_with("clearcoat")   # Goblin boya kabuğu
		for i in m3.mesh.get_surface_count():
			var m := m3.get_active_material(i)
			if not (m is BaseMaterial3D): continue
			var concept_paint: bool = m.resource_name.begins_with("Paint")
			if not (concept_paint or is_shell): continue
			var nm := StandardMaterial3D.new()
			nm.albedo_color = color.darkened(0.55) if m.resource_name.begins_with("Paint 2") else color
			nm.metallic = 0.55
			nm.roughness = 0.22
			nm.clearcoat_enabled = true
			nm.clearcoat = 1.0
			nm.clearcoat_roughness = 0.04
			m3.set_surface_override_material(i, nm)


## Desteklenmeyen cam efektleri beyaz görünmesin: koyu, yarı saydam, parlak cam.
func _fix_glass(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var m := m3.get_active_material(i)
			if m == null: continue
			var n := m.resource_name.to_lower()
			if (n == "glass" or n == "car_glass" or n.begins_with("glass ")) and not n.contains("red"):
				var g := StandardMaterial3D.new()
				g.albedo_color = Color(0.03, 0.04, 0.05, 0.75)
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.metallic = 0.9
				g.roughness = 0.04
				m3.set_surface_override_material(i, g)


## Tekerlekleri merkezlerinde dönebilsinler diye pivot düğümlerine bağlar.
func _rig_wheels(model: Node3D, pattern: String) -> Array:
	var out: Array = []
	if pattern == "": return out
	var body: Node3D = model.get_parent()
	for w in model.find_children(pattern, "Node3D", true, false):
		var node := w as Node3D
		if node.get_parent().name.begins_with("bone_rotation") or node.get_parent().name.begins_with("mc-wheel"): continue
		var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D: meshes.append(node)
		if meshes.is_empty() or not (meshes[0] as MeshInstance3D).visible: continue
		var aabb := AABB()
		var first := true
		for m in meshes:
			var b: AABB = node.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
		var parent: Node3D = node.get_parent()
		var center: Vector3 = node.transform * aabb.get_center()
		var pivot := Node3D.new()
		pivot.position = center
		parent.add_child(pivot)
		parent.remove_child(node)
		pivot.add_child(node)
		node.transform.origin = node.transform.origin - center
		var inv: Basis = parent.global_basis.orthonormalized().inverse()
		var rb: Basis = body.global_basis.orthonormalized()
		var nm := String(node.name)
		var front: bool = nm.contains("Front") or nm.contains("Ft") or nm.contains("_F")
		out.append({"pivot": pivot, "front": front, "axle": (inv * (rb * Vector3.RIGHT)).normalized(), "up": (inv * (rb * Vector3.UP)).normalized(), "spin": 0.0, "base": pivot.basis})
	return out


func _make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 40
	p.lifetime = 0.18
	p.local_coords = true
	p.direction = Vector3(0, 0, -1)
	p.spread = 6.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45
	var q := SphereMesh.new()
	q.radius = 0.5
	q.height = 1.0
	q.radial_segments = 8
	q.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.6, 1.8, 3.0, 1.0))
	g.set_color(1, Color(0.1, 0.3, 1.5, 0.0))
	p.color_ramp = g
	return p


func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 50
	p.lifetime = 1.2
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.05, 0.2)
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.5))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/sprites/smoke.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.8, 0.75, 0.55))
	g.set_color(1, Color(0.85, 0.8, 0.75, 0.0))
	p.color_ramp = g
	return p


func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 30
	p.lifetime = 0.5
	p.local_coords = false
	p.direction = Vector3(0, 0.6, -1)
	p.spread = 45.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.08
	var q := SphereMesh.new()
	q.radial_segments = 4
	q.rings = 2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(3.0, 2.0, 0.6)
	q.material = m
	p.mesh = q
	return p


## Görsel: konum, yön, gövde eğimi (ağırlık aktarımı), tekerlekler.
func _place(car: Dictionary, delta: float) -> void:
	var root: Node3D = car.root
	root.position = car.pos
	root.rotation.y = car.yaw
	var body: Node3D = car.body
	var pitch: float = clampf(-car.acc_long * 0.0035, -0.05, 0.05)
	var roll: float = clampf(car.acc_lat * 0.0016, -0.07, 0.07)
	if delta > 0.0:
		body.rotation.x = lerpf(body.rotation.x, pitch, 1.0 - exp(-delta * 6.0))
		body.rotation.z = lerpf(body.rotation.z, roll, 1.0 - exp(-delta * 6.0))
	for w in car.wheels:
		w.spin += car.vf * delta / 0.34
		var steer_a: float = -car.steer * 0.45 if w.front else 0.0
		w.pivot.basis = Basis(w.up, steer_a) * Basis(w.axle, w.spin) * w.base


## Pist koordinatlarını (ilerleme s, yanal x) güncelle.
func _track_sync(car: Dictionary) -> void:
	var pr: Array = track.project(car.pos, car.idx)
	car.idx = pr[0]
	car.x = pr[1]
	var s_raw: float = pr[2]
	var prev: float = fposmod(car.s, track.length)
	var d: float = s_raw - prev
	if d > track.length * 0.5: d -= track.length
	elif d < -track.length * 0.5: d += track.length
	car.s += d


## Ortak sürüş fiziği (dünya koordinatlarında, arcade).
func _physics(car: Dictionary, delta: float) -> void:
	var top: float = car.top + (NITRO_ADD if car.boost else 0.0)
	if car.boost:
		car.nitro -= delta * (0.2 - (0.025 * int(save.nitro) if car.player else 0.0))
		if car.nitro <= 0.0:
			car.nitro = 0.0
			car.boost = false
	for f in car.flames: f.emitting = car.boost
	var wrecked: bool = car.wreck > 0.0
	# Direksiyon: hızla azalan dönüş oranı; drift'te daha keskin
	var vf_prev: float = car.vf
	var spd: float = maxf(car.vf, 0.0)
	var max_rate: float = lerpf(1.9, 0.95, clampf(spd / 75.0, 0.0, 1.0)) * clampf(spd / 6.0, 0.0, 1.0)
	var target_rate: float = car.steer * max_rate * (1.45 if car.drift else 1.0)
	if wrecked: target_rate = 7.0 * signf(car.yaw_rate if car.yaw_rate != 0.0 else 1.0)
	car.yaw_rate = lerpf(car.yaw_rate, target_rate, 1.0 - exp(-delta * (3.0 if wrecked else 7.0)))
	car.yaw -= car.yaw_rate * delta
	var fwd := Vector3(sin(car.yaw), 0, cos(car.yaw))
	var right := fwd.cross(Vector3.UP)
	var vel: Vector3 = car.vel
	var vf: float = vel.dot(fwd)
	var vl: float = vel.dot(right)
	var racing: bool = state == State.RACE or car.finished
	# Boyuna
	if wrecked:
		vf = move_toward(vf, 0.0, 18.0 * delta)
	elif car.brake and not car.drift:
		vf = move_toward(vf, 0.0, BRAKE_DEC * delta)
	elif racing and car.throttle > 0.0:
		var acc: float = car.acc * pow(clampf(1.0 - vf / top, 0.0, 1.0), 0.6) + (14.0 if car.boost else 0.0)
		if vf > top: vf = move_toward(vf, top, 7.0 * delta)
		else: vf = minf(vf + acc * car.throttle * delta, top)
	else:
		vf = move_toward(vf, 0.0, 3.0 * delta)
	if car.drift: vf = move_toward(vf, 0.0, 5.0 * delta)
	var offroad: bool = absf(car.x) > Track.HALF
	if offroad and vf > 38.0: vf = move_toward(vf, 38.0, 18.0 * delta)
	# Yanal tutuş
	var grip: float = DRIFT_GRIP if car.drift else GRIP
	if wrecked: grip = 1.0
	if offroad: grip *= 0.7
	vl *= exp(-grip * delta)
	car.vel = fwd * vf + right * vl
	car.pos += car.vel * delta
	car.pos.y = 0.0
	car.vf = vf
	car.vl = vl
	car.acc_long = lerpf(car.acc_long, (vf - vf_prev) / maxf(delta, 0.001), 0.2)
	car.acc_lat = lerpf(car.acc_lat, vf * car.yaw_rate, 0.2)
	_track_sync(car)
	_walls(car, delta)
	if wrecked:
		car.wreck -= delta
		if car.wreck <= 0.0: _recover(car, false)
	var sliding: bool = absf(vl) > 5.0 and vf > 15.0
	car.smoke.emitting = sliding or car.drift and vf > 20.0
	_place(car, delta)


## Bariyerler: içeri it, hızın duvara dik bileşenini sektir, sürtünme.
func _walls(car: Dictionary, delta: float) -> void:
	car.wall_cd -= delta
	if absf(car.x) <= WALL: return
	var i: int = car.idx
	var n: Vector3 = track.right[i] * signf(car.x)
	var pen: float = absf(car.x) - WALL
	car.pos -= n * pen
	car.x = signf(car.x) * WALL
	var vn: float = car.vel.dot(n)
	if vn > 0.0:
		car.vel -= n * vn * 1.3
		car.vel *= 1.0 - minf(0.25, vn * 0.015)
		var ty: float = atan2(track.tan[i].x, track.tan[i].z)
		car.yaw = lerp_angle(car.yaw, ty, minf(0.25, vn * 0.03))
		car.yaw_rate *= 0.5
		if car.wall_cd <= 0.0 and vn > 3.0:
			car.wall_cd = 0.35
			car.wall_hits = car.get("wall_hits", 0) + 1
			if debug_log: print("  DUVAR ", car.name, " x=", snappedf(car.x, 0.1), " s=", int(fposmod(car.s, track.length)), " vn=", snappedf(vn, 0.1), " v=", int(car.vf * 3.6), " k=", snappedf(track.curvature(car.s), 0.0001))
			var sp: CPUParticles3D = car.sparks
			sp.global_position = car.pos + n * 1.0 + Vector3.UP * 0.5
			sp.restart()
			if car.player:
				cam_shake = clampf(vn * 0.06, 0.2, 0.8)
				sfx.impact.volume_db = linear_to_db(clampf(vn / 15.0, 0.3, 1.0))
				sfx.impact.play()
				Input.vibrate_handheld(int(clampf(vn * 8.0, 40, 200)))


## Araç-araç çarpışması: her araca iki daire, itme + darbe + dönme.
func _collide(delta: float) -> void:
	for i in cars.size():
		cars[i].bump_cd -= delta
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a: Dictionary = cars[i]
			var b: Dictionary = cars[j]
			if a.pos.distance_squared_to(b.pos) > 36.0: continue
			var fa: Vector3 = Vector3(sin(a.yaw), 0, cos(a.yaw))
			var fb: Vector3 = Vector3(sin(b.yaw), 0, cos(b.yaw))
			for oa in [-CIRCLE_OFF, CIRCLE_OFF]:
				for ob in [-CIRCLE_OFF, CIRCLE_OFF]:
					var ca: Vector3 = a.pos + fa * oa
					var cb: Vector3 = b.pos + fb * ob
					var d: Vector3 = ca - cb
					d.y = 0.0
					var dist: float = d.length()
					if dist >= CAR_R * 2.0 or dist < 0.001: continue
					var n: Vector3 = d / dist
					var pen: float = CAR_R * 2.0 - dist
					a.pos += n * pen * 0.5
					b.pos -= n * pen * 0.5
					var rel: float = (a.vel - b.vel).dot(n)
					if rel >= 0.0: continue
					var jimp: float = -(1.0 + 0.35) * rel * 0.5
					a.vel += n * jimp
					b.vel -= n * jimp
					a.yaw_rate += clampf(fa.cross(n).y * oa * jimp * 0.12, -2.0, 2.0)
					b.yaw_rate -= clampf(fb.cross(n).y * ob * jimp * 0.12, -2.0, 2.0)
					if debug_log and -rel > 4.0: print("  ÇARPIŞMA ", a.name, "-", b.name, " güç=", snappedf(-rel, 0.1), " s=", int(fposmod(a.s, track.length)))
					_impact(a, b, -rel)


func _impact(a: Dictionary, b: Dictionary, strength: float) -> void:
	if not (a.player or b.player): return
	var me: Dictionary = a if a.player else b
	var other: Dictionary = b if a.player else a
	if me.bump_cd > 0.0: return
	me.bump_cd = 0.4
	cam_shake = maxf(cam_shake, clampf(strength * 0.05, 0.2, 0.7))
	sfx.impact.volume_db = linear_to_db(clampf(strength / 15.0, 0.3, 1.0))
	sfx.impact.play()
	var sp: CPUParticles3D = other.sparks
	sp.global_position = (a.pos + b.pos) * 0.5 + Vector3.UP * 0.6
	sp.restart()
	# Sert vuruş + nitro ya da yüksek hız: rakip kaza yapar (takedown)
	if strength > 7.0 and other.wreck <= 0.0 and not other.finished and (me.boost or me.vf > other.vf + 4.0):
		other.wreck = 1.6
		other.yaw_rate = 6.0 * (1.0 if randf() < 0.5 else -1.0)
		me.nitro = minf(me.nitro + 0.35, 1.0)
		_popup("TAKEDOWN!  +NİTRO", Color(1.0, 0.4, 0.25))
		Input.vibrate_handheld(150)


## Kaza / ters yön / takılma sonrası aracı pistin üzerine düzgünce geri koy.
func _recover(car: Dictionary, to_center: bool) -> void:
	var s: float = car.s
	var x: float = 0.0 if to_center else clampf(car.x, -Track.HALF + 2.0, Track.HALF - 2.0)
	car.pos = track.point(s, x)
	var t: Vector3 = track.tangent(s)
	car.yaw = atan2(t.x, t.z)
	car.yaw_rate = 0.0
	car.vel = t * clampf(car.vf, 18.0, 30.0)
	car.wreck = 0.0
	car.stuck = 0.0
	car.wrong = 0.0
	if car.player:
		_popup("PİSTE DÖNDÜN", Color(0.8, 0.9, 1.0))


func _player_input(car: Dictionary, delta: float) -> void:
	var u: float = 0.0
	if _pressed("left"): u -= 1.0
	if _pressed("right"): u += 1.0
	var brake: bool = _pressed("brake")
	if autopilot:
		_ai_input(car, delta)
		u = car.steer
		brake = car.brake
	# Klavye dijital: yumuşak direksiyon
	car.steer = move_toward(car.steer, u, delta * (4.0 if absf(u) > 0.0 else 7.0))
	# Şerit yardımcısı (gündelik oyuncu için): direksiyon bırakılınca pist yönüne hizala
	if absf(u) < 0.05 and not autopilot and car.wreck <= 0.0:
		var t: Vector3 = track.tangent(car.s + 18.0)
		var diff: float = wrapf(atan2(t.x, t.z) - car.yaw, -PI, PI)
		car.steer += clampf(-diff * 1.6, -0.35, 0.35)
	car.throttle = 1.0
	car.drift = brake and absf(car.steer) > 0.25 and car.vf > 22.0
	car.brake = brake
	var straight_ahead: bool = absf(track.curvature(car.s + 60.0)) < 0.002 and absf(track.curvature(car.s + 140.0)) < 0.002
	if (_pressed("nitro") or (autopilot and car.nitro > 0.95 and straight_ahead)) and car.nitro > 0.08: car.boost = true
	# Nitro kazanımı: zamanla, drift ve kaymayla
	if not car.boost: car.nitro = minf(car.nitro + delta * (0.03 + 0.008 * int(save.nitro)), 1.0)
	if car.drift or absf(car.vl) > 5.0: car.nitro = minf(car.nitro + delta * 0.2, 1.0)
	skid.volume_db = lerpf(skid.volume_db, -8.0 if (car.drift or absf(car.vl) > 5.0) and car.vf > 15.0 else -60.0, delta * 8.0)
	# Ters yön / takılma: otomatik toparla
	var t2: Vector3 = track.tangent(car.s)
	var fwd: Vector3 = Vector3(sin(car.yaw), 0, cos(car.yaw))
	car.wrong = car.wrong + delta if fwd.dot(t2) < -0.2 else 0.0
	car.stuck = car.stuck + delta if car.vf < 4.0 and state == State.RACE else 0.0
	if car.wrong > 2.0 or car.stuck > 2.5 or Input.is_physical_key_pressed(KEY_R):
		_recover(car, true)


## Yapay zekâ sürücü: yarış çizgisini takip et, viraj öncesi yavaşla, sollamak için şerit değiştir.
func _ai_input(car: Dictionary, delta: float) -> void:
	var v: float = maxf(car.vf, 10.0)
	var look: float = 9.0 + v * 0.42
	var k: float = track.curvature(car.s + look)
	var line: float = clampf(signf(k) * minf(absf(k) * 450.0, 3.5), -4.0, 4.0)
	var follow: float = INF
	for o in cars:
		if o == car: continue
		var ds: float = o.s - car.s
		if ds > 0.0 and ds < 30.0 and absf(o.x - car.x) < 3.0:
			line = o.x - 4.2 if o.x > 0.0 else o.x + 4.2
			# Yer açılmadıysa çarpma, arkasında kal
			if ds < 9.0 and absf(o.x - car.x) < 2.3: follow = minf(follow, o.vf - 1.0)
		elif ds > -6.0 and ds < 6.0 and absf(o.x - line) < 2.6:
			line = car.x   # yanında araç var: o şeride geçme
	car.line = move_toward(car.line, clampf(line, -WALL + 0.8, WALL - 0.8), delta * 6.0)
	var target: Vector3 = track.point(car.s + look, car.line)
	var dir: Vector3 = target - car.pos
	var want: float = atan2(dir.x, dir.z)
	var diff: float = wrapf(want - car.yaw, -PI, PI)
	# İleri besleme (virajın gerektirdiği dönüş) + geri besleme (hedef noktaya yönel)
	var spd_ai: float = maxf(car.vf, 5.0)
	var rate_max: float = lerpf(1.9, 0.95, clampf(spd_ai / 75.0, 0.0, 1.0)) * clampf(spd_ai / 6.0, 0.0, 1.0)
	var ff: float = track.curvature(car.s + spd_ai * 0.25) * spd_ai / maxf(rate_max, 0.1)
	car.steer = clampf(ff * 0.6 - diff * 2.2, -1.0, 1.0)
	# Hedef hız: önümüzdeki virajlara göre frenleme mesafesi
	var top: float = car.top + (NITRO_ADD if car.boost else 0.0)
	var vt: float = top
	var d := 0.0
	while d < 160.0:
		var kk: float = absf(track.curvature(car.s + d))
		var vc: float = sqrt(A_LAT_AI * car.skill / maxf(kk, 0.0001))
		vt = minf(vt, sqrt(vc * vc + 2.0 * 26.0 * d))
		d += 8.0
	vt = minf(vt, follow)
	if not car.player:
		var gap: float = car.s - player.s
		if gap > 70.0: vt *= 0.92
		elif gap < -70.0: vt *= 1.06
	car.throttle = 1.0 if car.vf < vt else 0.0
	car.brake = car.vf > vt + 4.0
	car.drift = false
	if car.finished and not car.player:
		car.throttle = 1.0 if car.vf < 35.0 else 0.0
	if not car.player:
		car.ai_nitro_cd -= delta
		if car.ai_nitro_cd <= 0.0 and absf(k) < 0.002 and absf(track.curvature(car.s + 150.0)) < 0.002 and state == State.RACE:
			car.nitro = 0.6
			car.boost = true
			car.ai_nitro_cd = randf_range(9, 18)


# ---------------------------------------------------------------- yarış

func _setup_grid() -> void:
	for c in cars: c.root.queue_free()
	cars.clear()
	finish_order.clear()
	var level := int(save.level)
	var diff := clampf((level - 1) / 10.0, 0.0, 1.0)
	var rivals := RIVALS.duplicate()
	rivals.shuffle()
	for i in 4:
		var row := i / 2
		var lane: float = -2.25 if i % 2 == 0 else 2.25
		var s := -10.0 - row * 9.0 - (4.0 if i % 2 else 0.0)
		if i == 3:
			player = _make_car(GARAGE[paint_index].model, GARAGE[paint_index].color, true, s, lane, {"top": BASE_TOP + 2.0 * int(save.motor), "acc": 15.0 + int(save.motor)})
			cars.append(player)
		else:
			var r: Dictionary = rivals[i]
			cars.append(_make_car(r.model, r.color, false, s, lane, {
				"name": r.name, "top": lerpf(60.0, 80.0, diff) + (2 - i) * 1.2 + randf_range(-1.0, 1.0),
				"acc": lerpf(12.5, 16.5, diff), "skill": lerpf(0.82, 1.0, diff) + randf_range(-0.03, 0.03),
			}))


func _go_menu() -> void:
	state = State.MENU
	_setup_grid()
	engine.stop()
	skid.stop()
	hud.visible = false
	controls.visible = false
	over.visible = false
	menu.visible = true
	_refresh_menu()


func _start_race() -> void:
	if not save.paints.has(paint_index): return
	save.paint = paint_index
	_write_save()
	_setup_grid()
	state = State.COUNTDOWN
	countdown = 3.0
	cam_dir = Vector3.ZERO
	race_time = 0.0
	menu.visible = false
	over.visible = false
	hud.visible = true
	controls.visible = touch_mode
	touches.clear()
	engine.play()
	skid.play()
	sfx.beep.play()
	big_label.text = "3"
	_pop(big_label)


func _finish_player() -> void:
	state = State.FINISHED
	var place: int = finish_order.find(player) + 1
	var prize: int = PRIZES[place - 1]
	save.coins = int(save.coins) + prize
	if place == 1: save.level = int(save.level) + 1
	_write_save()
	over_place.text = ["1.", "2.", "3.", "4."][place - 1]
	over_place.add_theme_color_override("font_color", [Color(1, 0.82, 0.2), Color(0.85, 0.88, 0.95), Color(0.9, 0.6, 0.35), Color(0.8, 0.8, 0.8)][place - 1])
	over_info.text = "%s\nSÜRE  %s\n+%d COIN" % [["ZAFER!", "İKİNCİ", "ÜÇÜNCÜ", "SONUNCU"][place - 1], _fmt_time(race_time), prize]
	next_button.text = "SONRAKİ YARIŞ" if place == 1 else "TEKRAR DENE"
	controls.visible = false
	hud.visible = false
	await get_tree().create_timer(1.5).timeout
	if state != State.FINISHED: return
	over.visible = true
	over.modulate.a = 0.0
	create_tween().tween_property(over, "modulate:a", 1.0, 0.3)
	sfx.coin.play()


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	match state:
		State.MENU:
			menu_angle += delta * 0.25
			var p: Vector3 = player.root.position
			var f: Vector3 = track.tangent(player.s)
			var r: Vector3 = f.cross(Vector3.UP)
			var off: Vector3 = (-f * cos(menu_angle) + r * sin(menu_angle)) * 7.5
			camera.position = p + off + Vector3.UP * 2.0
			camera.look_at(p + Vector3.UP * 0.6)
			camera.fov = 45
			return
		State.COUNTDOWN:
			var before := ceili(countdown)
			countdown -= delta
			if countdown <= 0.0:
				state = State.RACE
				big_label.text = "GO!"
				_pop(big_label)
				sfx.go.play()
			elif ceili(countdown) != before:
				big_label.text = str(ceili(countdown))
				_pop(big_label)
				sfx.beep.play()
			engine.pitch_scale = 0.8 + (0.5 if _pressed("nitro") else 0.0)
			for c in cars: _place(c, delta)
		State.RACE, State.FINISHED:
			if state == State.RACE: race_time += delta
			var ranks_before := _ranks()
			for c in cars:
				if c.player and not c.finished: _player_input(c, delta)
				elif c.wreck <= 0.0: _ai_input(c, delta)
			# Kararlılık için iki alt adım
			for k in 2:
				for c in cars: _physics(c, delta * 0.5)
				_collide(delta * 0.5)
			_near_miss()
			for c in cars:
				if not c.finished and c.s >= LAPS * track.length:
					c.finished = true
					finish_order.append(c)
					if c.player: _finish_player()
			_overtake_check(ranks_before)
			# Vites hissi: her vitesde devir yükselip düşer
			var kmh: float = maxf(player.vf, 0.0) * 3.6
			var gear: int = mini(int(kmh / 55.0), 5)
			var rpm: float = fmod(kmh, 55.0) / 55.0 if gear < 5 else clampf((kmh - 275.0) / 80.0, 0.0, 1.0)
			engine.pitch_scale = 0.75 + rpm * 0.75 + gear * 0.06 + (0.1 if player.boost else 0.0)
	_update_camera(delta)
	_update_hud()


func _ranks() -> Dictionary:
	var sorted := cars.duplicate()
	sorted.sort_custom(func(a, b): return a.s > b.s)
	var out := {}
	for i in sorted.size(): out[sorted[i].id] = i + 1
	# Bitirenler bitiş sırasına göre
	for i in finish_order.size(): out[finish_order[i].id] = i + 1
	return out


func _near_miss() -> void:
	if state != State.RACE or player.vf < 35.0: return
	for c in cars:
		if c == player or c.get("nm", false): continue
		var ds: float = player.s - c.s
		if ds > 0.0 and ds < 3.0 and absf(c.x - player.x) < 3.2:
			c.nm = true
			player.nitro = minf(player.nitro + 0.08, 1.0)
			_popup("YAKIN GEÇİŞ  +NİTRO", Color(0.6, 0.9, 1.0))
		elif ds < -10.0 or ds > 20.0:
			c.nm = false


func _overtake_check(before: Dictionary) -> void:
	if state != State.RACE: return
	var now := _ranks()
	if now[player.id] < before[player.id]:
		_popup("SOLLAMA!  +NİTRO", Color(1.0, 0.85, 0.25))
		player.nitro = minf(player.nitro + 0.15, 1.0)


func _update_camera(delta: float) -> void:
	var root: Node3D = player.root
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var vdir: Vector3 = player.vel.normalized() if player.vel.length() > 5.0 else fwd
	var want: Vector3 = fwd.lerp(vdir, 0.5).normalized()
	# Sadece yön yumuşatılır; mesafe sabit kalır. Drift'te kamera hafif geride kalır, kayma görünür.
	cam_dir = cam_dir.slerp(want, 1.0 - exp(-delta * 5.0)).normalized() if cam_dir.length() > 0.5 else want
	var v: float = maxf(player.vf, 0.0)
	var dist: float = 5.6 + v * 0.01 - (0.5 if player.boost else 0.0)
	var height: float = 1.75 + v * 0.003
	camera.position = root.position - cam_dir * dist + Vector3.UP * height
	camera.look_at(root.position + cam_dir * 7.0 + Vector3.UP * 0.9)
	var fov: float = 64.0 + v * 0.13 + (10.0 if player.boost else 0.0)
	camera.fov = lerpf(camera.fov, fov, delta * 3.0)
	if cam_shake > 0.0:
		cam_shake = maxf(cam_shake - delta * 2.5, 0.0)
		var s := cam_shake * cam_shake * 0.35
		camera.position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	if player.boost and state == State.RACE:
		var s2 := 0.02
		camera.position += Vector3(randf_range(-s2, s2), randf_range(-s2, s2), 0)

# ---------------------------------------------------------------- girdi

func _pressed(zone: String) -> bool:
	for z in touches.values():
		if z == zone: return true
	match zone:
		"left": return Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
		"right": return Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
		"brake": return Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		"nitro": return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)
	return false


func _zone_at(p: Vector2) -> String:
	for name in zones:
		var c: Control = zones[name]
		if c.get_global_rect().grow(20).has_point(p): return name
	return ""


func _input(event: InputEvent) -> void:
	if state != State.RACE and state != State.COUNTDOWN:
		return
	if event is InputEventScreenTouch:
		touch_mode = true
		if event.pressed:
			var z := _zone_at(event.position)
			if z != "": touches[event.index] = z
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var z := _zone_at(event.position)
		if z != "" and z != "nitro": touches[event.index] = z
	elif event is InputEventMouseButton and not touch_mode and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var z := _zone_at(event.position)
			if z != "": touches[-1] = z
		else:
			touches.erase(-1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			if state == State.MENU: _start_race()
			elif over.visible: _start_race()
		elif event.keycode == KEY_ESCAPE and state != State.MENU:
			_go_menu()


# ---------------------------------------------------------------- arayüz

func _fmt_time(t: float) -> String:
	return "%d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 30
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.55, 0.08)
	normal.set_corner_radius_all(10)
	normal.skew = Vector2(-0.2, 0)
	normal.border_width_bottom = 5
	normal.border_color = Color(0.6, 0.25, 0.0)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 8
	normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.65, 0.2)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.9, 0.45, 0.05)
	pressed.border_width_bottom = 1
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.35, 0.35, 0.38, 0.9)
	disabled.border_color = Color(0.2, 0.2, 0.22)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		th.set_color(k, "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.72))
	th.set_color("font_outline_color", "Button", Color(0.3, 0.1, 0.0))
	th.set_constant("outline_size", "Button", 6)
	th.set_font_size("font_size", "Button", 34)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 8)
	return th


func _label(text: String, size: int, parent: Control, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## (ax, ay) çapası + piksel ofset ile w×h kutu
func _box(c: Control, ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox - w * 0.5
	c.offset_right = ox + w * 0.5
	c.offset_top = oy - h * 0.5
	c.offset_bottom = oy + h * 0.5
	c.pivot_offset = Vector2(w, h) * 0.5


func _panel(parent: Control, color := Color(0, 0, 0, 0.45)) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.skew = Vector2(-0.2, 0)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _button(text: String, parent: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): sfx.click.play(); cb.call())
	parent.add_child(b)
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	_full(root)
	root.theme = _theme()
	layer.add_child(root)

	# --- HUD
	hud = Control.new()
	_full(hud)
	root.add_child(hud)
	var pl := _panel(hud)
	_box(pl, 0, 0, 120, 62, 200, 96)
	_label("İLERLEME", 20, hud, Color(1, 0.75, 0.3), HORIZONTAL_ALIGNMENT_LEFT).position = Vector2(36, 18)
	prog_label = _label("0 %", 46, hud, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	prog_label.position = Vector2(34, 40)
	lap_label = _label("TUR 1/2", 22, hud, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	lap_label.position = Vector2(36, 118)
	var pr := _panel(hud)
	_box(pr, 1, 0, -120, 62, 200, 96)
	var sl := _label("SIRA", 20, hud, Color(1, 0.75, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	_box(sl, 1, 0, -100, 26, 140, 30)
	pos_label = _label("4/4", 50, hud, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_box(pos_label, 1, 0, -100, 72, 160, 56)
	time_label = _label("0:00.00", 26, hud, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_box(time_label, 1, 0, -100, 132, 200, 34)
	nitro_bar = ProgressBar.new()
	nitro_bar.show_percentage = false
	nitro_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.skew = Vector2(-0.3, 0)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.25, 0.75, 1.0)
	fg.skew = Vector2(-0.3, 0)
	fg.set_corner_radius_all(4)
	nitro_bar.add_theme_stylebox_override("background", bg)
	nitro_bar.add_theme_stylebox_override("fill", fg)
	nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(nitro_bar, 0.5, 0, 20, 34, 380, 20)
	hud.add_child(nitro_bar)
	var nl := _label("N₂O", 26, hud, Color(0.5, 0.85, 1.0))
	_box(nl, 0.5, 0, -210, 34, 70, 34)
	speedo = Control.new()
	speedo.set_script(load("res://scripts/speedo.gd"))
	_box(speedo, 1, 1, -140, -140, 250, 250)
	hud.add_child(speedo)
	big_label = _label("", 140, hud, Color(1.0, 0.85, 0.2))
	_box(big_label, 0.5, 0.4, 0, 0, 800, 180)
	big_label.modulate.a = 0
	popup_label = _label("", 40, hud, Color.WHITE)
	_box(popup_label, 0.5, 0.25, 0, 0, 900, 70)
	popup_label.modulate.a = 0

	# --- Dokunmatik kontroller
	controls = Control.new()
	_full(controls)
	root.add_child(controls)
	zones["left"] = _zone(controls, "‹", 0, 1, 110, -95, 170, 140)
	zones["right"] = _zone(controls, "›", 0, 1, 300, -95, 170, 140)
	zones["brake"] = _zone(controls, "FREN", 1, 1, -370, -80, 130, 100)
	zones["nitro"] = _zone(controls, "NİTRO", 1, 1, -125, -320, 150, 110, Color(0.05, 0.35, 0.8, 0.55))
	var keys := _label("A / D  direksiyon     S  fren-drift     BOŞLUK  nitro     ESC  menü", 18, hud, Color(1, 1, 1, 0.7))
	_box(keys, 0.5, 1, -60, -22, 900, 30)
	keys.visible = not touch_mode

	# --- Menü
	menu = Control.new()
	_full(menu)
	root.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	_full(shade)
	menu.add_child(shade)
	var title := _label("HİPER YARIŞ", 92, menu, Color(1.0, 0.6, 0.1))
	_box(title, 0.5, 0, 0, 70, 1000, 110)
	var sub := _label("KANYON  •  4 ARAÇ  •  2 TUR", 26, menu, Color(1, 1, 1, 0.9))
	_box(sub, 0.5, 0, 0, 128, 800, 36)
	coin_label = _label("", 30, menu, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	_box(coin_label, 1, 0, -170, 40, 300, 40)
	var lp := _button("◀", menu, _paint_step.bind(-1))
	_box(lp, 0.5, 1, -310, -170, 90, 80)
	var rp := _button("▶", menu, _paint_step.bind(1))
	_box(rp, 0.5, 1, 310, -170, 90, 80)
	paint_label = _label("", 34, menu)
	_box(paint_label, 0.5, 1, 0, -170, 520, 60)
	buy_button = _button("YARIŞ!", menu, _on_main_button)
	_box(buy_button, 0.5, 1, 0, -75, 360, 84)
	motor_button = _button("", menu, _upgrade.bind("motor"))
	motor_button.add_theme_font_size_override("font_size", 22)
	_box(motor_button, 0, 0, 180, 215, 300, 64)
	nitro_button = _button("", menu, _upgrade.bind("nitro"))
	nitro_button.add_theme_font_size_override("font_size", 22)
	_box(nitro_button, 0, 0, 180, 290, 300, 64)
	var credit := _label("Araç: CarConcept © Eric Chadwick/DGG (CC BY 4.0) · Çevre: Poly Haven (CC0) · Ses: Kenney (CC0)", 14, menu, Color(1, 1, 1, 0.55))
	_box(credit, 0.5, 1, 0, -14, 1200, 22)

	# --- Yarış sonu
	over = Control.new()
	_full(over)
	root.add_child(over)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	_full(dim)
	over.add_child(dim)
	over_place = _label("1.", 180, over)
	_box(over_place, 0.5, 0.28, 0, 0, 500, 220)
	over_info = _label("", 40, over)
	_box(over_info, 0.5, 0.58, 0, 0, 800, 170)
	next_button = _button("SONRAKİ YARIŞ", over, _start_race)
	_box(next_button, 0.5, 0.82, -170, 0, 320, 80)
	var garage := _button("GARAJ", over, _go_menu)
	_box(garage, 0.5, 0.82, 180, 0, 240, 80)


func _zone(parent: Control, text: String, ax: float, ay: float, ox: float, oy: float, w: float, h: float, color := Color(0.05, 0.07, 0.1, 0.45)) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(minf(w, h) * 0.3))
	sb.corner_detail = 12
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(p, ax, ay, ox, oy, w, h)
	parent.add_child(p)
	var l := _label(text, 24 if text.length() > 2 else 60, p)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return p

func _update_hud() -> void:
	if not hud.visible: return
	var ranks := _ranks()
	pos_label.text = "%d/4" % ranks[player.id]
	var prog: float = clampf(player.s / (LAPS * track.length), 0.0, 1.0)
	prog_label.text = "%d %%" % int(prog * 100.0)
	lap_label.text = "TUR %d/%d" % [clampi(int(player.s / track.length) + 1, 1, LAPS), LAPS]
	time_label.text = _fmt_time(race_time)
	nitro_bar.value = player.nitro
	speedo.speed_kmh = maxf(player.vf, 0.0) * 3.6
	speedo.nitro = player.nitro
	speedo.boosting = player.boost
	for c in cars:
		if c.tag:
			var r: int = ranks[c.id]
			c.tag.text = "%d.  %s" % [r, c.name]
			c.tag.modulate = Color(1, 0.85, 0.3) if r == 1 else Color.WHITE
			var ahead: float = c.s - player.s
			c.tag.visible = ahead > 6.0 and ahead < 140.0
	for name in zones:
		var z: Control = zones[name]
		z.modulate.a = 1.0 if _pressed(name) else 0.7


func _paint_step(d: int) -> void:
	paint_index = wrapi(paint_index + d, 0, GARAGE.size())
	var old: Dictionary = player
	var g: Dictionary = GARAGE[paint_index]
	player = _make_car(g.model, g.color, true, old.s, old.x, {"top": old.top, "acc": old.acc})
	cars[cars.find(old)] = player
	old.root.queue_free()
	_refresh_menu()


func _on_main_button() -> void:
	if save.paints.has(paint_index):
		_start_race()
	elif int(save.coins) >= int(GARAGE[paint_index].price):
		save.coins = int(save.coins) - int(GARAGE[paint_index].price)
		save.paints.append(paint_index)
		save.paint = paint_index
		_write_save()
		sfx.coin.play()
		_refresh_menu()


func _upgrade(kind: String) -> void:
	var lvl: int = int(save[kind])
	if lvl >= UPGRADE_COST.size() or int(save.coins) < UPGRADE_COST[lvl]: return
	save.coins = int(save.coins) - UPGRADE_COST[lvl]
	save[kind] = lvl + 1
	_write_save()
	sfx.coin.play()
	_refresh_menu()


func _refresh_menu() -> void:
	var p: Dictionary = GARAGE[paint_index]
	var owned: bool = save.paints.has(paint_index)
	paint_label.text = p.name + ("" if owned else "  —  %d ●" % p.price)
	buy_button.text = "YARIŞ!" if owned else "SATIN AL"
	buy_button.disabled = not owned and int(save.coins) < int(p.price)
	coin_label.text = "● %d    YARIŞ %d" % [save.coins, save.level]
	for pair in [[motor_button, "motor", "MOTOR"], [nitro_button, "nitro", "NİTRO"]]:
		var lvl: int = int(save[pair[1]])
		var b: Button = pair[0]
		if lvl >= UPGRADE_COST.size():
			b.text = "%s  MAKS" % pair[2]
			b.disabled = true
		else:
			b.text = "%s  Sv%d → %d ●" % [pair[2], lvl + 1, UPGRADE_COST[lvl]]
			b.disabled = int(save.coins) < UPGRADE_COST[lvl]


func _popup(text: String, color: Color) -> void:
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", color)
	popup_label.modulate.a = 1.0
	popup_label.scale = Vector2.ONE * 0.6
	var tw := create_tween()
	tw.tween_property(popup_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(popup_label, "modulate:a", 0.0, 0.3)


func _pop(l: Label) -> void:
	l.modulate.a = 1.0
	l.scale = Vector2.ONE * 1.8
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(l, "modulate:a", 0.0, 0.2)


# ---------------------------------------------------------------- kayıt

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save2.cfg") != OK: return
	for k in save.keys(): save[k] = cfg.get_value("save", k, save[k])
	if not save.paints.has(int(save.paint)): save.paint = 0


func _write_save() -> void:
	var cfg := ConfigFile.new()
	for k in save.keys(): cfg.set_value("save", k, save[k])
	cfg.save("user://save2.cfg")
