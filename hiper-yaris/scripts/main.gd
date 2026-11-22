extends Node3D
## Hiper Yarış — gerçekçi grafikli, gündelik kontrollü arcade yarış.
## Gaz otomatik. Direksiyon: A/D, ←/→ veya ekrandaki oklar. Fren / drift: S/↓ (direksiyonla birlikte).
## Nitro: Boşluk/Shift. Pistten çıkarsan: R. 4 araç, 2 tur, kanyon pisti.

enum State { MENU, COUNTDOWN, RACE, FINISHED }

const LAPS := 2
const BASE_TOP := 72.0          # m/s (~260 km/sa)
const NITRO_ADD := 20.0
var A_LAT_AI := float(OS.get_environment("ALAT")) if OS.get_environment("ALAT") != "" else 20.0          # yapay zekânın viraj ivmesi (m/s²)

const TRACK_POINTS := [
	Vector2(0, 0), Vector2(0, -300), Vector2(60, -520), Vector2(220, -640), Vector2(420, -620),
	Vector2(560, -500), Vector2(600, -300), Vector2(520, -140), Vector2(560, 40), Vector2(700, 180),
	Vector2(680, 380), Vector2(520, 480), Vector2(300, 460), Vector2(160, 340), Vector2(60, 200),
]

## yaw: modelin önünü +Z'ye çeviren açı. keep: sadece bu düğümleri göster. wheels: tekerlek düğümü deseni.
const MODELS := {
	"concept": {"path": "res://assets/real/cars/CarConcept.glb", "yaw": 0.0, "keep": [], "wheels": "Wheel*", "paint": true},
	"goblin": {"path": "res://assets/real/cars/goblin.glb", "yaw": PI, "keep": [], "wheels": "bone_rotation_*", "paint": true},
	"sport_a": {"path": "res://assets/real/cars/sport.glb", "yaw": -PI / 2.0, "keep": ["mc_Body_4"], "wheels": "mc-wheel*", "paint": false},
	"sport_b": {"path": "res://assets/real/cars/sport.glb", "yaw": -PI / 2.0, "keep": ["mc_Body_001_9"], "wheels": "mc-wheel*", "paint": false},
	"sport_c": {"path": "res://assets/real/cars/sport.glb", "yaw": -PI / 2.0, "keep": ["mc_Body_002_14"], "wheels": "mc-wheel*", "paint": false},
	"furia_a": {"path": "res://assets/real/cars/sport2.glb", "yaw": 0.0, "keep": ["glr-body_4"], "wheels": "glr-wheel*", "paint": false},
	"furia_b": {"path": "res://assets/real/cars/sport2.glb", "yaw": 0.0, "keep": ["glr-body_001_9"], "wheels": "glr-wheel*", "paint": false},
	"furia_c": {"path": "res://assets/real/cars/sport2.glb", "yaw": 0.0, "keep": ["glr-body_002_14"], "wheels": "glr-wheel*", "paint": false},
	"saba": {"path": "res://assets/real/cars/saba.glb", "yaw": -PI / 2.0, "keep": [], "wheels": "*WheelStock_*", "paint": false},
	"cheetah": {"path": "res://assets/real/cars/cheetah.glb", "yaw": -PI / 2.0, "keep": [], "wheels": "*WheelStock_*", "paint": false},
	"exterminator": {"path": "res://assets/real/cars/exterminator.glb", "yaw": -PI / 2.0, "keep": [], "wheels": "*WheelsStock_*", "paint": false},
}
const GARAGE := [
	{"name": "AURORA  •  BUZ MAVİSİ", "model": "concept", "color": Color(0.05, 0.3, 0.85), "price": 0},
	{"name": "CHEETAH '84  •  KIRMIZI", "model": "cheetah", "color": Color.WHITE, "price": 150},
	{"name": "STRADA GT  •  TURUNCU", "model": "sport_b", "color": Color.WHITE, "price": 250},
	{"name": "EXTERMINATOR  •  TUNING", "model": "exterminator", "color": Color.WHITE, "price": 350},
	{"name": "FURIA GT  •  YEŞİL", "model": "furia_a", "color": Color.WHITE, "price": 450},
	{"name": "GOBLIN V12  •  ZEHİR YEŞİLİ", "model": "goblin", "color": Color(0.2, 0.7, 0.05), "price": 600},
	{"name": "SABA V12  •  SARI", "model": "saba", "color": Color.WHITE, "price": 750},
	{"name": "STRADA GT  •  KARBON", "model": "sport_a", "color": Color.WHITE, "price": 900},
	{"name": "FURIA GT  •  BEYAZ", "model": "furia_b", "color": Color.WHITE, "price": 1050},
	{"name": "AURORA  •  YARIŞ KIRMIZISI", "model": "concept", "color": Color(0.75, 0.04, 0.04), "price": 1200},
	{"name": "GOBLIN V12  •  GECE SİYAHI", "model": "goblin", "color": Color(0.025, 0.025, 0.03), "price": 1400},
	{"name": "FURIA GT  •  SARI", "model": "furia_c", "color": Color.WHITE, "price": 1600},
]
const RIVALS := [
	{"name": "KARTAL", "model": "goblin", "color": Color(0.03, 0.03, 0.035)},
	{"name": "ŞAHİN", "model": "sport_c", "color": Color.WHITE},
	{"name": "KURT", "model": "saba", "color": Color.WHITE},
	{"name": "TİLKİ", "model": "concept", "color": Color(0.6, 0.05, 0.08)},
	{"name": "ŞİMŞEK", "model": "sport_b", "color": Color.WHITE},
	{"name": "BORA", "model": "goblin", "color": Color(0.9, 0.5, 0.02)},
	{"name": "POYRAZ", "model": "cheetah", "color": Color.WHITE},
	{"name": "ATMACA", "model": "exterminator", "color": Color.WHITE},
	{"name": "PARS", "model": "furia_a", "color": Color.WHITE},
	{"name": "VAŞAK", "model": "furia_b", "color": Color.WHITE},
	{"name": "KAPLAN", "model": "concept", "color": Color(0.85, 0.85, 0.83)},
	{"name": "YILDIRIM", "model": "furia_c", "color": Color.WHITE},
]
const CAR_COUNT := 10
const PRIZES := [400, 280, 200, 150, 110, 80, 60, 40, 30, 20]
const UPGRADE_COST := [200, 400, 700, 1100, 1600]

