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
	{"name": "FURIA GT  •  YEŞİL", "model": "furia_a", "color": Color.WHITE, "price": 0},
	{"name": "CHEETAH '84  •  KIRMIZI", "model": "cheetah", "color": Color.WHITE, "price": 150},
	{"name": "STRADA GT  •  TURUNCU", "model": "sport_b", "color": Color.WHITE, "price": 250},
	{"name": "EXTERMINATOR  •  TUNING", "model": "exterminator", "color": Color.WHITE, "price": 350},
	{"name": "AURORA  •  BUZ MAVİSİ", "model": "concept", "color": Color(0.05, 0.3, 0.85), "price": 450},
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
const CRASH_DV := 16.0   # bir fizik adımında bu kadar m/s hız değişimi = kaza
const PRIZES := [400, 280, 200, 150, 110, 80, 60, 40, 30, 20]
const UPGRADE_COST := [200, 400, 700, 1100, 1600]

var state := State.MENU
var track: Track
var model_scenes := {}
var car_seq := 0
var music: AudioStreamPlayer
var skid_mm: MultiMesh
var skid_i := 0
var speed_lines: CPUParticles3D
var confetti: CPUParticles3D
var last_lap_shown := false
var merged_cache := {}
var tick := 0
var hud_ranks := {}
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
var progress_bar: ProgressBar
var minimap: Control
var nitro_fill: ColorRect
var keys_label: Label
var stat_bars: Array = []
var price_label: Label
var pause_menu: Control
var results_box: VBoxContainer
var loading: ColorRect
const ACCENT := Color(1.0, 0.55, 0.12)
const ACCENT_2 := Color(1.0, 0.82, 0.25)


func _ready() -> void:
	randomize()
	_load_save()
	paint_index = int(save.paint)
	quality = int(save.quality) if int(save.quality) >= 0 else (0 if OS.has_feature("mobile") else 2)
	if OS.get_environment("QUALITY") != "": quality = int(OS.get_environment("QUALITY"))
	touch_mode = DisplayServer.is_touchscreen_available()
	for k in MODELS: model_scenes[k] = load(MODELS[k].path)
	for s in ["coin", "click", "nitro", "beep", "go"]:
		_add_sfx(s, load("res://sounds/%s.wav" % s))
	_add_sfx("impact", load("res://assets/audio/impact.ogg"))
	_add_sfx("crowd", load("res://sounds/crowd.wav"))
	_setup_music()
	engine = _looping("res://assets/audio/engine.ogg", -4.0)
	skid = _looping("res://assets/audio/skid.ogg", -60.0)
	_build_world()
	_build_ui()
	_go_menu()
	minimap.game = self
	_setup_minimap.call_deferred()
	if OS.get_cmdline_user_args().is_empty(): _warmup()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tool="):
			var tool: Node = load("res://tools/%s.gd" % arg.substr(7)).new()
			tool.name = arg.substr(7)
			add_child(tool)


func _setup_minimap() -> void:
	await get_tree().process_frame
	minimap.setup(track)


## Müzik: "Music" ses yolu + menüde boğuk duyulsun diye alçak geçiren filtre
func _setup_music() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_volume_db(idx, -9.0)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 900.0
	AudioServer.add_bus_effect(idx, lp)
	music = AudioStreamPlayer.new()
	var st: AudioStreamWAV = load("res://sounds/music_race.wav")
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	music.stream = st
	music.bus = "Music"
	add_child(music)
	music.play()


func _music_muffled(on: bool) -> void:
	var idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_effect_enabled(idx, 0, on)
	AudioServer.set_bus_volume_db(idx, -11.0 if on else -9.0)


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
	_build_fx()
	_apply_quality()


## Fren izleri (halka tamponlu tek MultiMesh), hız çizgileri ve bitiş konfetisi
func _build_fx() -> void:
	skid_mm = MultiMesh.new()
	skid_mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	skid_mm.mesh = q
	skid_mm.instance_count = [500, 900, 1400][quality]
	for i in skid_mm.instance_count: skid_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0)))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = skid_mm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.custom_aabb = AABB(Vector3(-5000, -1000, -5000), Vector3(10000, 2000, 10000))
	add_child(smi)
	# Hız çizgileri: kameraya bağlı, yüksek hızda/nitroda ekran kenarlarından akar
	speed_lines = CPUParticles3D.new()
	speed_lines.emitting = false
	speed_lines.amount = 40
	speed_lines.lifetime = 0.35
	speed_lines.local_coords = true
	speed_lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	speed_lines.emission_box_extents = Vector3(4.0, 2.4, 0.5)
	speed_lines.position = Vector3(0, 0, -9.0)
	speed_lines.direction = Vector3(0, 0, 1)
	speed_lines.spread = 0.0
	speed_lines.gravity = Vector3.ZERO
	speed_lines.initial_velocity_min = 30.0
	speed_lines.initial_velocity_max = 45.0
	var lq := BoxMesh.new()
	lq.size = Vector3(0.015, 0.015, 1.6)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.35)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lq.material = lm
	speed_lines.mesh = lq
	camera.add_child(speed_lines)
	# Konfeti
	confetti = CPUParticles3D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.explosiveness = 0.8
	confetti.amount = 160
	confetti.lifetime = 3.0
	confetti.local_coords = false
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(8, 1, 3)
	confetti.direction = Vector3(0, 1, 0)
	confetti.spread = 50.0
	confetti.initial_velocity_min = 6.0
	confetti.initial_velocity_max = 12.0
	confetti.gravity = Vector3(0, -4.0, 0)
	confetti.damping_min = 1.0
	confetti.damping_max = 2.0
	confetti.angular_velocity_min = -400.0
	confetti.angular_velocity_max = 400.0
	var cq := QuadMesh.new()
	cq.size = Vector2(0.12, 0.2)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.vertex_color_use_as_albedo = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cq.material = cm
	confetti.mesh = cq
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	cg.colors = PackedColorArray([Color(1, 0.2, 0.2), Color(1, 0.85, 0.1), Color(0.2, 0.8, 0.3), Color(0.2, 0.5, 1), Color(1, 0.4, 0.9)])
	confetti.color_initial_ramp = cg
	add_child(confetti)


