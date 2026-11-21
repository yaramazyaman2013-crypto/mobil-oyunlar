extends Node
## Görüntüsüz hızlı yarış simülasyonu: godot --headless --fixed-fps 30 -- --tool=sim
var t := 0.0
var next := 5.0
@onready var g := get_parent()

func _ready() -> void:
	g.autopilot = true
	g.debug_log = true
	await get_tree().process_frame
	if OS.get_environment("SEED") != "": seed(int(OS.get_environment("SEED")))
	g._start_race()

func _process(delta: float) -> void:
	t += delta
	if g.state == g.State.RACE and g.race_time > next:
		next += 10.0
		var r: Dictionary = g._ranks()
		var line := "t=%.0f " % g.race_time
		for c in g.cars:
			line += "%s(r%d %dkm/h x%.1f y%.1f g%d) " % [c.name, r[c.id], int(c.vf * 3.6), c.x, c.body.global_position.y, c.body.on_ground]
		print(line)
		var p: Dictionary = g.player
		var b = p.body
		print("   oyuncu vt=", snappedf(p.get("vt", 0.0), 0.1), " v=", snappedf(b.speed, 0.1), " gaz=", b.throttle, " fren=", b.brake, " zemin=", b.on_ground, " kayma=", snappedf(b.slip, 0.01), " top=", p.top, " eğim=", snappedf(b.global_basis.z.y, 0.02), " kütle=", b.mass)
	if g.over.visible:
		print("DUVAR_SÜRESİ ", g.cars.map(func(c): return "%s=%.1f" % [c.name, c.get("wall", 0.0)]))
		print("BİTTİ süre=", snappedf(g.race_time, 0.1), " sıra=", g.finish_order.map(func(c): return c.name), " uzunluk=", int(g.track.length))
		get_tree().quit()
	if t > 400: print("zaman aşımı"); get_tree().quit()