var state := State.MENU
var track: Track
var model_scenes := {}
var car_seq := 0
var quality := 2
var world_env: Environment
var sun: DirectionalLight3D
var quality_button: Button
var cars: Array = []
var player: Dictionary
var camera: Camera3D
var cam_shake := 0.0
var cam_dir := Vector3.ZERO
var cam_pos := Vector3.ZERO
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
var save := {"level": 1, "coins": 0, "paints": [0], "paint": 0, "motor": 0, "nitro": 0, "quality": -1}
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
	quality = int(save.quality) if int(save.quality) >= 0 else (0 if OS.has_feature("mobile") else 2)
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
			var tool: Node = load("res://tools/%s.gd" % arg.substr(7)).new()
			tool.name = arg.substr(7)
			add_child(tool)


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
	world_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -135, 0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_blur = 1.5
	add_child(sun)

	_build_track()

	camera = Camera3D.new()
	camera.fov = 68
	camera.far = 1500
	camera.near = 0.1
	add_child(camera)
	_apply_quality()


func _build_track() -> void:
	if track: track.queue_free()
	track = Track.new()
	track.env_quality = [0.35, 0.65, 1.0][quality]
	add_child(track)
	track.build(TRACK_POINTS, 1234)
	randomize()


## Grafik kalitesi: 0 düşük (telefon), 1 orta, 2 yüksek (PC)
func _apply_quality() -> void:
	var q := quality
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	world_env.ssao_enabled = q == 2
	world_env.glow_enabled = q >= 1
	world_env.fog_enabled = true
	world_env.sky.radiance_size = [Sky.RADIANCE_SIZE_64, Sky.RADIANCE_SIZE_128, Sky.RADIANCE_SIZE_256][q]
	sun.shadow_enabled = true
	sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][q]
	sun.directional_shadow_max_distance = [60.0, 120.0, 220.0][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	Engine.physics_ticks_per_second = [60, 90, 120][q]
	Engine.max_physics_steps_per_frame = 8
	camera.far = [700.0, 1000.0, 1500.0][q] if camera else 1500.0


func _cycle_quality() -> void:
	quality = (quality + 2) % 3   # yüksek -> orta -> düşük -> yüksek
	save.quality = quality
	_write_save()
	_build_track()
	_apply_quality()
	_go_menu()


# ---------------------------------------------------------------- araçlar

func _make_car(model_id: String, color: Color, is_player: bool, start_s: float, lane: float, info := {}) -> Dictionary:
	var body := Car.new()
	add_child(body)
	var model := _load_model(model_id, body)
	if MODELS[model_id].paint: _paint(model, color)
	_fix_glass(model)
	var wheels := _rig_wheels(body, model, MODELS[model_id].wheels)
	body.setup(wheels, 1250.0)
	var tune: Dictionary = info.get("tune", {})
	for k in tune: body.set(k, tune[k])
	var flames: Array = []
	for x in [-0.42, 0.42]:
		var f := _make_flame()
		f.position = Vector3(x, 0.45, -2.25)
		body.add_child(f)
		flames.append(f)
	var smoke := _make_smoke()
	smoke.position = Vector3(0, 0.3, -1.5)
	body.add_child(smoke)
	var sparks := _make_sparks()
	add_child(sparks)
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
		body.add_child(tag)
	car_seq += 1
	var car := {
		"id": car_seq, "body": body, "root": body, "model": model, "model_id": model_id,
		"flames": flames, "smoke": smoke, "sparks": sparks, "tag": tag, "name": info.get("name", "SEN"), "player": is_player,
		"s": start_s, "x": lane, "idx": track.idx(start_s), "vf": 0.0,
		"skill": info.get("skill", 1.0), "top": info.get("top", 80.0),
		"nitro": 0.0, "boost": false, "finished": false,
		"bump_cd": 0.0, "ai_nitro_cd": randf_range(4, 9), "line": lane, "stuck": 0.0, "wrong": 0.0, "flip": 0.0,
	}
	var p := track.point(start_s, lane)
	body.place(p, track.tangent(start_s), 0.0)
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
			var skip := false
			for w in ["light", "red", "lamp", "head", "tail", "brake", "blink", "reverse"]:
				if n.contains(w): skip = true
			if n.contains("glass") and not skip:
				var g := StandardMaterial3D.new()
				g.albedo_color = Color(0.03, 0.04, 0.05, 0.75)
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.metallic = 0.9
				g.roughness = 0.04
				m3.set_surface_override_material(i, g)


## Tekerlek görsellerini bulur, merkezlerinde pivot oluşturur ve fizik bağlantı noktalarını hesaplar.
func _rig_wheels(body: Node3D, model: Node3D, pattern: String) -> Array:
	var out: Array = []
	var inv_body := body.global_transform.affine_inverse()
	if pattern != "":
		var found: Array = model.find_children(pattern, "Node3D", true, false)
		var tops: Array = []
		for w in found:
			var nested := false
			for o in found:
				if o != w and o.is_ancestor_of(w): nested = true
			if not nested: tops.append(w)
		for w in tops:
			var node := w as Node3D
			var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
			if node is MeshInstance3D: meshes.append(node)
			if meshes.is_empty() or not (meshes[0] as MeshInstance3D).is_visible_in_tree(): continue
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
			var c_body: Vector3 = inv_body * pivot.global_position
			var to_parent: Basis = parent.global_basis.inverse() * body.global_basis
			var inv: Basis = parent.global_basis.orthonormalized().inverse()
			var rb: Basis = body.global_basis.orthonormalized()
			var radius := clampf(c_body.y, 0.26, 0.6)
			out.append({
				"mount": Vector3(c_body.x, c_body.y + 0.33, c_body.z), "radius": radius, "front": c_body.z > 0.0,
				"pivot": pivot, "base_pos": pivot.position, "base_center": c_body, "to_parent": to_parent,
				"base_basis": pivot.basis, "axle": (inv * (rb * Vector3.RIGHT)).normalized(), "up": (inv * (rb * Vector3.UP)).normalized(),
				"spin": 0.0, "contact": false, "comp": 0.0,
			})
	if out.size() < 4:
		# Tekerlek düğümü olmayan model (tek parça tekerlekler): standart bağlantı noktaları
		out.clear()
		for z in [1.38, -1.38]:
			for x in [0.82, -0.82]:
				out.append({"mount": Vector3(x, 0.68, z), "radius": 0.35, "front": z > 0.0, "pivot": null,
					"base_pos": Vector3.ZERO, "base_center": Vector3(x, 0.35, z), "to_parent": Basis(),
					"base_basis": Basis(), "axle": Vector3.RIGHT, "up": Vector3.UP, "spin": 0.0, "contact": false, "comp": 0.0})
	return out


func _make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 40
	p.lifetime = 0.12
	p.local_coords = true
	p.direction = Vector3(0, 0, -1)
	p.spread = 6.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.24
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
	g.set_color(0, Color(0.55, 0.8, 1.6, 0.9))
	g.set_color(1, Color(0.05, 0.15, 0.9, 0.0))
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


## Pist koordinatlarını (ilerleme s, yanal x) güncelle.
func _track_sync(car: Dictionary) -> void:
	var pr := track.project(car.body.global_position, car.idx)
	car.idx = pr[0]
	car.x = pr[1]
	var s_raw: float = pr[2]
	var prev: float = fposmod(car.s, track.length)
	var d: float = s_raw - prev
	if d > track.length * 0.5: d -= track.length
	elif d < -track.length * 0.5: d += track.length
	car.s += d
	car.vf = car.body.speed


## Her fizik adımında: kontroller, nitro, efektler, kurtarma.
func _drive(car: Dictionary, delta: float) -> void:
	var body: Car = car.body
	_track_sync(car)
	var test_mode: bool = get_node_or_null("accel") != null or get_node_or_null("handling") != null
	if car.player and test_mode: pass
	elif car.player and not car.finished: _player_input(car, delta)
	else: _ai_input(car, delta)
	if car.boost:
		car.nitro -= delta * (0.2 - (0.025 * int(save.nitro) if car.player else 0.0))
		if car.nitro <= 0.0:
			car.nitro = 0.0
			car.boost = false
	body.nitro_on = car.boost and body.throttle > 0.1
	for f in car.flames: f.emitting = body.nitro_on
	car.smoke.emitting = body.slip > 0.35 and absf(body.speed) > 8.0 and body.on_ground >= 2
	# Kurtarma: ters dönme, takılma, ters yön, pist dışı
	var up_dot: float = body.global_basis.y.dot(Vector3.UP)
	car.flip = car.flip + delta if up_dot < 0.35 else 0.0
	var racing: bool = state == State.RACE
	car.stuck = car.stuck + delta if racing and absf(body.speed) < 2.0 and body.throttle > 0.5 else 0.0
	var fwd: Vector3 = body.global_basis.z
	car.wrong = car.wrong + delta if racing and fwd.dot(track.tangent(car.s)) < -0.3 and body.speed > 3.0 else 0.0
	if debug_log and absf(car.x) > Track.HALF - 0.6: car.wall = car.get("wall", 0.0) + delta
	var off: bool = absf(car.x) > Track.HALF + 4.0 or body.global_position.y < track.point(car.s).y - 6.0
	if test_mode and car.player: return
	if car.flip > 1.5 or car.stuck > 3.0 or car.wrong > 2.5 or off or (car.player and Input.is_physical_key_pressed(KEY_R)):
		_recover(car)


## Oyuncu/yapay zekâ çarpışmaları: sert vuruşta sarsıntı, ses, takedown.
func _contacts(delta: float) -> void:
	for c in cars: c.bump_cd -= delta
	for c in cars:
		if c.player: continue
		var a: Car = player.body
		var b: Car = c.body
		var d := b.global_position - a.global_position
		if d.length() > 5.2: continue
		var rel: float = (a.linear_velocity - b.linear_velocity).dot(d.normalized())
		if rel < 3.0 or player.bump_cd > 0.0: continue
		player.bump_cd = 0.5
		cam_shake = maxf(cam_shake, clampf(rel * 0.05, 0.2, 0.7))
		sfx.impact.volume_db = linear_to_db(clampf(rel / 15.0, 0.3, 1.0))
		sfx.impact.play()
		var sp: CPUParticles3D = c.sparks
		sp.global_position = (a.global_position + b.global_position) * 0.5 + Vector3.UP * 0.6
		sp.restart()
		Input.vibrate_handheld(int(clampf(rel * 10.0, 40, 200)))
		# Takedown: hızlı ve sert vuruş rakibi savurur
		if rel > 9.0 and not c.finished:
			var push := Vector3(d.x, 0.0, d.z).normalized()
			b.apply_central_impulse(push * b.mass * 2.5)
			b.apply_torque_impulse(Vector3.UP * b.mass * 4.0 * (1.0 if randf() < 0.5 else -1.0))
			player.nitro = minf(player.nitro + 0.35, 1.0)
			_popup("TAKEDOWN!  +NİTRO", Color(1.0, 0.4, 0.25))


func _recover(car: Dictionary) -> void:
	if debug_log: print("  KURTARMA ", car.name, " model=", car.model_id, " yükseklik=", snappedf(car.body.global_position.y - track.point(car.s).y, 0.1), " hız=", int(car.body.speed * 3.6), " zemin=", car.body.on_ground, " s=", int(fposmod(car.s, track.length)), " x=", snappedf(car.x, 0.1), " flip=", snappedf(car.flip, 0.1), " stuck=", snappedf(car.stuck, 0.1), " wrong=", snappedf(car.wrong, 0.1))
	var s: float = car.s
	var x: float = clampf(car.x, -Track.HALF + 2.5, Track.HALF - 2.5)
	car.body.place(track.point(s, x), track.tangent(s), clampf(car.body.speed, 15.0, 30.0))
	car.flip = 0.0
	car.stuck = 0.0
	car.wrong = 0.0
	if car.player:
		_popup("PİSTE DÖNDÜN", Color(0.8, 0.9, 1.0))


func _player_input(car: Dictionary, delta: float) -> void:
	var body: Car = car.body
	if autopilot:
		_ai_input(car, delta)
		if car.nitro > 0.95 and absf(track.curvature(car.s + 60.0)) < 0.002 and absf(track.curvature(car.s + 140.0)) < 0.002:
			car.boost = true
	else:
		var u := 0.0
		if _pressed("left"): u -= 1.0
		if _pressed("right"): u += 1.0
		# Klavye dijital: yumuşak direksiyon
		body.steer = move_toward(body.steer, u, delta * (3.5 if absf(u) > 0.0 else 6.0))
		body.throttle = 1.0 if _pressed("gas") else 0.0
		body.brake = 1.0 if _pressed("brake") else 0.0
		body.handbrake = _pressed("handbrake")
		if _pressed("nitro") and car.nitro > 0.08: car.boost = true
	# Nitro kazanımı: zamanla, kaymayla (drift) ve hava süresiyle
	if not car.boost: car.nitro = minf(car.nitro + delta * (0.025 + 0.008 * int(save.nitro)), 1.0)
	if body.slip > 0.35 and body.speed > 15.0: car.nitro = minf(car.nitro + delta * 0.22, 1.0)
	if body.air_time > 0.25: car.nitro = minf(car.nitro + delta * 0.3, 1.0)
	skid.volume_db = lerpf(skid.volume_db, -6.0 if body.slip > 0.35 and absf(body.speed) > 8.0 and body.on_ground >= 2 else -60.0, delta * 8.0)


## Yapay zekâ sürücü: yarış çizgisini takip eder, virajdan önce frenler, sollar, nitro kullanır.
func _ai_input(car: Dictionary, delta: float) -> void:
	var body: Car = car.body
	var v: float = maxf(body.speed, 8.0)
	var look: float = 8.0 + v * 0.45
	var k: float = track.curvature(car.s + look)
	var line: float = clampf(signf(k) * minf(absf(k) * 450.0, 3.5), -4.0, 4.0)
	var follow: float = INF
	for o in cars:
		if o == car: continue
		var ds: float = o.s - car.s
		if ds > 0.0 and ds < 30.0 and absf(o.x - car.x) < 3.0:
			line = o.x - 4.2 if o.x > 0.0 else o.x + 4.2
			if ds < 10.0 and absf(o.x - car.x) < 2.3: follow = minf(follow, o.vf - 1.0)
		elif ds > -6.0 and ds < 6.0 and absf(o.x - line) < 2.6:
			line = car.x
	car.line = move_toward(car.line, clampf(line, -Track.HALF + 2.0, Track.HALF - 2.0), delta * 5.0)
	# Saf takip (pure pursuit) direksiyonu
	var target: Vector3 = track.point(car.s + look, car.line)
	var local: Vector3 = body.global_transform.affine_inverse() * target
	var ang: float = atan2(-local.x, local.z)        # + sağa
	var max_a: float = lerpf(body.max_steer, 0.11, clampf(absf(body.speed) / 70.0, 0.0, 1.0))
	body.steer = clampf(ang * 2.2 / maxf(max_a, 0.05) * 0.35, -1.0, 1.0)
	# Hedef hız: önümüzdeki virajlar için fren mesafesi
	var vt: float = car.top
	var d := 0.0
	while d < 180.0:
		var kk: float = absf(track.curvature(car.s + d))
		var vc: float = sqrt(A_LAT_AI * car.skill / maxf(kk, 0.0001))
		vt = minf(vt, sqrt(vc * vc + 2.0 * 14.0 * d))
		d += 8.0
	vt = minf(vt, follow)
	if not car.player:
		var gap: float = car.s - player.s
		if gap > 70.0: vt *= 0.93
		elif gap < -70.0: vt *= 1.06
		if car.finished: vt = minf(vt, 30.0)
	car.vt = vt
	body.throttle = 1.0 if body.speed < vt - 1.0 else (0.3 if body.speed < vt + 1.0 else 0.0)
	body.brake = 1.0 if body.speed > vt + 5.0 else 0.0
	body.handbrake = false
	if not car.player:
		car.ai_nitro_cd -= delta
		if car.ai_nitro_cd <= 0.0 and absf(k) < 0.002 and absf(track.curvature(car.s + 150.0)) < 0.002 and state == State.RACE:
			car.nitro = 0.6
			car.boost = true
			car.ai_nitro_cd = randf_range(9, 18)


# ---------------------------------------------------------------- yarış

func _setup_grid() -> void:
	for c in cars:
		c.body.queue_free()
		c.sparks.queue_free()
	cars.clear()
	finish_order.clear()
	var level := int(save.level)
	var diff := clampf((level - 1) / 10.0, 0.0, 1.0)
	var rivals := RIVALS.duplicate()
	rivals.shuffle()
	for i in CAR_COUNT:
		var row := i / 2
		var lane: float = -2.6 if i % 2 == 0 else 2.6
		var s := -12.0 - row * 10.0 - (5.0 if i % 2 else 0.0)
		if i == CAR_COUNT - 1:
			var g: Dictionary = GARAGE[paint_index]
			player = _make_car(g.model, g.color, true, s, lane, {"tune": {"power_kw": 300.0 + 22.0 * int(save.motor)}})
			cars.append(player)
		else:
			var r: Dictionary = rivals[i]
			cars.append(_make_car(r.model, r.color, false, s, lane, {
				"name": r.name, "top": lerpf(62.0, 82.0, diff) + (4 - i) * 0.6 + randf_range(-1.0, 1.0),
				"skill": lerpf(0.8, 1.0, diff) + randf_range(-0.03, 0.03),
				"tune": {"power_kw": lerpf(280.0, 340.0, diff)},
			}))
	for c in cars: c.body.freeze = true


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
	if place <= 3: save.level = int(save.level) + 1
	_write_save()
	over_place.text = "%d." % place
	var cols := [Color(1, 0.82, 0.2), Color(0.85, 0.88, 0.95), Color(0.9, 0.6, 0.35)]
	over_place.add_theme_color_override("font_color", cols[place - 1] if place <= 3 else Color(0.8, 0.8, 0.8))
	var titles := ["ZAFER!", "İKİNCİ", "ÜÇÜNCÜ"]
	over_info.text = "%s\nSÜRE  %s\n+%d COIN" % [titles[place - 1] if place <= 3 else "%d. SIRA" % place, _fmt_time(race_time), prize]
	next_button.text = "SONRAKİ YARIŞ" if place <= 3 else "TEKRAR DENE"
	controls.visible = false
	hud.visible = false
	await get_tree().create_timer(1.5).timeout
	if state != State.FINISHED: return
	over.visible = true
	over.modulate.a = 0.0
	create_tween().tween_property(over, "modulate:a", 1.0, 0.3)
	sfx.coin.play()


func _physics_process(delta: float) -> void:
	if state != State.RACE and state != State.FINISHED: return
	var ranks_before := _ranks()
	for c in cars: _drive(c, delta)
	_contacts(delta)
	for c in cars:
		if not c.finished and c.s >= LAPS * track.length:
			c.finished = true
			finish_order.append(c)
			if c.player: _finish_player()
	_overtake_check(ranks_before)
	_near_miss()


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	match state:
		State.MENU:
			menu_angle += delta * 0.25
			var p: Vector3 = player.body.global_position
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
				for c in cars: c.body.freeze = false
				big_label.text = "GO!"
				_pop(big_label)
				sfx.go.play()
			elif ceili(countdown) != before:
				big_label.text = str(ceili(countdown))
				_pop(big_label)
				sfx.beep.play()
			engine.pitch_scale = 0.8 + (0.6 if _pressed("gas") else 0.0)
		State.RACE, State.FINISHED:
			if state == State.RACE: race_time += delta
			var body: Car = player.body
			var kmh: float = absf(body.speed) * 3.6
			var gear: int = mini(int(kmh / 55.0), 5)
			var rpm: float = fmod(kmh, 55.0) / 55.0 if gear < 5 else clampf((kmh - 275.0) / 80.0, 0.0, 1.0)
			var load_f: float = 0.15 if body.throttle > 0.1 else 0.0
			engine.pitch_scale = lerpf(engine.pitch_scale, 0.7 + rpm * 0.75 + gear * 0.06 + load_f + (0.1 if player.boost else 0.0), delta * 10.0)
	_update_camera(delta)
	_update_hud()


func _ranks() -> Dictionary:
	var sorted := cars.duplicate()
	sorted.sort_custom(func(a, b): return a.s > b.s)
	var out := {}
	for i in sorted.size(): out[sorted[i].id] = i + 1
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
	var body: Car = player.body
	var p: Vector3 = body.global_position
	var fwd: Vector3 = body.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var vel: Vector3 = body.linear_velocity
	vel.y = 0.0
	var vdir: Vector3 = vel.normalized() if vel.length() > 6.0 else fwd
	var want: Vector3 = fwd.lerp(vdir, 0.4).normalized()
	cam_dir = cam_dir.slerp(want, 1.0 - exp(-delta * 4.5)).normalized() if cam_dir.length() > 0.5 else want
	var v: float = maxf(body.speed, 0.0)
	var dist: float = 5.8 + v * 0.012 - (0.5 if player.boost else 0.0)
	var target: Vector3 = p - cam_dir * dist + Vector3.UP * (1.9 + v * 0.003)
	# Yükseklik yumuşak takip (zıplamalarda sarsmasın)
	cam_pos = cam_pos.lerp(target, 1.0 - exp(-delta * 14.0)) if cam_pos != Vector3.ZERO else target
	cam_pos.x = target.x
	cam_pos.z = target.z
	camera.position = cam_pos
	camera.look_at(p + cam_dir * 7.0 + Vector3.UP * 0.9)
	var fov: float = 64.0 + v * 0.13 + (10.0 if player.boost else 0.0)
	camera.fov = lerpf(camera.fov, fov, delta * 3.0)
	if cam_shake > 0.0:
		cam_shake = maxf(cam_shake - delta * 2.5, 0.0)
		var s := cam_shake * cam_shake * 0.35
		camera.position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))