## Arka tekerleklerin altına fren/drift izi bırak
func _skid(car: Dictionary) -> void:
	var body: Car = car.body
	if not (body.on_ground >= 3 and body.slip > 0.35 and absf(body.speed) > 6.0): return
	var d: float = car.get("skid_d", 0.0) + absf(body.speed) * get_physics_process_delta_time()
	car.skid_d = d
	if d < 0.7: return
	car.skid_d = 0.0
	var fwd := body.linear_velocity.normalized()
	if fwd.length() < 0.5: return
	for w in body.wheels:
		if w.front or not w.contact: continue
		var p: Vector3 = body.global_transform * Vector3(w.mount.x, 0.0, w.mount.z)
		p.y = track.point(car.s, car.x).y + 0.035
		var b := Basis.looking_at(Vector3(fwd.x, 0, fwd.z).normalized(), Vector3.UP)
		skid_mm.set_instance_transform(skid_i, Transform3D(b, p))
		skid_i = (skid_i + 1) % skid_mm.instance_count


func _build_track() -> void:
	if track: track.queue_free()
	track = Track.new()
	track.env_quality = [0.25, 0.6, 1.0][quality]
	add_child(track)
	track.build(TRACK_POINTS, 1234)
	randomize()


## Grafik kalitesi: 0 düşük (telefon), 1 orta, 2 yüksek (PC)
func _apply_quality() -> void:
	var q := quality
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	world_env.ssao_enabled = q == 2
	world_env.glow_enabled = q >= 1
	world_env.fog_enabled = true
	world_env.sky.radiance_size = [Sky.RADIANCE_SIZE_32, Sky.RADIANCE_SIZE_128, Sky.RADIANCE_SIZE_256][q]
	world_env.sky.process_mode = Sky.PROCESS_MODE_QUALITY if q == 2 else Sky.PROCESS_MODE_INCREMENTAL
	sun.shadow_enabled = true
	sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][q]
	sun.directional_shadow_max_distance = [45.0, 110.0, 220.0][q]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	Engine.physics_ticks_per_second = [60, 90, 120][q]
	Engine.max_physics_steps_per_frame = 6
	if camera: camera.far = [600.0, 1000.0, 1500.0][q]


func _cycle_quality() -> void:
	quality = (quality + 2) % 3   # yüksek -> orta -> düşük -> yüksek
	save.quality = quality
	_write_save()
	_build_track()
	_apply_quality()
	_go_menu()
	_setup_minimap()


# ---------------------------------------------------------------- araçlar

