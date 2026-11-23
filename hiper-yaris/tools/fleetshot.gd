extends Node
## Tüm modelleri pistte yan yana dizip iki açıdan çeker
var f := 0
var cs: Array = []
@onready var g := get_parent()
func _ready() -> void:
	process_priority = 100   # ana oyunun kamera kodundan sonra çalış
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	await get_tree().process_frame
	for c in g.cars: c.body.visible = false
	var i := 0
	for m in g.MODELS:
		var s := 100.0 + i * 6.0
		var c: Dictionary = g._make_car(m, Color(0.6, 0.05, 0.05), false, s, -3.0)
		c.body.freeze = true
		cs.append(c)
		i += 1
func _process(_d: float) -> void:
	f += 1
	g.menu.visible = false
	g.hud.visible = false
	var mid: float = 100.0 + float(OS.get_environment("MID") if OS.get_environment("MID") != "" else "4.5") * 6.0
	if f < 15:
		g.camera.global_position = g.track.point(mid, 10.0) + Vector3.UP * 2.5
		g.camera.look_at(g.track.point(mid, -3.0) + Vector3.UP * 0.5)
		g.camera.fov = 80
	else:
		g.camera.global_position = g.track.point(84.0, -1.0) + Vector3.UP * 2.0
		g.camera.look_at(g.track.point(112.0, -3.0) + Vector3.UP * 0.6)
		g.camera.fov = 60
	if f == 14: g.get_viewport().get_texture().get_image().save_png("res://build/shots/fleet_side.png")
	if f == 20:
		g.get_viewport().get_texture().get_image().save_png("res://build/shots/fleet_rear.png")
		get_tree().quit()