# ---------------------------------------------------------------- girdi

func _pressed(zone: String) -> bool:
	for z in touches.values():
		if z == zone: return true
	match zone:
		"left": return Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
		"right": return Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
		"gas": return Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
		"brake": return Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		"handbrake": return Input.is_key_pressed(KEY_SPACE)
		"nitro": return Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_N)
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
	if touch_mode: _box(speedo, 0.5, 1, 0, -105, 200, 200)
	else: _box(speedo, 1, 1, -140, -140, 250, 250)
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
	zones["gas"] = _zone(controls, "GAZ", 1, 1, -110, -105, 170, 170, Color(0.1, 0.5, 0.15, 0.5))
	zones["brake"] = _zone(controls, "FREN", 1, 1, -300, -90, 130, 110, Color(0.5, 0.1, 0.1, 0.5))
	zones["handbrake"] = _zone(controls, "EL FRENİ", 1, 1, -300, -230, 130, 90)
	zones["nitro"] = _zone(controls, "NİTRO", 1, 1, -110, -300, 150, 100, Color(0.05, 0.35, 0.8, 0.55))
	var keys := _label("W gaz   S fren/geri   A/D direksiyon   BOŞLUK el freni (drift)   SHIFT nitro   R piste dön", 17, hud, Color(1, 1, 1, 0.7))
	_box(keys, 0.5, 1, -60, -22, 1000, 30)
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
	var sub := _label("KANYON  •  10 ARAÇ  •  2 TUR", 26, menu, Color(1, 1, 1, 0.9))
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
	quality_button = _button("", menu, _cycle_quality)
	quality_button.add_theme_font_size_override("font_size", 20)
	_box(quality_button, 0, 0, 180, 365, 300, 56)
	var credit := _label("Araçlar: Eric Chadwick/DGG, ollitei, Han66st, Daniel Zhabotinsky (CC BY 4.0) · Çevre: Poly Haven (CC0) · Ses: Kenney (CC0) · Fizik: Godot Jolt", 14, menu, Color(1, 1, 1, 0.55))
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
	pos_label.text = "%d/%d" % [ranks[player.id], cars.size()]
	var prog: float = clampf(player.s / (LAPS * track.length), 0.0, 1.0)
	prog_label.text = "%d %%" % int(prog * 100.0)
	lap_label.text = "TUR %d/%d" % [clampi(int(player.s / track.length) + 1, 1, LAPS), LAPS]
	time_label.text = _fmt_time(race_time)
	nitro_bar.value = player.nitro
	speedo.speed_kmh = absf(player.body.speed) * 3.6
	speedo.nitro = player.nitro
	speedo.boosting = player.boost
	for c in cars:
		if c.tag:
			var r: int = ranks[c.id]
			c.tag.text = "%d.  %s" % [r, c.name]
			c.tag.modulate = Color(1, 0.85, 0.3) if r == 1 else Color.WHITE
			var ahead: float = c.s - player.s
			c.tag.visible = ahead > 6.0 and ahead < 90.0 and _ahead_rank(c) < 3
	for name in zones:
		var z: Control = zones[name]
		z.modulate.a = 1.0 if _pressed(name) else 0.7


## Oyuncunun önündeki araçlar arasında bu aracın sırası (0 = en yakın)
func _ahead_rank(car: Dictionary) -> int:
	var d: float = car.s - player.s
	var r := 0
	for o in cars:
		if o == car or o == player: continue
		var od: float = o.s - player.s
		if od > 6.0 and od < d: r += 1
	return r


func _paint_step(d: int) -> void:
	paint_index = wrapi(paint_index + d, 0, GARAGE.size())
	var old: Dictionary = player
	var g: Dictionary = GARAGE[paint_index]
	player = _make_car(g.model, g.color, true, old.s, old.x)
	player.body.freeze = true
	cars[cars.find(old)] = player
	old.body.queue_free()
	old.sparks.queue_free()
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
	quality_button.text = "GRAFİK: %s" % ["DÜŞÜK", "ORTA", "YÜKSEK"][quality]
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
