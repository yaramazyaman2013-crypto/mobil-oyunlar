extends Node
## Drift dumanı görsel testi: oyuncu el freni + direksiyonla kayar, ekran görüntüsü alınır.
var frames := 0
var ph := 0
@onready var g := get_parent()
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	await get_tree().process_frame
	g._start_race()
	g.countdown = 0.01
func _physics_process(_d: float) -> void:
	if g.state != g.State.RACE: return
	frames += 1
	var p: Dictionary = g.player
	var b = p.body
	if frames == 3:
		for c in g.cars:
			if c != p:
				c.s += 60.0
				c.idx = g.track.idx(c.s)
				c.body.place(g.track.point(c.s, c.x), g.track.tangent(c.s), 30.0)
		p.s = 300.0
		p.idx = g.track.idx(300.0)
		b.place(g.track.point(300.0, -3.0), g.track.tangent(300.0), 34.0)
	if frames > 3:
		b.throttle = 1.0
		b.steer = 0.8 if frames < 110 else -0.6
		b.handbrake = frames > 40 and frames < 110
	if frames == 95: shot("smoke_1")
	if frames == 130: shot("smoke_2"); get_tree().quit()
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % n)
	print("shot ", n, " kayma=", snappedf(g.player.body.slip, 0.01))
