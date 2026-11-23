class_name Garage
extends Node3D
## Menüdeki showroom garajı: döner platform, tavan ışıkları, spot ışıklar, lastik yığınları,
## takım dolapları, çalışma tezgâhı ve duvarda oyun adı. Pistten uzakta (yerin altında) durur.

const W := 24.0     # genişlik (x)
const D := 22.0     # derinlik (z)
const H := 7.5      # yükseklik
const ACCENT := Color(1.0, 0.55, 0.12)

var turntable: Node3D
var center := Vector3.ZERO     # aracın durduğu nokta (dünya)


func build(quality: int) -> void:
	center = global_position + Vector3(0, 0.14, 0)
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_texture = load("res://assets/deco/garage_floor.png")
	floor_m.uv1_scale = Vector3(6, 6, 1)
	floor_m.albedo_color = Color(0.55, 0.55, 0.58)
	floor_m.roughness = 0.12
	floor_m.metallic = 0.2
	floor_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var wall_m := StandardMaterial3D.new()
	wall_m.albedo_texture = load("res://assets/deco/garage_wall.png")
	wall_m.uv1_triplanar = true
	wall_m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	wall_m.albedo_color = Color(0.32, 0.33, 0.36)
	wall_m.roughness = 0.45
	wall_m.metallic = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.085, 0.09)
	dark.roughness = 0.6
	var glow := StandardMaterial3D.new()
	glow.albedo_color = ACCENT
	glow.emission_enabled = true
	glow.emission = ACCENT
	glow.emission_energy_multiplier = 2.5
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(1, 1, 1)
	panel.emission_enabled = true
	panel.emission = Color(1.0, 0.97, 0.92)
	panel.emission_energy_multiplier = 3.0

	# Zemin, tavan, duvarlar
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), floor_m)
	_box(Vector3(W, 0.3, D), Vector3(0, H + 0.15, 0), dark)
	_box(Vector3(W, H, 0.3), Vector3(0, H / 2, -D / 2), wall_m)
	_box(Vector3(W, H, 0.3), Vector3(0, H / 2, D / 2), wall_m)
	_box(Vector3(0.3, H, D), Vector3(-W / 2, H / 2, 0), wall_m)
	_box(Vector3(0.3, H, D), Vector3(W / 2, H / 2, 0), wall_m)
	# Süpürgelik ve duvar boyunca turuncu ışık şeridi
	for side in [-1.0, 1.0]:
		_box(Vector3(W, 0.5, 0.05), Vector3(0, 0.25, side * (D / 2 - 0.17)), dark)
		_box(Vector3(0.05, 0.5, D), Vector3(side * (W / 2 - 0.17), 0.25, 0), dark)
		_box(Vector3(W - 0.4, 0.06, 0.04), Vector3(0, 3.2, side * (D / 2 - 0.17)), glow)
		_box(Vector3(0.04, 0.06, D - 0.4), Vector3(side * (W / 2 - 0.17), 3.2, 0), glow)
	# Tavan ışık panelleri
	for x in [-6.0, 0.0, 6.0]:
		for z in [-5.0, 0.0, 5.0]:
			_box(Vector3(3.2, 0.06, 0.7), Vector3(x, H - 0.03, z), panel)

	# Döner platform + parlayan kenar
	turntable = Node3D.new()
	add_child(turntable)
	var plat := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.3
	cm.bottom_radius = 3.4
	cm.height = 0.14
	cm.radial_segments = 64
	plat.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.13, 0.13, 0.14)
	pm.metallic = 0.8
	pm.roughness = 0.3
	plat.material_override = pm
	plat.position.y = 0.07
	turntable.add_child(plat)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.36
	tm.outer_radius = 3.46
	tm.rings = 64
	ring.mesh = tm
	ring.material_override = glow
	ring.position.y = 0.1
	add_child(ring)
	# Lastik yığınları
	var tire := CylinderMesh.new()
	tire.top_radius = 0.36
	tire.bottom_radius = 0.36
	tire.height = 0.26
	tire.radial_segments = 20
	var tire_m := StandardMaterial3D.new()
	tire_m.albedo_color = Color(0.04, 0.04, 0.045)
	tire_m.roughness = 0.85
	for spot in [Vector3(-10.5, 0, -9.0), Vector3(-9.6, 0, -9.3), Vector3(10.3, 0, 8.8), Vector3(-10.4, 0, 8.6)]:
		var n: int = 4 + randi() % 3
		for k in n:
			var t := MeshInstance3D.new()
			t.mesh = tire
			t.material_override = tire_m
			t.position = spot + Vector3(randf_range(-0.03, 0.03), 0.13 + k * 0.26, randf_range(-0.03, 0.03))
			add_child(t)
	# Takım dolapları (kırmızı, çekmece çizgili) ve tezgâh
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.62, 0.04, 0.03)
	red.metallic = 0.6
	red.roughness = 0.35
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 0.9
	steel.roughness = 0.3
	for x in [3.5, 5.1, 6.7]:
		_box(Vector3(1.5, 1.1, 0.6), Vector3(x, 0.55, -D / 2 + 0.5), red)
		for k in 5:
			_box(Vector3(1.3, 0.02, 0.02), Vector3(x, 0.2 + k * 0.18, -D / 2 + 0.81), steel)
	_box(Vector3(4.6, 0.08, 0.8), Vector3(-5.0, 0.95, -D / 2 + 0.55), steel)
	_box(Vector3(4.6, 0.9, 0.05), Vector3(-5.0, 0.45, -D / 2 + 0.2), dark)
	_box(Vector3(4.6, 1.2, 0.04), Vector3(-5.0, 1.9, -D / 2 + 0.17), dark)   # alet panosu

	# Arka duvar: şirket logosu (ışıklı çerçeve içinde)
	var logo := Sprite3D.new()
	logo.texture = load("res://assets/ui/aslan_logo_wall.png")
	logo.pixel_size = 0.0068
	logo.position = Vector3(0, 4.5, -D / 2 + 0.2)
	logo.shaded = false
	add_child(logo)
	_box(Vector3(4.4, 0.06, 0.05), Vector3(0, 2.6, -D / 2 + 0.18), glow)
	# Duvarlarda dikey ışık şeritleri (showroom havası)
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color.WHITE
	strip.emission_enabled = true
	strip.emission = Color(0.85, 0.92, 1.0)
	strip.emission_energy_multiplier = 2.2
	for x in [-9.0, -6.0, -3.5, 3.5, 6.0, 9.0]:
		_box(Vector3(0.12, H - 1.2, 0.04), Vector3(x, H / 2, -D / 2 + 0.18), strip)
	for z in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		for side in [-1.0, 1.0]:
			_box(Vector3(0.04, H - 1.2, 0.12), Vector3(side * (W / 2 - 0.18), H / 2, z), strip)
	# Platformun tam üstünde halka ışık
	var cring := MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 3.0
	ct.outer_radius = 3.25
	ct.rings = 64
	cring.mesh = ct
	cring.material_override = panel
	cring.position = Vector3(0, H - 0.35, 0)
	add_child(cring)

	# Işıklar: platforma bakan spotlar + genel dolgu
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var sp := SpotLight3D.new()
		var p := Vector3(cos(a) * 5.5, H - 0.4, sin(a) * 5.5)
		sp.position = p
		add_child(sp)
		sp.look_at(global_position + Vector3(0, 0.5, 0))
		sp.spot_range = 14.0
		sp.spot_angle = 34.0
		sp.light_energy = 6.0
		sp.light_color = Color(1.0, 0.95, 0.88)
		sp.shadow_enabled = quality >= 1 and a == 0.0
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, H - 1.2, 3.0)
	fill.omni_range = 18.0
	fill.light_energy = 1.4
	add_child(fill)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
