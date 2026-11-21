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
			line += "%s(r%d %dkm/h x%.1f%s) " % [c.name, r[c.id], int(c.vf * 3.6), c.x, " KAZA" if c.wreck > 0.0 else ""]
		print(line)
	if g.over.visible:
		print("BİTTİ süre=", snappedf(g.race_time, 0.1), " sıra=", g.finish_order.map(func(c): return c.name), " uzunluk=", int(g.track.length))
		get_tree().quit()
	if t > 300: print("zaman aşımı"); get_tree().quit()
