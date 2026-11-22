extends Node
## Başlangıç grid'i yandan + yarışta arkadan oyuncu: yükseklik ve tekerlek kontrolü
var f := 0
var phase := 0
@onready var g := get_parent()
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
func _process(_d: float) -> void:
	f += 1
	if phase == 0 and f == 10:
		g._start_race()
		phase = 1
	if phase == 1 and f == 14:
		# yükseklik raporu: araç altı ile yol arasındaki boşluk
		for c in g.cars:
			var b = c.body
			var road_y: float = g.track.point(c.s, c.x).y
			print("%-8s model=%-12s yerden=%.2f m" % [c.name, c.model_id, b.global_position.y - road_y])
	if phase == 1 and f >= 14 and f < 18:
		g.state = -1
		var p: Vector3 = g.track.point(-35.0, 14.0)
		g.camera.global_position = p + Vector3.UP * 1.5
		g.camera.look_at(g.track.point(-35.0, 0.0) + Vector3.UP * 0.6)
		g.camera.fov = 70
	if phase == 1 and f == 18:
		g.get_viewport().get_texture().get_image().save_png("res://build/shots/grid_side.png")
		g.state = g.State.COUNTDOWN
		g.countdown = 0.01
		phase = 2
	if phase == 2 and f == 60:
		g.get_viewport().get_texture().get_image().save_png("res://build/shots/race_back.png")
		for c in g.cars:
			var b = c.body
			print("%-8s zemin=%d yerden=%.2f" % [c.name, b.on_ground, b.global_position.y - g.track.point(c.s, c.x).y])
		get_tree().quit()