func _make_car(model_id: String, color: Color, is_player: bool, start_s: float, lane: float, info := {}) -> Dictionary:
	var body := Car.new()
	add_child(body)
	var model := _load_model(model_id, body)
	if MODELS[model_id].paint: _paint(model, color)
	_fix_glass(model)
	_merge_body(model, MODELS[model_id].wheels, model_id + str(color))
	var wheels := _rig_wheels(body, model, MODELS[model_id].wheels)
	body.setup(wheels, 1250.0)
	for w in wheels:
		if w.pivot:
			for wm in (w.pivot as Node).find_children("*", "MeshInstance3D", true, false):
				(wm as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not is_player:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var gm := mi as MeshInstance3D
			gm.visibility_range_end = [220.0, 400.0, 0.0][quality]
			if quality == 0: gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tune: Dictionary = info.get("tune", {})
	for k in tune: body.set(k, tune[k])
	var flames: Array = []
	for x in [-0.42, 0.42]:
		var f := _make_flame()
		f.position = Vector3(x, 0.45, -2.25)
		body.add_child(f)
		flames.append(f)
	var smoke: Array = []
	for w in wheels:
		if w.front: continue
		var sm := _make_smoke()
		sm.position = Vector3(w.mount.x, 0.4, w.mount.z - 0.2)
		body.add_child(sm)
		smoke.append(sm)
	var sparks := _make_sparks()
	add_child(sparks)
	var debris := _make_debris(color)
	add_child(debris)
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
	if not is_player:
		var eng := AudioStreamPlayer3D.new()
		var est: AudioStreamOggVorbis = load("res://assets/audio/engine.ogg").duplicate()
		est.loop = true
		eng.stream = est
		eng.unit_size = 7.0
		eng.max_distance = 90.0
		eng.volume_db = -6.0
		eng.name = "EngineSound"
		body.add_child(eng)
	car_seq += 1
	var car := {
		"id": car_seq, "body": body, "root": body, "model": model, "model_id": model_id,
		"flames": flames, "smoke": smoke, "sparks": sparks, "debris": debris, "tag": tag, "name": info.get("name", "SEN"), "player": is_player,
		"s": start_s, "x": lane, "idx": track.idx(start_s), "vf": 0.0,
		"skill": info.get("skill", 1.0), "top": info.get("top", 80.0),
		"nitro": 0.0, "boost": false, "finished": false,
		"bump_cd": 0.0, "wreck": 0.0, "prev_vel": Vector3.ZERO, "scrape_cd": 0.0, "ai_nitro_cd": randf_range(4, 9), "line": lane, "stuck": 0.0, "wrong": 0.0, "flip": 0.0,
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
	# Optimizasyon: dışarıdan görünmeyen iç parçaları gizle (her biri ayrı çizim çağrısı)
	# Sadece dışarıdan görünmeyen küçük parçalar (taban/iskelet/direk gibi yapı parçaları kalır)
	var hidden_words := ["pedal", "seat", "steering", "dash", "floormat", "badge", "axle", "radiator"]
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		if OS.get_environment("NOHIDE") != "": break
		var full := String(m.name).to_lower() + " " + String(m.get_parent().name).to_lower()
		for w in hidden_words:
			if full.contains(w):
				if OS.get_environment("HIDELOG") != "": print("GİZLENDİ ", m.name, " / ", m.get_parent().name)
				m.visible = false
				break
	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		if not m.visible: continue
		var b: AABB = holder.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	# Sadece büyük gövde parçaları gölge atsın
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mm := m as MeshInstance3D
		var sz: float = (holder.global_transform.affine_inverse() * mm.global_transform * mm.get_aabb()).size.length()
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sz > aabb.size.length() * 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
				g.albedo_color = Color(0.02, 0.025, 0.035, 0.93)
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.metallic = 0.9
				g.roughness = 0.04
				m3.set_surface_override_material(i, g)


## Optimizasyon: tekerlek dışındaki tüm parçaları malzemeye göre tek mesh'te birleştir
## (40-60 çizim çağrısı -> malzeme sayısı kadar) ve uzak mesafe için LOD üret. Sonuç önbelleğe alınır.
func _merge_body(model: Node3D, pattern: String, cache_key: String) -> void:
	if OS.get_environment("NOMERGE") != "": return
	var inv := model.global_transform.affine_inverse()
	var parts: Array = []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree(): continue
		var in_wheel := false
		var n: Node = m
		while n != null and n != model:
			if pattern != "" and String(n.name).match(pattern): in_wheel = true
			n = n.get_parent()
		if not in_wheel: parts.append(m)
	if parts.is_empty(): return
	var mesh: ArrayMesh = merged_cache.get(cache_key)
	if mesh == null:
		var groups := {}
		for m in parts:
			var xf: Transform3D = inv * m.global_transform
			for si in m.mesh.get_surface_count():
				var mat: Material = m.get_active_material(si)
				if not groups.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[mat] = st
				groups[mat].append_from(m.mesh, si, xf)
		mesh = ArrayMesh.new()
		for mat in groups:
			var st: SurfaceTool = groups[mat]
			st.commit(mesh)
			if mesh.get_surface_count() > 0:
				mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		merged_cache[cache_key] = mesh
	var merged := MeshInstance3D.new()
	merged.mesh = mesh
	merged.name = "MergedBody"
	model.add_child(merged)
	# Düğümleri silme: bazı modellerde tekerlekler gövde parçasının alt düğümü (ör. Aurora)
	for m in parts: m.mesh = null


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


## Gerçekçi lastik dumanı: yumuşak, genişleyerek yükselen, dönerek dağılan bulutlar
func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = [20, 36, 52][quality]
	p.lifetime = 1.0
	# Arabanın çerçevesinde: duman arabayla gelip arkasında iz olarak yayılır (hızda ekranda kalır)
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3(0, 0.25, -1)
	p.spread = 28.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -50.0
	p.angular_velocity_max = 50.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.4, 1.1))
	curve.add_point(Vector2(1.0, 1.9))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/sprites/smoke_soft.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.proximity_fade_enabled = true       # zemine sert kesişmesin
	m.proximity_fade_distance = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Kameraya yaklaşan duman saydamlaşsın: görüşü asla kapatmasın
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.5
	m.distance_fade_max_distance = 5.5
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.88, 0.86, 0.84, 0.0), Color(0.88, 0.86, 0.84, 0.5), Color(0.82, 0.8, 0.78, 0.26), Color(0.8, 0.78, 0.76, 0.0)])
	p.color_ramp = g
	return p


func _set_smoke(car: Dictionary, on: bool) -> void:
	for sm in car.smoke: sm.emitting = on

