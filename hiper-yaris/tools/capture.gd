extends Node
## Test: menüyü ve yarışın farklı noktalarını otomatik oynatıp ekran görüntüsü alır.
## godot -- --tool=capture   (çıktı: build/shots/)
## Yazılımsal renderer yavaş olduğu için araçları pist boyunca ileri "ışınlar".
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
	print("shot ", name, " s=", int(p.s), " v=", int(p.vf * 3.6), "kmh rank=", g._ranks()[p.id], " x=", snappedf(p.x, 0.1))

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
					c.pos = g.track.point(c.s, c.x)
					var t: Vector3 = g.track.tangent(c.s)
					c.yaw = atan2(t.x, t.z)
					c.vel = t * 55.0
					c.idx = g.track.idx(c.s)
				g.player.nitro = 1.0 if ji == 1 else 0.4
				if ji == 1: g.player.boost = true
				
			wait += 1
			if wait == 25:
				shot("03_race_%d" % ji); ji += 1; wait = 0
		3:
			pass
			step += 1
		4: if g.over.visible and g.over.modulate.a >= 1.0: shot("04_finish"); step += 1
		5: get_tree().quit()
	if frames > 3000: print("timeout"); get_tree().quit()
