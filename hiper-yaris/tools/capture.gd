extends Node
## Test: menüyü ve yarışın farklı noktalarını otomatik oynatıp ekran görüntüsü alır.
## godot -- --tool=capture   (çıktı: build/shots/)
var frames := 0
var step := 0
var jumps := [300.0, 1100.0, 1900.0]
var ji := 0
var wait := 0
@onready var g := get_parent()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	g.autopilot = true

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % name)
	var p: Dictionary = g.player
	var b = p.body
	var spins := []
	for w in b.wheels: spins.append(snappedf(w.spin, 0.1))
	print("shot ", name, " s=", int(p.s), " v=", int(b.speed * 3.6), "kmh zemin=", b.on_ground, " tekerlek_dönüş=", spins, " sıkışma=", b.wheels.map(func(w): return snappedf(w.comp, 0.01)))

func _process(_d: float) -> void:
	frames += 1
	match step:
		0: if frames == 20: shot("01_menu"); g._start_race(); step += 1
		1: if frames == 32: shot("02_countdown"); g.countdown = 0.01; step += 1
		2:
			if ji >= jumps.size(): get_tree().quit(); return
			if wait == 0:
				var jump: float = jumps[ji] - g.player.s
				for c in g.cars:
					c.s += jump
					c.idx = g.track.idx(c.s)
					c.body.place(g.track.point(c.s, c.x), g.track.tangent(c.s), 50.0)
				g.player.nitro = 1.0
				if ji == 1: g.player.boost = true
			wait += 1
			if wait == 40:
				shot("03_race_%d" % ji); ji += 1; wait = 0
	if frames > 3000: print("timeout"); get_tree().quit()