func _make_debris(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 26
	p.lifetime = 1.8
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector3(0, -16, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	var q := BoxMesh.new()
	q.size = Vector3(0.3, 0.05, 0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = color if color != Color.WHITE else Color(0.25, 0.25, 0.27)
	m.metallic = 0.6
	m.roughness = 0.4
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0.5, 0.5, 0.5))
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
	var test_mode: bool = get_node_or_null("accel") != null or get_node_or_null("handling") != null or get_node_or_null("smokeshot") != null
	# Darbe algılama: bir fizik adımındaki ani hız değişimi = çarpışma şiddeti (duvar ya da araç)
	var dv: float = (car.prev_vel - body.linear_velocity).length()
	car.prev_vel = body.linear_velocity
	car.scrape_cd -= delta
	if car.wreck > 0.0:
		# Kaza modu: kontrol yok, araç savruluyor
		car.wreck -= delta
		body.throttle = 0.0
		body.brake = 0.3
		body.steer = 0.0
		body.handbrake = false
		car.boost = false
		body.nitro_on = false
		for f in car.flames: f.emitting = false
		_set_smoke(car, true)
		if car.wreck <= 0.0: _recover(car)
		return
	car.immune = car.get("immune", 0.0) - delta
	if state == State.RACE and not test_mode and dv > CRASH_DV and absf(body.speed) + dv > 25.0 and car.immune <= 0.0:
		_crash(car, dv)
		return
	if car.player and state == State.RACE and dv > 5.0 and car.bump_cd <= 0.0:
		car.bump_cd = 0.3
		cam_shake = maxf(cam_shake, clampf(dv * 0.05, 0.15, 0.6))
		sfx.impact.volume_db = linear_to_db(clampf(dv / 14.0, 0.25, 1.0))
		sfx.impact.play()
		Input.vibrate_handheld(int(clampf(dv * 12.0, 30, 180)))
	# Duvara sürtünme: sürekli kıvılcım
	if body.get_contact_count() > 0 and absf(car.x) > Track.HALF - 1.6 and absf(body.speed) > 12.0 and car.scrape_cd <= 0.0:
		car.scrape_cd = 0.09
		var sp: CPUParticles3D = car.sparks
		sp.global_position = body.global_position + track.right[car.idx] * signf(car.x) * 1.0 + Vector3.UP * 0.4
		sp.restart()
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
	var burnout: bool = body.throttle > 0.8 and absf(body.speed) < 12.0 and body.slip > 0.2
	_set_smoke(car, body.on_ground >= 2 and ((body.slip > 0.3 and absf(body.speed) > 4.0) or burnout))
	_skid(car)
	if not car.player:
		var es: AudioStreamPlayer3D = body.get_node_or_null("EngineSound")
		if es: es.pitch_scale = 0.6 + absf(body.speed) / 45.0
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
		if rel > 9.0 and not c.finished and c.wreck <= 0.0 and player.wreck <= 0.0:
			var push := Vector3(d.x, 0.0, d.z).normalized()
			b.apply_central_impulse(push * b.mass * 3.0)
			_crash(c, rel + 10.0)
			player.nitro = minf(player.nitro + 0.4, 1.0)
			_popup("TAKEDOWN!  +NİTRO", Color(1.0, 0.4, 0.25))
			_slowmo(0.4, 0.6)


## Kaza: sürüş yardımları kapanır, araç takla atar, enkaz ve duman saçılır; ~2 sn sonra piste döner.
func _crash(car: Dictionary, strength: float) -> void:
	if car.wreck > 0.0 or car.finished: return
	if debug_log: print("  KAZA ", car.name, " şiddet=", snappedf(strength, 0.1), " s=", int(fposmod(car.s, track.length)))
	var body: Car = car.body
	car.wreck = 2.2
	body.wrecked = true
	var spin := Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)).normalized()
	body.apply_torque_impulse(spin * body.mass * clampf(strength * 0.35, 3.0, 9.0))
	body.apply_central_impulse(Vector3.UP * body.mass * clampf(strength * 0.18, 1.5, 4.5))
	var db: CPUParticles3D = car.debris
	db.global_position = body.global_position + Vector3.UP * 0.6
	db.restart()
	var sp: CPUParticles3D = car.sparks
	sp.global_position = body.global_position + Vector3.UP * 0.5
	sp.restart()
	var d2: float = player.body.global_position.distance_to(body.global_position)
	if car.player or d2 < 40.0:
		sfx.impact.volume_db = 0.0 if car.player else linear_to_db(clampf(1.0 - d2 / 45.0, 0.2, 1.0))
		sfx.impact.play()
	if car.player:
		cam_shake = 1.0
		_popup("KAZA!", Color(1.0, 0.3, 0.25))
		Input.vibrate_handheld(350)
		_slowmo(0.3, 1.1)


