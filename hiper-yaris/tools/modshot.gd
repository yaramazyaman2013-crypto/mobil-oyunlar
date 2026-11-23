extends Node
## Boyalı + neonlu filo, tribün ve modifiye menüsü ekran görüntüleri
var f := 0
@onready var g := get_parent()
func _ready() -> void:
	process_priority = 100
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	await get_tree().process_frame
	var i := 0
	for m in g.MODELS:
		var c: Dictionary = g._make_car(m, Color(0.6, 0.05, 0.05), false, 100.0 + i * 6.0, -3.0, {"look": {"paint": [Color(0.02, 0.14, 0.55), Color(0.95, 0.68, 0.02), Color(0.62, 0.02, 0.03)][i % 3], "neon": Color(0.65, 0.15, 1.0)}})
		c.body.freeze = true
		i += 1
func _process(_d: float) -> void:
	f += 1
	if f < 15:
		g.menu.visible = false
		var mid: float = 100.0 + 4.5 * 6.0
		g.camera.global_position = g.track.point(mid, 10.0) + Vector3.UP * 2.5
		g.camera.look_at(g.track.point(mid, -3.0) + Vector3.UP * 0.5)
		g.camera.fov = 80
	elif f < 30:
		g.camera.global_position = g.track.point(40.0, 4.0) + Vector3.UP * 4.0
		g.camera.look_at(g.track.point(-60.0, -6.0) + Vector3.UP * 3.0)
		g.camera.fov = 70
	elif f == 30:
		g._show_mods(true)
	if f == 14: g.get_viewport().get_texture().get_image().save_png("res://build/shots/mod_fleet.png")
	if f == 29: g.get_viewport().get_texture().get_image().save_png("res://build/shots/stands.png")
	if f == 45:
		g.get_viewport().get_texture().get_image().save_png("res://build/shots/mod_menu.png")
		get_tree().quit()