## Ağır çekim (gerçek zamanlı süre)
func _slowmo(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _recover(car: Dictionary) -> void:
	if debug_log: print("  KURTARMA ", car.name, " model=", car.model_id, " yükseklik=", snappedf(car.body.global_position.y - track.point(car.s).y, 0.1), " hız=", int(car.body.speed * 3.6), " zemin=", car.body.on_ground, " s=", int(fposmod(car.s, track.length)), " x=", snappedf(car.x, 0.1), " flip=", snappedf(car.flip, 0.1), " stuck=", snappedf(car.stuck, 0.1), " wrong=", snappedf(car.wrong, 0.1))
	var s: float = car.s
	var x: float = clampf(car.x, -Track.HALF + 2.5, Track.HALF - 2.5)
	car.body.place(track.point(s, x), track.tangent(s), clampf(car.body.speed, 15.0, 30.0))
	car.flip = 0.0
	car.stuck = 0.0
	car.wrong = 0.0
	car.wreck = 0.0
	car.immune = 1.5   # piste döndükten hemen sonra tekrar kaza sayılmasın
	car.body.wrecked = false
	car.prev_vel = car.body.linear_velocity
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
	# Hedef hız: önceden hesaplanmış viraj/fren tablosundan (her adımda döngü yok)
	var vt: float = minf(car.top, track.safe_speed(car.s, A_LAT_AI * car.skill))
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
		c.debris.queue_free()
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
			var cs := _car_stats(paint_index)
			player = _make_car(g.model, g.color, true, s, lane, {"tune": {"power_kw": cs.power + 22.0 * int(save.motor), "grip_front": 1.25 * cs.grip, "grip_rear": 1.35 * cs.grip}})
			cars.append(player)
		else:
			var r: Dictionary = rivals[i]
			cars.append(_make_car(r.model, r.color, false, s, lane, {
				"name": r.name, "top": lerpf(62.0, 82.0, diff) + (4 - i) * 0.6 + randf_range(-1.0, 1.0),
				"skill": lerpf(0.8, 1.0, diff) + randf_range(-0.03, 0.03),
				"tune": {"power_kw": lerpf(280.0, 340.0, diff)},
			}))
	for c in cars: c.body.freeze = true
	for lm in track.start_lights: lm.emission = Color(0, 0, 0)


func _go_menu() -> void:
	Engine.time_scale = 1.0
	if music: _music_muffled(true)
	get_tree().paused = false
	pause_menu.visible = false
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
	Engine.time_scale = 1.0
	get_tree().paused = false
	pause_menu.visible = false
	save.paint = paint_index
	_write_save()
	_setup_grid()
	state = State.COUNTDOWN
	countdown = 3.0
	last_lap_shown = false
	_music_muffled(true)
	# Geri sayımda fizik açık, frenler basılı: araçlar süspansiyonuna oturur (havada başlamaz)
	for c in cars:
		c.body.freeze = false
		c.body.brake = 1.0
		c.body.handbrake = true
		c.body.throttle = 0.0
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


func _physics_process(delta: float) -> void:
	if state != State.RACE and state != State.FINISHED: return
	tick += 1
	var check := tick % 6 == 0       # sıralama/olay kontrolleri her 6 adımda bir (pahalı sıralama)
	var ranks_before := _ranks() if check else {}
	for c in cars: _drive(c, delta)
	_contacts(delta)
	for c in cars:
		if not c.finished and c.s >= LAPS * track.length:
			c.finished = true
			c.time = race_time
			finish_order.append(c)
			if c.player: _finish_player()
	if check:
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
				for c in cars:
					c.body.freeze = false
					c.body.handbrake = false
					c.body.brake = 0.0
				for lm in track.start_lights: lm.emission = Color(0.1, 1.0, 0.2)
				_music_muffled(false)
				sfx.crowd.play()
				for c in cars:
					var es: Node = c.body.get_node_or_null("EngineSound")
					if es: es.play()
				big_label.add_theme_font_size_override("font_size", 150)
				big_label.text = "GO!"
				_pop(big_label)
				sfx.go.play()
			elif ceili(countdown) != before:
				var lit := 5 - ceili(countdown) * 5 / 3
				for li in track.start_lights.size():
					track.start_lights[li].emission = Color(1.0, 0.05, 0.02) if li <= lit else Color(0, 0, 0)
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
	if player.wreck > 0.0: want = cam_dir if cam_dir.length() > 0.5 else want
	cam_dir = cam_dir.slerp(want, 1.0 - exp(-delta * 4.5)).normalized() if cam_dir.length() > 0.5 else want
	var v: float = maxf(body.speed, 0.0)
	var dist: float = 5.8 + v * 0.012 - (0.5 if player.boost else 0.0) + (4.0 if player.wreck > 0.0 else 0.0)
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
	old.debris.queue_free()
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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS   # duraklatmada da arayüz çalışsın
	add_child(layer)
	var root := Control.new()
	_full(root)
	root.theme = _theme()
	layer.add_child(root)
	var pin := Node.new()
	pin.set_script(load("res://scripts/pause_input.gd"))
	pin.toggle.connect(_toggle_pause)
	add_child(pin)

	# --- HUD
	hud = Control.new()
	_full(hud)
	root.add_child(hud)
	var pl := _panel(hud)
	_box(pl, 0, 0, 150, 70, 260, 112)
	var sl := _label("SIRA", 18, pl, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	sl.position = Vector2(20, 8)
	pos_label = _label("10/10", 54, pl, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	pos_label.position = Vector2(18, 26)
	lap_label = _label("TUR 1/2", 20, pl, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	_box(lap_label, 1, 0, -70, 30, 120, 28)
	time_label = _label("0:00.00", 22, pl, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_box(time_label, 1, 0, -70, 62, 120, 30)
	# İlerleme çubuğu (üst orta)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	progress_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.5), 6))
	progress_bar.add_theme_stylebox_override("fill", _flat(ACCENT, 6))
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(progress_bar, 0.5, 0, 0, 26, 420, 12)
	hud.add_child(progress_bar)
	prog_label = _label("0 %", 18, hud, Color(1, 1, 1, 0.85))
	_box(prog_label, 0.5, 0, 0, 48, 200, 26)
	# Duraklat
	var pause_b := _button("II", hud, _toggle_pause)
	pause_b.add_theme_font_size_override("font_size", 26)
	_box(pause_b, 0.5, 0, 0, 92, 64, 52)
	# Mini harita
	minimap = Control.new()
	minimap.set_script(load("res://scripts/minimap.gd"))
	_box(minimap, 1, 0, -128, 118, 220, 200)
	hud.add_child(minimap)
	speedo = Control.new()
	speedo.set_script(load("res://scripts/speedo.gd"))
	if touch_mode: _box(speedo, 0.5, 1, 0, -100, 190, 190)
	else: _box(speedo, 1, 1, -140, -140, 250, 250)
	hud.add_child(speedo)
	big_label = _label("", 150, hud, ACCENT_2)
	_box(big_label, 0.5, 0.4, 0, 0, 800, 190)
	big_label.modulate.a = 0
	popup_label = _label("", 38, hud, Color.WHITE)
	_box(popup_label, 0.5, 0.3, 0, 0, 900, 64)
	popup_label.modulate.a = 0

	# --- Dokunmatik kontroller
	controls = Control.new()
	_full(controls)
	root.add_child(controls)
	zones["left"] = _zone(controls, "◀", 0, 1, 105, -100, 180, 150)
	zones["right"] = _zone(controls, "▶", 0, 1, 300, -100, 180, 150)
	zones["gas"] = _zone(controls, "GAZ", 1, 1, -105, -110, 170, 180, Color(0.1, 0.55, 0.2, 0.55))
	zones["brake"] = _zone(controls, "FREN", 1, 1, -290, -90, 150, 120, Color(0.6, 0.12, 0.1, 0.55))
	zones["handbrake"] = _zone(controls, "DRİFT", 1, 1, -290, -235, 150, 100)
	zones["nitro"] = _zone(controls, "NİTRO", 1, 1, -105, -305, 170, 110, Color(0.05, 0.3, 0.75, 0.55))
	nitro_fill = ColorRect.new()
	nitro_fill.color = Color(0.3, 0.75, 1.0, 0.55)
	nitro_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zones["nitro"].add_child(nitro_fill)
	zones["nitro"].move_child(nitro_fill, 0)
	keys_label = _label("W gaz · S fren/geri · A/D direksiyon · BOŞLUK drift · SHIFT nitro · R piste dön · ESC duraklat", 16, hud, Color(1, 1, 1, 0.65))
	_box(keys_label, 0.5, 1, -80, -20, 1000, 28)
	keys_label.visible = not touch_mode

	# --- Menü (garaj)
	menu = Control.new()
	_full(menu)
	root.add_child(menu)
	var title := _label("HİPER YARIŞ", 64, menu, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	_box(title, 0, 0, 300, 52, 560, 80)
	var sub := _label("KANYON  •  10 ARAÇ  •  2 TUR", 20, menu, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_box(sub, 0, 0, 300, 98, 560, 30)
	var top_r := _panel(menu)
	_box(top_r, 1, 0, -170, 50, 300, 64)
	coin_label = _label("", 26, top_r, ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER)
	coin_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Sol panel: araç bilgisi
	var car_p := _panel(menu)
	_box(car_p, 0, 0.5, 200, 30, 360, 300)
	var gl := _label("GARAJ", 18, car_p, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	gl.position = Vector2(20, 12)
	paint_label = _label("", 26, car_p, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	paint_label.position = Vector2(20, 36)
	paint_label.size = Vector2(330, 70)
	paint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	paint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	stat_bars.clear()
	var y := 118.0
	for st in ["HIZ", "İVME", "TUTUŞ"]:
		var l := _label(st, 18, car_p, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
		l.position = Vector2(20, y)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.12), 4))
		pb.add_theme_stylebox_override("fill", _flat(ACCENT, 4))
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.position = Vector2(110, y + 6)
		pb.size = Vector2(225, 14)
		car_p.add_child(pb)
		stat_bars.append(pb)
		y += 34.0
	var lp := _button("◀", car_p, _paint_step.bind(-1))
	lp.position = Vector2(20, 228)
	lp.size = Vector2(80, 56)
	var rp := _button("▶", car_p, _paint_step.bind(1))
	rp.position = Vector2(260, 228)
	rp.size = Vector2(80, 56)
	price_label = _label("", 22, car_p, ACCENT_2)
	price_label.position = Vector2(100, 238)
	price_label.size = Vector2(160, 36)
	# Sağ panel: yükseltmeler ve ayarlar
	var up_p := _panel(menu)
	_box(up_p, 1, 0.5, -180, 30, 320, 300)
	var ul := _label("YÜKSELTMELER", 18, up_p, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	ul.position = Vector2(20, 12)
	motor_button = _button("", up_p, _upgrade.bind("motor"))
	motor_button.add_theme_font_size_override("font_size", 20)
	motor_button.position = Vector2(20, 46)
	motor_button.size = Vector2(280, 60)
	nitro_button = _button("", up_p, _upgrade.bind("nitro"))
	nitro_button.add_theme_font_size_override("font_size", 20)
	nitro_button.position = Vector2(20, 116)
	nitro_button.size = Vector2(280, 60)
	var sl2 := _label("AYARLAR", 18, up_p, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	sl2.position = Vector2(20, 190)
	quality_button = _button("", up_p, _cycle_quality)
	quality_button.add_theme_font_size_override("font_size", 20)
	quality_button.position = Vector2(20, 222)
	quality_button.size = Vector2(280, 58)
	buy_button = _button("YARIŞ!", menu, _on_main_button)
	buy_button.add_theme_font_size_override("font_size", 40)
	_box(buy_button, 0.5, 1, 0, -70, 380, 86)
	var credit := _label("Araçlar: Eric Chadwick/DGG, ollitei, Han66st, Daniel Zhabotinsky (CC BY 4.0) · Çevre: Poly Haven (CC0) · Ses: Kenney (CC0) · Fizik: Godot Jolt", 13, menu, Color(1, 1, 1, 0.5))
	_box(credit, 0.5, 1, 0, -12, 1200, 20)

	# --- Duraklatma
	pause_menu = Control.new()
	_full(pause_menu)
	root.add_child(pause_menu)
	var pdim := ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.6)
	_full(pdim)
	pdim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(pdim)
	var pt := _label("DURAKLATILDI", 56, pause_menu, Color.WHITE)
	_box(pt, 0.5, 0.25, 0, 0, 700, 80)
	var b1 := _button("DEVAM", pause_menu, _toggle_pause)
	_box(b1, 0.5, 0.45, 0, 0, 340, 76)
	var b2 := _button("YENİDEN BAŞLAT", pause_menu, func(): _toggle_pause(); _start_race())
	_box(b2, 0.5, 0.6, 0, 0, 340, 70)
	var b3 := _button("GARAJ", pause_menu, func(): _toggle_pause(); _go_menu())
	_box(b3, 0.5, 0.75, 0, 0, 340, 70)
	pause_menu.visible = false

	# --- Yarış sonu: sıralama tablosu
	over = Control.new()
	_full(over)
	root.add_child(over)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_full(dim)
	over.add_child(dim)
	over_place = _label("1.", 120, over, ACCENT_2)
	_box(over_place, 0.25, 0.3, 0, 0, 420, 150)
	over_info = _label("", 32, over)
	_box(over_info, 0.25, 0.55, 0, 0, 460, 160)
	var tp := _panel(over, Color(0, 0, 0, 0.55))
	_box(tp, 0.7, 0.45, 0, 0, 520, 500)
	results_box = VBoxContainer.new()
	results_box.position = Vector2(20, 16)
	results_box.size = Vector2(480, 470)
	results_box.add_theme_constant_override("separation", 2)
	tp.add_child(results_box)
	next_button = _button("SONRAKİ YARIŞ", over, _start_race)
	_box(next_button, 0.25, 0.8, 0, 0, 340, 76)
	var garage := _button("GARAJ", over, _go_menu)
	_box(garage, 0.25, 0.92, 0, 0, 240, 56)

	# --- Yükleniyor
	loading = ColorRect.new()
	loading.color = Color(0.06, 0.05, 0.05, 1.0)
	_full(loading)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(loading)
	var lt := _label("HİPER YARIŞ", 72, loading, ACCENT)
	_box(lt, 0.5, 0.45, 0, 0, 800, 90)
	var ll := _label("Yükleniyor…", 26, loading, Color(1, 1, 1, 0.8))
	_box(ll, 0.5, 0.58, 0, 0, 600, 40)
	loading.visible = false


func _flat(c: Color, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	return sb


func _zone(parent: Control, text: String, ax: float, ay: float, ox: float, oy: float, w: float, h: float, color := Color(0.05, 0.07, 0.1, 0.5)) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(minf(w, h) * 0.22))
	sb.corner_detail = 10
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.4)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.clip_contents = true
	_box(p, ax, ay, ox, oy, w, h)
	parent.add_child(p)
	var l := _label(text, 26 if text.length() > 2 else 58, p)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return p


func _toggle_pause() -> void:
	if state != State.RACE and state != State.COUNTDOWN and not get_tree().paused: return
	var p := not get_tree().paused
	get_tree().paused = p
	pause_menu.visible = p
	touches.clear()
	if p: engine.stream_paused = true
	else: engine.stream_paused = false


func _update_hud() -> void:
	if not hud.visible: return
	if Engine.get_process_frames() % 5 == 0 or hud_ranks.is_empty(): hud_ranks = _ranks()
	var ranks := hud_ranks
	pos_label.text = "%d/%d" % [ranks[player.id], cars.size()]
	var prog: float = clampf(player.s / (LAPS * track.length), 0.0, 1.0)
	progress_bar.value = prog
	prog_label.text = "%d %%" % int(prog * 100.0)
	var lap: int = clampi(int(player.s / track.length) + 1, 1, LAPS)
	lap_label.text = "TUR %d/%d" % [lap, LAPS]
	if lap == LAPS and not last_lap_shown and state == State.RACE:
		last_lap_shown = true
		big_label.text = "SON TUR!"
		big_label.add_theme_font_size_override("font_size", 110)
		_pop(big_label)
		sfx.crowd.play()
	speed_lines.emitting = state == State.RACE and (player.boost or absf(player.body.speed) > 62.0)
	time_label.text = _fmt_time(race_time)
	speedo.speed_kmh = absf(player.body.speed) * 3.6
	speedo.nitro = player.nitro
	speedo.boosting = player.boost
	var nz: Control = zones["nitro"]
	nitro_fill.position = Vector2(0, nz.size.y * (1.0 - player.nitro))
	nitro_fill.size = Vector2(nz.size.x, nz.size.y * player.nitro)
	for c in cars:
		if c.tag:
			var r: int = ranks[c.id]
			c.tag.text = "%d.  %s" % [r, c.name]
			c.tag.modulate = ACCENT_2 if r == 1 else Color.WHITE
			var ahead: float = c.s - player.s
			c.tag.visible = ahead > 6.0 and ahead < 90.0 and _ahead_rank(c) < 3
	for name in zones:
		var z: Control = zones[name]
		z.modulate = Color(1.25, 1.25, 1.25, 1.0) if _pressed(name) else Color(1, 1, 1, 0.75)


func _car_stats(i: int) -> Dictionary:
	# Pahalı araçlar daha güçlü ve daha iyi yol tutar
	return {"power": 290.0 + i * 9.0, "grip": 1.0 + i * 0.02}


func _refresh_menu() -> void:
	var p: Dictionary = GARAGE[paint_index]
	var owned: bool = save.paints.has(paint_index)
	paint_label.text = p.name
	var st := _car_stats(paint_index)
	var pw: float = st.power + 22.0 * int(save.motor)
	stat_bars[0].value = clampf((pow(pw, 1.0 / 3.0) - 6.0) / (8.2 - 6.0), 0.05, 1.0)
	stat_bars[1].value = clampf((pw - 260.0) / 260.0, 0.05, 1.0)
	stat_bars[2].value = clampf((st.grip - 0.95) / 0.3, 0.05, 1.0)
	price_label.text = "SAHİPSİN" if owned else "%d ●" % p.price
	price_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if owned else ACCENT_2)
	buy_button.text = "YARIŞ!" if owned else "SATIN AL  %d ●" % p.price
	buy_button.disabled = not owned and int(save.coins) < int(p.price)
	coin_label.text = "● %d     YARIŞ %d" % [save.coins, save.level]
	quality_button.text = "GRAFİK: %s" % ["DÜŞÜK", "ORTA", "YÜKSEK"][quality]
	for pair in [[motor_button, "motor", "MOTOR"], [nitro_button, "nitro", "NİTRO"]]:
		var lvl: int = int(save[pair[1]])
		var b: Button = pair[0]
		var pips := "Sv %d/%d" % [lvl, UPGRADE_COST.size()]
		if lvl >= UPGRADE_COST.size():
			b.text = "%s  %s  MAKS" % [pair[2], pips]
			b.disabled = true
		else:
			b.text = "%s  %s  %d ●" % [pair[2], pips, UPGRADE_COST[lvl]]
			b.disabled = int(save.coins) < UPGRADE_COST[lvl]


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
	var titles := ["ZAFER!", "İKİNCİ!", "ÜÇÜNCÜ!"]
	over_info.text = "%s\nSÜRE  %s\n+%d ●" % [titles[place - 1] if place <= 3 else "%d. SIRA" % place, _fmt_time(race_time), prize]
	next_button.text = "SONRAKİ YARIŞ" if place <= 3 else "TEKRAR DENE"
	controls.visible = false
	hud.visible = false
	speed_lines.emitting = false
	confetti.global_position = player.body.global_position + player.body.global_basis.z * 10.0 + Vector3.UP * 1.0
	confetti.restart()
	sfx.crowd.play()
	await get_tree().create_timer(1.5).timeout
	if state != State.FINISHED: return
	_fill_results()
	over.visible = true
	over.modulate.a = 0.0
	create_tween().tween_property(over, "modulate:a", 1.0, 0.3)
	sfx.coin.play()


func _fill_results() -> void:
	for ch in results_box.get_children(): ch.queue_free()
	var head := _result_row("#", "SÜRÜCÜ", "SÜRE", Color(1, 1, 1, 0.6), false)
	results_box.add_child(head)
	var order: Array = finish_order.duplicate()
	var rest: Array = cars.filter(func(c): return not c.finished)
	rest.sort_custom(func(a, b): return a.s > b.s)
	order.append_array(rest)
	for i in order.size():
		var c: Dictionary = order[i]
		var t: String = _fmt_time(c.time) if c.has("time") else "+%d m" % int(LAPS * track.length - c.s)
		results_box.add_child(_result_row("%d" % (i + 1), c.name, t, ACCENT_2 if c.player else Color.WHITE, c.player))


func _result_row(a: String, b: String, c: String, col: Color, hl: bool) -> Control:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(480, 40)
	row.add_theme_stylebox_override("panel", _flat(Color(1, 0.55, 0.1, 0.25) if hl else Color(1, 1, 1, 0.04), 6))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var la := _label(a, 22, row, col, HORIZONTAL_ALIGNMENT_LEFT)
	la.position = Vector2(14, 4)
	var lb := _label(b, 22, row, col, HORIZONTAL_ALIGNMENT_LEFT)
	lb.position = Vector2(70, 4)
	var lc := _label(c, 22, row, col, HORIZONTAL_ALIGNMENT_RIGHT)
	lc.position = Vector2(300, 4)
	lc.size = Vector2(160, 32)
	return row


## Açılışta tüm araç malzemelerini ve efektleri bir kez çizdirerek shader derleme takılmalarını önler.
func _warmup() -> void:
	loading.visible = true
	var temp: Array = []
	var origin := track.point(-40.0, 0.0)
	var fwd := track.tangent(-40.0)
	var side := fwd.cross(Vector3.UP)
	var i := 0
	for m in MODELS:
		var c := _make_car(m, Color(0.5, 0.5, 0.5), false, -40.0, 0.0)
		c.body.freeze = true
		c.body.global_position = origin + side * ((i % 4) - 1.5) * 2.6 + fwd * (int(i / 4) * 5.0)
		for f in c.flames: f.emitting = true
		_set_smoke(c, true)
		c.sparks.global_position = c.body.global_position + Vector3.UP
		c.sparks.restart()
		c.debris.global_position = c.body.global_position + Vector3.UP
		c.debris.restart()
		temp.append(c)
		i += 1
	camera.global_position = origin - fwd * 12.0 + Vector3.UP * 4.0
	camera.look_at(origin + fwd * 6.0)
	for k in 4: await get_tree().process_frame
	for c in temp:
		c.body.queue_free()
		c.sparks.queue_free()
		c.debris.queue_free()
	loading.visible = false


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
